--!strict
-- The Garden Nursery's window (#1200, lawn-nursery.md section 2), opened by the "Nursery" prompt on the stall in the
-- Park camp (tag LawnStall, prompt LawnStallPrompt). Three tabs, Pieces, Paths and Fences; a row each: the piece's
-- picture, its name, its spot size (or Path / Fence) with its rarity badge, and a gold Buy with the price ("Owned" in
-- grey once bought, "Opens at Tier 3" in grey before its tier). Nothing rotates and nothing is limited: every piece is
-- always for sale. A press reads "..." until ProfileSync shows it owned or a few seconds pass; the server checks the
-- tier, the coins and that the player stands at the stall (BuyLawn). Walking away closes it. Rules: Components/LawnLogic.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LawnLogic = require(script.Parent.Parent.Components.LawnLogic)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

export type Callbacks = {
	buy: (id: string) -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the stall: the window closes
}

export type LawnStall = {
	frame: Frame,
	render: (self: LawnStall, state: Types.PlayerState) -> (),
	showTab: (self: LawnStall, tab: LawnLogic.StallTab) -> (),
	opened: (self: LawnStall) -> (),
	closed: (self: LawnStall) -> (),
	destroy: (self: LawnStall) -> (),
}

type Row = {
	row: LawnLogic.StallRow,
	tab: LawnLogic.StallTab,
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
local GLYPH = "🌷" -- a lawn piece with no picture yet (Screens/LawnTab's)
local TABS: { { tab: LawnLogic.StallTab, label: string } } = {
	{ tab = "pieces", label = "Pieces" },
	{ tab = "path", label = "Paths" },
	{ tab = "fence", label = "Fences" },
}

local LawnStall = {}
LawnStall.__index = LawnStall

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

function LawnStall.new(callbacks: Callbacks): LawnStall
	local self = setmetatable({}, LawnStall) :: any
	self._callbacks = callbacks
	self._state = nil :: Types.PlayerState?
	self._tab = "pieces" :: LawnLogic.StallTab
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
		name = "LawnStall",
		title = "Garden Nursery",
		subtitle = "Plants, paths and pretty things!",
		color = Theme.colors.good,
		icon = GLYPH,
		size = UDim2.new(1, 0, 0, MAX_SIZE.Y),
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
			style = if def.tab == "pieces" then "gold" else "ghost",
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
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	for _, def in TABS do
		for order, row in LawnLogic.stallRows(def.tab) do
			self:_row(def.tab, row, order, buyH)
		end
	end
	self:showTab("pieces")
	return self :: LawnStall
end

-- One row: the picture, the name, "Small spot" with the rarity badge, and the Buy button.
function LawnStall._row(
	self: any,
	tab: LawnLogic.StallTab,
	row: LawnLogic.StallRow,
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
	local line: Frame = Create("Frame", {
		Name = "Line",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, 40),
		Size = UDim2.new(1, -(left + BUY_W + 16), 0, BADGE_H),
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local badgeColor, badgeText = Theme.lawnRarityColors(row.rarity)
	local badge = text({
		Name = "Rarity",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, BADGE_H),
		BackgroundTransparency = 0,
		BackgroundColor3 = badgeColor,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = badgeText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = row.rarity,
		Parent = line,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = badge,
	})
	text({
		Name = "Detail",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(96, BADGE_H), -- "Small spot" whole at the small text size
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextTruncate = Enum.TextTruncate.None,
		Text = row.detail,
		Parent = line,
	})
	local entry: Row = {
		row = row,
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

function LawnStall._press(self: any, entry: Row)
	local state: Types.PlayerState? = self._state
	if state == nil or self._pending ~= nil then
		return
	end
	local action = LawnLogic.stallAction(state, entry.row)
	if action.mode ~= "buy" or not action.enabled then
		return
	end
	self._pending = entry.row.id
	self._pendingToken += 1
	local token = self._pendingToken
	task.delay(PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending ~= nil then
			self._pending = nil
			self:_paint()
		end
	end)
	self:_paint()
	self._callbacks.buy(entry.row.id)
end

function LawnStall._paint(self: any)
	local state: Types.PlayerState? = self._state
	if state == nil then
		return
	end
	for _, entry: Row in self._rows do
		local pending = self._pending == entry.row.id
		local action = LawnLogic.stallAction(state, entry.row)
		local label = if pending then "..." else action.text
		if entry.label ~= label then
			entry.label = label
			entry.buy:setText(label)
			entry.buy:setStyle(action.style :: any)
		end
		entry.buy:setEnabled(action.enabled and self._pending == nil)
		entry.frame.BackgroundTransparency = if action.mode == "owned" then 0.35 else 0
	end
end

function LawnStall.showTab(self: any, tab: LawnLogic.StallTab)
	self._tab = tab
	for name, button in self._tabs do
		button:setStyle(if name == tab then "gold" else "ghost")
	end
	for _, entry: Row in self._rows do
		entry.frame.Visible = entry.tab == tab
	end
	self._list.CanvasPosition = Vector2.zero
end

function LawnStall.render(self: any, state: Types.PlayerState)
	local before: Types.PlayerState? = self._state
	self._state = state
	-- a sync that shows the pending piece owned answers the buy
	local pending: string? = self._pending
	if pending ~= nil and LawnLogic.owns(state, pending) then
		self._pending = nil
		self._pendingToken += 1
	end
	if before ~= state or pending ~= nil then
		self:_paint()
	end
end

-- While open, walking away from the stall closes the window (checked once a second).
function LawnStall.opened(self: any)
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

function LawnStall.closed(self: any)
	self._open = false
	self._tick += 1
end

function LawnStall.destroy(self: any)
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

return LawnStall
