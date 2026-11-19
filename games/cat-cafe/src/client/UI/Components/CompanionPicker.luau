--!strict
-- #5296 (Derek 2026-11-18: "add a "companion" button and then from there can choose which companion with a preview of
-- what stats they boost for luck/money"; Design-Agent's companion-menu mock), switch companionMenu: the Cats window's
-- picker. It covers the window: "Pick your Companion", then a card per cat, best first (CompanionPicker.order), each
-- with its picture, name, rarity, its Money and Luck as the companion, and Follow (Following on the companion, which
-- sends it home). At most MAX cards, so a big collection never builds hundreds of 3D pictures.
--   CompanionPicker.order(cats, catById) -> { Types.CatInstance }   pure: best first
--   picker = CompanionPicker.new({ parent, follow })
--   picker:open(cats, catById, followUid) / picker:close() / picker:isOpen()
--   picker:render(cats, catById, followUid)   while open: the Follow / Following words

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local CatPortrait = require(script.Parent.CatPortrait)
local CompanionLogic = require(script.Parent.CompanionLogic)
local Create = require(script.Parent.Create)
local MenuFamily = require(script.Parent.MenuFamily)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Follower = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Follower")) :: any

local PAL = MenuFamily.pal

local CompanionPicker = {}
CompanionPicker.__index = CompanionPicker

CompanionPicker.MAX = 24
CompanionPicker.TITLE = "Pick your Companion"
CompanionPicker.NOTE = "They follow you and boost Money and Luck, and they keep their cafe job."

local CARD = Vector2.new(128, 184)
local CHIP_H = 14 -- #5303: the trait chip's row, added to the card while companionTraits is on
local ART = 64
local GAP = Theme.sizes.gap
local BUTTON_H = Scale.tapHeight(Theme.sizes.touchMin)

export type Props = {
	parent: Instance,
	follow: (uid: string) -> (), -- "" sends the companion home
}

type Card = {
	frame: Frame,
	portrait: any,
	button: any,
	uid: string,
}

