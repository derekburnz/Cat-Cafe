--!strict
-- #5502 the Christmas advent calendar's card (Design-Agent's advent-calendar-spec.md). One line on top says what is
-- next ("Door 7 is ready!", "Next door tomorrow") with OPEN beside it, then the 24 doors, six to a line: each shows
-- its number and its prize in words before it opens, so nothing is a surprise box. An opened door is tinted green
-- with a tick, the door a tap opens now wears a green border, a door whose date has not come shows its date, and the
-- four calendar cats' doors (6, 12, 18 and 24) are gold. Opened from the Rewards list's Advent row and the board in
-- the Town Square (Controllers/AdventBoardController). OPEN reads "..." until a sync opens the door or
-- PENDING_SECONDS pass; the server alone decides (dates and both switches) and takes no door number.
-- Rules: Components/AdventLogic. The card never opens by itself.

local AdventLogic = require(script.Parent.Parent.Components.AdventLogic)
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local PAL = MenuFamily.pal
local CREAM = MenuFamily.card

export type Callbacks = {
	open: () -> (), -- OPEN, or a tap on the door that is ready
	close: () -> (),
}

export type AdventCalendar = {
	frame: Frame,
	setCatalog: (self: AdventCalendar, catalog: Types.Catalog) -> (),
	render: (self: AdventCalendar, state: Types.PlayerState) -> (),
	onOpen: (self: AdventCalendar) -> (),
	destroy: (self: AdventCalendar) -> (),
}

type Tile = {
	frame: Frame,
	stroke: UIStroke,
	prize: TextLabel,
	status: TextLabel,
	tick: TextLabel,
	tap: TextButton,
	cat: boolean,
}

local COLUMNS = 6
local GAP = 8
local TILE_H, SHORT_TILE_H = 82, 64
local STRIP_H, SHORT_STRIP_H = 44, 36
local OPEN_W = 150
local PENDING_SECONDS = 2
local GOLD_FILL = CREAM.goldCard

local AdventCalendar = {}
AdventCalendar.__index = AdventCalendar

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CREAM.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function AdventCalendar.new(callbacks: Callbacks): AdventCalendar
	local self = setmetatable({}, AdventCalendar) :: any
	self._callbacks = callbacks
	self._view = nil :: AdventLogic.View?
	self._names = {} :: { [string]: string } -- cat id -> its catalog name
	self._tiles = {} :: { [number]: Tile }
	self._pendingAt = nil :: number? -- os.clock() of the last OPEN press
	local short = Scale.isShort()
	local tileH = if short then SHORT_TILE_H else TILE_H
	local stripH = if short then SHORT_STRIP_H else STRIP_H

	local panel = Panel.new({
		name = "AdventCalendar",
		title = "Advent Calendar",
		subtitle = "One door a day until Christmas · missed doors wait for you",
		color = Theme.colors.berry,
		dark = true,
		icon = Theme.icons.gifts,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(700, 470), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	local strip: Frame = Create("Frame", {
		Name = "Strip",
		BackgroundColor3 = CREAM.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, stripH),
		Parent = panel.content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CREAM.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	self._line = text({
		Name = "Next",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -(OPEN_W + 28), 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = strip,
	})
	self._open = Button.new({
		name = "Open",
		text = "OPEN",
		style = "primary",
		size = UDim2.fromOffset(OPEN_W, stripH - 8),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -4, 0.5, 0),
		textSize = Theme.sizes.textBody + 1,
		parent = strip,
		onClick = function()
			self:_press()
		end,
	})
	self._open.instance.Visible = false

	local grid: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Doors",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, stripH + GAP),
		Size = UDim2.new(1, 0, 1, -(stripH + GAP)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIGridLayout", {
			-- six to a line whatever the window's width: each cell a sixth of the line less its share of the gaps
			CellSize = UDim2.new(1 / COLUMNS, -GAP, 0, tileH),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			FillDirectionMaxCells = COLUMNS,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 9),
		}),
	})
	self._grid = grid

	for _, cell in AdventLogic.cells(nil) do
		local cat = cell.cat ~= nil
		local frame: Frame = Create("Frame", {
			Name = ("Door%02d"):format(cell.n),
			BackgroundColor3 = if cat then GOLD_FILL else CREAM.card,
			BorderSizePixel = 0,
			LayoutOrder = cell.n,
			Parent = grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		})
		local stroke: UIStroke = Create("UIStroke", {
			Color = CREAM.cardStroke,
			Thickness = Theme.sizes.stroke,
			Parent = frame,
		})
		text({
			Name = "Number",
			Position = UDim2.fromOffset(7, 2),
			Size = UDim2.new(1, -34, 0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 2,
			TextColor3 = if cat then CREAM.gold else CREAM.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if cat then ("%d ★"):format(cell.n) else tostring(cell.n),
			Parent = frame,
		})
		local tick: TextLabel = text({
			Name = "Tick",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 3),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.good,
			FontFace = Theme.fonts.display,
			TextColor3 = Theme.colors.white,
			Text = "✓",
			Visible = false,
			ZIndex = 2,
			Parent = frame,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = tick })
		local prize = text({
			Name = "Prize",
			Position = UDim2.fromOffset(5, 22),
			Size = UDim2.new(1, -10, 1, -42),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextScaled = true,
			Parent = frame,
		})
		Create("UITextSizeConstraint", {
			MinTextSize = 9,
			MaxTextSize = Theme.sizes.textSmall,
			Parent = prize,
		})
		local status = text({
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, -8, 0, 16),
			FontFace = Theme.fonts.display,
			TextColor3 = CREAM.subtext,
			Parent = frame,
		})
		-- the door that is ready opens on a tap anywhere on it
		local tap: TextButton = Create("TextButton", {
			Name = "Tap",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			AutoButtonColor = false,
			Visible = false,
			ZIndex = 3,
			Parent = frame,
		})
		tap.Activated:Connect(function()
			self:_press()
		end)
		self._tiles[cell.n] = {
			frame = frame,
			stroke = stroke,
			prize = prize,
			status = status,
			tick = tick,
			tap = tap,
			cat = cat,
		}
	end

	self:_refresh()
	return self :: AdventCalendar
