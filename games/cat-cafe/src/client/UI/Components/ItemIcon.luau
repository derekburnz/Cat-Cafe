--!strict
-- A food picture for shop rows, as in the Grow a Garden seed shop: the item's own model from
-- ReplicatedStorage.Assets (the LureDef's `asset` name) held still at a three-quarter view on a round tile in the
-- rarity colour. Until the asset thread's model is there, the food's glyph from Theme.foodIcons stands in.
-- A still ViewportFrame only redraws when its contents change, so a list of these costs no frames.
-- setFood (F69) colours the tile by the food's grade (Components/FoodGrade) and adds the grade badge: a word pill
-- across the bottom edge, or a lettered gem in the top right corner of a picture too small for the word. Since F97
-- section 3 a food draws its uploaded picture (Components/ShopIcons.food) on that tile. Since #1242 an item with a
-- picture never loads its 3D model: the model under the picture stayed drawn wherever the icon was set only once (the
-- bowl's rows, prize chips, the spin wheel), so only an item with no picture at all shows its model, and a picture
-- still loading shows the glyph.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local FoodGrade = require(script.Parent.FoodGrade)
local IconArt = require(script.Parent.IconArt)
local Outline = require(script.Parent.Outline)
local ShopIcons = require(script.Parent.ShopIcons)
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
	plain: boolean?, -- no tile behind the picture: a bold picture on its own (the spin wheel's prizes, #966)
}

export type ItemIcon = {
	frame: Frame,
	-- asset: the model name in ReplicatedStorage.Assets, drawn only when there is no image; glyph: shown when there
	-- is no model and while the image loads; image: an uploaded shop icon (Components/ShopIcons)
	-- tint: the tile's colour in place of the rarity's (the Decor strip's per-kind tiles, #964)
	set: (
		self: ItemIcon,
		asset: string?,
		glyph: string,
		rarity: string?,
		image: string?,
		tint: Color3?
	) -> (),
	-- a food by its LureDef, or by `id` alone when the catalog does not have it: tile, picture and grade badge;
	-- `image` in place of the food's own uploaded picture
	setFood: (self: ItemIcon, lure: Types.LureDef?, id: string?, image: string?) -> (),
	-- a potion's bottle, trying each of its pictures in turn (#1256)
	setPotion: (self: ItemIcon, potionId: string?, rarity: string?) -> (),
	destroy: (self: ItemIcon) -> (),
}

local FOV = 30
local THREE_QUARTER = 30 -- degrees turned from face-on
local TILE_SHADE = 0.55 -- the tile is the rarity colour mixed this far toward cream, so the item stands out
local IMAGE_SCALE = 1.35 -- a shop icon over the glyph's padded box: about 86% of the tile

local ItemIcon = {}
ItemIcon.__index = ItemIcon

-- A copy of the asset with every script removed, or nil when Assets has no model by that name yet.
-- A door set's models are `<asset>_Front` and `<asset>_Back` (F80), so the front stands in for the set.
local function cloneModel(asset: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets
		then assets:FindFirstChild(asset .. "_Front") or assets:FindFirstChild(asset)
		else nil
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
	if props.plain then
		frame.BackgroundTransparency = 1
		self._border.Enabled = false
	end

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

function ItemIcon.setFood(self: any, lure: Types.LureDef?, id: string?, image: string?)
	local grade = FoodGrade.of(lure)
	local key = if lure then lure.id else id or ""
	local asset = if lure then lure.asset else nil
	self:set(asset, Theme.foodIcons[key] or Theme.icons.food, grade, image or ShopIcons.food(key))
	local badge = self:_badgeLabel()
	badge.BackgroundColor3 = Theme.rarityColor(grade)
	badge.TextColor3 = Theme.rarityTextColor(grade)
	badge.Text = FoodGrade.badge(grade, self._badgeKind == "gem")
	badge.Visible = true
end

function ItemIcon.set(
	self: any,
	model: string?,
	glyph: string,
	rarity: string?,
	image: string?,
	tint: Color3?
)
	local badge: TextLabel? = self._badge
	if badge then
		badge.Visible = false -- setFood shows it again; anything else has no grade
	end
	local color = Theme.rarityColor(rarity)
	self.frame.BackgroundColor3 = tint or color:Lerp(Theme.colors.cream, TILE_SHADE)
	self._border.Color = color:Lerp(Theme.colors.outline, 0.35)
	-- the model only for an item with no picture (#1242, Derek live 11-04: the bowl's rows, time rewards and spin
	-- prizes still showed the old 3D food renders). A picture still loading shows the glyph under it (IconArt).
	local wanted = if image then nil else model
	if wanted ~= self._asset or (wanted ~= nil and self._model == nil) then
		self:_setModel(wanted)
	end
	local hasModel = self._model ~= nil
	-- the glyph label holds the picture, so it stays shown with one; its emoji only while nothing else draws
	self._glyph.Text = if hasModel then "" else glyph
	if image then
		IconArt.setImage(self._glyph, image, IMAGE_SCALE)
	else
		-- spins, crates, potions and decor tiles get the drawn icon; the Decor Index's unknown piece stays a plain "?"
		IconArt.set(self._glyph, if glyph ~= "?" and not hasModel then glyph else nil)
	end
	self._glyph.Visible = image ~= nil or not hasModel
end

function ItemIcon.setPotion(self: any, potionId: string?, rarity: string?)
	local bottles = ShopIcons.potionAll(potionId)
	self:set(nil, Theme.icons.potion, rarity, bottles[1])
	local scale = ShopIcons.potionScale(potionId) -- Small smaller, Big bigger (#1403)
	if #bottles > 1 or scale ~= 1 then
		-- a flask that fails to load hands over to the next
		IconArt.setImages(self._glyph, bottles, IMAGE_SCALE * scale)
	end
end

-- The model in the viewport, or none; a model Assets does not have yet leaves the glyph.
function ItemIcon._setModel(self: any, asset: string?)
	local old: Model? = self._model
	if old then
		old:Destroy()
		self._model = nil
	end
	self._asset = asset
	local model = if asset then cloneModel(asset) else nil
	if not model then
		return
	end
	assert(model, "model")
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
