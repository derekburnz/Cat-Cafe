--!strict
-- Picnic Treats (#3715, Design-Agent's draft): the Park's Picnic Basket as a pick card, shown while the server sends
-- the basket's `treats` (the `picnicTreats` switch). Three treats, each a picture, its name, the potion it gives and a
-- Pick button. One pick waits at a time; after it the three cards are greyed and the line under the title reads
-- "Next picnic in 3 h 12 min". A press shows "..." until the next CampExtrasState or a refusal answers. Free, never
-- sold and never random: the player chooses, the server checks the timer (PickPicnicTreat).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampExtras = require(Shared:WaitForChild("CampExtras")) :: any
local Catalog = require(Shared:WaitForChild("Catalog")) :: any

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local PAL = Theme.dark

export type Callbacks = {
	pick: (treatId: string) -> (),
	close: () -> (),
}

export type PicnicTreats = {
	frame: Frame,
	-- the basket's view from CampExtrasState (nil before the first)
	setView: (self: PicnicTreats, view: Types.CampExtraView?) -> (),
	opened: (self: PicnicTreats) -> (),
	closed: (self: PicnicTreats) -> (),
	-- PickPicnicTreat refused: the "..." lifts (the server's toast says why)
	refused: (self: PicnicTreats) -> (),
	destroy: (self: PicnicTreats) -> (),
}

type Card = { treatId: string, frame: Frame, icon: ItemIcon.ItemIcon, button: Button.Button }

local TITLE = "Picnic Treats"
local READY = "Pick one treat."
local GLYPHS: { [string]: string } = { sandwich = "🥪", lemonade = "🥤", cupcake = "🧁" }
local PICTURES: { [string]: string } =
	{ sandwich = "PicnicSandwich", lemonade = "PicnicLemonade", cupcake = "PicnicCupcake" }
local MAX_WIDTH = 520
local PENDING_SECONDS = 5 -- a pick with no answer lets the buttons go again after this long
local GAP = Theme.sizes.gap

local PicnicTreats = {}
PicnicTreats.__index = PicnicTreats

-- The words on the card for a view at server time `now`: the line under the title and whether a pick waits.
function PicnicTreats.status(view: Types.CampExtraView?, now: number): (string, boolean)
	if view == nil or not view.open then
		return "Opens with the Park", false
	end
	if view.held > 0 then
		return READY, true
	end
	if view.nextAt ~= nil then
		return "Next picnic in " .. CampExtras.waitText(view.nextAt - now), false
	end
	return "Next picnic soon", false
end

-- "1 Money Potion" for a treat id, from the catalog's potion name.
function PicnicTreats.gives(treatId: string): string
	local treat = CampExtras.getTreat(treatId)
	local potion: any = if treat ~= nil then Catalog.getPotion(treat.potion) else nil
	local name: string = if potion ~= nil then potion.name else "potion"
	return "1 " .. name
end

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
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

function PicnicTreats.new(callbacks: Callbacks): PicnicTreats
	local self = setmetatable({}, PicnicTreats) :: any
	self._callbacks = callbacks
	self._view = nil :: Types.CampExtraView?
	self._cards = {} :: { Card }
	self._pending = nil :: string?
	self._pendingToken = 0
	self._open = false
	self._tick = 0

	local short = Scale.isShort()
	local buttonH = Scale.tapHeight(44, Theme.sizes.buttonDepth)
	local picture = if short then 44 else 64
	local cardH = picture + 8 + 22 + 18 + 8 + buttonH + 16
	local statusH = 24
	local height = cardH + statusH + GAP * 3 + (if short then 44 else 56)

	local panel = Panel.new({
		dark = true,
		name = "PicnicTreats",
		title = TITLE,
		color = Theme.colors.berry,
		icon = "🧺",
		image = ShopIcons.hud("Picnic"),
		size = UDim2.new(1, 0, 0, height),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, height), Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	self._status = text({
		Name = "Status",
		Size = UDim2.new(1, 0, 0, statusH),
		FontFace = Theme.fonts.bodyBold,
		Text = READY,
		Parent = content,
	})

	local row: Frame = Create("Frame", {
		Name = "Treats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, statusH + GAP),
		Size = UDim2.new(1, 0, 0, cardH),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	})

	for index, treat in CampExtras.TREATS do
		local treatId: string = treat.id
		local frame: Frame = Create("Frame", {
			Name = treatId,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1 / 3, -GAP, 1, 0),
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(picture, picture),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 8),
		})
		icon:set(nil, GLYPHS[treatId] or "🧺", "Common", ShopIcons.hud(PICTURES[treatId] or ""))
		text({
			Name = "Name",
			Position = UDim2.fromOffset(4, picture + 12),
			Size = UDim2.new(1, -8, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			Text = treat.name,
			Parent = frame,
		})
		text({
			Name = "Gives",
			Position = UDim2.fromOffset(4, picture + 34),
			Size = UDim2.new(1, -8, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			Text = PicnicTreats.gives(treatId),
			Parent = frame,
		})
		local button = Button.new({
			name = "Pick",
			text = "Pick",
			style = "primary",
			size = UDim2.new(1, -12, 0, buttonH),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_press(treatId)
			end,
		})
		table.insert(
			self._cards,
			{ treatId = treatId, frame = frame, icon = icon, button = button }
		)
	end

	self:_paint()
	return self
end

function PicnicTreats._press(self: any, treatId: string)
	local _, ready = PicnicTreats.status(self._view, Workspace:GetServerTimeNow())
	if not ready or self._pending ~= nil then
		return
	end
	self._pending = treatId
	self._pendingToken += 1
	local token = self._pendingToken
	self:_paint()
	self._callbacks.pick(treatId)
	task.delay(PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending ~= nil then
			self._pending = nil
			self:_paint()
		end
	end)
end

function PicnicTreats._paint(self: any)
	local line, ready = PicnicTreats.status(self._view, Workspace:GetServerTimeNow())
	self._status.Text = line
	self._status.TextColor3 = if ready then PAL.good else PAL.subtext
	for _, card in self._cards :: { Card } do
		local waiting = self._pending == card.treatId
		card.button:setText(if waiting then "..." else "Pick")
		card.button:setEnabled(ready and self._pending == nil)
		card.frame.BackgroundTransparency = if ready then 0 else 0.45
	end
end

PicnicTreats.CLOSE_AFTER = 0.4 -- #4286: seconds the greyed card shows after a pick went through, before it closes

function PicnicTreats.setView(self: any, view: Types.CampExtraView?)
	local before: Types.CampExtraView? = self._view
	local picked = self._pending ~= nil
		and before ~= nil
		and view ~= nil
		and (view :: Types.CampExtraView).held < (before :: Types.CampExtraView).held
	self._view = view
	self._pending = nil -- a new state answers the pick
	self:_paint()
	-- #4286 (Derek 2026-11-14: "the menu after picking picnic food ... should close so it doesn't look like it didnt
	-- work"): a pick the server took (one treat fewer held) closes the card a moment later
	if picked and self._open then
		local tick = self._tick
		task.delay(PicnicTreats.CLOSE_AFTER, function()
			if self._open and self._tick == tick then
				self._callbacks.close()
			end
		end)
	end
end

function PicnicTreats.refused(self: any)
	self._pending = nil
	self:_paint()
end

-- The countdown line moves on each second while the card is up.
function PicnicTreats.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				self:_paint()
			end
		end
	end)
end

function PicnicTreats.closed(self: any)
	self._open = false
	self._tick += 1
end

function PicnicTreats.destroy(self: any)
	self._open = false
	self._tick += 1
	for _, card in self._cards :: { Card } do
		card.button:destroy()
		card.icon:destroy()
	end
	self._cards = {}
	self._panel:destroy()
end

return PicnicTreats
