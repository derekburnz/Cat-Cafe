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
-- #4702 (Derek 2026-11-16): a first spawn after joining through a friend no longer moves to the friend's front door
-- (F92's palArrival move is gone), so an AFK rest rejoin onto a friend's server lands at home like any other; the
-- PalArrived wave and the #3995 friend-join notes still go out (palJoinedNote), with no area for a location bubble.
-- #3072 (Derek2 2026-11-10: "you spawn with camera inside cannon when rejoining put yourself infront of your cafe"):
-- any other first spawn of a returning player moves to the street outside their own front door (homeArrival).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AfkCafe = require(ReplicatedStorage.Shared.AfkCafe)
local AreaWholeService = require(script.Parent.AreaWholeService)
local CafeRoom = require(ReplicatedStorage.Shared.CafeRoom)
local Cannon = require(ReplicatedStorage.Shared.Cannon)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local DragonKeep = require(ReplicatedStorage.Shared.DragonKeep)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local NightPass = require(ReplicatedStorage.Shared.NightPass)
local NightService = require(script.Parent.NightService)
local PalService = require(script.Parent.PalService)
local PlotService = require(script.Parent.PlotService)
local SecondCat = require(ReplicatedStorage.Shared.SecondCat)
local StreamAround = require(script.Parent.Parent.Util.StreamAround)
local Telemetry = require(script.Parent.Telemetry)
local Tier3Trip = require(ReplicatedStorage.Shared.Tier3Trip)
local TravelService = require(script.Parent.TravelService)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CannonService = {}

local STREAM_TIMEOUT = 2 -- seconds RequestStreamAroundAsync may wait
local FLIGHT_ATTRIBUTES = {
	"Launching",
	"CannonLaunchAt",
	"CannonFrom",
	"CannonTo",
	"CannonHeading",
	Cannon.FLIGHT_SCALE,
}

local world: WorldBuilder.World
local landedAt: { [Player]: number } = {} -- server time each player's last flight ended
local passUsed: { [Player]: boolean } = {} -- #2692: night_pass_used logged this session
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

-- #3198: whether a first flight into `destination` may land at `beside`, the spot next to its waiting stray. The
-- Alleyway's first flight lands beside the beginner's stray wherever it waits (#2913: the alley is open floor from
-- its camp's line on). Any other area's only inside its camp, behind the SAFE ZONE stripe (Cannon.inCampReach):
-- the spot beside a Park stray was behind the camp's fence (#3198), or past the stripe in the gateway (#3886).
local function besideInReach(destination: string, beside: Vector3): boolean
	local camp = Layout.camps[destination]
	if camp == nil or destination == Cannon.OPEN_AREA then
		return true
	end
	local x, z = Layout.campSpace(camp, beside.X, beside.Z)
	return Cannon.inCampReach(x, z, {
		halfAcross = camp.halfAcross,
		depth = Config.World.CampDepth,
		openingHalfWidth = camp.openingHalfWidth,
	})
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
	local others = othersAt(player)
	-- #2913, #2915: a first flight into the Alleyway or the Park comes down beside a waiting stray, facing it, when
	-- that spot is clear; otherwise the pad as always
	local stray = CatService.firstLandingStray(player, destination)
	local centre = Vector3.new(pad.centre.x, pad.centre.y, pad.centre.z)
	local beside = if stray ~= nil then Cannon.besideStray(stray, centre) else nil
	-- #3292: the landing comes no further than BESIDE_MAX_FROM_PAD from the pad, but the camp rule (#3198) still reads
	-- the plain spot by the stray, so a stray behind the fence still sends the flight to the pad
	local byStray = if stray ~= nil then Cannon.besideStray(stray, centre, nil, math.huge) else nil
	if
		stray ~= nil
		and beside ~= nil
		and byStray ~= nil
		and Cannon.isClear(beside, others)
		and besideInReach(destination, beside)
		and besideInReach(destination, byStray)
	then
		local root = Vector3.new(beside.X, beside.Y + 3, beside.Z)
		return CFrame.lookAt(root, Vector3.new(stray.X, root.Y, stray.Z))
	end
	local at = Cannon.landingSpot(spots, others, pad.area)
	local root = Vector3.new(at.X, at.Y + 3, at.Z)
	if stray ~= nil and (Vector3.new(stray.X, root.Y, stray.Z) - root).Magnitude > 1 then
		-- #3198: on the pad, but turned toward the stray the flight could not land beside
		return CFrame.lookAt(root, Vector3.new(stray.X, root.Y, stray.Z))
	end
	return CFrame.new(root) * CFrame.Angles(0, math.rad(pad.centre.rotY or 0), 0)
end

local function refuse(player: Player, destination: string, reason: string)
	Net.toast(player, reason, "warn")
	Net.fire(player, "CannonLaunch", destination, nil)
end

-- #5533 cannonGlow (shared/CannonGlow): a launch to, or a landing in, the glowing area ends the glow
local function clearGlow(player: Player, destination: string)
	local CannonGlow = require(ReplicatedStorage.Shared.CannonGlow) :: any
	if CannonGlow.clears(player:GetAttribute(CannonGlow.ATTR), destination) then
		player:SetAttribute(CannonGlow.ATTR, nil)
	end
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
	-- #4447: Soft Landing skips the wait after a landing
	local landed = if DragonKeep.of(profile).softLanding then nil else landedAt[player]
	-- #2692: a beginner flies at night and in the dusk warning; #3035: a first-session Tier 1 player too
	local pass = NightPass.of(profile, LiveFlagService.on(NightPass.FLAG))
	local reason = Cannon.launchRefusal({
		cannonId = cannonId,
		destination = destination,
		knownCannon = model ~= nil,
		knownDestination = Layout.landingPads[destination] ~= nil
			and (destination == Cannon.TOWN or area ~= nil),
		destinationName = if area ~= nil then area.name else nil,
		destinationTier = if area ~= nil then area.tier else nil,
		destinationFrom = if area ~= nil then area.launchFrom else nil, -- #4070
		destinationFromName = if area ~= nil and area.launchFrom ~= nil
			then (Catalog.getArea(area.launchFrom) or area).name
			else nil,
		tier = Economy.tier(profile),
		areasOpen = NightPass.open(ClockService.areasOpen(), pass),
		duskWarning = not pass
			and Cannon.inDuskWarning(ClockService.phase(), ClockService.phaseEndsAt(), now),
		distance = if root ~= nil and model ~= nil
			then Cannon.reach(root.Position, model:GetPivot().Position) -- #4343: flat, as the ring
			else nil,
		anywhere = LiveFlagService.on(Cannon.ANYWHERE_FLAG), -- #5382
		carrying = CatService.isLoaded(player),
		busy = CatService.inMinigame(player),
		flying = CatService.inFlight(player),
		sinceTackled = if type(shovedAt) == "number" then now - shovedAt else nil,
		sinceLanded = if landed ~= nil then now - landed else nil,
	})
	if reason == nil and (humanoid == nil or (humanoid :: Humanoid).Health <= 0) then
		reason = "Still loading"
	end
	if reason ~= nil or character == nil or root == nil or model == nil then
		-- #4544: a pick refused because the area's Tier is above the player's (the AreaVisit journey)
		if area ~= nil and area.tier > Economy.tier(profile) then
			Telemetry.tripPicked(player, profile, destination, true)
		end
		if destination == Tier3Trip.AREA then
			Telemetry.tier3Stop(player, profile, "refused", reason or "Still loading") -- #5517
		end
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
	-- #4920: the walk-through's flights out are quicker while the firstFlightQuick switch is on (Cannon.flightScale);
	-- set before CannonLaunchAt, so the client reads it with the flight
	local scale = if LiveFlagService.on(Cannon.QUICK_FLAG)
		then Cannon.flightScale(Economy.tier(profile), SecondCat.caught(profile.stats), destination)
		else 1
	flyer:SetAttribute(Cannon.FLIGHT_SCALE, if scale ~= 1 then scale else nil)
	flyer:SetAttribute("Launching", true)
	flyer:SetAttribute("CannonLaunchAt", now)
	flyer:SetAttribute("CannonFrom", cannonId)
	flyer:SetAttribute("CannonTo", destination)
	clearGlow(player, destination) -- #5533 cannonGlow: the first flight there ends the glow
	flyer:SetAttribute("CannonHeading", heading)
	Net.fire(player, "CannonLaunch", destination, now)
	-- Derek 2026-11-18 (areaWhole): the destination area starts streaming in whole now, during the flight
	local wholeTakes = AreaWholeService.heading(player, destination)
	Telemetry.custom(player, "cannon_launch", 1, { cannonId, destination })
	if destination == Tier3Trip.AREA then
		Telemetry.tier3Stop(player, profile, "picked") -- #5517
	end
	if area ~= nil then
		Telemetry.tripPicked(player, profile, destination, false) -- #4544: the AreaVisit journey
	end
	profile.stats.cannonFlights += 1 -- #3618: the Liftoff badge
	if
		pass
		and destination ~= Cannon.TOWN
		and not ClockService.areasOpen()
		and not passUsed[player]
	then
		passUsed[player] = true -- #2692: once a session, a night flight only the pass allowed
		Telemetry.custom(player, "night_pass_used", 1, { destination, ClockService.phase() })
	end
	local launcher = DataService.get(player)
	if launcher ~= nil then
		Telemetry.onboarding(player, launcher, "first_cannon") -- #1273: the way out to the first catch
		Telemetry.cleanEvent(player, launcher, Telemetry.CLEAN_EVENTS.launch) -- #4504: the second trip's launch
	end

	-- this flight is still the character's: not respawned, not left, not a newer flight
	local function current(): boolean
		return player.Parent == Players
			and player.Character == flyer
			and flyer.Parent ~= nil
			and flyer:GetAttribute("CannonLaunchAt") == now
	end
	task.spawn(function()
		local pad = Layout.landingPads[destination]
		if current() and pad ~= nil and not wholeTakes then
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
	task.delay(Config.CannonTeleportAtSeconds * scale, function()
		if current() then
			-- one flight at a time picks its spot, so two moves never share one (section 3b)
			local landing = landingFor(player, destination)
			if landing ~= nil then
				flyer:PivotTo(landing)
			end
		end
	end)
	-- #5269 (landSafe): the feet touch at CannonTouchdownAt, so the character is let go then; the flight's attributes
	-- and the landing's bookkeeping still wait for CannonLaunchSeconds, so the effects and sounds run as before
	local landEarly = LiveFlagService.on(Cannon.LAND_FLAG)
		and type(Config.CannonTouchdownAt) == "number"
		and Config.CannonTouchdownAt < Config.CannonLaunchSeconds
	if landEarly then
		task.delay(Config.CannonTouchdownAt * scale, function()
			if current() then
				body.Anchored = false
			end
		end)
	end
	task.delay(Config.CannonLaunchSeconds * scale, function()
		if not current() then
			return
		end
		body.Anchored = false
		for _, name in FLIGHT_ATTRIBUTES do
			flyer:SetAttribute(name, nil)
		end
		landedAt[player] = serverNow()
		NightService.landed(player) -- a flight into an area that lands after night start is swept at once
		local lander = if area ~= nil then DataService.get(player) else nil
		clearGlow(player, destination) -- #5533 cannonGlow: arrived
		if lander ~= nil then
			Telemetry.cleanEvent(player, lander, Telemetry.arrivedEvent(destination)) -- #4504: arrived
			Telemetry.tripArrived(player, destination) -- #4544
			if destination == Tier3Trip.AREA then
				Telemetry.tier3Stop(player, lander, "landed") -- #5517
			end
		end
	end)
end

-- Just inside the player's own back door, facing it (plot space: -Z faces the street, so the back wall is toward
-- +Z). Nil without a plot.
local function cafeLanding(player: Player): CFrame?
	local plot = PlotService.get(player)
	if plot == nil then
		return nil
	end
	local spot = CafeRoom.point(Layout.plot.respawnSpot, plot.room.width, plot.room.depth) -- #4543
	return plot.cframe * CFrame.new(spot.x, spot.y, spot.z) * CFrame.Angles(0, math.pi, 0)
end

-- #4716 (Derek 2026-11-16): every join, AFK rejoins included, waits Cannon.homeWaitSeconds (2 minutes) and a new
-- player in the bowl first order starts home too.
-- #3072: a returning player's first character of the session moves from the Town Square spawn to the street outside
-- their own front door, facing it (TravelService.homeFront, where the Home button lands). The save and the cafe come
-- a moment after the character (PlotService assigns the plot once the profile has loaded), so this waits for both,
-- up to Cannon.HOME_WAIT_SECONDS, and then moves only a character that still stands at the spawn. The landing's
-- position goes in the player's Cannon.HOME_ATTRIBUTE so their client can put the camera behind them.
local FREE_STRAY_WAIT = 3 -- #5533: seconds a freeStart join waits for its waiting stray before it lands anyway
local function homeArrival(player: Player, character: Model)
	local started = os.clock()
	local profile = DataService.get(player)
	while profile == nil or PlotService.get(player) == nil do
		-- a rest's rejoin waits longer: its save comes once the old server lets go of it (Cannon.homeWaitSeconds)
		local limit = Cannon.homeWaitSeconds(player:GetAttribute(AfkCafe.REJOIN_ATTRIBUTE) == true)
		if
			os.clock() - started >= limit
			or player.Parent ~= Players
			or player.Character ~= character
		then
			return
		end
		task.wait(0.25)
		profile = DataService.get(player)
	end
	if profile == nil then
		return
	end
	-- #5533 (shared/FreeStart): a new save on the play first start begins at the Alleyway landing by day, facing its
	-- waiting stray, as a flight would land it but with no flight; at night (areas shut) it starts as before
	Telemetry.orderJoin(player, profile)
	if
		player:GetAttribute("FreeStart") == true
		and (profile.tutorialStep or 0) < Config.TutorialGuaranteedStrayStep
		and ClockService.areasOpen()
	then
		local waited = 0
		while CatService.firstLandingStray(player, "alley") == nil and waited < FREE_STRAY_WAIT do
			task.wait(0.25) -- the stray tick puts the save's waiting stray on its near point within a second
			waited += 0.25
		end
		local root = rootOf(character)
		local landing = landingFor(player, "alley")
		if
			landing ~= nil
			and root ~= nil
			and player.Character == character
			and character.Parent ~= nil
			and character:GetAttribute("Launching") ~= true
			and not CatService.isLoaded(player)
		then
			StreamAround.wait(player, (landing :: CFrame).Position)
			if player.Character == character and character.Parent ~= nil then
				character:PivotTo(landing :: CFrame)
				Cannon.noteMove(player, landing :: CFrame) -- the camera goes behind the character there
				Telemetry.cleanEvent(player, profile, Telemetry.arrivedEvent("alley"))
				return
			end
		end
	end
	if
		not Cannon.joinsAtHome(
			profile.introSeen,
			-- #3666: the intro test's scene half starts at home as everyone did while the intro played itself
			Telemetry.introPlays(player, profile),
			profile.tutorialStep,
			Config.TutorialGuaranteedStrayStep,
			require(ReplicatedStorage.Shared.TutorialOrder).bowlFirst(player) -- #4716: a new player starts home too
		)
	then
		return
	end
	local landing = TravelService.homeFront(player)
	if landing == nil then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync((landing :: CFrame).Position, STREAM_TIMEOUT)
	end)
	local root = rootOf(character)
	local spawn = Layout.playerSpawn
	if
		root == nil
		or player.Character ~= character
		or character.Parent == nil
		or character:GetAttribute("Launching") == true
		or CatService.isLoaded(player)
		or not Cannon.stillAtSpawn(
			root.Position,
			Vector3.new(spawn.x, spawn.y, spawn.z),
			-- #4967: a new player anywhere in the Town Square still goes to their door
			(profile.tutorialStep or 0) < Config.TutorialGuaranteedStrayStep
		)
	then
		return -- gone, flying, carrying or walked off already: left where they are
	end
	character:PivotTo(landing :: CFrame)
	player:SetAttribute(Cannon.HOME_ATTRIBUTE, (landing :: CFrame).Position)
end

-- #4702: a player who joined through a friend's invite or by following them stays where everyone else spawns, but
-- every client still gets PalArrived(joinerUserId, palUserId, nil) for the wave and the #3995 joined notes; no area,
-- so no friend location bubble.
local function palJoinedNote(player: Player)
	local pal = PalService.joinedVia(player)
	if pal == nil or pal.Parent ~= Players or player.Parent ~= Players then
		return
	end
	Net.fireAll("PalArrived", player.UserId, pal.UserId, nil)
end

-- Where a respawn lands: on its camp's pad after a death in a wild area by day (section 4), on a free spot, else
-- inside its own cafe. A first spawn of the session goes to the player's own front door for a returning player
-- (homeArrival, #3072; also after joining through a friend, #4702), and stays at the hometown spawn, facing the
-- cannon, for a new one.
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
		homeArrival(player, character) -- #3072
		palJoinedNote(player)
		return
	end
	task.wait(0.1) -- after Roblox has placed the character at the town spawn
	if player.Character ~= character or character.Parent == nil or CatService.isLoaded(player) then
		return -- a carrier's death drops its cat first (data-model 10c); this only guards one that could not be dropped
	end
	local profile = DataService.get(player)
	local open = NightPass.open(
		ClockService.areasOpen(),
		profile ~= nil and NightPass.of(profile, LiveFlagService.on(NightPass.FLAG)) -- #2692, #3035
	)
	local landing = if area ~= nil and open then landingFor(player, area) else cafeLanding(player)
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
-- #2651: puts the player's character on a free spot of `destination`'s landing pad, as a flight's landing does; false
-- when there is no character or no pad (FallCatchService's mist catch).
function CannonService.landOnPad(player: Player, destination: string): boolean
	local character = player.Character
	local landing = if character ~= nil then landingFor(player, destination) else nil
	if character == nil or landing == nil then
		return false
	end
	-- #4788: with streaming on, the pad streams in first (yields up to StreamAround.SECONDS; never while it is off)
	if
		StreamAround.wait(player, landing.Position)
		and (player.Character ~= character or character.Parent == nil)
	then
		return false
	end
	character:PivotTo(landing)
	clearGlow(player, destination) -- #5533 cannonGlow: arrived
	return true
end

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
		passUsed[player] = nil
		diedIn[player] = nil
		spawned[player] = nil
	end)
	coverCannons(not ClockService.areasOpen())
	ClockService.changed:Connect(function()
		coverCannons(not ClockService.areasOpen())
	end)
end

return CannonService
