--!strict
-- #4539 (Derek 2026-11-15: the Town Square is too cluttered; shared/StationTiers): below a station's tier its model is
-- hidden on this player's screen. #4680 (Derek 2026-11-16: "dont show it at all"): no "🔒 Unlocks at Tier X" sign
-- floats there any more, and the station's own "!" (Components/PoolBang) stays down too. At the tier everything comes
-- back as it was. Only this client's view changes: the station stays in the world for everyone
-- else, and the server refuses its actions below the tier anyway (WalkUpController skips its ring and prompt).
--
-- Roblox terms: LocalTransparencyModifier is a per-client fade on top of a part's Transparency (1 = unseen here only),
-- and a CanCollide set by a client only changes that client's own physics, which is where its character walks.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local PoolBang = require(script.Parent.Parent.UI.Components.PoolBang)
local StationTiers = require(Shared:WaitForChild("StationTiers"))
local UIController = require(script.Parent.UIController)
local WalkUp = require(Shared:WaitForChild("WalkUp"))

local StationLockController = {}

local POLL_SECONDS = 1

type Saved = { kind: string, value: any }

local saved: { [Instance]: Saved } = {} -- what each hidden instance was, to put back

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

local function sweep()
	local state = UIController.state
	if state == nil then
		return
	end
	local on = switchOn()
	for tag in StationTiers.BY_TAG do
		local locked = StationTiers.locked(tag, state.tier, on)
		for _, model in CollectionService:GetTagged(tag) do
			if not model:IsDescendantOf(Workspace) then
				continue -- the templates in ReplicatedStorage.Assets carry the tags too
			end
			if locked then
				for _, instance in partsOf(model) do
					hideOne(instance)
				end
			else
				for _, instance in partsOf(model) do
					restoreOne(instance)
				end
			end
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
	PoolBang.locked = StationLockController.locked -- #4680: no "!" over a station still locked for this tier
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
