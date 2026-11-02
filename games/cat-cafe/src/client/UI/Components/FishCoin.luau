--!strict
-- The golden fish (F97 section 4, Derek 2026-10-28: "Golden fish / golden cat coins should be merged together as one
-- currency and picture"): Theme.textures.fishCoin, a shiny gold fish with a white glint (CatCafe_Icon_GoldenFish,
-- Model-Agent #690), centred in a square `size` wide. The fish is wider than tall, so it fills the width and sits in
-- the middle. Without the picture it falls back to the old drawn coin: a gold coin with a lighter rim, two cat ears
-- behind it and a little cat face (golden-fish.md section 1).
--   FishCoin.new({ parent, size }) -> Frame   the size is the picture's square (the drawn coin's ears reach higher)
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
-- the fish spans 95% of its 512 px picture's width and 65% of its height, centred (alpha box 12, 90 to 500, 422), so
-- the picture fills the square as it is
local PICTURE_SCALE = 1

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
			AnchorPoint = Vector2.new(0.5, 0.5),
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

-- For a parent sized by scale (a Spin Wheel tile): the fish is drawn once at FILL_BASE and a UIScale keeps it at
-- `share` of the parent's width, centred (the drawn coin a little low so its ears fit). The parent's own signal ends
-- with it.
function FishCoin.fill(parent: GuiObject, share: number, zIndex: number?): Frame
	local holder = FishCoin.new({
		parent = parent,
		size = FILL_BASE,
		position = UDim2.fromScale(0.5, if Theme.textures.fishCoin ~= "" then 0.5 else 0.56),
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
