--!strict
-- The Rummage Bin's loot card (#3464): "You found:" over one row per item won, each with the item's picture, its name
-- and its amount ("x2", "+10"). It shows in the lower middle of the screen where the bar's win banner was, stays
-- LootCardLogic.SECONDS or until tapped, and never blocks anything else: only the card itself takes the tap. A win
-- with a golden crate wears a gold frame. What it lists is LootCardLogic.rows of the server's win.
--   show(win)        the card for that win; nothing for a win with no rows
--   hide()
--   isShowing() -> boolean
-- Names for Motion-FX-Agent: the card is `Card` in the ScreenGui CatCafeLoot, its rows `Row1`..`Row4` inside `Rows`,
-- each row's picture `Icon`.

local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LootCardLogic = require(script.Parent.Parent.Components.LootCardLogic)
local Motion = require(script.Parent.Parent.Components.Motion)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type LootCard = {
	screenGui: ScreenGui,
	show: (self: LootCard, win: unknown) -> (),
	hide: (self: LootCard) -> (),
	isShowing: (self: LootCard) -> boolean,
	destroy: (self: LootCard) -> (),
}

local CARD_W = 300
local PAD = 12
local TITLE_H = 28
local ROW_H = 48 -- 36 px on a phone, where the UI is drawn at 0.75 (#3464)
local ROW_GAP = 4
local ICON = 40
local BOTTOM = 110 -- as the rescue bar's result banner: clear of the hotbar

local LootCard = {}
LootCard.__index = LootCard

function LootCard.new(parent: Instance): LootCard
	local self = setmetatable({}, LootCard) :: any
	self._token = 0
	self._icons = {} :: { ItemIcon.ItemIcon }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeLoot",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 11, -- over the HUD (10), under the windows
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

	-- the card is the button: a tap anywhere on it closes it, and nothing outside it takes input
	local card: TextButton = Create("TextButton", {
		Name = "Card",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM),
		Size = UDim2.fromOffset(CARD_W, 120),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 2) }),
	})
	self._card = card
	self._stroke = Create("UIStroke", {
		Name = "Frame",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.colors.outline,
		Thickness = Theme.sizes.outline + 1,
		Parent = card,
	}) :: UIStroke
	Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD - 4),
		Size = UDim2.new(1, -PAD * 2, 0, TITLE_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 5,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = LootCardLogic.TITLE,
		Parent = card,
	})
	local rows: Frame = Create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD - 4 + TITLE_H + 2),
		Size = UDim2.new(1, -PAD * 2, 0, ROW_H),
		Parent = card,
	})
	self._rows = rows
	card.Activated:Connect(function()
		self:hide()
	end)
	return self :: LootCard
end

function LootCard._clear(self: any)
	for _, icon: ItemIcon.ItemIcon in self._icons do
		icon:destroy()
	end
	table.clear(self._icons)
	for _, child in (self._rows :: Frame):GetChildren() do
		child:Destroy()
	end
end

function LootCard._row(self: any, index: number, row: LootCardLogic.Row): Frame
	local frame: Frame = Create("Frame", {
		Name = "Row" .. index,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, (index - 1) * (ROW_H + ROW_GAP)),
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = self._rows,
	})
	local icon = ItemIcon.new({
		parent = frame,
		name = "Icon",
		size = UDim2.fromOffset(ICON, ICON),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 0, 0.5, 0),
		badge = "none",
	})
	table.insert(self._icons, icon)
	if row.kind == "lure" then
		icon:set(
			nil,
			Theme.foodIcons[row.id or ""] or Theme.icons.food,
			"Rare",
			ShopIcons.food(row.id)
		)
	elseif row.kind == "crate" then
		local golden = row.id ~= nil and string.find(row.id, "golden", 1, true) ~= nil
		icon:set(
			nil,
			Theme.icons.crate,
			if golden then "Legendary" else "Rare",
			ShopIcons.crate(row.id)
		)
	elseif row.kind == "potion" then
		icon:setPotion(row.id, "Epic")
	else
		icon:set(nil, Theme.icons.goldenFish, "Legendary", ShopIcons.prize("fish"))
	end
	Create("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(ICON + 10, 0),
		Size = UDim2.new(1, -(ICON + 10 + 64), 1, 0),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = row.name,
		Parent = frame,
	})
	local amount: TextLabel = Create("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 60, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 4,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = row.amount,
		Parent = frame,
	})
	Outline.text(amount, 2)
	return frame
end

function LootCard.show(self: any, win: unknown)
	local rows = LootCardLogic.rows(win)
	if #rows == 0 then
		return
	end
	self._token += 1
	local token = self._token
	self:_clear()
	local gold = LootCardLogic.gold(win)
	local stroke: UIStroke = self._stroke
	stroke.Color = if gold then Theme.colors.gold else Theme.colors.outline
	local card: TextButton = self._card
	local tall = #rows * ROW_H + (#rows - 1) * ROW_GAP
	local holder: Frame = self._rows
	holder.Size = UDim2.new(1, -PAD * 2, 0, tall)
	card.Size = UDim2.fromOffset(CARD_W, PAD - 4 + TITLE_H + 2 + tall + PAD)
	local still = Motion.reduced()
	for index, row in rows do
		local frame = self:_row(index, row)
		if not still and index > 1 then
			-- the rows land one after the other
			frame.Visible = false
			task.delay((index - 1) * LootCardLogic.ROW_GAP_SECONDS, function()
				if self._token == token and frame.Parent ~= nil then
					frame.Visible = true
				end
			end)
		end
	end
	card.Visible = true
	if not still then
		Tween.popIn(card, 0.8)
	end
	task.delay(LootCardLogic.SECONDS, function()
		if self._token == token then
			self:hide()
		end
	end)
end

function LootCard.hide(self: any)
	self._token += 1
	local card: TextButton = self._card
	card.Visible = false
	self:_clear()
end

function LootCard.isShowing(self: any): boolean
	return (self._card :: TextButton).Visible
end

function LootCard.destroy(self: any)
	self:hide()
	local screenGui: ScreenGui = self.screenGui
	screenGui:Destroy()
end

return LootCard
