--!strict
-- The Cat Cannon (F84, docs/design/cat-cafe/hometown-cannon.md sections 3, 5 and 7). LaunchCannon(cannonId,
-- destination) from a player at a cannon is checked by shared/Cannon.launchRefusal. An accepted flight anchors the
-- character at the barrel's Seat with Launching, CannonLaunchAt, CannonFrom, CannonTo and CannonHeading (the flat
-- unit Vector3 from the cannon toward the landing pad, for the flight's arc; Derek 2026-11-03: the flight should
-- carry on toward where it goes) set, so every client plays the flight from them, and sends CannonLaunch(destination,
-- launchAt) to the caller for the camera and the name card. The destination starts streaming in at the launch.
-- At CannonTeleportAtSeconds, inside the clouds, the still anchored character moves onto a free spot of the
-- destination's landing pad, and at CannonLaunchSeconds it is let go and the attributes clear together. A refusal
-- answers with a toast and CannonLaunch(destination, nil). A character that dies in a wild area by day comes back on
-- its camp's pad (section 4); any other respawn comes back just inside its own cafe's back door (Layout.plot's
-- respawnSpot, Derek 2026-10-28 01:17), never a carrier. Every cannon's moon cover (its ..._MoonCover model) is down
-- over the barrel while the areas are closed and lifted by day (section 3a: "At dusk a moon cover drops").
-- F92 (playing-together.md section 5): a first spawn after joining through a pal's invite or by following them stands
-- at that pal's front door instead (palArrival).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Cannon = require(ReplicatedStorage.Shared.Cannon)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local NightService = require(script.Parent.NightService)
local PalService = require(script.Parent.PalService)
local PlotService = require(script.Parent.PlotService)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CannonService = {}

local STREAM_TIMEOUT = 2 -- seconds RequestStreamAroundAsync may wait
local FLIGHT_ATTRIBUTES =
	{ "Launching", "CannonLaunchAt", "CannonFrom", "CannonTo", "CannonHeading" }

local world: WorldBuilder.World
local landedAt: { [Player]: number } = {} -- server time each player's last flight ended
local diedIn: { [Player]: string } = {} -- the wild area a character died in by day, for its respawn
local spawned: { [Player]: boolean } = {} -- the player has had a character this session, so the next is a respawn

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(character: Model?): BasePart?
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- Every other character's root, for the landing spots.
local function othersAt(player: Player): { Vector3 }
	local list: { Vector3 } = {}
	for _, other in Players:GetPlayers() do
		local root = if other ~= player then rootOf(other.Character) else nil
		if root ~= nil then
			table.insert(list, root.Position)
		end
	end
	return list
end

-- The way a flight from `cannon` to `destination` heads (Cannon.heading): toward the landing pad's centre.
local function headingFor(cannon: Model, destination: string, seat: CFrame): Vector3
	local pad = Layout.landingPads[destination]
	local to = if pad ~= nil then Vector3.new(pad.centre.x, pad.centre.y, pad.centre.z) else nil
	return Cannon.heading(cannon:GetPivot().Position, to, seat.LookVector)
end

-- A free spot on `destination`'s landing pad (section 3b) as the root's CFrame, facing the way the pad faces; nil
-- for a place with no pad.
local function landingFor(player: Player, destination: string): CFrame?
	local pad = Layout.landingPads[destination]
	if pad == nil then
		return nil
	end
	local spots: { Vector3 } = {}
	for _, spot in pad.spots do
		table.insert(spots, Vector3.new(spot.x, spot.y, spot.z))
	end
	local at = Cannon.landingSpot(spots, othersAt(player), pad.area)
	return CFrame.new(at.X, at.Y + 3, at.Z) * CFrame.Angles(0, math.rad(pad.centre.rotY or 0), 0)
end

local function refuse(player: Player, destination: string, reason: string)
	Net.toast(player, reason, "warn")
	Net.fire(player, "CannonLaunch", destination, nil)
end

