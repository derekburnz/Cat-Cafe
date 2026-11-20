--!strict
-- The Christmas Event's Gift Stall (snowglobe-village-spec section 5), opened by the "Shop" prompt on the stall in
-- Snowglobe Village (tag SnowglobeStall, prompt SnowglobeStallPrompt) while the christmasEvent switch is on. Two tabs,
-- Outfits and Decor; a row each: the item's picture, its name, what it is, and a Snowflake price button ("Owned" in
-- grey once bought, grey while the player is short). The title band says how many Snowflakes the player has. Fixed
-- prices: nothing random, nothing for Robux. It reads a view ({ snowflakes, items = { id, name, cost, owned } },
-- Components/GiftStallLogic) and calls buy(id); the server checks everything and its sync answers the buy. A press
-- reads "..." until the view shows it owned or a few seconds pass. Walking away closes it. Modelled on
-- Screens/HarvestStall.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local GiftStallLogic = require(script.Parent.Parent.Components.GiftStallLogic)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal

export type Callbacks = {
	buy: (id: string) -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the stall: the window closes
}

export type GiftStall = {
	frame: Frame,
	render: (self: GiftStall, view: GiftStallLogic.View) -> (),
	showTab: (self: GiftStall, tab: GiftStallLogic.Tab) -> (),
	opened: (self: GiftStall) -> (),
	closed: (self: GiftStall) -> (),
	destroy: (self: GiftStall) -> (),
}

type Row = {
	id: string,
	tab: GiftStallLogic.Tab,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	buy: Button.Button,
	label: string?,
}

local MAX_SIZE = Vector2.new(560, 420)
local ROW_H = 76
local PICTURE = 60
local BUY_W = 150
local BADGE_H = 20
local PENDING_SECONDS = 4 -- a buy with no answer lets the button go again after this long
local GAP = Theme.sizes.gap
local GLYPH = "🎁" -- an item with no picture yet
local TABS: { { tab: GiftStallLogic.Tab, label: string } } = {
	{ tab = "outfit", label = "Outfits" },
	{ tab = "decor", label = "Decor" },
}
local TITLE = "Gift Stall"
local DETAIL: { [string]: string } = { outfit = "Hat for your cats", decor = "Cafe decor" }

local GiftStall = {}
GiftStall.__index = GiftStall

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function GiftStall.new(callbacks: Callbacks): GiftStall
	local self = setmetatable({}, GiftStall) :: any
	self._callbacks = callbacks
	self._view = nil :: GiftStallLogic.View?
	self._tab = "outfit" :: GiftStallLogic.Tab
	self._rows = {} :: { Row }
	self._tabs = {} :: { [string]: Button.Button }
	self._pending = nil :: string?
	self._pendingToken = 0
	self._open = false
	self._tick = 0
	local tabH = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	local buyH = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		dark = true,
		name = "GiftStall",
		title = TITLE,
		subtitle = "You have ❄ 0",
		color = Color3.fromHex("8FD3FF"),
		icon = GLYPH,
		-- as tall as the screen allows, up to MAX_SIZE (as the Oasis Spa, #3500): on a small phone the fixed height
		-- ran past the bottom of the screen (#3518)
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	local tabRow: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tabH),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, def in TABS do
		self._tabs[def.tab] = Button.new({
			name = def.label .. "Tab",
			text = def.label,
			style = if def.tab == "outfit" then "gold" else "ghost",
			size = UDim2.new(1 / #TABS, -GAP, 1, 0),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			parent = tabRow,
			sound = "uiTab",
			onClick = function()
				self:showTab(def.tab)
			end,
		})
	end

	local listTop = tabH + GAP
	self._list = Create("ScrollingFrame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 1, -listTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Outline.listPadding(10), -- #2294: room for the rows' outlines
	})

	for _, def in TABS do
		for order, row in GiftStallLogic.rows(GiftStallLogic.defaultView(nil), def.tab) do
			self:_row(def.tab, row, order, buyH)
		end
	end
	-- #5025 (QoL 1): a small phone shows 3 of a tab's rows; a "More below" pill (as the Ticket Booth's) sits over the
	-- list's bottom while rows are hidden under it, a tap scrolls one row down, and it goes once the bottom is in view
	local list: ScrollingFrame = self._list
	local more = Button.new({
		name = "MoreBelow",
		text = "▼ More below",
		style = "secondary",
		size = UDim2.fromOffset(130, 36),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -6),
		textSize = Theme.sizes.textSmall,
		parent = content,
		onClick = function()
			list.CanvasPosition = Vector2.new(0, list.CanvasPosition.Y + ROW_H + GAP)
		end,
	})
	more.instance.ZIndex = 5
	local function moreShown()
		local hidden = list.AbsoluteCanvasSize.Y
			- (list.CanvasPosition.Y + list.AbsoluteWindowSize.Y)
		more.instance.Visible = hidden > 8
	end
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(moreShown)
	list:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(moreShown)
	list:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(moreShown)
	self:showTab("outfit")
	moreShown()
	return self :: GiftStall