end

function AdventCalendar._press(self: any)
	local view: AdventLogic.View? = self._view
	if view == nil or not view.ready then
		return
	end
	local pendingAt: number? = self._pendingAt
	if pendingAt ~= nil and os.clock() - pendingAt < PENDING_SECONDS then
		return
	end
	self._pendingAt = os.clock()
	self._callbacks.open()
	self:_refresh()
	-- OPEN comes back as soon as the wait is over if no sync answered
	task.delay(PENDING_SECONDS, function()
		if self._tiles[1] then
			self:_refresh()
		end
	end)
end

function AdventCalendar.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._names)
	for _, def in catalog.cats do
		self._names[def.id] = def.name
	end
	self:_refresh()
end

function AdventCalendar.render(self: any, state: Types.PlayerState)
	local view: AdventLogic.View? = (state :: any).advent
	local before: AdventLogic.View? = self._view
	self._view = view
	local newest: number? = if before ~= nil
			and view ~= nil
			and view.opened > before.opened
		then view.opened
		else nil
	if newest ~= nil then
		self._pendingAt = nil
	end
	self:_refresh()
	local tile: Tile? = if newest ~= nil then self._tiles[newest] else nil
	if tile ~= nil and self.frame.Visible then
		Sound.play(if tile.cat then "jingleDailyCard" else "uiDailyStamp")
		Tween.popIn(tile.tick, 0.5)
	end
end

function AdventCalendar._refresh(self: any)
	if not self.frame.Visible then
		return
	end
	local view: AdventLogic.View? = self._view
	local pendingAt: number? = self._pendingAt
	local pending = pendingAt ~= nil and os.clock() - pendingAt < PENDING_SECONDS
	for _, cell in AdventLogic.cells(view) do
		local tile: Tile? = self._tiles[cell.n]
		if tile == nil then
			continue
		end
		local opened = cell.state == "opened"
		local ready = cell.state == "ready"
		tile.prize.Text = AdventLogic.prizeText(
			cell.prize,
			if cell.cat then self._names[cell.cat] or "A cat" else nil
		)
		tile.status.Text = if opened
			then "Opened"
			elseif ready then (if pending then "..." else "Tap to open")
			elseif cell.state == "waiting" then "Soon"
			else cell.date
		tile.status.TextColor3 = if opened or ready then CREAM.good else CREAM.subtext
		tile.tick.Visible = opened
		tile.tap.Visible = ready
		tile.stroke.Color = if ready
			then Theme.colors.good
			elseif tile.cat then Theme.colors.goldDark
			else CREAM.cardStroke
		tile.stroke.Thickness = Theme.sizes.stroke + (if ready or tile.cat then 1 else 0)
		if tile.cat then
			tile.frame.BackgroundTransparency = if opened then 0.35 else 0
		else
			tile.frame.BackgroundColor3 = if opened
				then CREAM.card:Lerp(Theme.colors.good, 0.22)
				else CREAM.card
		end
	end

	local ready = view ~= nil and view.ready
	self._line.Text = AdventLogic.headline(view)
	self._line.TextColor3 = if ready then CREAM.good else CREAM.text
	self._open.instance.Visible = ready
	self._open:setEnabled(not pending)
	self._open:setText(if pending then "..." else "OPEN")
end

-- The window opened: the line the ready door is on scrolls into view.
function AdventCalendar.onOpen(self: any)
	self:_refresh()
	local view: AdventLogic.View? = self._view
	local grid: ScrollingFrame = self._grid
	local tile: Tile? = if view ~= nil
		then self._tiles[math.clamp(view.opened + 1, 1, AdventLogic.DOORS)]
		else nil
	if tile ~= nil then
		local top = tile.frame.AbsolutePosition.Y - grid.AbsolutePosition.Y + grid.CanvasPosition.Y
		local room = grid.AbsoluteWindowSize.Y - tile.frame.AbsoluteSize.Y
		if top > grid.CanvasPosition.Y + room or top < grid.CanvasPosition.Y then
			grid.CanvasPosition = Vector2.new(0, math.max(0, top - GAP))
		end
	end
end

function AdventCalendar.destroy(self: any)
	self._open:destroy()
	table.clear(self._tiles)
	self._panel:destroy()
end

return AdventCalendar