local function onLaunchCannon(player: Player, rawCannonId: unknown, rawDestination: unknown)
	local cannonId, destination = Guard.id(rawCannonId), Guard.id(rawDestination)
	local profile = DataService.get(player)
	if cannonId == nil or destination == nil or profile == nil then
		return
	end
	local character = player.Character
	local root = rootOf(character)
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local model: Model? = world.cannons[cannonId]
	local area = if destination ~= Cannon.TOWN then Catalog.getArea(destination) else nil
	local now = serverNow()
	local shovedAt = if character ~= nil then character:GetAttribute("ShovedAt") else nil
	local landed = landedAt[player]
	local reason = Cannon.launchRefusal({
		cannonId = cannonId,
		destination = destination,
		knownCannon = model ~= nil,
		knownDestination = Layout.landingPads[destination] ~= nil
			and (destination == Cannon.TOWN or area ~= nil),
		destinationName = if area ~= nil then area.name else nil,
		destinationTier = if area ~= nil then area.tier else nil,
		tier = Economy.tier(profile),
		areasOpen = ClockService.areasOpen(),
		duskWarning = Cannon.inDuskWarning(ClockService.phase(), ClockService.phaseEndsAt(), now),
		distance = if root ~= nil and model ~= nil
			then (root.Position - model:GetPivot().Position).Magnitude
			else nil,
		carrying = CatService.isCarrying(player),
		busy = CatService.inMinigame(player),
		flying = CatService.inFlight(player),
		sinceTackled = if type(shovedAt) == "number" then now - shovedAt else nil,
		sinceLanded = if landed ~= nil then now - landed else nil,
	})
	if reason == nil and (humanoid == nil or (humanoid :: Humanoid).Health <= 0) then
		reason = "Still loading"
	end
	if reason ~= nil or character == nil or root == nil or model == nil then
		refuse(player, destination, reason or "Still loading")
		return
	end
	local flyer = character :: Model
	local body = root :: BasePart
	local cannon = model :: Model
	-- every cannon (town and camps) turns to the landing pad, so the barrel, the seat and CannonHeading agree and the
	-- flight is one arc with no turn in the air (#1205); a pad under the cannon keeps the seat's own look
	local heading = headingFor(cannon, destination, WorldBuilder.cannonSeat(cannon))
	local fireTurn = (cannon:GetAttribute("FireTurn") :: number?) or 0
	WorldBuilder.aimCannon(cannon, Cannon.aimTurn(heading, fireTurn))
	local seat = WorldBuilder.cannonSeat(cannon)
	body.Anchored = true
	flyer:PivotTo(seat)
	flyer:SetAttribute("Launching", true)
	flyer:SetAttribute("CannonLaunchAt", now)
	flyer:SetAttribute("CannonFrom", cannonId)
	flyer:SetAttribute("CannonTo", destination)
	flyer:SetAttribute("CannonHeading", heading)
	Net.fire(player, "CannonLaunch", destination, now)
	Telemetry.custom(player, "cannon_launch", 1, { cannonId, destination })

	-- this flight is still the character's: not respawned, not left, not a newer flight
	local function current(): boolean
		return player.Parent == Players
			and player.Character == flyer
			and flyer.Parent ~= nil
			and flyer:GetAttribute("CannonLaunchAt") == now
	end
	task.spawn(function()
		local pad = Layout.landingPads[destination]
		if current() and pad ~= nil then
			local centre = pad.centre
			-- with StreamingEnabled off this has nothing to do; it can also time out, which only means pop-in
			pcall(function()
				player:RequestStreamAroundAsync(
					Vector3.new(centre.x, centre.y, centre.z),
					STREAM_TIMEOUT
				)
			end)
		end
	end)
	task.delay(Config.CannonTeleportAtSeconds, function()
		if current() then
			-- one flight at a time picks its spot, so two moves never share one (section 3b)
			local landing = landingFor(player, destination)
			if landing ~= nil then
				flyer:PivotTo(landing)
			end
		end
	end)
	task.delay(Config.CannonLaunchSeconds, function()
		if not current() then
			return
		end
		body.Anchored = false
		for _, name in FLIGHT_ATTRIBUTES do
			flyer:SetAttribute(name, nil)
		end
		landedAt[player] = serverNow()
		NightService.landed(player) -- a flight into an area that lands after night start is swept at once
	end)
end

-- Just inside the player's own back door, facing it (plot space: -Z faces the street, so the back wall is toward
-- +Z). Nil without a plot.
local function cafeLanding(player: Player): CFrame?
	local plot = PlotService.get(player)
	if plot == nil then
		return nil
	end
	local spot = Layout.plot.respawnSpot
	return plot.cframe * CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, math.pi, 0)
end

