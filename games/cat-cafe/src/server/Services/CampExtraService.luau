--!strict
-- The camp extras on the server (F100, camp-extras.md section 4; the rules are shared/CampExtras).
-- CollectCampExtra(extraId) takes everything the Picnic Basket, Fish Pond or Lost and Found holds; BuyYardSale(crateId)
-- takes the Yard Sale's free crate of the day (#1051), banked for the Market, which opens
-- it free. Both check that the player's tier opens the extra's area and that they stand within CampExtraRangeStuds
-- (plus RANGE_SLACK for lag) of its PromptAnchor, then settle the save and check what it holds or sells; a refusal
-- toasts why. Each answers CampExtraResult(extraId, ok, paid, prize) and logs camp_extra (the extra, what was taken, the
-- tier). Since #1537 the Yard Sale also sells the day's lawn rows (shared/YardSale; LawnService takes the BuyLawn),
-- shown as its view's `decor`. CampExtrasState goes to a player on join and whenever their view changes (a fill, a new UTC day, a rank up,
-- a collect or a buy), checked every CHECK_SECONDS for every loaded player, which also keeps a shut extra fresh so it
-- opens with one fill waiting. Golden fish here are earned only: nothing is sold for Robux (monetization-policy).
-- #1732 (camp-stations.md section 4b): a Lost and Found find can be a lost cat, an Epic from the player's open areas
-- (the bait bowl's pick), with the rescue's gold and rainbow chances and the player's own luck. It joins the cafe as a
-- rescued cat (CafeService.addCaughtCat, method "rescue"), with the CatCaught card and the shout-out.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CampExtras = require(ReplicatedStorage.Shared.CampExtras)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Clock = require(ReplicatedStorage.Shared.Clock)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Potions = require(ReplicatedStorage.Shared.Potions)
local RareMomentService = require(script.Parent.RareMomentService)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local YardPick = require(ReplicatedStorage.Shared.YardPick)
local YardSale = require(ReplicatedStorage.Shared.YardSale)

local CampExtraService = {}

local CHECK_SECONDS = 2
local RANGE_SLACK = 4 -- studs past the prompt's reach, for a character the server sees a moment late

local random = Random.new()
local sent: { [Player]: string } = {} -- the CampExtrasState last sent to each player, encoded, so it is not resent

-- Where the player's character stands, or nil.
local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return (root :: BasePart).Position
end

-- Where an extra's prompt is: its placed model's PromptAnchor, else the model's pivot, else its Layout spot.
local function anchorOf(def: Types.CampExtraDef): Vector3?
	for _, instance in CollectionService:GetTagged(CampExtras.TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("ExtraId") == def.id
		then
			local anchor = instance:FindFirstChild("PromptAnchor", true)
			if anchor ~= nil and anchor:IsA("Attachment") then
				return (anchor :: Attachment).WorldPosition
			end
			return (instance :: Model):GetPivot().Position
		end
	end
	local x, y, z = Layout.campExtraAt(def.area)
	if x ~= nil and y ~= nil and z ~= nil then
		return Vector3.new(x, y + 1.5, z)
	end
	return nil
end

-- True when the player stands within reach of the extra's prompt.
local function inReach(player: Player, def: Types.CampExtraDef): boolean
	local position, anchor = rootPosition(player), anchorOf(def)
	return position ~= nil
		and anchor ~= nil
		and (position - anchor).Magnitude <= Config.CampExtraRangeStuds + RANGE_SLACK
end

-- #3093: 2 for a Golden Pond owner (PassService sets the attribute on the server after checking the pass; a client's
-- own attribute never reaches the server), else 1.
local function pondTimes(player: Player): number
	return CampExtras.pondTimes(player:GetAttribute(CampExtras.GOLD_POND_ATTRIBUTE) == true)
end

-- #3614: the Yard Sale's lucky pick, behind its switch.
local function pickOn(): boolean
	return LiveFlagService.on(YardPick.FLAG)
end

-- The Yard Sale's wait in hours when it is not the free crate's (nil while the pick's switch is off).
local function yardHours(): number?
	return if pickOn() then YardPick.hours(true) else nil
end

-- #3715: Picnic Treats, behind its switch: the basket fills by the treats' rule and is taken with a pick.
local function treatsOn(): boolean
	return LiveFlagService.on(CampExtras.TREATS_FLAG)
end

-- #3614: with the pick on, the Yard Sale's view carries this player's rows: what the board shows is what is rolled.
local function addPick(state: Types.CampExtrasState, tier: number)
	if pickOn() and state.yardSale.open then
		state.yardSale.pick = YardPick.rows(tier)
	end
end

-- Settles the player's extras and sends CampExtrasState when it differs from the last one sent (or `force`).
local function refresh(player: Player, profile: Types.PlayerProfile, force: boolean)
	local now = os.time()
	local tier = Economy.tier(profile)
	CampExtras.settle(profile.campExtras, tier, now, treatsOn())
	local state =
		CampExtras.view(profile.campExtras, tier, now, pondTimes(player), yardHours(), treatsOn())
	addPick(state, tier)
	-- #1537: the Yard Sale's second panel, the day's lawn rows (lawn-nursery.md section 7)
	local day = YardSale.dayAt(now)
	YardSale.refresh(profile.yardDecor, day)
	state.yardSale.decor = YardSale.view(profile, profile.yardDecor, day)
	state.yardSale.decorAt = YardSale.restocksAt(day)
	local encoded = HttpService:JSONEncode(state)
	if force or sent[player] ~= encoded then
		sent[player] = encoded
		Net.fire(player, "CampExtrasState", state)
	end
end

-- The analytics word for what a prize held: "fish", "spins", a potion id, a crate id or "lost_cat", several joined
-- by "+" in a fixed order.
local function whatOf(prize: Types.IndexPrize, lostCats: number): string
	local parts: { string } = {}
	if (prize.fish or 0) > 0 then
		table.insert(parts, "fish")
	end
	if (prize.spins or 0) > 0 then
		table.insert(parts, "spins")
	end
	for _, map in { prize.potions, prize.crates } do
		local ids: { string } = {}
		local counts: { [string]: number } = map or {}
		for id in counts do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			table.insert(parts, id)
		end
	end
	if lostCats > 0 then
		table.insert(parts, "lost_cat")
	end
	return table.concat(parts, "+")
end

-- #1732: brings a lost cat of `rarity` to the player's cafe: one of that rarity from the areas their tier opens, its
-- coat rolled like a rescue's with their own gold and rainbow luck, joining as a rescued cat.
local function giveLostCat(
	player: Player,
	profile: Types.PlayerProfile,
	rarity: string,
	tier: number
)
	local rank = Catalog.rarityRank[rarity]
	if rank == nil then
		return
	end
	local def = Catching.pickBaitCat(Catalog.rarityOrder[rank], tier, random:NextNumber())
	local now = os.time()
	local kinds = ClockService.dayKinds()
	local variant = Catching.rollCoat(
		def,
		random:NextNumber(),
		IndexRewards.rainbowChance(
			Clock.rainbowChance(Config.RainbowChanceRescue, kinds),
			IndexRewards.rainbowLuck(profile)
		),
		IndexRewards.rollChance(
			Clock.goldChance(Config.GoldChanceRescue, kinds),
			IndexRewards.totals(profile).goldLuck + Potions.goldLuck(profile, now)
		)
	)
	local instance, isNew = CafeService.addCaughtCat(player, def, true, nil, nil, "rescue", variant)
	Net.fire(player, "CatCaught", def.id, isNew, instance.variant)
	RareMomentService.shoutOut(
		player,
		def.rarity,
		Catching.shoutOut(
			player.DisplayName,
			"found",
			def,
			instance.variant,
			" at the Lost and Found"
		)
	)
end

-- #3361: the warning when the spin bank is full and Lost and Found finds of spins wait for room.
local function spinsFullLine(left: number): string
	return string.format(
		"Spins full: %d %s left at the Lost and Found. Spin, then claim the rest",
		left,
		if left == 1 then "find" else "finds"
	)
end

local function refuse(player: Player, extraId: string, reason: string)
	Net.toast(player, reason, "warn")
	Net.fire(player, "CampExtraResult", extraId, false, {})
end

local function onCollect(player: Player, rawExtraId: unknown)
	local extraId = Guard.oneOf(rawExtraId, CampExtras.COLLECT)
	local profile = DataService.get(player)
	if extraId == nil or profile == nil then
		return
	end
	local def = Catalog.getCampExtra(extraId) :: Types.CampExtraDef
	local tier = Economy.tier(profile)
	local now = os.time()
	if not CampExtras.isOpen(extraId, tier) then
		refuse(
			player,
			extraId,
			CampExtras.collectBlocker(profile.campExtras, extraId, tier, now) :: string
		)
		return
	end
	-- #3082: every extra collects from anywhere (the Cat Cannon's menu has the button), so only the tier above gates
	-- it. Until then only a Golden Pond owner's pond did (#1463); the pass doubles the fish instead (#3093).
	if not CampExtras.FROM_ANYWHERE and not inReach(player, def) then
		refuse(player, extraId, string.format("Walk up to the %s first", def.name))
		return
	end
	if extraId == "picnic" and treatsOn() then
		-- #3715: the basket is a pick now; an old button or a made-up call never takes it as potions
		refuse(player, extraId, "Pick a treat at the Picnic Basket")
		refresh(player, profile, true)
		return
	end
	CampExtras.settle(profile.campExtras, tier, now, treatsOn())
	local blocker = CampExtras.collectBlocker(profile.campExtras, extraId, tier, now)
	if blocker ~= nil then
		refuse(player, extraId, blocker)
		refresh(player, profile, true)
		return
	end
	local prize, count, lostCats = CampExtras.take(
		profile.campExtras,
		extraId,
		tier,
		now,
		function(): number
			return random:NextNumber()
		end,
		pondTimes(player),
		-- #3361: a find of spins is kept here when the bank is full, instead of being paid into it and lost
		math.max(0, Config.SpinBankCap - profile.spin.banked)
	)
	local left = if extraId == "lostFound" then profile.campExtras.lostFound.held else 0
	if prize == nil then
		refuse(player, extraId, if left > 0 then spinsFullLine(left) else "Nothing yet")
		refresh(player, profile, true)
		return
	end
	local paid = Payout.pay(player, profile, prize, "camp_extra")
	Telemetry.onboarding(player, profile, "first_camp_collect") -- #1888
	Telemetry.custom(
		player,
		"camp_extra",
		count,
		{ tostring(extraId), whatOf(prize, #lostCats), tostring(tier) }
	)
	Net.fire(player, "CampExtraResult", extraId, true, paid, prize)
	-- #3361: each lost cat on its own, so an error on one still brings the others, and the sync and the fresh view
	-- always go out (a skipped view left "3 to claim" on screen after a claim had taken them)
	for _, rarity in lostCats do
		local ok, err = pcall(function()
			giveLostCat(player, profile, rarity, tier)
		end)
		if not ok then
			warn(
				string.format(
					"[CampExtras] lost cat (%s) failed for user %d: %s",
					rarity,
					player.UserId,
					tostring(err)
				)
			)
		end
	end
	if left > 0 then
		Net.toast(player, spinsFullLine(left), "warn")
	end
	CafeService.sync(player)
	refresh(player, profile, true)
end

-- #3715: Picnic Treats. The player's pick of one of three fixed treats, each one potion; the timer and the hold are
-- the server's (CampExtras.pickTreat). Free: no coins, fish or Robux are read or taken, nothing shortens the wait and
-- nothing is rolled. From anywhere, as every extra since #3082, so only the tier gates it.
local function onPickTreat(player: Player, rawTreatId: unknown)
	local treatId = Guard.oneOf(rawTreatId, CampExtras.treatIds())
	local profile = DataService.get(player)
	if treatId == nil or profile == nil then
		return
	end
	if not treatsOn() then
		refuse(player, "picnic", "Picnic Treats are not open yet")
		return
	end
	local tier = Economy.tier(profile)
	local prize, why = CampExtras.pickTreat(profile.campExtras, treatId, tier, os.time())
	if prize == nil then
		refuse(player, "picnic", why or "Nothing yet")
		refresh(player, profile, true)
		return
	end
	local paid = Payout.pay(player, profile, prize, "camp_extra")
	Telemetry.onboarding(player, profile, "first_camp_collect") -- #1888
	Telemetry.custom(player, "camp_extra", 1, { "picnic", treatId, tostring(tier) })
	Net.fire(player, "CampExtraResult", "picnic", true, paid, prize)
	CafeService.sync(player)
	refresh(player, profile, true)
end

-- #3614 (camp-stations.md section 3a): the free lucky pick. Rolled from this player's YardPick rows and banked in
-- this one call, so there is nothing to lose between the roll and the crate and nothing a client can choose. Free:
-- no coins, fish or Robux are read or taken, and nothing shortens the wait.
local pickRandom = Random.new()
local function onYardSalePick(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if not pickOn() then
		refuse(player, CampExtras.YARD_SALE, "The lucky pick is not open yet")
		return
	end
	local def = Catalog.getCampExtra(CampExtras.YARD_SALE) :: Types.CampExtraDef
	local tier = Economy.tier(profile)
	local now = os.time()
	CampExtras.settle(profile.campExtras, tier, now, treatsOn())
	if
		not CampExtras.FROM_ANYWHERE -- #3082: the Yard Sale's card opens from the Cat Cannon's menu too
		and CampExtras.isOpen(CampExtras.YARD_SALE, tier)
		and not inReach(player, def)
	then
		refuse(player, CampExtras.YARD_SALE, "Walk up to the Yard Sale first")
		return
	end
	local blocker = CampExtras.pickBlocker(profile.campExtras, tier, now, YardPick.hours(true))
	if blocker ~= nil then
		refuse(player, CampExtras.YARD_SALE, blocker)
		refresh(player, profile, true)
		return
	end
	local rows = YardPick.rows(tier)
	local index = YardPick.pick(rows, pickRandom:NextNumber())
	local row = rows[index]
	local crate = Catalog.getCrate(row.crateId)
	if crate == nil then
		refuse(player, CampExtras.YARD_SALE, "That crate is not at the Yard Sale now")
		return
	end
	profile.crates[row.crateId] = (profile.crates[row.crateId] or 0) + 1
	local yard = profile.campExtras.yardSale
	yard.lastClaimAt = now -- the next pick is YardSaleRollHours from now
	yard.claims += 1
	profile.stats.yardPicks += 1 -- #3694 section 3
	Telemetry.custom(player, "yard_pick", 1, { row.crateId, tostring(tier) })
	local won: Types.IndexPrize = { crates = { [row.crateId] = 1 } }
	Net.fire(player, "YardSalePicked", index, row.crateId, row.tier)
	Net.fire(player, "CampExtraResult", CampExtras.YARD_SALE, true, { "1 " .. crate.name }, won)
	CafeService.sync(player)
	refresh(player, profile, false)
end

local function onBuyYardSale(player: Player, rawCrateId: unknown)
	-- #3614: with the lucky pick on there is no crate to choose; a client still on the old card gets the pick
	if pickOn() then
		onYardSalePick(player)
		return
	end
	local crateId = Guard.id(rawCrateId)
	local profile = DataService.get(player)
	if crateId == nil or profile == nil then
		return
	end
	local def = Catalog.getCampExtra(CampExtras.YARD_SALE) :: Types.CampExtraDef
	local tier = Economy.tier(profile)
	local now = os.time()
	CampExtras.settle(profile.campExtras, tier, now, treatsOn())
	if
		not CampExtras.FROM_ANYWHERE -- #3082: the Yard Sale's card opens from the Cat Cannon's menu too
		and CampExtras.isOpen(CampExtras.YARD_SALE, tier)
		and not inReach(player, def)
	then
		refuse(player, CampExtras.YARD_SALE, "Walk up to the Yard Sale first")
		return
	end
	local blocker = CampExtras.buyBlocker(profile.campExtras, crateId, tier, now)
	local crate = Catalog.getCrate(crateId)
	if blocker ~= nil or crate == nil then
		refuse(player, CampExtras.YARD_SALE, blocker or "That crate is not at the Yard Sale today")
		refresh(player, profile, true)
		return
	end
	-- free since #1051 (crate-prices.md section 5): no fish taken; the take logs as camp_extra below
	profile.crates[crateId] = (profile.crates[crateId] or 0) + 1
	local yard = profile.campExtras.yardSale
	yard.lastClaimAt = now -- the next is YardSaleClaimHours from now (#1154)
	yard.claims += 1
	Telemetry.custom(player, "camp_extra", 1, { CampExtras.YARD_SALE, crateId, tostring(tier) })
	local bought: Types.IndexPrize = { crates = { [crateId] = 1 } }
	Net.fire(player, "CampExtraResult", CampExtras.YARD_SALE, true, { "1 " .. crate.name }, bought)
	CafeService.sync(player)
	refresh(player, profile, false)
end

-- #1537: true when the player's tier opens the Yard Sale and they may buy at it (LawnService's BuyLawn): from
-- anywhere since #3082, within reach of it before.
function CampExtraService.atYardSale(player: Player, tier: number): boolean
	local def = Catalog.getCampExtra(CampExtras.YARD_SALE)
	return def ~= nil
		and CampExtras.isOpen(CampExtras.YARD_SALE, tier)
		and (CampExtras.FROM_ANYWHERE or inReach(player, def))
end

-- #1537: sends the player's CampExtrasState again (after a Yard Sale lawn buy, or a refused one).
function CampExtraService.resend(player: Player)
	local profile = DataService.get(player)
	if profile ~= nil then
		refresh(player, profile, true)
	end
end

function CampExtraService.start()
	Net.on("CollectCampExtra", onCollect)
	Net.on("BuyYardSale", onBuyYardSale)
	Net.on("PickPicnicTreat", onPickTreat)
	Net.on("YardSalePick", function(player: Player)
		onYardSalePick(player)
	end)
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		refresh(player, profile, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sent[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in DataService.loadedPlayers() do
				local profile = DataService.get(player)
				if profile ~= nil then
					refresh(player, profile, false)
				end
			end
		end
	end)
end

-- Studio-only test hooks (Debug.campExtras): moves every extra's clock `seconds` into the past, as if the player had
-- been away that long, then settles and sends the state; returns it.
function CampExtraService.debugAway(
	player: Player,
	profile: Types.PlayerProfile,
	seconds: number
): Types.CampExtrasState
	local save = profile.campExtras
	save.picnic.at -= seconds
	save.pond.at -= seconds
	save.lostFound.at -= seconds
	save.yardSale.lastClaimAt = math.max(0, save.yardSale.lastClaimAt - seconds)
	refresh(player, profile, true)
	local tier = Economy.tier(profile)
	local state = CampExtras.view(save, tier, os.time(), pondTimes(player), yardHours(), treatsOn())
	addPick(state, tier)
	return state
end

return CampExtraService
