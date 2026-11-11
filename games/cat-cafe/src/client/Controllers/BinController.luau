--!strict
-- The Rummage Bin on this client (#3050; the rules are shared/RummageBin, the server is BinService). The bin's prompt
-- (RummageBin.PROMPT on the model's PromptAnchor, made by WorldBuilder, drawn as the UI's action pill with the chances
-- under it) reads "Rummage" while this player's bin is full and "Empty for now 🐾" while it is not, from the player's
-- BinNextAt attribute: never a countdown, and nothing announces the refill (Monetization-Agent 11-10). The model shows
-- its `_Ready` look (lid back, prizes poking out) or its `_Empty` look (lid shut) the same way, for this player only.
-- A press on a full bin sends RescueBegin with RummageBin.SPOT; the server answers with the rescue bar
-- (RescueChallenge), and its winning RescueResult fires Moments.RummageWin(row id, first) for the effects and sounds
-- (UIController). Nothing is sent during a catch, a rescue, a flight or the intro.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(script.Parent.Parent.Net)
local RummageBin = require(Shared:WaitForChild("RummageBin"))
local UI = require(script.Parent.Parent.UI)

local BinController = {}

local LABEL_SECONDS = 1

local models: { [Model]: ProximityPrompt? } = {} -- each placed bin on this client and its prompt

local function ready(): boolean
	local nextAt = Players.LocalPlayer:GetAttribute(RummageBin.NEXT_AT_ATTRIBUTE)
	return type(nextAt) ~= "number" or Workspace:GetServerTimeNow() >= nextAt
end

-- Shows one of the model's two looks. Their parts are all opaque, so a look is hidden at Transparency 1.
local function setLook(model: Model, full: boolean)
	for _, look in model:GetChildren() do
		if not look:IsA("Model") then
			continue
		end
		local shown = (look.Name:sub(-6) == "_Empty") ~= full
		local transparency = if shown then 0 else 1
		for _, piece in look:GetDescendants() do
			if piece:IsA("BasePart") and (piece :: BasePart).Transparency ~= transparency then
				(piece :: BasePart).Transparency = transparency
			end
		end
	end
end

local function label()
	local full = ready()
	local action = if full then RummageBin.ACTION else RummageBin.EMPTY
	for model, prompt in models do
		if prompt ~= nil and prompt.ActionText ~= action then
			prompt.ActionText = action
		end
		setLook(model, full)
	end
end

local function busy(): boolean
	local ui: any = UI
	local character = Players.LocalPlayer.Character
	return (
		character ~= nil
		and (
			character:GetAttribute("Launching") == true
			or character:GetAttribute("CloudHopAt") ~= nil
		)
	)
		or ui.catch.circlesActive()
		or ui.rescue.isActive()
		or ui.intro.playing()
end

local function onTriggered()
	if busy() or not ready() then
		return -- an empty bin's pill already says so
	end
	Net.fire("RescueBegin", RummageBin.SPOT)
end

-- Picks up a placed bin's prompt (again after its model streams back in).
local function track(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return
	end
	local model = instance :: Model
	if models[model] ~= nil then
		return
	end
	local prompt = model:FindFirstChild(RummageBin.PROMPT, true)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		-- not here yet: take it when it arrives
		local waiting: RBXScriptConnection
		waiting = model.DescendantAdded:Connect(function(child: Instance)
			if child.Name == RummageBin.PROMPT and child:IsA("ProximityPrompt") then
				waiting:Disconnect()
				track(model)
			end
		end)
		return
	end
	local found = prompt :: ProximityPrompt
	models[model] = found
	found.Triggered:Connect(onTriggered)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			models[model] = nil
		end
	end)
	label()
end

function BinController.start()
	for _, instance in CollectionService:GetTagged(RummageBin.TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(RummageBin.TAG):Connect(track)
	Players.LocalPlayer:GetAttributeChangedSignal(RummageBin.NEXT_AT_ATTRIBUTE):Connect(label)
	task.spawn(function()
		while true do
			task.wait(LABEL_SECONDS)
			label()
		end
	end)
end

return BinController
