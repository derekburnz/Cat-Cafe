--!strict
-- #3955 (Derek 2026-11-13: "lost and found also needs changing it just doesnt do anything but walk on and give u smth
-- u cant even tell"): the Sewer's Lost and Found as a station card, opened by its ring (WalkUpController) or prompt
-- (CampExtrasController) in place of the silent walk-on claim. One cream picture card as the station menus mock and
-- the Yard Sale's: the station's picture on a gold tile with a "2 WAITING" / "SOON" pill, how many finds wait (or
-- "Nothing found yet" and when the next one comes), what can turn up as small picture tiles with their chances
-- (Config.LostFoundTable, LostFoundLogic.rows), and a wide Claim button. Claim sends CollectCampExtra("lostFound");
-- the server still decides what each find is. Its answer (`found`) turns the card over to a reveal: the find's
-- pictures large with a banner naming it, until a tap or REVEAL_SECONDS. Free and never sold.
--   LostFound.new(callbacks)   built hidden; the UI registers its frame as the "LostFound" modal
--   :setCatalog(catalog) :setView(view) :opened() :closed() :found(prize, paid) :refused() :destroy()

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LostFoundLogic = require(script.Parent.Parent.Components.LostFoundLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local PAL = MenuFamily.pal
local CARD = MenuFamily.card

export type Callbacks = {
	collect: () -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away: the card closes
}

export type LostFound = {
	frame: Frame,
	setCatalog: (self: LostFound, catalog: Types.Catalog) -> (),
	setView: (self: LostFound, view: Types.CampExtraView?) -> (),
	opened: (self: LostFound) -> (),
	closed: (self: LostFound) -> (),
	-- CampExtraResult ok for the Lost and Found: the reveal of what turned up
	found: (self: LostFound, prize: Types.IndexPrize?, paid: { string }?) -> (),
	-- CampExtraResult refused: the "..." lifts (the server's toast says why)
	refused: (self: LostFound) -> (),
	destroy: (self: LostFound) -> (),
}

local MAX_WIDTH = 540
local TILE = 104 -- the station's picture tile
local STATUS_H = 22 -- the pill on the tile's edge
local FIND_H = 50 -- one "can turn up" tile
local FIND_PICTURE = 22
local FINDS_CLEAR = 10 -- #3982: px between the last row of finds and the Claim button
local REVEAL_PICTURE = 56
local REVEAL_SECONDS = 4
local PENDING_SECONDS = 5 -- a claim with no answer lets the button go again after this long
local GAP = Theme.sizes.gap
local SUBTITLE = "Lost things turn up here"
local NOTE = "Something turns up every 2 hours. Claim takes every find waiting."

local LostFound = {}
LostFound.__index = LostFound

local function text(props: { [string]: any }, children: { Instance }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = CARD.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged, children)
end

-- A pill of white display words on `fill` with the card's ink edge.
local function pill(props: { [string]: any }): TextLabel
	local label = text(props, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = CARD.cardStroke,
			Thickness = 2,
		}),
	})
	Outline.text(label, 1)
	return label
end

