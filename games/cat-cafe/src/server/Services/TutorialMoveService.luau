--!strict
-- #2697 part 2: moves a player to their bait bowl as the tutorial reaches the bowl step, and to the Town Square cannon
-- as it reaches the cannon step (shared/TutorialMoves), from CafeService.tutorialStepped. Never while they carry a cat,
-- catch or rescue, or fly; a move skipped that way is not tried again (the client's step pointers still lead them).
-- #3158: the move to the cannon waits TutorialMoves.CANNON_DELAY seconds after the step and is dropped for a player
-- who walked off in that time.
-- Also tags each plot's BaitBowl part for the client's pointers (the cannons carry CatCannon already).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Cannon = require(ReplicatedStorage.Shared.Cannon)
local CatService = require(script.Parent.CatService)
local Layout = require(script.Parent.Parent.World.Layout)
local PlotService = require(script.Parent.PlotService)
local TutorialMoves = require(ReplicatedStorage.Shared.TutorialMoves)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TutorialMoveService = {}

local world: WorldBuilder.World

local ROOT_HEIGHT = 3 -- a standing root above the ground the target stands on

local function stand(at: Vector3, look: Vector3): CFrame
	return CFrame.lookAt(at, at + look)
end

local function targetFor(player: Player, target: TutorialMoves.Target): CFrame?
	if target == "bowl" then
		local plot = PlotService.get(player)
		if plot == nil then
			return nil
		end
		local bowl = plot.baitBowl.Position
		-- out from the plot's middle through the bowl: the front garden side
		local toward = bowl + (bowl - plot.cframe.Position)
		return stand(TutorialMoves.standAt(bowl, toward, TutorialMoves.BOWL_STUDS, ROOT_HEIGHT))
	end
	local cannon: Model? = world.cannons.town
	if cannon == nil then
		return nil
	end
	local spawn = Layout.playerSpawn
	local at = (cannon :: Model):GetPivot().Position
	local ground = Vector3.new(at.X, spawn.y, at.Z)
	return stand(
		TutorialMoves.standAt(
			ground,
			Vector3.new(spawn.x, spawn.y, spawn.z),
			TutorialMoves.CANNON_STUDS,
			ROOT_HEIGHT
		)
	)
end

-- The character's root while a move may happen: nil with no character, or while they carry a cat, catch or rescue, or
-- fly.
local function freeRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if
		root == nil
		or not root:IsA("BasePart")
		or CatService.isLoaded(player)
		or CatService.inMinigame(player)
		or CatService.inFlight(player)
	then
		return nil
	end
	return root :: BasePart
end

local function move(player: Player, target: TutorialMoves.Target)
	local character = player.Character
	if character == nil or freeRoot(player) == nil then
		return
	end
	local landing = targetFor(player, target)
	if landing ~= nil then
		character:PivotTo(landing)
		Cannon.noteMove(player, landing) -- the client's camera goes behind the character there
	end
end

local pending: { [Player]: number } = {} -- the newest waiting move's token, so only that one happens

local function onStepped(player: Player, from: number, to: number)
	local target = TutorialMoves.target(from, to)
	if target == nil then
		return
	end
	local wait = TutorialMoves.delay(target :: TutorialMoves.Target)
	if wait <= 0 then
		move(player, target :: TutorialMoves.Target)
		return
	end
	-- #3158: the move to the cannon waits a beat after the step (#3640: 1 second), and is dropped
	-- when the player has walked off by then, left, or has a cat in hand
	local root = freeRoot(player)
	if root == nil then
		return
	end
	local stood = root.Position
	local token = (pending[player] or 0) + 1
	pending[player] = token
	task.delay(wait, function()
		if pending[player] ~= token then
			return
		end
		pending[player] = nil
		if player.Parent == nil then
			return
		end
		local now = freeRoot(player)
		if now ~= nil and TutorialMoves.stayed(stood, now.Position) then
			move(player, target :: TutorialMoves.Target)
		end
	end)
end

function TutorialMoveService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	for _, plot in world.plots do
		CollectionService:AddTag(plot.baitBowl, TutorialMoves.BOWL_TAG)
	end
	CafeService.tutorialStepped:Connect(onStepped)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return TutorialMoveService
