--!strict
-- #4539 (Derek 2026-11-15: the Town Square is too cluttered; shared/StationTiers): below a station's tier its model is
-- hidden on this player's screen and a small "🔒 Unlocks at Tier X" sign floats where it stands. At the tier
-- everything comes back as it was. Only this client's view changes: the station stays in the world for everyone
-- else, and the server refuses its actions below the tier anyway (WalkUpController skips its ring and prompt).
--
-- Roblox terms: LocalTransparencyModifier is a per-client fade on top of a part's Transparency (1 = unseen here only),
-- and a CanCollide set by a client only changes that client's own physics, which is where its character walks.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local StationTiers = require(Shared:WaitForChild("StationTiers"))
local Theme = require(script.Parent.Parent.UI.Theme)
local UIController = require(script.Parent.UIController)
local WalkUp = require(Shared:WaitForChild("WalkUp"))

local StationLockController = {}

local POLL_SECONDS = 1
local SIGN_NAME = "CatCafeStationLock"

type Saved = { kind: string, value: any }

local saved: { [Instance]: Saved } = {} -- what each hidden instance was, to put back
local signs: { [Instance]: BillboardGui? } = {}

local function switchOn(): boolean
	return LiveFlags.shown(
		StationTiers.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. StationTiers.FLAG)
	)
end

local function hideOne(instance: Instance)
	if saved[instance] ~= nil then
		return
	end
	if instance:IsA("BasePart") then
		local part = instance :: BasePart
		saved[instance] = { kind = "part", value = part.CanCollide }
		part.LocalTransparencyModifier = 1
		part.CanCollide = false
	elseif instance:IsA("Decal") then -- Textures too
		local decal = instance :: Decal
		saved[instance] = { kind = "decal", value = decal.LocalTransparencyModifier }
		decal.LocalTransparencyModifier = 1
	elseif
		instance:IsA("ProximityPrompt")
		or instance:IsA("BillboardGui")
		or instance:IsA("SurfaceGui")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Light")
		or instance:IsA("Highlight")
	then
		saved[instance] = { kind = "enabled", value = (instance :: any).Enabled }
		(instance :: any).Enabled = false
	end
end

local function restoreOne(instance: Instance)
	local was = saved[instance]
	if was == nil then
		return
	end
	saved[instance] = nil
	if was.kind == "part" then
		(instance :: BasePart).LocalTransparencyModifier = 0
		(instance :: BasePart).CanCollide = was.value
	elseif was.kind == "decal" then
		(instance :: Decal).LocalTransparencyModifier = was.value
	else
		(instance :: any).Enabled = was.value
	end
end

-- The station's model and its walk-up ring, which may sit outside the model.
local function partsOf(model: Instance): { Instance }
	local list = model:GetDescendants()
	table.insert(list, model)
	local link = model:FindFirstChild(WalkUp.CIRCLE)
	local ring: Instance? = if link ~= nil and link:IsA("ObjectValue")
		then (link :: ObjectValue).Value
		else nil
	if ring ~= nil and not ring:IsDescendantOf(model) then
		table.insert(list, ring)
		for _, child in ring:GetDescendants() do
			table.insert(list, child)
		end
	end
	return list
end

local function anchorOf(model: Instance): BasePart?
	if model:IsA("Model") and model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part ~= nil then part :: BasePart else nil
end

local function signFor(model: Instance, tag: string): BillboardGui?
	local sign: BillboardGui? = signs[model]
	if sign and sign.Parent then
		return sign
	end
	local anchor = anchorOf(model)
	local text = StationTiers.sign(tag)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if anchor == nil or text == nil or playerGui == nil then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = SIGN_NAME
	gui.Adornee = anchor
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.Size = UDim2.fromOffset(170, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Theme.colors.cocoa
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Theme.colors.cream
	label.FontFace = Theme.fonts.display
	label.TextScaled = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = playerGui
	signs[model] = gui
	return gui
end

local function dropSign(model: Instance)
	local sign: BillboardGui? = signs[model]
	signs[model] = nil
	if sign then
		sign:Destroy()
	end
end

local function sweep()
	local state = UIController.state
	if state == nil then
		return
	end
	local on = switchOn()
	local seen: { [Instance]: boolean } = {}
	for tag in StationTiers.BY_TAG do
		local locked = StationTiers.locked(tag, state.tier, on)
		for _, model in CollectionService:GetTagged(tag) do
			if not model:IsDescendantOf(Workspace) then
				continue -- the templates in ReplicatedStorage.Assets carry the tags too
			end
			if locked then
				seen[model] = true
				for _, instance in partsOf(model) do
					hideOne(instance)
				end
				signFor(model, tag)
			else
				for _, instance in partsOf(model) do
					restoreOne(instance)
				end
				dropSign(model)
			end
		end
	end
	-- a sign whose station streamed out or unlocked goes
	for model in signs do
		if not seen[model] then
			dropSign(model)
		end
	end
	for instance in saved do
		if instance.Parent == nil then
			saved[instance] = nil
		end
	end
end

-- Whether the stations tagged `tag` are shut for this player now: WalkUpController skips it.
function StationLockController.locked(tag: string): boolean
	local state = UIController.state
	return state ~= nil and StationTiers.locked(tag, state.tier, switchOn())
end

function StationLockController.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function(): string?
				sweep()
				return nil -- CI's luau-lsp wants two values from pcall
			end)
			if not ok then
				warn("[StationLock] " .. tostring(err))
			end
			task.wait(POLL_SECONDS)
		end
	end)
end

return StationLockController
