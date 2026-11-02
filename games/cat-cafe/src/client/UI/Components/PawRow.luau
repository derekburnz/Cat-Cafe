--!strict
-- A row of patience paws (v0.4 catching, data-model section 10 step 5): one paw per failed catch a player may
-- have on a stray, pink while left and grey once spent. Each paw is a pad and four toes drawn from rounded
-- frames, so it needs no image upload. lose() pops the paw that was just spent.

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Props = {
	parent: Instance,
	paw: number, -- one paw's size in pixels
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
}

export type PawRow = {
	frame: Frame,
	set: (self: PawRow, left: number?, total: number?) -> (),
	lose: (self: PawRow, left: number) -> (),
	destroy: (self: PawRow) -> (),
}

local GAP = 3
local LOST_TRANSPARENCY = 0.55
-- Pad and toes as fractions of the paw's box: {x, y, width, height}, centred on x and y.
local PARTS: { { number } } = {
	{ 0.5, 0.68, 0.6, 0.5 },
	{ 0.14, 0.34, 0.26, 0.3 },
	{ 0.37, 0.15, 0.26, 0.3 },
	{ 0.63, 0.15, 0.26, 0.3 },
	{ 0.86, 0.34, 0.26, 0.3 },
}

type Paw = { frame: Frame, parts: { Frame }, strokes: { UIStroke } }

local PawRow = {}
PawRow.__index = PawRow

local function newPaw(parent: Instance, size: number, order: number, zIndex: number): Paw
	local frame: Frame = Create("Frame", {
		Name = "Paw" .. order,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order,
		ZIndex = zIndex,
		Parent = parent,
	})
	local parts: { Frame } = {}
	local strokes: { UIStroke } = {}
	for index, part in PARTS do
		local piece: Frame = Create("Frame", {
			Name = if index == 1 then "Pad" else "Toe" .. (index - 1),
			BackgroundColor3 = Theme.colors.pink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(part[1], part[2]),
			Size = UDim2.fromScale(part[3], part[4]),
			ZIndex = zIndex,
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		table.insert(parts, piece)
		table.insert(strokes, Outline.border(piece, math.max(1, math.floor(size / 12))))
	end
	return { frame = frame, parts = parts, strokes = strokes }
end

local function paint(paw: Paw, spent: boolean)
	for _, piece in paw.parts do
		piece.BackgroundColor3 = if spent then Theme.colors.muted else Theme.colors.pink
		piece.BackgroundTransparency = if spent then LOST_TRANSPARENCY else 0
	end
	for _, stroke in paw.strokes do
		stroke.Transparency = if spent then LOST_TRANSPARENCY else 0
	end
end

function PawRow.new(props: Props): PawRow
	local self = setmetatable({}, PawRow) :: any
	self._size = props.paw
	self._zIndex = props.zIndex or 1
	self.frame = Create("Frame", {
		Name = "Paws",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = props.anchorPoint or Vector2.new(),
		Position = props.position or UDim2.new(),
		Size = UDim2.fromOffset(0, props.paw),
		Visible = false,
		ZIndex = self._zIndex,
		Parent = props.parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._paws = {} :: { Paw }
	return self :: PawRow
end

-- left nil hides the row: the player cannot run out on this cat (a dropped cat they carried, the tutorial).
function PawRow.set(self: any, left: number?, total: number?)
	if left == nil then
		self.frame.Visible = false
		return
	end
	local count = math.max(left, total or left, 1)
	local paws: { Paw } = self._paws
	while #paws < count do
		table.insert(paws, newPaw(self.frame, self._size, #paws + 1, self._zIndex))
	end
	for index, paw in paws do
		paw.frame.Visible = index <= count
		paint(paw, index > left)
	end
	self.frame.Visible = true
end

-- The paw at left + 1 was just spent: it pops and greys.
function PawRow.lose(self: any, left: number)
	local paw: Paw? = self._paws[left + 1]
	if not paw then
		return
	end
	paint(paw, true)
	Tween.popIn(paw.frame, 1.5)
end

function PawRow.destroy(self: any)
	self.frame:Destroy()
end

return PawRow
