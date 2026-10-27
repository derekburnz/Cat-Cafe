--!strict
-- The golden fish coin (golden-fish.md section 1, Derek 2026-10-27: "it can be a cute coin with like a cat face on
-- it"): a gold coin with a lighter rim, two cat ears behind it and a little cat face (two eyes and an "ω" mouth),
-- drawn from frames so it needs no uploaded image. When the asset thread's coin picture lands, this is the one
-- place to swap.
--   FishCoin.new({ parent, size }) -> Frame   the size is the coin's; the ears reach a third of it higher

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

return FishCoin