end

-- One row: the picture, the name, what it is, and the Snowflake price button.
function GiftStall._row(
	self: any,
	tab: GiftStallLogic.Tab,
	row: GiftStallLogic.Row,
	order: number,
	buyH: number
)
	local frame: Frame = Create("Frame", {
		Name = row.id,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Visible = false,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local icon = ItemIcon.new({
		parent = frame,
		size = UDim2.fromOffset(PICTURE, PICTURE),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 8, 0.5, 0),
	})
	icon:set(row.model, GLYPH, nil)
	local left = PICTURE + 18
	text({
		Name = "Name",
		Position = UDim2.fromOffset(left, 10),
		Size = UDim2.new(1, -(left + BUY_W + 16), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Text = row.name,
		Parent = frame,
	})
	text({
		Name = "Detail",
		Position = UDim2.fromOffset(left, 40),
		Size = UDim2.new(1, -(left + BUY_W + 16), 0, BADGE_H),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = DETAIL[row.kind] or "",
		Parent = frame,
	})
	local entry: Row = {
		id = row.id,
		tab = tab,
		frame = frame,
		icon = icon,
		buy = nil :: any,
		label = nil,
	}
	entry.buy = Button.new({
		name = "Buy",
		text = "",
		style = "gold",
		size = UDim2.fromOffset(BUY_W, buyH),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = frame,
		onClick = function()
			self:_press(entry)
		end,
	})
	table.insert(self._rows, entry)
end

-- The view's row for `entry`, nil when the view does not offer it.
local function rowOf(view: GiftStallLogic.View, entry: Row): GiftStallLogic.Row?
	for _, row in GiftStallLogic.rows(view, entry.tab) do
		if row.id == entry.id then
			return row
		end
	end
	return nil
end

function GiftStall._press(self: any, entry: Row)
	local view: GiftStallLogic.View? = self._view
	if view == nil or self._pending ~= nil then
		return
	end
	local row = rowOf(view, entry)
	if row == nil then
		return
	end
	local action = GiftStallLogic.action(view, row)
	if action.mode ~= "buy" or not action.enabled then
		return
	end
	self._pending = entry.id
	self._pendingToken += 1
	local token = self._pendingToken
	task.delay(PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending ~= nil then
			self._pending = nil
			self:_paint()
		end
	end)
	self:_paint()
	self._callbacks.buy(entry.id)
end

function GiftStall._paint(self: any)
	local view: GiftStallLogic.View? = self._view
	if view == nil then
		return
	end
	self._panel:setTitle(
		TITLE,
		("You have %s %d"):format(GiftStallLogic.FLAKE, GiftStallLogic.flakes(view))
	)
	for _, entry: Row in self._rows do
		local row = rowOf(view, entry)
		entry.frame:SetAttribute("Offered", row ~= nil)
		if row == nil then
			entry.frame.Visible = false
			continue
		end
		entry.frame.Visible = entry.tab == self._tab
		local pending = self._pending == entry.id
		local action = GiftStallLogic.action(view, row)
		local label = if pending then "..." else action.text
		-- the style keys it too: a price going from short to affordable keeps its text but turns gold
		local key = label .. "|" .. action.style
		if entry.label ~= key then
			entry.label = key
			entry.buy:setText(label)
			entry.buy:setStyle(action.style :: any)
		end
		entry.buy:setEnabled(action.enabled and self._pending == nil)
		entry.frame.BackgroundTransparency = if action.mode == "owned" then 0.35 else 0
	end
end

function GiftStall.showTab(self: any, tab: GiftStallLogic.Tab)
	self._tab = tab
	for name, button in self._tabs do
		button:setStyle(if name == tab then "gold" else "ghost")
	end
	for _, entry: Row in self._rows do
		entry.frame.Visible = entry.tab == tab and entry.frame:GetAttribute("Offered") ~= false
	end
	self._list.CanvasPosition = Vector2.zero
end

function GiftStall.render(self: any, view: GiftStallLogic.View)
	local before: GiftStallLogic.View? = self._view
	self._view = view
	-- a sync that shows the pending piece owned answers the buy
	local pending: string? = self._pending
	if pending ~= nil and GiftStallLogic.owns(view, pending) then
		self._pending = nil
		self._pendingToken += 1
	end
	if before ~= view or pending ~= nil then
		self:_paint()
	end
end

-- While open, walking away from the stall closes the window (checked once a second).
function GiftStall.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				local callbacks: Callbacks = self._callbacks
				local far = callbacks.far
				if far ~= nil and far() then
					callbacks.close()
					return
				end
			end
		end
	end)
end

function GiftStall.closed(self: any)
	self._open = false
	self._tick += 1
end

function GiftStall.destroy(self: any)
	self._open = false
	self._tick += 1
	for _, entry: Row in self._rows do
		entry.icon:destroy()
		entry.buy:destroy()
	end
	for _, button in self._tabs do
		button:destroy()
	end
	self._panel:destroy()
end

return GiftStall
