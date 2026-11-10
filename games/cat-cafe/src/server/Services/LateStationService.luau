--!strict
-- #2651 part 4 (late-stations.md): the Oasis Spa (Desert camp, Tier 6) and the Relic Museum (Ruins camp, Tier 7) on
-- the server; the rules are shared/LateStations. Every remote is refused with "Coming soon" until
-- Config.LateStationsOpen (set when UI-Engineer's cards are in), then checks the tier, the range to the station's
-- PromptAnchor (CampExtraRangeStuds plus RANGE_SLACK, as CampExtraService) and everything again inside the handler:
--   SpaPut(slot, uid): the cat leaves its role (earnings settled first) and Auto Equip refills the role.
--   SpaTakeOut(slot): no level gained.
--   SpaCollect(): +1 level for every finished slot, back to the cat room.
--   SpaBuySlot(slot): the next slot, through GoldenFish.trySpend (the one fish-spend helper).
--   MuseumDonate(uid): the copy leaves the save and fills its exhibit; a finished room adds to tips forever.
-- Each answers LateStationResult(stationId, ok, detail) and sends LateStationsState when it changed, also checked
-- every CHECK_SECONDS so a slot finishing turns on its "!". Nothing is sold for Robux (monetization-policy).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local LateStations = require(ReplicatedStorage.Shared.LateStations)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)
local Types = require(ReplicatedStorage.Shared.Types)

local LateStationService = {}

local CHECK_SECONDS = 2
local RANGE_SLACK = 4 -- studs past the prompt's reach, for a character the server sees a moment late

local sent: { [Player]: string } = {} -- the LateStationsState last sent to each player, encoded

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return (root :: BasePart).Position
end

