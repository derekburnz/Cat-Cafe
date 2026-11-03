--!strict
-- The store page video's director, server side (Animation-Engineer, 2026-11-03; storyboard
-- /mnt/project-files/Animation-Engineer/trailer/storyboard.md). It lives only in the trailer place that
-- assets/cat-cafe/anim/trailer/trailer.project.json builds, never in the published game, and runs only in a Studio
-- playtest. It stages the scene with the game's own services, so every frame of the video is the real game:
--   * the first player's save becomes a Tier 3 cafe with four cats round the starter Tabby, so the star's check-in
--     takes the Entertainer's spot by the game's own rule, every tip and ask already seen, by day;
--   * the player becomes the default Roblox avatar (R6, Pal Hair, Blue and Black Motorcycle Shirt, Dark Green Jeans);
--   * Rocker Cat is spawned as a real stray down the Alleyway, and the player stands up the lane from it;
--   * the three shovers are built from their catalog outfits for the client to stage (Trailer.Cast).
-- TrailerCamera.client.luau then runs the take: the player's real net swing, catch, carry and camp check-in, the
-- shovers' dives and the cameras. Its "home" cue sends the player to their cafe for the last shot; "reset" stages
-- the scene again for another take.
--
-- It refuses to run while the server's saves reach the real DataStore (a published place with Studio API access),
-- so a take can never change anyone's real save.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local TrailerConfig = require(ReplicatedStorage.TrailerConfig)

if not RunService:IsStudio() then
	return
end

-- Main.server.luau makes this bridge once every service has started (Studio only).
ServerStorage:WaitForChild("CatCafeDebug")