-- F92 (playing-together.md section 5): a player who joined through a pal's invite or by following them starts on the
-- path just out from that pal's front door, facing the street (Layout.plot.palArrival), new players too. Then every
-- client gets PalArrived(joinerUserId, palUserId, palArea) for the wave from both characters, and the joiner's HUD
-- says where the pal is: palArea is the catching area the pal stands in, nil in town or a cafe.
local function palArrival(player: Player, character: Model)
	local pal = PalService.joinedVia(player)
	local plot = if pal ~= nil then PlotService.get(pal) else nil
	if pal == nil or plot == nil then
		return
	end
	task.wait(0.1) -- after Roblox has placed the character at the town spawn
	local spot = Layout.plot.palArrival
	local landing = plot.cframe * CFrame.new(spot.x, spot.y, spot.z) -- plot space -Z is the street
	pcall(function()
		player:RequestStreamAroundAsync(landing.Position, 2)
	end)
	if player.Character ~= character or character.Parent == nil or pal.Parent ~= Players then
		return
	end
	character:PivotTo(landing)
	local palRoot = rootOf(pal.Character)
	local area = if palRoot ~= nil then WorldBuilder.areaAt(world, palRoot.Position) else nil
	Net.fireAll("PalArrived", player.UserId, pal.UserId, area)
end

-- Where a respawn lands: on its camp's pad after a death in a wild area by day (section 4), on a free spot, else
-- inside its own cafe. A first spawn of the session stays at the hometown spawn, facing the cannon, unless the player
-- joined through a pal (palArrival).
local function watchCharacter(player: Player, character: Model, respawn: boolean)
	local area = diedIn[player]
	diedIn[player] = nil
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid ~= nil and humanoid:IsA("Humanoid") then
		(humanoid :: Humanoid).Died:Connect(function()
			local root = rootOf(character)
			if root ~= nil and character:GetAttribute("Launching") ~= true then
				local where = WorldBuilder.areaAt(world, root.Position)
				if where ~= nil and Layout.landingPads[where] ~= nil then
					diedIn[player] = where
				end
			end
		end)
	end
	if character:WaitForChild("HumanoidRootPart", 10) == nil then
		return
	end
	if not respawn then
		palArrival(player, character)
		return
	end
	task.wait(0.1) -- after Roblox has placed the character at the town spawn
	if
		player.Character ~= character
		or character.Parent == nil
		or CatService.isCarrying(player)
	then
		return -- a carrier's death drops its cat first (data-model 10c); this only guards one that could not be dropped
	end
	local landing = if area ~= nil and ClockService.areasOpen()
		then landingFor(player, area)
		else cafeLanding(player)
	if landing == nil then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync((landing :: CFrame).Position, 2)
	end)
	if player.Character == character and character.Parent ~= nil then
		character:PivotTo(landing :: CFrame)
	end
end

-- Down over every cannon's barrel while the areas are closed, lifted by day. Each part keeps the Transparency it
-- was built with in its CoverTransparency attribute, which the intro reads for its own night (intro-cutscene.md 2a).
local function coverCannons(covered: boolean)
	for _, cannon in world.cannons do
		for _, item in cannon:GetDescendants() do
			if item:IsA("Model") and item.Name:sub(-10) == "_MoonCover" then
				for _, piece in item:GetDescendants() do
					if piece:IsA("BasePart") then
						local part = piece :: BasePart
						local shown = part:GetAttribute("CoverTransparency")
						if type(shown) ~= "number" then
							shown = part.Transparency
							part:SetAttribute("CoverTransparency", shown)
							part:SetAttribute("CoverCollides", part.CanCollide)
						end
						part.Transparency = if covered then shown :: number else 1
						part.CanCollide = covered and part:GetAttribute("CoverCollides") == true
					end
				end
			end
		end
	end
end

-- After CatService, TravelService and NightService.
function CannonService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	Net.on("LaunchCannon", onLaunchCannon)
	local function joined(player: Player)
		spawned[player] = player.Character ~= nil -- a player already here at start has spawned once (review N227)
		player.CharacterAdded:Connect(function(character)
			local respawn = spawned[player] == true
			spawned[player] = true
			watchCharacter(player, character, respawn)
		end)
		if player.Character ~= nil then
			task.spawn(watchCharacter, player, player.Character, false)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		landedAt[player] = nil
		diedIn[player] = nil
		spawned[player] = nil
	end)
	coverCannons(not ClockService.areasOpen())
	ClockService.changed:Connect(function()
		coverCannons(not ClockService.areasOpen())
	end)
end

return CannonService
