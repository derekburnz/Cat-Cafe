--!strict
-- The station perk card (#2687 part 4, Derek2 2026-11-09: "make unlocking the stations inside new areas more impactful
-- so it feels like you are actually unlocking progress"). One dark card in the middle of the screen, over the windows
-- (the rank up window opens the list), under the toasts. Components/PerkCardLogic says what it shows.
--   PerkCard.new(parent)
--   card:showUnlocked(perk)   "Unlocked!": the station's picture and name, "New perk: <name>" in gold and its one line;
--                             init shows it a beat after Moments.StationReveal, once the station has built in
--   card:showList(tier)       "Your perks": each owned perk's row, then the next one locked ("Opens at Tier 5"); it
--                             scrolls when the screen is short
--   card:hide(), card:isShowing(), card:destroy()
-- The one button closes it. With Roblox's Reduce Motion on the card shows without its pop.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local PerkCardLogic = require(script.Parent.Parent.Components.PerkCardLogic)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)

local PAL = MenuFamily.pal

export type PerkCard = {
	screenGui: ScreenGui,
	showUnlocked: (self: PerkCard, perk: PerkCardLogic.Perk, pool: boolean?) -> (),
	showList: (self: PerkCard, tier: number?, pool: boolean?) -> (),
	hide: (self: PerkCard) -> (),
	isShowing: (self: PerkCard) -> boolean,
	destroy: (self: PerkCard) -> (),
}

local CARD_W = 480 -- room for the longest perk line ("+1 golden fish on the first catch of each new cat")
local PAD = 16
local TITLE_H = 34
local GAP = 10
local ICON = 64 -- the Unlocked card's station picture
local STATION_H = 30
local LINE_H = Theme.sizes.textBody + 8
local ROW_H = 52 -- a perk's row in the list: its name over its one line
local ROW_ICON = 36
local LIST_PAD = 3 -- the list's inner margin, past a row's 2 px edge
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local PerkCard = {}
PerkCard.__index = PerkCard

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function PerkCard.new(parent: Instance): PerkCard
	local self = setmetatable({}, PerkCard) :: any
	self._mode = "unlocked" :: "unlocked" | "list"
	self._rows = {} :: { Frame }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafePerks",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 22, -- over the windows (20), so the rank up window's list shows on it; under the toasts (30)
		Parent = parent,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)
	self._root = root

	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD_W, 260),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 3 }),
	})
	self._card = card
	self._pop = Create("UIScale", { Parent = card }) :: UIScale

	local title = label({
		Name = "Title",
		Position = UDim2.fromOffset(PAD, PAD - 4),
		Size = UDim2.new(1, -PAD * 2, 0, TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge + 2,
		TextColor3 = PAL.gold,
		Parent = card,
	})
	Outline.text(title, 1.5)
	self._title = title

	-- the Unlocked card's middle: the picture, the station, the perk and its line
	local unlocked: Frame = Create("Frame", {
		Name = "Unlocked",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD + TITLE_H),
		Size = UDim2.new(1, -PAD * 2, 0, ICON + STATION_H + LINE_H * 2 + GAP),
		Parent = card,
	})
	self._unlocked = unlocked
	self._icon = label({
		Name = "Icon",
		Size = UDim2.new(1, 0, 0, ICON),
		FontFace = Theme.fonts.display,
		TextSize = ICON - 8,
		TextTruncate = Enum.TextTruncate.None,
		Parent = unlocked,
	})
	self._station = label({
		Name = "Station",
		Position = UDim2.fromOffset(0, ICON),
		Size = UDim2.new(1, 0, 0, STATION_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = unlocked,
	})
	self._perk = label({
		Name = "Perk",
		Position = UDim2.fromOffset(0, ICON + STATION_H + GAP / 2),
		Size = UDim2.new(1, 0, 0, LINE_H),
		TextColor3 = PAL.gold,
		Parent = unlocked,
	})
	self._perkText = label({
		Name = "PerkText",
		Position = UDim2.fromOffset(0, ICON + STATION_H + GAP / 2 + LINE_H),
		Size = UDim2.new(1, 0, 0, LINE_H),
		FontFace = Theme.fonts.body,
		TextColor3 = PAL.subtext,
		Parent = unlocked,
	})

	-- the list's rows, scrolling when the screen is short
	local list: ScrollingFrame = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD, PAD + TITLE_H),
		Size = UDim2.new(1, -PAD * 2, 0, ROW_H),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		Visible = false,
		Parent = card,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- room for each row's gold edge inside the scrolling list's clip
		Create("UIPadding", {
			PaddingTop = UDim.new(0, LIST_PAD),
			PaddingBottom = UDim.new(0, LIST_PAD),
			PaddingLeft = UDim.new(0, LIST_PAD),
			PaddingRight = UDim.new(0, LIST_PAD),
		}),
	})
	self._list = list

	self._button = Button.new({
		name = "Ok",
		text = PerkCardLogic.OK,
		style = "gold",
		size = UDim2.new(1, -PAD * 2, 0, Theme.sizes.touchMin),
		textSize = Theme.sizes.textBody + 2,
		parent = card,
		onClick = function()
			self:hide()
		end,
	})

	self._resize = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if card.Visible then
			self:_layout()
		end
	end)
	return self :: PerkCard