local Server = ServerScriptService.Server
local CafeService = require(Server.Services.CafeService)
local CatService = require(Server.Services.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(Server.Services.ClockService)
local DataService = require(Server.Services.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Layout = require(Server.World.Layout)
local PlotService = require(Server.Services.PlotService)
local Tips = require(ReplicatedStorage.Shared.Tips)

local LOG = "[Trailer]"
local PROFILE_WAIT = 30 -- seconds for the player's save to load
local HOME_STEP_OUT = 6 -- studs out from the front door, as TravelService lands a player at home

if DataService.saves() then
	warn(
		LOG,
		"not staging: this server's saves reach the real DataStore. Build the trailer place with Rojo and open that file"
			.. " (see assets/cat-cafe/anim/trailer/README.md) so no real save changes."
	)
	return
end

-- The shared state the client reads ------------------------------------------------------------------------------

local folder = Instance.new("Folder")
folder.Name = "Trailer"
local cast = Instance.new("Folder")
cast.Name = "Cast"
cast.Parent = folder
local cue = Instance.new("RemoteEvent")
cue.Name = "Cue"
cue.Parent = folder

-- The Alleyway's frame: the name arch's line, the way into the Alleyway (depth) and a home runner's right (across).
local alley = Layout.areas.alley
local arches = alley.arches
local camp = Layout.camps.alley
assert(arches ~= nil and arches[1] ~= nil and camp ~= nil, "the Alleyway has no arch or camp")
local arch = arches[1]
local gate = Vector3.new(arch.x, alley.floorY, arch.z)
local inward = Vector3.new(alley.center.x - gate.X, 0, alley.center.z - gate.Z).Unit
local right = CFrame.lookAt(Vector3.zero, -inward).RightVector
local pad = Vector3.new(camp.pad.x, alley.floorY, camp.pad.z)

local function lanePoint(depth: number, across: number): Vector3
	return gate + inward * depth + right * across
end

folder:SetAttribute("Gate", gate)
folder:SetAttribute("Inward", inward)
folder:SetAttribute("Right", right)
folder:SetAttribute("Pad", pad)
folder:SetAttribute("FloorY", alley.floorY)
folder:SetAttribute("Take", 0)
folder.Parent = ReplicatedStorage
local take = 0

-- Looks ----------------------------------------------------------------------------------------------------------

local function describe(look: TrailerConfig.Look): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local hair: { string } = {}
	for _, id in look.hair do
		table.insert(hair, tostring(id))
	end
	description.HairAccessory = table.concat(hair, ",")
	description.Shirt = look.shirt
	description.Pants = look.pants
	description.Face = look.face
	description.HeadColor = look.skin
	description.TorsoColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.LeftLegColor = look.skin
	description.RightLegColor = look.skin
	return description
end

local function build(look: TrailerConfig.Look, name: string): Model?
	local ok, result = pcall(function(): Model
		return Players:CreateHumanoidModelFromDescription(describe(look), Enum.HumanoidRigType.R6)
	end)
	if not ok then
		warn(LOG, "could not build", name, result)
		return nil
	end
	local model = result :: Model
	model.Name = name
	model.Archivable = true
	model:SetAttribute("NetLevel", look.net)
	return model
end

-- The player's own character: the default avatar as a StarterCharacter (R6 whatever the place's avatar setting), with
-- the Studio user's own outfit kept off it.
local heroModel = build(TrailerConfig.hero, "StarterCharacter")
if heroModel ~= nil then
	StarterPlayer.LoadCharacterAppearance = false
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old ~= nil then
		old:Destroy()
	end
	heroModel.Parent = StarterPlayer
end
for index, shover in TrailerConfig.shovers do
	local model = build(shover.look, "Shover" .. index)
	if model ~= nil then
		model.Parent = cast
	end
end

-- The save -------------------------------------------------------------------------------------------------------

local function waitForProfile(player: Player): any
	local deadline = os.clock() + PROFILE_WAIT
	while player.Parent == Players and os.clock() < deadline do
		local profile = DataService.get(player)
		if profile ~= nil then
			return profile
		end
		task.wait(0.2)
	end
	return nil
end

-- Everything a returning player has long since seen, so no card, ask or tutorial step pops up in a take.
local function quiet(profile: any)
	profile.introSeen = true
	profile.tutorialStep = 5
	local seen = Tips.sanitizeSeen(nil, true)
	for _, id in Tips.ASKS do
		seen[id] = true
	end
	seen[Tips.FEEDBACK_ASK] = true
	seen[Tips.STUCK_HELP] = true
	profile.tipsSeen = seen
	profile.feedbackAsked = true
	local help: { [string]: boolean } = {}
	for step = 0, 5 do
		help[tostring(step)] = true
	end
	profile.stuckHelpShown = help
	profile.starterCatClaimed = true
	profile.notifyAskAt = os.time()
end

local function setUpCafe(player: Player, profile: any)
	quiet(profile)
	profile.tier = math.clamp(TrailerConfig.tier, 1, Catalog.maxTier)
	profile.coins = TrailerConfig.coins
	for id, level in TrailerConfig.upgrades do
		local def = Catalog.getUpgrade(id)
		if def ~= nil then
			profile.upgradeLevels[id] = math.clamp(level, def.startLevel, def.maxLevel)
		end
	end
	for _, id in TrailerConfig.decor do
		if Catalog.getDecor(id) ~= nil then
			profile.decorOwned[id] = true
			profile.decorPlaced[id] = true
		end
	end
	for _, catId in TrailerConfig.cafeCats do
		local def = Catalog.getCat(catId)
		if def ~= nil then
			CafeService.addCaughtCat(player, def, false, profile)
		end
	end
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- The star on its spot for the last shot: the newest one checked in goes on TrailerConfig.starSpot, swapping with
-- whoever stood there (the game's rule already puts it there; this only covers a save that differs).
local function seatStar(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local star: any = nil
	for _, instance in profile.cats do
		if
			instance.catId == TrailerConfig.star
			and (star == nil or instance.caughtAt > star.caughtAt)
		then
			star = instance
		end
	end
	if star == nil or star.spotId == TrailerConfig.starSpot then
		return
	end
	local holder = Economy.catOnSpot(profile, TrailerConfig.starSpot)
	if holder ~= nil then
		holder.spotId = star.spotId
	end
	star.spotId = TrailerConfig.starSpot
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- Every star checked in by a take, so the next take's star is new to the cafe again.
local function forgetStars(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	for uid, instance in profile.cats do
		if instance.catId == TrailerConfig.star then
			profile.cats[uid] = nil
		end
	end
	profile.collection[TrailerConfig.star] = nil
	CafeService.refreshPlot(player)
	CafeService.sync(player)
end

-- The stage ------------------------------------------------------------------------------------------------------

local function strayModel(strayId: string): Model?
	for _, child in CatService.strayFolder():GetChildren() do
		if child:IsA("Model") and child:GetAttribute("StrayId") == strayId then
			return child
		end
	end
	return nil
end

-- Rocker Cat as a real stray, moved to its mark; one still waiting from a take that never caught it is used again.
local function placeStar(): string
	local strayId = folder:GetAttribute("StrayId")
	local model = if type(strayId) == "string" then strayModel(strayId) else nil
	if model == nil then
		strayId = CatService.debugSpawnStray(TrailerConfig.star, "alley")
		model = strayModel(strayId :: string)
	end
	if model ~= nil then
		local at = lanePoint(TrailerConfig.starDepth, TrailerConfig.starAcross)
		local pivot = model:GetPivot()
		local mark = Vector3.new(at.X, pivot.Position.Y, at.Z)
		-- facing up the lane, toward the player coming down it
		model:PivotTo(CFrame.lookAt(mark, mark - inward))
		-- awake for the shot: a nap a wander pause starts is cut short (CatService's nap ends when Napping clears)
		model:GetAttributeChangedSignal("Napping"):Connect(function()
			if model:GetAttribute("Napping") == true then
				model:SetAttribute("Napping", false)
			end
		end)
	end
	return strayId :: string
end

local function placeHero(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local at = lanePoint(TrailerConfig.heroDepth, TrailerConfig.heroAcross) + Vector3.new(0, 3, 0)
	character:PivotTo(CFrame.lookAt(at, at + inward))
end

local function stage(player: Player)
	ClockService.debugSetPhase("day")
	folder:SetAttribute("Ready", false)
	forgetStars(player)
	folder:SetAttribute("StrayId", placeStar())
	placeHero(player)
	take += 1
	folder:SetAttribute("Take", take)
	folder:SetAttribute("Ready", true)
	print(LOG, "staged take", take)
end

-- On the street outside the player's front door, facing it, as TravelService's home landing.
local function sendHome(player: Player)
	local plot = PlotService.get(player)
	local character = player.Character
	if plot == nil or character == nil then
		return
	end
	local door = plot.door.Position
	local doorLocal = plot.cframe:PointToObjectSpace(door)
	local outside =
		plot.cframe:PointToWorldSpace(Vector3.new(doorLocal.X, 3, doorLocal.Z - HOME_STEP_OUT))
	pcall(function()
		player:RequestStreamAroundAsync(outside)
	end)
	character:PivotTo(CFrame.lookAt(outside, Vector3.new(door.X, outside.Y, door.Z)))
end

-- A fresh character in the default look, once the game's own spawn handlers are done with it (CatService sets the
-- walk speed 0.2 s in).
local function respawn(player: Player): boolean
	player:LoadCharacterAsync()
	local character = player.Character
	local root = if character ~= nil then character:WaitForChild("HumanoidRootPart", 10) else nil
	task.wait(0.5)
	return root ~= nil
end

local director: Player? = nil

cue.OnServerEvent:Connect(function(player: Player, what: unknown)
	if player ~= director then
		return
	end
	if what == "home" then
		seatStar(player)
		sendHome(player)
	elseif what == "reset" then
		-- a take stopped with the cat in the arms checks it in first, so no carry outlives the old character
		if CatService.isCarrying(player) then
			CatService.forceCheckIn(player)
		end
		if respawn(player) then
			stage(player)
		end
	end
end)

local function direct(player: Player)
	if director ~= nil then
		return
	end
	director = player
	local profile = waitForProfile(player)
	if profile == nil then
		warn(LOG, "no save loaded for", player.Name)
		return
	end
	setUpCafe(player, profile)
	if respawn(player) then
		stage(player)
	end
end

Players.PlayerAdded:Connect(direct)
for _, player in Players:GetPlayers() do
	task.spawn(direct, player)
end