-- Where a station's prompt is: its placed model's PromptAnchor, else the model's pivot, else its Layout spot.
local function anchorOf(stationId: string, areaId: string): Vector3?
	for _, instance in CollectionService:GetTagged(LateStations.TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("StationId") == stationId
		then
			local anchor = instance:FindFirstChild("PromptAnchor", true)
			if anchor ~= nil and anchor:IsA("Attachment") then
				return (anchor :: Attachment).WorldPosition
			end
			return (instance :: Model):GetPivot().Position
		end
	end
	local x, y, z = Layout.lateStationAt(areaId)
	if x ~= nil and y ~= nil and z ~= nil then
		return Vector3.new(x, y + 1.5, z)
	end
	return nil
end

local function inReach(player: Player, stationId: string): boolean
	local area = if stationId == LateStations.SPA
		then LateStations.SPA_AREA
		else LateStations.MUSEUM_AREA
	local position, anchor = rootPosition(player), anchorOf(stationId, area)
	return position ~= nil
		and anchor ~= nil
		and (position - anchor).Magnitude <= Config.CampExtraRangeStuds + RANGE_SLACK
end

local function refresh(player: Player, profile: Types.PlayerProfile, force: boolean)
	local state = LateStations.view(profile, Economy.tier(profile), os.time())
	local encoded = HttpService:JSONEncode(state)
	if force or sent[player] ~= encoded then
		sent[player] = encoded
		Net.fire(player, "LateStationsState", state)
	end
end

local function refuse(player: Player, stationId: string, reason: string)
	Net.toast(player, reason, "warn")
	Net.fire(player, "LateStationResult", stationId, false, {})
end

-- The loaded profile when the station may be used now (open, the tier, in reach), else nil after a refusal.
local function ready(player: Player, stationId: string): Types.PlayerProfile?
	local profile = DataService.get(player)
	if profile == nil then
		return nil
	end
	if not Config.LateStationsOpen then
		refuse(player, stationId, LateStations.Messages.comingSoon)
		return nil
	end
	if not LateStations.isOpen(stationId, Economy.tier(profile)) then
		refuse(
			player,
			stationId,
			if stationId == LateStations.SPA
				then LateStations.Messages.spaShut
				else LateStations.Messages.museumShut
		)
		return nil
	end
	if not inReach(player, stationId) then
		local name = if stationId == LateStations.SPA then "Oasis Spa" else "Relic Museum"
		refuse(player, stationId, string.format("Walk up to the %s first", name))
		return nil
	end
	return profile
end

-- "1-9", "10-19" … "50" for analytics: counts only, never who.
local function band(level: number): string
	if level >= Config.CatMaxLevel then
		return tostring(Config.CatMaxLevel)
	end
	local low = math.floor(level / 10) * 10
	return string.format("%d-%d", math.max(1, low), low + 9)
end

local function catName(catId: string): string
	local def = Catalog.getCat(catId)
	return if def ~= nil then def.name else catId -- the catalog name: a typed name is never put in a toast
end

local function onSpaPut(player: Player, rawSlot: unknown, rawUid: unknown)
	local slot, uid = Guard.int(rawSlot, 1, #Config.SpaSlotPrices), Guard.id(rawUid)
	if slot == nil or uid == nil then
		return
	end
	local profile = ready(player, LateStations.SPA)
	if profile == nil then
		return
	end
	local blocker = LateStations.putBlocker(
		profile,
		Economy.tier(profile),
		slot,
		uid,
		TradeService.isTrading(player) or CafeService.isOffered(player, uid)
	)
	if blocker ~= nil then
		refuse(player, LateStations.SPA, blocker)
		refresh(player, profile, true)
		return
	end
	local instance = profile.cats[uid]
	local working = instance.spotId ~= nil
	if working then
		Economy.settle(profile, os.time(), ClockService.epoch()) -- what it earned so far, at the old rate
	end
	LateStations.put(profile, slot, uid, os.time())
	Telemetry.custom(player, "spa_put", 1, { band(CatStats.level(instance)) })
	Net.fire(player, "LateStationResult", LateStations.SPA, true, { slot = slot, uid = uid })
	if working then
		CafeService.refreshPlot(player)
		CafeService.requestAutoEquip(player) -- a better cat steps into the role it left
	end
	CafeService.sync(player)
	refresh(player, profile, false)
end

local function onSpaTakeOut(player: Player, rawSlot: unknown)
	local slot = Guard.int(rawSlot, 1, #Config.SpaSlotPrices)
	if slot == nil then
		return
	end
	local profile = ready(player, LateStations.SPA)
	if profile == nil then
		return
	end
	local uid = LateStations.takeOut(profile, slot)
	if uid == nil then
		refuse(player, LateStations.SPA, LateStations.Messages.slotEmpty)
		refresh(player, profile, true)
		return
	end
	Net.fire(player, "LateStationResult", LateStations.SPA, true, { slot = slot, uid = uid })
	CafeService.requestAutoEquip(player)
	CafeService.sync(player)
	refresh(player, profile, false)
end

local function onSpaCollect(player: Player)
	local profile = ready(player, LateStations.SPA)
	if profile == nil then
		return
	end
	local relaxed = LateStations.collect(profile, os.time())
	if #relaxed == 0 then
		refuse(player, LateStations.SPA, LateStations.Messages.nothingReady)
		refresh(player, profile, true)
		return
	end
	local gained = 0
	for _, cat in relaxed do
		gained += cat.to - cat.from
		Telemetry.custom(player, "spa_collect", 1, { band(cat.from) })
		Net.toast(
			player,
			string.format("%s relaxed: Lv %d → %d!", catName(cat.catId), cat.from, cat.to),
			"good"
		)
	end
	if gained > 0 then
		profile.stats.catLevelUps = (profile.stats.catLevelUps or 0) + gained
	end
	Net.fire(player, "LateStationResult", LateStations.SPA, true, { relaxed = relaxed })
	CafeService.requestAutoEquip(player) -- a levelled cat may now beat one at work
	CafeService.sync(player) -- also sends CatLevelUp for each
	refresh(player, profile, false)
end

local function onSpaBuySlot(player: Player, rawSlot: unknown)
	local slot = Guard.int(rawSlot, 2, #Config.SpaSlotPrices)
	if slot == nil then
		return
	end
	local profile = ready(player, LateStations.SPA)
	if profile == nil then
		return
	end
	local blocker = LateStations.buyBlocker(
		profile,
		Economy.tier(profile),
		slot,
		profile.goldenFish
	) or TradeService.fishSpendBlocker(player) -- #2745 (section 1d)
	local price = LateStations.nextSlotPrice(profile)
	if blocker ~= nil or price == nil then
		refuse(player, LateStations.SPA, blocker or LateStations.Messages.allOpen)
		refresh(player, profile, true)
		return
	end
	if not GoldenFish.trySpend(profile, price) then
		refuse(player, LateStations.SPA, LateStations.Messages.fish)
		return
	end
	Telemetry.fishSink(player, profile, price, "Shop", "spa_slot")
	profile.spa.slots = slot
	Net.fire(player, "LateStationResult", LateStations.SPA, true, { slot = slot, bought = true })
	CafeService.sync(player)
	refresh(player, profile, false)
end

local function onMuseumDonate(player: Player, rawUid: unknown)
	local uid = Guard.id(rawUid)
	if uid == nil then
		return
	end
	local profile = ready(player, LateStations.MUSEUM)
	if profile == nil then
		return
	end
	local blocker = LateStations.donateBlocker(
		profile,
		Economy.tier(profile),
		uid,
		TradeService.isTrading(player) or CafeService.isOffered(player, uid)
	)
	if blocker ~= nil then
		refuse(player, LateStations.MUSEUM, blocker)
		refresh(player, profile, true)
		return
	end
	local instance = profile.cats[uid]
	local working = instance.spotId ~= nil
	local def = Catalog.getCat(instance.catId)
	-- earnings so far at the old rate, before the cat (and, for a room, the bonus) changes it
	Economy.settle(profile, os.time(), ClockService.epoch())
	local catId, room = LateStations.donate(profile, uid)
	Telemetry.custom(
		player,
		"museum_donate",
		1,
		{ if def ~= nil then def.rarity :: string else "?", instance.variant }
	)
	if room ~= nil then
		local area = Catalog.getArea(room)
		Telemetry.custom(player, "museum_room", #LateStations.roomsDone(profile.museum), { room })
		Net.toast(
			player,
			string.format(
				"%s Hall complete! +%d%% tips forever",
				if area ~= nil then area.name else room,
				math.floor(Config.MuseumRoomTipBonus * 100 + 0.5)
			),
			"good"
		)
	end
	Net.fire(player, "LateStationResult", LateStations.MUSEUM, true, { catId = catId, room = room })
	if working then
		CafeService.requestAutoEquip(player)
	end
	CafeService.refreshPlot(player)
	CafeService.sync(player)
	refresh(player, profile, false)
end

function LateStationService.start()
	Net.on("SpaPut", onSpaPut)
	Net.on("SpaTakeOut", onSpaTakeOut)
	Net.on("SpaCollect", onSpaCollect)
	Net.on("SpaBuySlot", onSpaBuySlot)
	Net.on("MuseumDonate", onMuseumDonate)
	if not Config.LateStationsOpen then
		return -- no state until the cards are in
	end
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

-- Studio-only test hook (Debug): moves every soaking cat's start `seconds` into the past, as if the player had been
-- away that long, and sends the state; returns it.
function LateStationService.debugAway(
	player: Player,
	profile: Types.PlayerProfile,
	seconds: number
): Types.LateStationsState
	for _, soak in profile.spa.soaking do
		soak.at -= seconds
	end
	refresh(player, profile, true)
	return LateStations.view(profile, Economy.tier(profile), os.time())
end

return LateStationService
