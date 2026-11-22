--!strict
-- Snowglobe Village (snowglobe-village-spec sections 1 and 3). Once the christmasEvent switch is on, this server
-- builds the giant snow globe in the Town Square and the village (World/SnowglobeWorld), once. Off, nothing is built,
-- and switching it off later leaves what is built standing until the server restarts (the dates and the switch keep
-- the portal shut). shared/SnowglobeSave holds the rules; the clock is AdventService.now (Studio's test offset).
-- #5665 part 2, the event row (Harvest Hollow's, with Snowflakes for pumpkins):
--   tripBlocker(player)     why a Travel "snowglobe" trip is refused, or nil: the switch, the dates (Dec 1 20:00 UTC
--                           to the end of Jan 3), Tier 2, the village not built yet. TravelService asks, and lands the
--                           trip at SnowglobeWorld.landing(); a walk into the globe (SnowglobePortalTouch) is one.
--   arrived(player)         the day's first visit gives +40 (SnowglobeSave.visit). TravelService calls it as a trip
--                           lands (a PivotTo fires no Touched); a touch on the SnowglobeArrival pad counts too.
--   The Snowflake patch     every SnowglobeFlake is a pickup the whole server shares: a player who touches a ready
--                           one (root within TOUCH_STUDS plus half its size) gets +1, and it hides and regrows after
--                           SnowglobeSave.regrowSeconds (Harvest's 300 s, 150 s with 6 or more players near).
--                           Attributes for the client: Ready (boolean) and RegrowAt (os.time).
--   The strays              the village is added to CatService (SnowglobeWorld.areaInfo), where a player may catch
--                           only while it is open for them. By day (ClockService.areasOpen), while it is open by the
--                           dates and the switch, one stray of SnowglobeSave.ODDS arrives every TOPUP_SECONDS while
--                           fewer than STRAY_CAP are out. A net catch there gives SnowglobeSave.catchFlakes.
-- Nothing is random but the strays' rarity, and nothing here costs Robux.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catching = require(ReplicatedStorage.Shared.Catching)
local Economy = require(ReplicatedStorage.Shared.Economy)
local SnowglobeSave = require(ReplicatedStorage.Shared.SnowglobeSave)
local Types = require(ReplicatedStorage.Shared.Types)

local AdventService = require(script.Parent.AdventService)
local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local ClockService = require(script.Parent.ClockService)
local DataService = require(script.Parent.DataService)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local SnowglobeWorld = require(script.Parent.Parent.World.SnowglobeWorld)
local Telemetry = require(script.Parent.Telemetry)

local SnowglobeService = {}

SnowglobeService.FLAG = SnowglobeSave.FLAG
SnowglobeService.STEP = 30 -- seconds between switch checks until it is built
SnowglobeService.NEAR_STUDS = 90 -- "players near" for the busy regrow, as Harvest's
SnowglobeService.TOUCH_STUDS = 12 -- a touch counts only with the player's root this close (exploit tools fire touches)
local TOUCH_GAP = 0.5 -- one pick per player per half second, whatever the touch events do

SnowglobeService.portal = nil :: Model?
SnowglobeService.folder = nil :: Folder?
SnowglobeService.area = nil :: any

local built = false -- the village is in the Workspace and CatService knows it
local lastTouch: { [Player]: number } = {}

local function now(): number
	return AdventService.now()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return (instance :: BasePart).Position
	elseif instance:IsA("Model") then
		return (instance :: Model):GetPivot().Position
	end
	return nil
end

local function blocker(profile: Types.PlayerProfile): string?
	return SnowglobeSave.areaBlocker(
		now(),
		Economy.tier(profile),
		LiveFlagService.on(SnowglobeSave.FLAG)
	)
end

local function shut(player: Player): (Types.PlayerProfile?, string?)
	local profile = DataService.get(player)
	if profile == nil then
		return nil, "loading"
	end
	return profile, blocker(profile)
end

local function saveOf(profile: Types.PlayerProfile): SnowglobeSave.Save
	local save = profile.snowglobe
	if save == nil then
		save = SnowglobeSave.fresh()
		profile.snowglobe = save
	end
	return save :: SnowglobeSave.Save
end

local function give(player: Player, profile: Types.PlayerProfile, n: number): number
	local after, added = SnowglobeSave.give(profile.snowflakes, n)
	profile.snowflakes = if after > 0 then after else nil
	if added > 0 then
		CafeService.sync(player)
	end
	return added
end

local function touchedOk(player: Player): boolean
	local clock = os.clock()
	local last = lastTouch[player]
	if last ~= nil and clock - last < TOUCH_GAP then
		return false
	end
	lastTouch[player] = clock
	return true
end

-- Whether the player stands at `instance` (its pivot within TOUCH_STUDS plus half its size of the root).
local function standsAt(player: Player, instance: Instance): boolean
	local root = rootOf(player)
	local at = positionOf(instance)
	if root == nil or at == nil then
		return false
	end
	local reach = SnowglobeService.TOUCH_STUDS
	if instance:IsA("BasePart") then
		reach += (instance :: BasePart).Size.Magnitude / 2
	elseif instance:IsA("Model") then
		reach += (instance :: Model):GetExtentsSize().Magnitude / 2
	end
	return (root.Position - at).Magnitude <= reach
end

local function playersNear(at: Vector3): number
	local count = 0
	for _, other in Players:GetPlayers() do
		local root = rootOf(other)
		if root ~= nil and (root.Position - at).Magnitude <= SnowglobeService.NEAR_STUDS then
			count += 1
		end
	end
	return count
end

-- A picked snowflake hides until it regrows (its Touch box stays, and Ready says whether a touch counts).
local function showFlake(spot: Instance, shown: boolean)
	for _, child in spot:GetDescendants() do
		if child:IsA("BasePart") and child.Name ~= "Touch" then
			local part = child :: BasePart
			local base = part:GetAttribute("SnowglobeBaseTransparency")
			if type(base) ~= "number" then
				base = part.Transparency
				part:SetAttribute("SnowglobeBaseTransparency", base)
			end
			part.Transparency = if shown then base :: number else 1
		end
	end
end

local function pick(spot: Instance, player: Player)
	if
		spot:GetAttribute("Ready") == false
		or not standsAt(player, spot)
		or not touchedOk(player)
	then
		return
	end
	local profile, reason = shut(player)
	local at = positionOf(spot)
	if profile == nil or reason ~= nil or at == nil then
		return
	end
	spot:SetAttribute("Ready", false) -- before anything that yields, so two touches cannot both pick it
	showFlake(spot, false)
	local wait = SnowglobeSave.regrowSeconds(playersNear(at))
	spot:SetAttribute("RegrowAt", os.time() + wait)
	if give(player, profile, 1) > 0 then
		Net.toast(player, "+1 Snowflake", "good")
	end
	task.delay(wait, function()
		if spot.Parent ~= nil then
			spot:SetAttribute("Ready", true)
			spot:SetAttribute("RegrowAt", nil)
			showFlake(spot, true)
		end
	end)
end

function SnowglobeService.arrived(player: Player)
	local profile, reason = shut(player)
	if profile == nil or reason ~= nil then
		return
	end
	local after, added = SnowglobeSave.visit(saveOf(profile), profile.snowflakes, now())
	if added > 0 then
		profile.snowflakes = after
		Net.toast(
			player,
			string.format("Welcome to Snowglobe Village! +%d Snowflakes", added),
			"good"
		)
		CafeService.sync(player)
	end
end

local function arrive(arrival: Instance, player: Player)
	if standsAt(player, arrival) and touchedOk(player) then
		SnowglobeService.arrived(player)
	end
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model ~= nil then Players:GetPlayerFromCharacter(model :: Model) else nil
end

local function touchPartsOf(instance: Instance): { BasePart }
	if instance:IsA("BasePart") then
		return { instance :: BasePart }
	end
	local parts: { BasePart } = {}
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child :: BasePart)
		end
	end
	return parts
end

local function watchTag(tag: string, onTouch: (instance: Instance, player: Player) -> ())
	local function hook(instance: Instance)
		if tag == SnowglobeWorld.FLAKE_TAG and instance:GetAttribute("Ready") == nil then
			instance:SetAttribute("Ready", true)
		end
		for _, part in touchPartsOf(instance) do
			part.Touched:Connect(function(hit: BasePart)
				local player = playerFromHit(hit)
				if player ~= nil then
					onTouch(instance, player)
				end
			end)
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		hook(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
end

-- A net catch in the village gives the cat's Snowflakes (Harvest's 1, 2, 3, 5, 10).
local function onCaught(player: Player, def: Types.CatDef, areaId: string)
	if areaId ~= SnowglobeSave.AREA then
		return
	end
	local profile, reason = shut(player)
	if profile == nil or reason ~= nil then
		return
	end
	local added = give(player, profile, SnowglobeSave.catchFlakes(def.rarity))
	if added > 0 then
		Net.toast(
			player,
			string.format("+%d Snowflake%s", added, if added == 1 then "" else "s"),
			"good"
		)
		Telemetry.custom(player, "snowglobe_catch", added, { def.rarity :: string })
	end
end

function SnowglobeService.tripBlocker(player: Player): string?
	local profile, reason = shut(player)
	if profile == nil then
		return "Still loading"
	end
	if reason ~= nil then
		return reason
	end
	if not built then
		return "Snowglobe Village is getting ready"
	end
	return nil
end

-- The strays' top-up, from the build until the village closes. Stray spawns follow the day like every area's.
local strayRandom = Random.new()
local function strays()
	task.spawn(function()
		while now() < SnowglobeSave.CLOSES_AT do
			task.wait(SnowglobeSave.TOPUP_SECONDS)
			if
				SnowglobeSave.open(now())
				and LiveFlagService.on(SnowglobeSave.FLAG)
				and ClockService.areasOpen()
				and CatService.strayCount(SnowglobeSave.AREA) < SnowglobeSave.STRAY_CAP
			then
				local rarity: Types.Rarity =
					Catching.pickRarity(SnowglobeSave.ODDS :: any, strayRandom:NextNumber()) :: any
				CatService.spawnIn(SnowglobeSave.AREA, rarity)
			end
		end
	end)
end

local function build()
	SnowglobeService.portal = SnowglobeWorld.buildPortal(Workspace)
	local portal = SnowglobeService.portal
	if portal ~= nil then
		-- #5502: the advent calendar board beside the globe; its doors stay shut by date and switch (AdventService)
		local ok, err: any = pcall(SnowglobeWorld.buildAdventBoard, Workspace, portal)
		if not ok then
			warn("[SnowglobeService] advent board failed: " .. tostring(err))
		end
	end
	local folder, info = SnowglobeWorld.buildArea(Workspace)
	SnowglobeService.folder = folder
	SnowglobeService.area = info
	-- #5665: the village as a CatService area, its catches open only while it is open for the player
	CatService.addArea(info, function(profile: Types.PlayerProfile): boolean
		return blocker(profile) == nil
	end)
	built = true
	strays()
end

function SnowglobeService.start()
	CatService.onCaught(onCaught)
	watchTag(SnowglobeWorld.FLAKE_TAG, pick)
	watchTag(SnowglobeWorld.ARRIVAL_TAG, arrive)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastTouch[player] = nil
	end)
	task.spawn(function()
		while not LiveFlagService.on(SnowglobeService.FLAG) do
			task.wait(SnowglobeService.STEP)
		end
		local ok, err: any = pcall(build)
		if not ok then
			warn("[SnowglobeService] build failed: " .. tostring(err))
		end
	end)
end

return SnowglobeService
