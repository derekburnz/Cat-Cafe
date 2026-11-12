--!strict
-- The roll board (#3611, part of #3608): the list that hovers over a station whose prize is rolled, drawn from a
-- RollBoardLogic.View. A violet card with the station's name, one line, and a row per prize: its picture on a cream
-- tile (a food with a small golden fish when it brings both), its name and its chance. A better prize has a blue
-- edge, the best a gold edge and a gold chance. While the roll passes, the row it is on lights soft blue (LIT:
-- never white or gold, which are resting edges on the Yard Sale's board, Derek 2026-11-12) and the others fade; the
-- light goes when the roll is over.
--   RollBoard.new(parent)   the card, WIDTH design px wide and as tall as its rows (AutomaticSize)
--   board:set(view)         what it shows; rows are rebuilt only when they change, so a clock line costs nothing
--   board:light(index?)     the row the roll is on (nil: none, every row back to full)
--   board.frame, board:destroy()
-- It holds no UIScale: the screen that hangs it (a BillboardGui over the Rummage Bin, BinController) sets its size.

local Create = require(script.Parent.Create)
local IconArt = require(script.Parent.IconArt)
local Outline = require(script.Parent.Outline)
local RollBoardLogic = require(script.Parent.RollBoardLogic)
local Theme = require(script.Parent.Parent.Theme)

local RollBoard = {}
RollBoard.__index = RollBoard

export type RollBoard = {
	frame: Frame,
	set: (self: RollBoard, view: RollBoardLogic.View) -> (),
	light: (self: RollBoard, index: number?) -> (),
	destroy: (self: RollBoard) -> (),
}

type RowParts = {
	frame: Frame,
	stroke: UIStroke,
	tile: Frame,
	pictures: { TextLabel },
	name: TextLabel,
	chance: TextLabel?,
	tier: number,
}

RollBoard.WIDTH = 320
RollBoard.ROW = 32
local PAD = 8
local GAP = 4
local TILE = 26
local CHANCE_WIDTH = 46
local TITLE_SIZE = 22
local LINE_SIZE = 15
local NAME_SIZE = 17
local FADED = 0.55 -- a row the roll is not on, and every row of an empty bin: 45% of itself

local BODY = Color3.fromHex("3C286E")
local ROW = Color3.fromHex("543C8C")
local ROW_EDGE = Color3.fromHex("6A52A8")
local TILE_COLOR = Color3.fromHex("FFE296")
local BLUE = Color3.fromHex("6EB4FF")
local GOLD = Color3.fromHex("FFD650")
local LINE = Color3.fromHex("E4D6FF") -- the line under the title: 9.6:1 on the body
local LIT = Color3.fromRGB(143, 208, 255) -- the roll's light, the effects' soft blue
local LIT_FILL = Color3.fromHex("3F7FD0") -- under white words: 4.2:1, and the words wear an ink outline
local INK = Theme.colors.ink
local WHITE = Theme.colors.white

local function edgeFor(tier: number): Color3
	return if tier >= 3 then GOLD elseif tier == 2 then BLUE else ROW_EDGE
end

local function words(props: { [string]: any }): TextLabel
	local label: TextLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	Outline.text(label, 2, INK)
	return label
end

-- The card's height in design px for a view (a BillboardGui needs its size said).
function RollBoard.height(view: RollBoardLogic.View): number
	local height = PAD * 2 + (TITLE_SIZE + 2) + GAP + (LINE_SIZE + 3)
	height += #view.rows * (RollBoard.ROW + GAP)
	if view.foot ~= nil then
		height += GAP + LINE_SIZE + 3
	end
	return height
end

function RollBoard.new(parent: Instance): RollBoard
	local self = setmetatable({}, RollBoard) :: any
	local frame: Frame = Create("Frame", {
		Name = "RollBoard",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(RollBoard.WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = BODY,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Create("UIStroke", {
			Color = INK,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, PAD),
			PaddingBottom = UDim.new(0, PAD),
			PaddingLeft = UDim.new(0, PAD),
			PaddingRight = UDim.new(0, PAD),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.frame = frame
	self._title = words({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_SIZE + 2),
		TextSize = TITLE_SIZE,
		LayoutOrder = 1,
		Parent = frame,
	})
	self._line = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, LINE_SIZE + 3),
		FontFace = Theme.fonts.display,
		TextSize = LINE_SIZE,
		TextColor3 = LINE,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		Parent = frame,
	})
	self._foot = Create("TextLabel", {
		Name = "Foot",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, LINE_SIZE + 3),
		FontFace = Theme.fonts.display,
		TextSize = LINE_SIZE - 1,
		TextColor3 = LINE,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1000,
		Visible = false,
		Parent = frame,
	})
	self._rows = {} :: { RowParts }
	self._key = ""
	self._dim = false
	self._lit = nil :: number?
	return self :: RollBoard
end

function RollBoard._row(self: any, index: number, view: RollBoardLogic.RowView): RowParts
	local frame: Frame = Create("Frame", {
		Name = "Row" .. index,
		Size = UDim2.new(1, 0, 0, RollBoard.ROW),
		BackgroundColor3 = ROW,
		BorderSizePixel = 0,
		LayoutOrder = 10 + index,
		Parent = self.frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	frame:SetAttribute("RowId", view.id)
	local stroke: UIStroke = Create("UIStroke", {
		Color = edgeFor(view.tier),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(TILE, TILE),
		BackgroundColor3 = TILE_COLOR,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	local pictures: { TextLabel } = {}
	local two = #view.images >= 2
	local main: TextLabel = Create("TextLabel", {
		Name = "Picture",
		BackgroundTransparency = 1,
		AnchorPoint = if two then Vector2.zero else Vector2.new(0.5, 0.5),
		Position = if two then UDim2.fromScale(0.02, 0.02) else UDim2.fromScale(0.5, 0.5),
		Size = if two then UDim2.fromScale(0.78, 0.78) else UDim2.fromScale(0.9, 0.9),
		FontFace = Theme.fonts.display,
		TextSize = 16,
		Text = view.glyph,
		Parent = tile,
	})
	IconArt.setImage(main, view.images[1], 1)
	table.insert(pictures, main)
	if two then
		local small: TextLabel = Create("TextLabel", {
			Name = "Picture2",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromScale(0.5, 0.5),
			FontFace = Theme.fonts.display,
			TextSize = 9,
			Text = "",
			ZIndex = 2,
			Parent = tile,
		})
		IconArt.setImage(small, view.images[2], 1)
		table.insert(pictures, small)
	end
	local chanceWidth = if view.chance ~= nil then CHANCE_WIDTH else 0
	local name = words({
		Name = "Name",
		Position = UDim2.fromOffset(TILE + 9, 0),
		Size = UDim2.new(1, -(TILE + 9 + chanceWidth + 4), 1, 0),
		TextSize = NAME_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = view.name,
		Parent = frame,
	})
	-- a long name (a food with its golden fish) steps down to fit rather than being cut
	name.TextScaled = true
	Create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = NAME_SIZE, Parent = name })
	local chance: TextLabel? = nil
	if view.chance ~= nil then
		chance = words({
			Name = "Chance",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 0),
			Size = UDim2.new(0, CHANCE_WIDTH, 1, 0),
			TextSize = NAME_SIZE,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if view.tier >= 3 then GOLD else WHITE,
			Text = view.chance,
			Parent = frame,
		})
	end
	return {
		frame = frame,
		stroke = stroke,
		tile = tile,
		pictures = pictures,
		name = name,
		chance = chance,
		tier = view.tier,
	}
end

-- A row at full strength, lit, or faded.
function RollBoard._paint(_self: any, row: RowParts, lit: boolean, faded: boolean)
	local fade = if faded then FADED else 0
	row.frame.BackgroundColor3 = if lit then LIT_FILL else ROW
	row.frame.BackgroundTransparency = fade
	row.stroke.Color = if lit then LIT else edgeFor(row.tier)
	row.stroke.Thickness = if lit then 3 else 2
	row.stroke.Transparency = fade
	row.tile.BackgroundTransparency = fade
	for _, picture in row.pictures do
		picture.TextTransparency = fade
		IconArt.setTransparency(picture, fade)
	end
	local function fadeLabel(label: TextLabel)
		label.TextTransparency = fade
		local stroke = label:FindFirstChildWhichIsA("UIStroke") :: UIStroke?
		if stroke ~= nil then
			stroke.Transparency = fade
		end
	end
	fadeLabel(row.name)
	local chance: TextLabel? = row.chance
	if chance ~= nil then
		fadeLabel(chance)
	end
end

function RollBoard._repaint(self: any)
	local lit: number? = self._lit
	for index, row in self._rows :: { RowParts } do
		local on = lit == index
		self:_paint(row, on, self._dim or (lit ~= nil and not on))
	end
end

function RollBoard.set(self: any, view: RollBoardLogic.View)
	self._title.Text = view.title
	self._line.Text = view.line
	self._foot.Text = view.foot or ""
	self._foot.Visible = view.foot ~= nil
	local parts: { string } = {}
	for _, row in view.rows do
		table.insert(parts, row.id .. "|" .. row.name .. "|" .. (row.chance or ""))
	end
	local key = table.concat(parts, ";")
	if key ~= self._key then
		self._key = key
		for _, row in self._rows :: { RowParts } do
			row.frame:Destroy()
		end
		local rows: { RowParts } = {}
		for index, row in view.rows do
			local made: RowParts = self:_row(index, row)
			table.insert(rows, made)
		end
		self._rows = rows
		self._lit = nil
	end
	self._dim = view.dim
	self:_repaint()
end

function RollBoard.light(self: any, index: number?)
	if self._lit == index then
		return
	end
	self._lit = index
	self:_repaint()
end

function RollBoard.destroy(self: any)
	self.frame:Destroy()
	self._rows = {}
end

return RollBoard
