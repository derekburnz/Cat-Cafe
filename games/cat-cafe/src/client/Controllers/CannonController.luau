--!strict
-- The Cat Cannon on this client (F84, docs/design/cat-cafe/hometown-cannon.md sections 3, 4 and 7). Holding a
-- cannon's "Hop in" prompt opens the picker (UI.cannon.open); Launch fires LaunchCannon; CannonLaunch from the
-- server starts the name card in the clouds (UI.cannon.flight) or brings a refused Launch back (UI.cannon.result);
-- CampCheckIn fires Moments.CampCheckIn for the effects and the chime and, for this player's own cat, the check-in
-- toast. The prompts hide while this player carries a cat or flies. The UI's cannon mode is on from the start (the
-- Cannon and Home buttons); WorldController tells the UI which wild area the character is in.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cannon = require(Shared:WaitForChild("Cannon"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local CannonController = {}

local player = Players.LocalPlayer
local PROMPT_REFRESH_SECONDS = 0.2
local TAG = "CatCannon"

local prompts: { [Model]: ProximityPrompt } = {}
local lastCarried: string? = nil -- the CatId this player carried last, for the camp check-in toast

local function flying(): boolean
	local character = player.Character
	return character ~= nil
		and (
			character:GetAttribute("Launching") == true
			or character:GetAttribute("CloudHopAt") ~= nil
		)
end

-- Shown to anyone not carrying and not flying (section 3a); the server checks everything again.
local function refreshPrompts()
	local state = UIController.state
	local shown = state ~= nil and state.carrying == nil and not flying()
	for _, prompt in prompts do
		prompt.Enabled = shown
	end
end

local function watchCannon(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	local function hook(prompt: ProximityPrompt)
		prompts[model] = prompt
		prompt.Triggered:Connect(function(who: Player)
			if who == player then
				local id = model:GetAttribute("CannonId")
				UI.cannon.open(if type(id) == "string" then id else nil)
			end
		end)
	end
	local found = model:FindFirstChild("CannonPrompt", true)
	if found ~= nil and found:IsA("ProximityPrompt") then
		hook(found :: ProximityPrompt)
	else
		local waiting: RBXScriptConnection? = nil
		waiting = model.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == "CannonPrompt" and descendant:IsA("ProximityPrompt") then
				if waiting ~= nil then
					waiting:Disconnect()
				end
				hook(descendant :: ProximityPrompt)
			end
		end)
	end
	if model:GetAttribute("CannonId") == "town" then
		local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		UI.cannon.setCannon(if part ~= nil then part :: BasePart else nil)
	end
end

local function watchCharacter(character: Model)
	local function remember()
		local catId = character:GetAttribute("CarryingCatId")
		if type(catId) == "string" then
			lastCarried = catId
		end
	end
	remember()
	character:GetAttributeChangedSignal("CarryingCatId"):Connect(remember)
end

-- #3072 (Derek2 2026-11-10: "you spawn with camera inside cannon when rejoining"): the game's camera starts looking
-- north whichever way the character faces, and at the Town Square spawn that put it inside the Cat Cannon. This puts
-- it behind the character, looking the way they face, for a few frames (a spawn resets the camera once more a frame
-- or two in); the game's camera keeps that way after. Left alone while a script holds the camera (the intro, a
-- flight).
local AIM_FRAMES = 4

local function aimBehind(character: Model, near: Vector3?)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root == nil or not root:IsA("BasePart") then
			return
		end
		local part = root :: BasePart
		if near ~= nil then
			-- the server's move reaches this client a moment after the attribute may
			local deadline = os.clock() + 2
			while
				(part.Position - near).Magnitude > Cannon.HOME_SPAWN_STUDS
				and os.clock() < deadline
			do
				task.wait()
			end
		end
		for _ = 1, AIM_FRAMES do
			local camera = Workspace.CurrentCamera
			if
				player.Character ~= character
				or camera == nil
				or camera.CameraType ~= Enum.CameraType.Custom
			then
				return
			end
			local from, focus = Cannon.cameraBehind(part.Position, part.CFrame.LookVector)
			camera.CFrame = CFrame.lookAt(from, focus)
			RunService.RenderStepped:Wait()
		end
	end)
end

function CannonController.start()
	UI.cannon.setEnabled(true)
	for _, model in CollectionService:GetTagged(TAG) do
		watchCannon(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watchCannon)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			prompts[instance :: Model] = nil
		end
	end)
	if player.Character ~= nil then
		watchCharacter(player.Character)
		aimBehind(player.Character, nil) -- #3072: the first character of the session, at the Town Square spawn
	else
		local first: RBXScriptConnection? = nil
		first = player.CharacterAdded:Connect(function(character: Model)
			if first ~= nil then
				first:Disconnect()
			end
			aimBehind(character, nil)
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	-- #3072: the server moved this player to their own front door at join (CannonService.homeArrival)
	local function arrivedHome()
		local at = player:GetAttribute(Cannon.HOME_ATTRIBUTE)
		local character = player.Character
		if typeof(at) == "Vector3" and character ~= nil then
			aimBehind(character, at)
		end
	end
	player:GetAttributeChangedSignal(Cannon.HOME_ATTRIBUTE):Connect(arrivedHome)
	arrivedHome()
	-- the server moved this player (a tutorial move, a trip home or to the cannon): the camera goes behind them there
	player:GetAttributeChangedSignal(Cannon.MOVED_SEQ):Connect(function()
		local at = player:GetAttribute(Cannon.MOVED_ATTRIBUTE)
		local character = player.Character
		if typeof(at) == "Vector3" and character ~= nil then
			aimBehind(character, at)
		end
	end)

	-- #2915: the cannon the character stands in range of (the server's own range), for "Fly to the Park"
	UI.cannon.nearest = function(): string?
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		local at = (root :: BasePart).Position
		local best: string? = nil
		local bestDistance = Config.World.CannonRangeStuds + Cannon.RANGE_SLACK
		for model in prompts do
			local id = model:GetAttribute("CannonId")
			local distance = (model:GetPivot().Position - at).Magnitude
			if type(id) == "string" and distance <= bestDistance then
				best, bestDistance = id, distance
			end
		end
		return best
	end

	UI.events.launchCannon:Connect(function(cannonId: string, destination: string)
		Net.fire("LaunchCannon", cannonId, destination)
	end)
	Net.on("CannonLaunch", function(destination: string, launchAt: number?)
		if type(launchAt) == "number" then
			UI.cannon.result(true, destination)
			UI.cannon.flight(destination, launchAt)
		else
			UI.cannon.result(false, destination)
		end
	end)
	Net.on("CampCheckIn", function(userId: number, campId: string)
		Moments.CampCheckIn:Fire(userId, campId)
		if userId == player.UserId then
			local def = if lastCarried ~= nil then Catalog.getCat(lastCarried) else nil
			UI.cannon.checkedIn(if def ~= nil then def.name else nil)
		end
	end)

	task.spawn(function()
		while true do
			refreshPrompts()
			task.wait(PROMPT_REFRESH_SECONDS)
		end
	end)
end

return CannonController
