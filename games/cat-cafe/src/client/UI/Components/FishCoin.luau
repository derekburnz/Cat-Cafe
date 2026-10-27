--!strict
-- The golden fish coin (golden-fish.md section 1, Derek 2026-10-27: "it can be a cute coin with like a cat face on
-- it"): a gold coin with a lighter rim, two cat ears behind it and a little cat face (two eyes and an "ω" mouth),
-- drawn from frames. Once Theme.textures.fishCoin holds the asset thread's picture (CatCafe_Icon_GoldenFish, Derek
-- okayed it 2026-10-27) the coin is that picture instead, in the same place and size.
--   FishCoin.new({ parent, size }) -> Frame   the size is the coin's; the ears reach a third of it higher
--   FishCoin.fill(parent, share) -> Frame   a coin `share` of a scale-sized parent's width, kept so as it resizes

local CatEars = require(script.Parent.CatEars)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	parent: Instance,
	size: number,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	name: string?,
}

local FishCoin = {}

local FILL_BASE = 40 -- px the filling coin is drawn at before its UIScale
-- the picture's round face is 88% of its width with its centre 55% down (the ears take the top), so the picture is
-- drawn this much bigger than the coin and lifted until its face covers the coin's square
local PICTURE_SCALE = 1 / 0.88
local PICTURE_FACE_Y = 0.55

function FishCoin.new(props: Props): Frame
	local size = props.size
	local z = props.zIndex or 1
	local outline = if size >= 32 then Theme.sizes.outline else 2
	local holder: Frame = Create("Frame", {
		Name = props.name or "FishCoin",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchorPoint or Vector2.new(),
		ZIndex = z,
		Parent = props.parent,
	})
	local picture = Theme.textures.fishCoin
	if picture ~= "" then
		Create("ImageLabel", {
			Name = "Coin",
			BackgroundTransparency = 1,
			Image = picture,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, PICTURE_FACE_Y),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(PICTURE_SCALE, PICTURE_SCALE),
			ZIndex = z + 1,
			Parent = holder,
		})
		return holder
	end
	CatEars.add(holder, Theme.fish.coin, {
		size = math.floor(size * 0.42),
		inset = 0.24,
		y = math.floor(size * 0.2),
		outline = outline,
		zIndex = z,
	})
	local coin: Frame = Create("Frame", {
		Name = "Coin",
		BackgroundColor3 = Theme.fish.coin,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = holder,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(coin, outline)
	Outline.shade(coin, 0.18)
	-- the raised rim of a coin, a lighter ring just inside the edge
	local ring: Frame = Create("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		ZIndex = z + 1,
		Parent = coin,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(ring, math.max(1.5, size / 16), Theme.fish.rim)
	local eye = math.max(3, math.floor(size * 0.12))
	for _, x in { 0.36, 0.64 } do
		Create("Frame", {
			Name = "Eye",
			BackgroundColor3 = Theme.colors.outline,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.44),
			Size = UDim2.fromOffset(eye, eye),
			ZIndex = z + 2,
			Parent = coin,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	Create("TextLabel", {
		Name = "Mouth",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromScale(0.6, 0.3),
		FontFace = Theme.fonts.display,
		TextSize = math.max(8, math.floor(size * 0.36)),
		TextColor3 = Theme.colors.outline,
		Text = "ω",
		ZIndex = z + 2,
		Parent = coin,
	})
	return holder
end

-- For a parent sized by scale (a Spin Wheel tile): the coin is drawn once at FILL_BASE and a UIScale keeps it at
-- `share` of the parent's width, centred a little low so the ears fit. The parent's own signal ends with it.
function FishCoin.fill(parent: GuiObject, share: number, zIndex: number?): Frame
	local holder = FishCoin.new({
		parent = parent,
		size = FILL_BASE,
		position = UDim2.fromScale(0.5, 0.56),
		anchorPoint = Vector2.new(0.5, 0.5),
		zIndex = zIndex,
	})
	local scale: UIScale = Create("UIScale", { Parent = holder })
	local function fit()
		scale.Scale = math.max(0.05, parent.AbsoluteSize.X * share / FILL_BASE)
	end
	fit()
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	return holder
end

return FishCoin
