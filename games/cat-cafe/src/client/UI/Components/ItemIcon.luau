--!strict
-- A food picture for shop rows, as in the Grow a Garden seed shop: the item's own model from
-- ReplicatedStorage.Assets (the LureDef's `asset` name) held still at a three-quarter view on a round tile in the
-- rarity colour. Until the asset thread's model is there, the food's glyph from Theme.foodIcons stands in.
-- A still ViewportFrame only redraws when its contents change, so a list of these costs no frames.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	parent: Instance,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	name: string?,
}

export type ItemIcon = {
	frame: Frame,
	-- asset: the model name in ReplicatedStorage.Assets; glyph: shown when there is no model
	set: (self: ItemIcon, asset: string?, glyph: string, rarity: string?) -> (),
	destroy: (self: ItemIcon) -> (),
}

local FOV = 30
local THREE_QUARTER = 30 -- degrees turned from face-on
local TILE_SHADE = 0.55 -- the tile is the rarity colour mixed this far toward cream, so the item stands out

local ItemIcon = {}
ItemIcon.__index = ItemIcon

-- A copy of the asset with every script removed, or nil when Assets has no model by that name yet.
local function cloneModel(asset: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets then assets:FindFirstChild(asset) else nil
	if not source then
		return nil
	end
	local copy = (source :: Instance):Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	if copy:IsA("Model") then
		return copy :: Model
	end
	local wrapper = Instance.new("Model")
	copy.Parent = wrapper
	return wrapper
end

function ItemIcon.new(props: Props): ItemIcon
	local self = setmetatable({}, ItemIcon) :: any
	local frame: Frame = Create("Frame", {
		Name = props.name or "Icon",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		AnchorPoint = props.anchorPoint or Vector2.new(),
		Position = props.position or UDim2.new(),
		Size = props.size,
		Parent = props.parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	self._border = Outline.border(frame, 2)
	self.frame = frame

	local camera: Camera = Create("Camera", { FieldOfView = FOV })
	local viewport: ViewportFrame = Create("ViewportFrame", {
		Name = "View",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(200, 190, 180),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Parent = frame,
	})
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	self._viewport = viewport
	self._camera = camera

	self._glyph = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		Text = "",
		Visible = false,
		Parent = frame,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0.18, 0),
			PaddingBottom = UDim.new(0.18, 0),
		}),
	})
	self._model = nil :: Model?
	self._asset = nil :: string?
	return self :: ItemIcon
end

function ItemIcon.set(self: any, asset: string?, glyph: string, rarity: string?)
	local color = Theme.rarityColor(rarity)
	self.frame.BackgroundColor3 = color:Lerp(Theme.colors.cream, TILE_SHADE)
	self._border.Color = color:Lerp(Theme.colors.outline, 0.35)
	self._glyph.Text = glyph
	if asset == self._asset and (self._model ~= nil or asset == nil) then
		return
	end
	local old: Model? = self._model
	if old then
		old:Destroy()
		self._model = nil
	end
	self._asset = asset
	local model = if asset then cloneModel(asset) else nil
	if not model then
		self._glyph.Visible = true
		return
	end
	assert(model, "model")
	self._glyph.Visible = false
	-- face the item toward the camera (models face -Z, the Roblox front), turn it a little and frame its box
	model:PivotTo(CFrame.Angles(0, math.rad(THREE_QUARTER), 0))
	local boxCFrame, boxSize = model:GetBoundingBox()
	local centre = boxCFrame.Position
	local radius = boxSize.Magnitude / 2
	local distance = radius / math.tan(math.rad(FOV / 2)) * 1.1
	self._camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, radius * 0.6, -distance), centre)
	model.Parent = self._viewport
	self._model = model
end

function ItemIcon.destroy(self: any)
	local model: Model? = self._model
	if model then
		model:Destroy()
	end
	self.frame:Destroy()
end

return ItemIcon