-- Best first (Components/CompanionLogic).
CompanionPicker.order = CompanionLogic.order

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function CompanionPicker.new(props: Props)
	local self = setmetatable({}, CompanionPicker) :: any
	self._props = props
	self._cards = {} :: { Card }
	self._shownKey = ""
	local frame: Frame = Create("Frame", {
		Name = "CompanionPicker",
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Active = true,
		Parent = props.parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	Outline.border(frame, Theme.sizes.stroke, PAL.cardStroke)
	self.frame = frame
	label({
		Name = "Title",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -(BUTTON_H + 36), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = CompanionPicker.TITLE,
		ZIndex = 31,
		Parent = frame,
	})
	label({
		Name = "Note",
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -(BUTTON_H + 36), 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = CompanionPicker.NOTE,
		ZIndex = 31,
		Parent = frame,
	})
	self._close = Button.new({
		name = "Close",
		-- #5359 (Derek 2026-11-18: "in companion menu X is just a white box"): the menus' own close button (Panel),
		-- not a ghost one with a ✕ the font draws as a blank box
		text = "X",
		style = "close",
		textSize = Theme.sizes.textLarge + 2,
		size = UDim2.fromOffset(BUTTON_H, BUTTON_H),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -8, 0, 8),
		parent = frame,
		zIndex = 32,
		onClick = function()
			self:close()
		end,
	})
	local top = 8 + BUTTON_H + 6
	local grid: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Cats",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, top),
		Size = UDim2.new(1, -16, 1, -(top + 8)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 31,
		Parent = frame,
	}, {
		Create("UIGridLayout", {
			Name = "Grid",
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	self._grid = grid
	return self
end

function CompanionPicker.isOpen(self: any): boolean
	return self.frame.Visible
end

function CompanionPicker.close(self: any)
	self.frame.Visible = false
	self:_clear()
end

function CompanionPicker._clear(self: any)
	for _, card in self._cards do
		card.portrait:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
	self._shownKey = ""
end

function CompanionPicker.open(
	self: any,
	cats: { [string]: Types.CatInstance }?,
	catById: { [string]: Types.CatDef },
	followUid: string?
)
	self.frame.Visible = true
	self:render(cats, catById, followUid)
end

function CompanionPicker.render(
	self: any,
	cats: { [string]: Types.CatInstance }?,
	catById: { [string]: Types.CatDef },
	followUid: string?
)
	if not self.frame.Visible then
		return
	end
	local list = CompanionPicker.order(cats, catById)
	local uids: { string } = {}
	local keys: { string } = {}
	for index = 1, math.min(#list, CompanionPicker.MAX) do
		local cat = list[index]
		table.insert(uids, cat.uid)
		table.insert(keys, cat.uid .. ":" .. (if cat.trait then cat.trait.id else ""))
	end
	self._followUid = followUid
	-- #5303: the cards build again when a trait changes or the companionTraits switch flips
	local chips = Follower.traitsOn()
	local key = table.concat(keys, ",") .. (if chips then "|t" else "")
	if key ~= self._shownKey then
		self:_clear()
		self._shownKey = key
		self._chips = chips
		local layout = self._grid:FindFirstChild("Grid") :: UIGridLayout?
		if layout then
			layout.CellSize = UDim2.fromOffset(CARD.X, CARD.Y + (if chips then CHIP_H else 0))
		end
		for index = 1, #uids do
			local cat = list[index]
			local def: Types.CatDef? = catById[cat.catId]
			local made: Card = self:_card(index, cat, def)
			table.insert(self._cards :: { Card }, made)
		end
	end
	for _, card in self._cards do
		local following = followUid ~= nil and followUid ~= "" and card.uid == followUid
		card.button:setText(if following then "Following" else "Follow")
		card.button:setStyle(if following then "slate" else "primary")
		local stroke = card.frame:FindFirstChildOfClass("UIStroke")
		if stroke ~= nil then
			stroke.Color = if following then Theme.colors.gold else PAL.cardStroke
			stroke.Thickness = if following then 4 else Theme.sizes.stroke
		end
	end
end

function CompanionPicker._card(
	self: any,
	index: number,
	cat: Types.CatInstance,
	def: Types.CatDef?
): Card
	local frame: Frame = Create("Frame", {
		Name = cat.uid,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		ZIndex = 31,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
	})
	Outline.border(frame, Theme.sizes.stroke, PAL.cardStroke)
	local portrait = CatPortrait.new({
		parent = frame,
		size = UDim2.fromOffset(ART, ART),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 4),
		still = true,
		zIndex = 32,
	})
	portrait:set(def, cat.variant == "gold")
	local rarity = if def then def.rarity else nil
	local name = if type(cat.name) == "string" and cat.name ~= ""
		then cat.name
		elseif def then def.name
		else "Cat"
	local coat = if cat.variant == "rainbow"
		then " 🌈"
		elseif cat.variant == "gold" then " ✨"
		else ""
	label({
		Name = "Name",
		Position = UDim2.fromOffset(4, ART + 6),
		Size = UDim2.new(1, -8, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		Text = name .. coat,
		ZIndex = 32,
		Parent = frame,
	})
	label({
		Name = "Rarity",
		Position = UDim2.fromOffset(4, ART + 22),
		Size = UDim2.new(1, -8, 0, 14),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.rarityColor(rarity),
		Text = rarity or "",
		ZIndex = 32,
		Parent = frame,
	})
	local money = Follower.catAmount(cat, rarity, "money") -- #5303: its trait included
	local percent = math.floor(money * 1000 + 0.5) / 10
	label({
		Name = "Money",
		Position = UDim2.fromOffset(4, ART + 36),
		Size = UDim2.new(1, -8, 0, 14),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.gold,
		Text = if percent == math.floor(percent)
			then string.format("+%d%% Money", percent)
			else string.format("+%.1f%% Money", percent),
		ZIndex = 32,
		Parent = frame,
	})
	label({
		Name = "Luck",
		Position = UDim2.fromOffset(4, ART + 50),
		Size = UDim2.new(1, -8, 0, 14),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.good,
		Text = string.format("+%.2f Luck", Follower.catAmount(cat, rarity, "luck")),
		ZIndex = 32,
		Parent = frame,
	})
	-- #5303: the trait chip under the numbers, in the trait's rarity colour ("Loyal Heart +3%")
	local chipRow = if self._chips == true then CHIP_H else 0
	local chip: string? = if chipRow > 0 then Follower.traitChip(cat.trait) else nil
	if chip ~= nil then
		local color: string? = Follower.traitColor(cat.trait)
		label({
			Name = "TraitChip",
			Position = UDim2.fromOffset(4, ART + 64),
			Size = UDim2.new(1, -8, 0, CHIP_H),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = if color then Color3.fromHex(color) else PAL.text,
			Text = chip,
			ZIndex = 32,
			Parent = frame,
		})
	end
	local uid = cat.uid
	local button = Button.new({
		name = "Follow",
		text = "Follow",
		style = "primary",
		size = UDim2.new(1, -12, 0, math.min(BUTTON_H, CARD.Y - (ART + 68) - 4)),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -4),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		zIndex = 33,
		onClick = function()
			local current: any = self._followUid
			self._props.follow(if current == uid then "" else uid)
		end,
	})
	return { frame = frame, portrait = portrait, button = button, uid = uid }
end

function CompanionPicker.destroy(self: any)
	self:_clear()
	self.frame:Destroy()
end

return CompanionPicker
