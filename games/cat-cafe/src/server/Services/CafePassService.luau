--!strict
-- The Cafe Pass on the server (#1645, cafe-pass.md; rules in shared/CafePass). At each join, and once a minute for
-- everyone here (a season can change while a player plays), the save rolls onto the running season: the old season's
-- reached, unclaimed rewards are paid then (free always, paid if that season's track was bought) and XP and claims
-- reset. Pass XP comes from quests through Payout (prize.passXp). PassClaim(track, level) and PassClaimAll() pay
-- reached rewards: each claim is marked in the same step as its payment, with no yield between, so it pays once.
-- Spins over the banked cap become SPIN_FISH golden fish each. A named item is kept in pass.items forever; the season
-- cat (Maple Muffin, an exclusive pass cat in Catalog.cats) joins the cafe as a gift cat. Sends CafePassState.
-- #1626: ProductService's Cafe Pass receipt calls buyPaid, which unlocks the running season's paid track.
-- PassSetTag picks the chat tag shown (VIP, a season tag or off; ChatTags), and PassService shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CafePass = require(ReplicatedStorage.Shared.CafePass)
local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ChatTags = require(ReplicatedStorage.Shared.ChatTags)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local PassService = require(script.Parent.PassService)
local Payout = require(script.Parent.Payout)
local Spin = require(ReplicatedStorage.Shared.Spin)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local CafePassService = {}

local SPIN_FISH = 10 -- golden fish for each spin the bank has no room for (cafe-pass.md section 2)
local ROLL_SECONDS = 60
local TRACKS: { string } = { "free", "paid" }

local function season(): (number, number, number?)
	return CafePass.seasonAt(os.time(), RunService:IsStudio())
end

-- #1626: the chat tags the player may show (ChatTags.choices): VIP if they own the pass, then their season tags.
local function tagChoices(player: Player, profile: Types.PlayerProfile): { string }
	return ChatTags.choices(PassService.owns(player, Config.VipPassId), profile.pass.items)
end

-- Shows the player's chat tag from their saved pick and items (PassService.setTagPick).
local function applyTag(player: Player, profile: Types.PlayerProfile)
	PassService.setTagPick(player, profile.pass.tag, profile.pass.items)
end

-- Sends the Pass screen its state, with the tag picker's choices and the tag shown now.
function CafePassService.send(player: Player, profile: Types.PlayerProfile)
	local running, startsAt, endsAt = season()
	local view = CafePass.view(profile.pass, running, startsAt, endsAt)
	view.tags = tagChoices(player, profile)
	view.tagShown = ChatTags.shown(
		profile.pass.tag,
		PassService.owns(player, Config.VipPassId),
		profile.pass.items
	)
	Net.fire(player, "CafePassState", view)
end

-- Pays one reward of season `of` (already marked claimed, or owed from a season that ended) and returns its lines.
local function pay(
	player: Player,
	profile: Types.PlayerProfile,
	of: number,
	track: string,
	level: number
): { string }
	local reward = CafePass.rewardOf(of, track :: CafePass.Track, level)
	local paid: { string } = {}
	if reward == nil then
		return paid
	end
	if reward.prize ~= nil then
		local prize = table.clone(reward.prize :: Types.IndexPrize)
		local spins = prize.spins
		if spins ~= nil and spins > 0 then
			prize.spins = nil
			local banked = Spin.bank(profile.spin, spins)
			if banked > 0 then
				table.insert(
					paid,
					string.format("%d spin%s", banked, if banked == 1 then "" else "s")
				)
			end
			if banked < spins then
				prize.fish = (prize.fish or 0) + (spins - banked) * SPIN_FISH
			end
		end
		for _, line in (Payout.pay(player, profile, prize, "cafe_pass_" .. track)) do
			table.insert(paid, line)
		end
	end
	local item = reward.item
	if item ~= nil then
		profile.pass.items[item.id] = true
		if item.kind == "cat" then
			local def = Catalog.getCat(item.id)
			if def ~= nil then
				CafeService.addGiftCat(player, profile, def, CatStats.DEFAULT_CHARM)
			end
		end
		table.insert(paid, item.name)
		if item.kind == "tag" then
			applyTag(player, profile) -- a new season tag shows straight away when nothing else is picked
		end
	end
	Telemetry.custom(player, "cafe_pass_claim", 1, { track, tostring(level), tostring(of) })
	return paid
end

-- Rolls the save onto the running season, paying what the old one still owed. True when anything changed.
local function roll(player: Player, profile: Types.PlayerProfile): boolean
	local running = season()
	local from = profile.pass.season
	if running == 0 or from == running then
		return false
	end
	local owed = CafePass.roll(profile.pass, running)
	local paid: { string } = {}
	for _, claim in owed do
		for _, line in pay(player, profile, claim.season, claim.track, claim.level) do
			table.insert(paid, line)
		end
	end
	if #paid > 0 then
		Net.toast(
			player,
			"Last season's Cafe Pass rewards arrived: " .. table.concat(paid, ", "),
			"good"
		)
	end
	return true
end

local function claim(
	player: Player,
	profile: Types.PlayerProfile,
	track: string,
	level: number
): { string }
	local running = season()
	CafePass.markClaimed(profile.pass, track :: CafePass.Track, level, running)
	return pay(player, profile, running, track, level)
end

local function onClaim(player: Player, rawTrack: unknown, rawLevel: unknown)
	local track = Guard.oneOf(rawTrack, TRACKS)
	local level = Guard.int(rawLevel, 1, Config.PassLevels)
	local profile = DataService.get(player)
	if track == nil or level == nil or profile == nil then
		return
	end
	roll(player, profile)
	local blocker = CafePass.claimBlocker(profile.pass, (season()), track :: CafePass.Track, level)
	if blocker ~= nil then
		Net.toast(player, blocker, "warn")
		CafePassService.send(player, profile)
		return
	end
	local paid = claim(player, profile, track, level)
	if #paid > 0 then
		Net.toast(player, table.concat(paid, ", "), "good")
	end
	CafeService.sync(player)
	CafePassService.send(player, profile)
end

local function onClaimAll(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	roll(player, profile)
	local running = season()
	local paid: { string } = {}
	for _, ready in CafePass.claimable(profile.pass, running) do
		for _, line in claim(player, profile, ready.track, ready.level) do
			table.insert(paid, line)
		end
	end
	if #paid > 0 then
		Net.toast(player, table.concat(paid, ", "), "good")
		CafeService.sync(player)
	end
	CafePassService.send(player, profile)
end

-- The running season (0 while the pass is closed).
function CafePassService.running(): number
	return (season())
end

-- #1626: the Cafe Pass receipt. Rolls the save onto the running season first (so a season still owed is paid with
-- its own track), then unlocks this season's paid track; no yield, so the caller records the receipt in the same
-- step. True when it was bought now, false when this season's track was already the player's.
function CafePassService.buyPaid(player: Player, profile: Types.PlayerProfile): boolean
	roll(player, profile)
	local bought = CafePass.buyPaid(profile.pass, (season()))
	if bought then
		Telemetry.custom(player, "cafe_pass_bought", 1, { tostring(profile.pass.season) })
	end
	return bought
end

-- #1626: PassSetTag(tagId): a tag the player may show now (ChatTags.choices) or "off". Saved as profile.pass.tag.
local function onSetTag(player: Player, rawTag: unknown)
	local profile = DataService.get(player)
	if profile == nil or not ChatTags.validPick(rawTag) then
		return
	end
	local pick = rawTag :: string
	if pick ~= ChatTags.OFF and table.find(tagChoices(player, profile), pick) == nil then
		Net.toast(player, "That tag isn't yours yet", "warn")
		CafePassService.send(player, profile)
		return
	end
	profile.pass.tag = pick
	applyTag(player, profile)
	CafePassService.send(player, profile)
end

function CafePassService.start()
	Net.on("PassClaim", onClaim)
	Net.on("PassClaimAll", onClaimAll)
	Net.on("PassSetTag", onSetTag)
	PassService.changed:Connect(function(player: Player)
		local profile = DataService.get(player)
		if profile ~= nil then
			CafePassService.send(player, profile) -- VIP bought or found late: the picker's choices change
		end
	end)
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		task.defer(function()
			if player.Parent ~= Players then
				return
			end
			if roll(player, profile) then
				CafeService.sync(player)
			end
			applyTag(player, profile)
			CafePassService.send(player, profile)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(ROLL_SECONDS)
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil and roll(player, profile) then
					CafeService.sync(player)
					CafePassService.send(player, profile)
				end
			end
		end
	end)
end

return CafePassService
