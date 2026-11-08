--!strict
-- Cafe styles (F53, golden-fish.md sections 4 and 8). Each plot model carries Wallpaper, Floor and Paint, the decor
-- id of the crate style in use (none when unset). The plot's parts tagged with the same name take that piece's
-- colour and material: the inside walls (Wallpaper), the floor (Floor) and the outside facade (Paint), so every
-- player sees a cafe's paint from the street. A part's own look is kept and comes back when the style is put away.
-- Parts that stream in later are styled as they arrive. Only this client's copy changes.
-- #2106: a part's own look is kept in attributes on the part (StyleOwnColor, StyleOwnMaterial), not in a weak table:
-- Roblox can drop a weak table's Instance key while the part still stands, and then a removed paint stayed on.
-- #2256: a style with a `texture` also lays that image on each part's Top face (a StyleTexture child, 6 studs a
-- tile), over the style's colour and material; it comes off when the style changes to one without, or is put away.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crates = require(ReplicatedStorage.Shared.Crates)
local Types = require(ReplicatedStorage.Shared.Types)

local StyleController = {}

local OWN_COLOR = "StyleOwnColor"
local OWN_MATERIAL = "StyleOwnMaterial"
local TEXTURE_NAME = "StyleTexture" -- #2256: the Texture a style with an image puts on the part

-- #2256: puts the style's tiled image on the part's Top face, or takes it off when `texture` is nil.
local function showTexture(part: BasePart, texture: string?)
	local made = part:FindFirstChild(TEXTURE_NAME)
	if texture == nil then
		if made ~= nil then
			made:Destroy()
		end
		return
	end
	local image: Texture
	if made ~= nil and made:IsA("Texture") then
		image = made :: Texture
	else
		if made ~= nil then
			made:Destroy()
		end
		image = Instance.new("Texture")
		image.Name = TEXTURE_NAME
		image.Face = Crates.TEXTURE_FACE
		image.StudsPerTileU = Crates.TEXTURE_STUDS
		image.StudsPerTileV = Crates.TEXTURE_STUDS
		image.Color3 = Color3.new(1, 1, 1)
		image.Transparency = 0
		image.Parent = part
	end
	if image.Texture ~= texture then
		image.Texture = texture
	end
end

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
	local ownColor = part:GetAttribute(OWN_COLOR)
	local ownMaterial = part:GetAttribute(OWN_MATERIAL)
	local own: Crates.PartLook? = if typeof(ownColor) == "Color3"
		then {
			color = ownColor,
			material = Crates.materialNamed(ownMaterial) or part.Material,
		}
		else nil
	if own == nil then
		own = { color = part.Color, material = part.Material }
	end
	local look = Crates.partLook(
		if type(decorId) == "string" then decorId else nil,
		slot.kind,
		own :: Crates.PartLook
	)
	if look.styled then
		if typeof(ownColor) ~= "Color3" then
			part:SetAttribute(OWN_COLOR, part.Color)
			part:SetAttribute(OWN_MATERIAL, part.Material.Name)
		end
	else
		part:SetAttribute(OWN_COLOR, nil)
		part:SetAttribute(OWN_MATERIAL, nil)
	end
	part.Color = look.color
	part.Material = look.material
	showTexture(part, look.texture)
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