end

function PerkCard._row(self: any, index: number, row: PerkCardLogic.Row): Frame
	local frame: Frame = Create("Frame", {
		Name = "Row_" .. row.id,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.new(1, -(8 + LIST_PAD * 2), 0, ROW_H),
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIStroke", {
			Color = if row.owned then Theme.colors.gold else PAL.cardStroke,
			Thickness = Theme.sizes.stroke,
		}),
	})
	label({
		Name = "Icon",
		Position = UDim2.fromOffset(8, (ROW_H - ROW_ICON) / 2),
		Size = UDim2.fromOffset(ROW_ICON, ROW_ICON),
		TextSize = ROW_ICON - 6,
		TextTruncate = Enum.TextTruncate.None,
		TextTransparency = if row.owned then 0 else 0.3,
		Text = row.icon,
		Parent = frame,
	})
	local left = 8 + ROW_ICON + 8
	label({
		Name = "Name",
		Position = UDim2.fromOffset(left, 5),
		Size = UDim2.new(1, -(left + 8), 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if row.owned then PAL.gold else PAL.subtext,
		Text = row.title,
		Parent = frame,
	})
	label({
		Name = "Line",
		Position = UDim2.fromOffset(left, 27),
		Size = UDim2.new(1, -(left + 8), 0, 20),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if row.owned then PAL.text else PAL.subtext,
		Text = row.text,
		Parent = frame,
	})
	return frame
end

-- The card is CARD_W wide, or the screen less 16 px a side; the list takes the rows it has, no taller than the screen
-- leaves (it scrolls past that).
function PerkCard._layout(self: any)
	local scale = math.max(self._uiScale.Scale, 0.01)
	local room = self._root.AbsoluteSize / scale
	local width = math.min(CARD_W, math.max(280, room.X - 32))
	local y = PAD + TITLE_H
	if self._mode == "list" then
		local count = #self._rows
		local full = count * ROW_H + math.max(count - 1, 0) * 6 + LIST_PAD * 2
		local fixed = y + GAP + Theme.sizes.touchMin + PAD
		local most = math.max(ROW_H, room.Y - 24 - fixed)
		local listH = math.min(full, most)
		self._list.Size = UDim2.new(1, -PAD * 2, 0, listH)
		y += listH
	else
		y += self._unlocked.Size.Y.Offset
	end
	y += GAP
	self._button.instance.Position = UDim2.fromOffset(PAD, y)
	y += Theme.sizes.touchMin + PAD
	self._card.Size = UDim2.fromOffset(width, y)
end

function PerkCard._open(self: any)
	self:_layout()
	self._card.Visible = true
	if GuiService.ReducedMotionEnabled then
		self._pop.Scale = 1
	else
		self._pop.Scale = 0.6
		TweenService:Create(self._pop, POP, { Scale = 1 }):Play()
	end
end

function PerkCard._clearRows(self: any)
	for _, row in self._rows :: { Frame } do
		row:Destroy()
	end
	table.clear(self._rows)
end

function PerkCard.showUnlocked(self: any, perk: PerkCardLogic.Perk, pool: boolean?)
	local view = PerkCardLogic.unlocked(perk, pool)
	self._mode = "unlocked"
	self:_clearRows()
	self._title.Text = "🎉 " .. view.title
	self._icon.Text = view.icon
	self._station.Text = view.station
	self._perk.Text = "⭐ " .. view.perk
	self._perkText.Text = view.text
	self._unlocked.Visible = true
	self._list.Visible = false
	self._button:setText(PerkCardLogic.OK)
	self:_open()
	Sound.play("giftClaim")
end

function PerkCard.showList(self: any, tier: number?, pool: boolean?)
	self._mode = "list"
	self:_clearRows()
	self._title.Text = "⭐ " .. PerkCardLogic.LIST_TITLE
	local rows = PerkCardLogic.list(tier, pool)
	for index, row in rows do
		local frame: Frame = self:_row(index, row)
		table.insert(self._rows, frame)
	end
	self._list.CanvasPosition = Vector2.zero
	self._unlocked.Visible = false
	self._list.Visible = true
	self._button:setText(PerkCardLogic.CLOSE)
	self:_open()
end

function PerkCard.hide(self: any)
	self._card.Visible = false
end

function PerkCard.isShowing(self: any): boolean
	return self._card.Visible
end

function PerkCard.destroy(self: any)
	self._resize:Disconnect()
	self:_clearRows()
	self._button:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return PerkCard
