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

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CampExtras = require(ReplicatedStorage.Shared.CampExtras)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
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

-- Settles the player's extras and sends CampExtrasState when it differs from the last one sent (or `force`).
local function refresh(player: Player, profile: Types.PlayerProfile, force: boolean)
	local now = os.time()
	local tier = Economy.tier(profile)
	CampExtras.settle(profile.campExtras, tier, now)
	local state = CampExtras.view(profile.campExtras, tier, now)
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

-- The analytics word for what a prize held: "fish", a potion id or a crate id, several joined by "+" in a fixed order.
local function whatOf(prize: Types.IndexPrize): string
	local parts: { string } = {}
	if (prize.fish or 0) > 0 then
		table.insert(parts, "fish")
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
	return table.concat(parts, "+")
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
	-- #1463 (camp-stations.md section 4): a Golden Pond owner collects the pond from anywhere, the same fish a walker
	-- gets. PassService sets the attribute on the server, and a client's own attribute never reaches it.
	local anywhere = extraId == "pond"
		and player:GetAttribute(CampExtras.GOLD_POND_ATTRIBUTE) == true
	if not anywhere and not inReach(player, def) then
		refuse(player, extraId, string.format("Walk up to the %s first", def.name))
		return
	end
	CampExtras.settle(profile.campExtras, tier, now)
	local blocker = CampExtras.collectBlocker(profile.campExtras, extraId, tier, now)
	if blocker ~= nil then
		refuse(player, extraId, blocker)
		refresh(player, profile, true)
		return
	end
	local prize, count = CampExtras.take(profile.campExtras, extraId, tier, now, function(): number
		return random:NextNumber()
	end)
	if prize == nil then
		refuse(player, extraId, "Nothing yet")
		return
	end
	local paid = Payout.pay(player, profile, prize, "camp_extra")
	Telemetry.custom(player, "camp_extra", count, { extraId, whatOf(prize), tostring(tier) })
	Net.fire(player, "CampExtraResult", extraId, true, paid, prize)
	CafeService.sync(player)
	refresh(player, profile, false)
end

local function onBuyYardSale(player: Player, rawCrateId: unknown)
	local crateId = Guard.id(rawCrateId)
	local profile = DataService.get(player)
	if crateId == nil or profile == nil then
		return
	end
	local def = Catalog.getCampExtra(CampExtras.YARD_SALE) :: Types.CampExtraDef
	local tier = Economy.tier(profile)
	local now = os.time()
	CampExtras.settle(profile.campExtras, tier, now)
	if CampExtras.isOpen(CampExtras.YARD_SALE, tier) and not inReach(player, def) then
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

-- #1537: true when the player's tier opens the Yard Sale and they stand within reach of it (LawnService's BuyLawn).
function CampExtraService.atYardSale(player: Player, tier: number): boolean
	local def = Catalog.getCampExtra(CampExtras.YARD_SALE)
	return def ~= nil and CampExtras.isOpen(CampExtras.YARD_SALE, tier) and inReach(player, def)
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
-- been away that long (a UTC day for each 86400 s on the Lost and Found), then settles and sends the state; returns
-- it.
function CampExtraService.debugAway(
	player: Player,
	profile: Types.PlayerProfile,
	seconds: number
): Types.CampExtrasState
	local save = profile.campExtras
	local days = math.floor(seconds / 86400)
	save.picnic.at -= seconds
	save.pond.at -= seconds
	save.lostFound.day -= days
	save.yardSale.lastClaimAt = math.max(0, save.yardSale.lastClaimAt - seconds)
	refresh(player, profile, true)
	return CampExtras.view(save, Economy.tier(profile), os.time())
end

return CampExtraService
