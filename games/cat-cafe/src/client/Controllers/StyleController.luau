--!strict
-- Cafe styles (F53, golden-fish.md sections 4 and 8). Each plot model carries Wallpaper, Floor and Paint, the decor
-- id of the crate style in use (none when unset). The plot's parts tagged with the same name take that piece's
-- colour and material: the inside walls (Wallpaper), the floor (Floor) and the outside facade (Paint), so every
-- player sees a cafe's paint from the street. A part's own look is kept and comes back when the style is put away.
-- Parts that stream in later are styled as they arrive. Only this client's copy changes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crates = require(ReplicatedStorage.Shared.Crates)
local Types = require(ReplicatedStorage.Shared.Types)

local StyleController = {}

type Look = { color: Color3, material: Enum.Material }

local originals: { [BasePart]: Look } = setmetatable({}, { __mode = "k" }) :: any

-- The Plot-tagged model the part belongs to, or nil.
local function plotOf(instance: Instance): Model?
	local node = instance.Parent
	while node ~= nil do
		if node:IsA("Model") and CollectionService:HasTag(node, "Plot") then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end

-- Shows the slot's style on one part, or its own look when the plot has none.
local function apply(
	part: BasePart,
	plot: Model,
	slot: { kind: Types.DecorKind, attribute: string }
)
	local decorId = plot:GetAttribute(slot.attribute)
	local color, material =
		Crates.styleLook(if type(decorId) == "string" then decorId else nil, slot.kind)
	local original = originals[part]
	if color ~= nil then
		if original == nil then
			originals[part] = { color = part.Color, material = part.Material }
		end
		part.Color = color
		if material ~= nil then
			part.Material = material
		end
	elseif original ~= nil then
		part.Color = original.color
		part.Material = original.material
		originals[part] = nil
	end
end

local function applyTagged(instance: Instance, slot: { kind: Types.DecorKind, attribute: string })
	if not instance:IsA("BasePart") then
		return
	end
	local plot = plotOf(instance)
	if plot ~= nil then
		apply(instance :: BasePart, plot, slot)
	end
end

local function watchPlot(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local plot = instance :: Model
	for _, slot in Crates.STYLE_SLOTS do
		plot:GetAttributeChangedSignal(slot.attribute):Connect(function()
			for _, tagged in CollectionService:GetTagged(slot.attribute) do
				if tagged:IsA("BasePart") and tagged:IsDescendantOf(plot) then
					apply(tagged :: BasePart, plot, slot)
				end
			end
		end)
	end
end

function StyleController.start()
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	for _, slot in Crates.STYLE_SLOTS do
		CollectionService:GetInstanceAddedSignal(slot.attribute):Connect(function(instance)
			applyTagged(instance, slot)
		end)
		for _, instance in CollectionService:GetTagged(slot.attribute) do
			applyTagged(instance, slot)
		end
	end
end

return StyleController
