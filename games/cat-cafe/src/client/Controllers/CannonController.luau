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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
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
	end
	player.CharacterAdded:Connect(watchCharacter)

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