function LostFound.new(callbacks: Callbacks): LostFound
	local self = setmetatable({}, LostFound) :: any
	self._callbacks = callbacks
	self._view = nil :: Types.CampExtraView?
	self._pending = false
	self._pendingToken = 0
	self._open = false
	self._tick = 0
	self._revealToken = 0
	self._label = ""
	self._enabled = nil :: boolean?
	self._chips = {} :: { PrizeChips.PrizeChips }

	local buyH = Scale.tapHeight(44, Theme.sizes.buttonDepth)
	local rows = LostFoundLogic.rows()
	local findRows = math.ceil(#rows / 4)
	local findsH = findRows * FIND_H + (findRows - 1) * 4
	-- #3982 (Review-QA in Studio): the finds keep FINDS_CLEAR above the Claim button, whose lip and outline reach
	-- up past its box and covered the second row's chances
	local top =
		math.max(TILE + math.ceil(STATUS_H / 2) + 12, 28 + 20 + 4 + findsH + 8 + FINDS_CLEAR)
	local cardH = top + buyH + 8
	local height = cardH + GAP + 18 + 56

	local panel = Panel.new({
		dark = true,
		name = "LostFound",
		title = "Lost and Found",
		subtitle = SUBTITLE,
		color = Theme.colors.mintDark,
		icon = "📦",
		image = ShopIcons.hud("LostFound"),
		size = UDim2.new(1, 0, 0, height),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, height), Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, cardH),
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	self._card = card
	local tile: Frame = Create("Frame", {
		Name = "Tile",
		BackgroundColor3 = CARD.goldCard,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(TILE, TILE),
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = 2 }),
	})
	self._icon = ItemIcon.new({
		parent = tile,
		size = UDim2.fromOffset(TILE - 14, TILE - 14),
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	self._icon:set(nil, "📦", "Rare", ShopIcons.hud("LostFound"))
	self._status = pill({
		Name = "Status",
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.goodDark,
		Position = UDim2.fromOffset(10 + math.floor(TILE / 2), 8 + TILE),
		Size = UDim2.fromOffset(0, STATUS_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 2,
		Parent = card,
	})
	local left = 10 + TILE + 12
	local info: Frame = Create("Frame", {
		Name = "Info",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, 8),
		Size = UDim2.new(1, -(left + 10), 0, top - 8),
		Parent = card,
	})
	self._title = text({
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTitle - 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	self._line = text({
		Name = "Line",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	-- what can turn up: a small tile per row of the table, its pictures over its chance
	local finds: Frame = Create("Frame", {
		Name = "Finds",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, findsH),
		Parent = info,
	}, {
		Create("UIGridLayout", {
			CellPadding = UDim2.fromOffset(4, 4),
			CellSize = UDim2.new(0.25, -3, 0, FIND_H),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, row in rows do
		local cell: Frame = Create("Frame", {
			Name = "Find" .. order,
			BackgroundColor3 = CARD.goldCard,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = finds,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Create("UIStroke", { Color = CARD.line, Thickness = 1 }),
		})
		if row.lostCat ~= nil then
			text({
				Name = "Cat",
				Position = UDim2.fromOffset(2, 3),
				Size = UDim2.new(1, -4, 0, FIND_PICTURE + 4),
				FontFace = Theme.fonts.bodyBold,
				TextScaled = true,
				TextColor3 = MenuFamily.rarity(row.lostCat),
				Text = "🐱 " .. row.lostCat .. " cat",
				Parent = cell,
			}, {
				Create(
					"UITextSizeConstraint",
					{ MaxTextSize = Theme.sizes.textSmall, MinTextSize = 9 }
				),
			})
		else
			local chips = PrizeChips.new({
				parent = cell,
				tile = FIND_PICTURE,
				textSize = Theme.sizes.textTiny,
				textColor = CARD.text,
				showBonus = false,
				maxPictures = 2,
				fitTo = cell,
				fitPad = 4,
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 3),
				align = Enum.HorizontalAlignment.Center,
			})
			chips:set(row.prize :: any) -- the shared IndexPrize, the same fields
			table.insert(self._chips, chips)
		end
		text({
			Name = "Chance",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -2),
			Size = UDim2.new(1, 0, 0, 16),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			Text = row.chance,
			Parent = cell,
		})
	end
	self._button = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = UDim2.new(1, -16, 0, buyH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		textSize = Theme.sizes.textBody + 2,
		parent = card,
		onClick = function()
			self:_press()
		end,
	})
	text({
		Name = "Note",
		Position = UDim2.fromOffset(0, cardH + GAP),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Text = NOTE,
		Parent = content,
	})

	-- the reveal: over the whole card, the find large with a banner; a tap or REVEAL_SECONDS puts the card back
	local reveal: TextButton = Create("TextButton", {
		Name = "Reveal",
		AutoButtonColor = false,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Visible = false,
		ZIndex = 10,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 4 }),
	})
	self._reveal = reveal
	self._revealBanner = pill({
		Name = "Banner",
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.goldDark,
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.None,
		Text = "YOU FOUND",
		ZIndex = 12,
		Parent = reveal,
	})
	self._revealChips = PrizeChips.new({
		parent = reveal,
		tile = REVEAL_PICTURE,
		textSize = Theme.sizes.textBody + 2,
		textColor = CARD.text,
		maxPictures = 3,
		fitTo = reveal,
		fitPad = 20,
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		align = Enum.HorizontalAlignment.Center,
	})
	self._revealChips.frame.ZIndex = 11
	self._revealWords = text({
		Name = "Words",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextWrapped = true,
		ZIndex = 12,
		Parent = reveal,
	})
	self._revealTap = reveal.Activated:Connect(function()
		self:_hideReveal()
	end)
	self:_paint()
	return self :: LostFound
end

function LostFound._press(self: any)
	local view: Types.CampExtraView? = self._view
	local _, _, _, ready = LostFoundLogic.status(view, Workspace:GetServerTimeNow())
	if self._pending or not ready then
		return
	end
	self._pending = true
	self._pendingToken += 1
	local token = self._pendingToken
	task.delay(PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending then
			self._pending = false
			self:_paint()
		end
	end)
	self:_paint()
	self._callbacks.collect()
end

function LostFound._paint(self: any)
	local view: Types.CampExtraView? = self._view
	local now = Workspace:GetServerTimeNow()
	local title, line, status, ready = LostFoundLogic.status(view, now)
	self._title.Text = title
	self._line.Text = line
	local statusLabel: TextLabel = self._status
	statusLabel.Text = status
	statusLabel.BackgroundColor3 = if ready
		then Theme.colors.goodDark
		else Theme.colors.disabledDark
	local label = LostFoundLogic.button(view, now, self._pending)
	if self._label ~= label then
		self._label = label
		self._button:setText(label)
	end
	local enabled = ready and not self._pending
	if self._enabled ~= enabled then
		self._enabled = enabled
		self._button:setEnabled(enabled)
	end
end

function LostFound._hideReveal(self: any)
	self._revealToken += 1
	self._reveal.Visible = false
end

function LostFound.found(self: any, prize: Types.IndexPrize?, paid: { string }?)
	self._pending = false
	self._pendingToken += 1
	self:_paint()
	self._revealChips:set(prize)
	self._revealChips.frame.Visible = prize ~= nil
	self._revealWords.Text = LostFoundLogic.foundText(paid)
	local reveal: TextButton = self._reveal
	reveal.Visible = true
	if not GuiService.ReducedMotionEnabled then
		Tween.popIn(self._revealChips.frame, 0.6)
	end
	self._revealToken += 1
	local token = self._revealToken
	task.delay(REVEAL_SECONDS, function()
		if self._revealToken == token then
			self:_hideReveal()
		end
	end)
end

function LostFound.refused(self: any)
	self._pending = false
	self._pendingToken += 1
	self:_paint()
	local button: Frame = self._button.instance
	button.Rotation = -8
	Tween.to(
		button,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Rotation = 0 }
	)
end

function LostFound.setCatalog(self: any, catalog: Types.Catalog)
	for _, chips: PrizeChips.PrizeChips in self._chips do
		chips:setCatalog(catalog)
	end
	self._revealChips:setCatalog(catalog)
end

function LostFound.setView(self: any, view: Types.CampExtraView?)
	self._view = view
	self._pending = false
	self._pendingToken += 1
	self:_paint()
end

-- While open the "Next find in" line moves once a second, and walking away closes the card.
function LostFound.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_hideReveal()
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				local far = (self._callbacks :: Callbacks).far
				if far ~= nil and far() then
					self._callbacks.close()
					return
				end
				self:_paint()
			end
		end
	end)
end

function LostFound.closed(self: any)
	self._open = false
	self._tick += 1
	self:_hideReveal()
end

function LostFound.destroy(self: any)
	self._open = false
	self._tick += 1
	self._revealToken += 1
	self._revealTap:Disconnect()
	for _, chips: PrizeChips.PrizeChips in self._chips do
		chips:destroy()
	end
	self._revealChips:destroy()
	self._icon:destroy()
	self._button:destroy()
	self._panel:destroy()
end

return LostFound
