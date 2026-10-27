--!strict
-- A food picture for shop rows, as in the Grow a Garden seed shop: the item's own model from
-- ReplicatedStorage.Assets (the LureDef's `asset` name) held still at a three-quarter view on a round tile in the
-- rarity colour. Until the asset thread's model is there, the food's glyph from Theme.foodIcons stands in.
-- A still ViewportFrame only redraws when its contents change, so a list of these costs no frames.
-- setFood (F69) colours the tile by the food's grade (Components/FoodGrade) and adds the grade badge: a word pill
-- across the bottom edge, or a lettered gem in the top right corner of a picture too small for the word.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local FoodGrade = require(script.Parent.FoodGrade)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Badge = "word" | "gem"

export type Props = {
	parent: Instance,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	name: string?,
	badge: Badge?, -- how setFood shows the grade; "word" by default, "gem" for small pictures
}

export type ItemIcon = {
	frame: Frame,
	-- asset: the model name in ReplicatedStorage.Assets; glyph: shown when there is no model
	set: (self: ItemIcon, asset: string?, glyph: string, rarity: string?) -> (),
	-- a food by its LureDef, or by `id` alone when the catalog does not have it: tile, picture and grade badge
	setFood: (self: ItemIcon, lure: Types.LureDef?, id: string?) -> (),
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
	self._badgeKind = props.badge or "word"
	self._badge = nil :: TextLabel?
	return self :: ItemIcon
end

-- The grade badge, made the first time a food is shown.
function ItemIcon._badgeLabel(self: any): TextLabel
	local existing: TextLabel? = self._badge
	if existing then
		return existing
	end
	local gem = self._badgeKind == "gem"
	local label: TextLabel = Create("TextLabel", {
		Name = "Grade",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = if gem then UDim2.fromScale(0.86, 0.14) else UDim2.fromScale(0.5, 1),
		Size = if gem then UDim2.fromScale(0.38, 0.38) else UDim2.new(1, 8, 0.24, 0),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		Text = "",
		ZIndex = 4,
		Parent = self.frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UITextSizeConstraint", { MaxTextSize = if gem then 14 else 13, MinTextSize = 6 }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, if gem then 1 else 5),
			PaddingRight = UDim.new(0, if gem then 1 else 5),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		}),
	})
	if gem then
		Create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = label })
	end
	Outline.border(label, 1.5)
	self._badge = label
	return label
end

function ItemIcon.setFood(self: any, lure: Types.LureDef?, id: string?)
	local grade = FoodGrade.of(lure)
	local key = if lure then lure.id else id or ""
	local asset = if lure then lure.asset else nil
	self:set(asset, Theme.foodIcons[key] or Theme.icons.food, grade)
	local badge = self:_badgeLabel()
	badge.BackgroundColor3 = Theme.rarityColor(grade)
	badge.TextColor3 = Theme.rarityTextColor(grade)
	badge.Text = FoodGrade.badge(grade, self._badgeKind == "gem")
	badge.Visible = true
end

function ItemIcon.set(self: any, asset: string?, glyph: string, rarity: string?)
	local badge: TextLabel? = self._badge
	if badge then
		badge.Visible = false -- setFood shows it again; anything else has no grade
	end
	local color = Theme.rarityColor(rarity)
	self.frame.BackgroundColor3 = color:Lerp(Theme.colors.cream, TILE_SHADE)
	self._border.Color = color:Lerp(Theme.colors.outline, 0.35)
	self._glyph.Text = glyph
	if asset == self._asset and (self._model ~= nil or asset == nil) then
		-- the same picture as before; a tile that never had a model shows its glyph (the coin tiles were blank)
		self._glyph.Visible = self._model == nil
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
