--!strict
-- Juniper's Mystery Market window (#2565 mystery-market.md section 2a, #2574), opened by walking into the ring in front
-- of the cart (Controllers/WalkUpController) or its prompt. Top to bottom:
--   * this week's featured item on a gold card with a SALE ribbon, its sale price with the full price struck through
--     ("300 400"), its one line, "Sale ends in 4d 06h" and Buy
--   * next week's featured item as a "?" tile with "Next sale: 4d 06h", which keeps the mystery
--   * every other item at its full price, each with Buy
--   * how many golden fish the player has
-- An owned item reads "You have this!", one above the player's tier "Opens at Tier 2" with a greyed button, and while
-- the server still refuses buys (PlayerState.mysteryOpen false, until the save bump) every button reads "Soon". Buy
-- sends BuyMystery(itemId, shownPrice) and shows "..." until the next ProfileSync or 5 s; the server works the price
-- out from its own clock and refuses a sale that ended while the window was open. Golden fish only, nothing random and
-- nothing for Robux (section 2d). Words and rules in Components/MysteryLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BagColourPicker = require(script.Parent.Parent.Components.BagColourPicker)
local BagColours =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BagColours"))
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local MysteryLogic = require(script.Parent.Parent.Components.MysteryLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local ShortNumber = require(script.Parent.Parent.Components.ShortNumber)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))
local SharedCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

-- #3535: the live switches the shelf's items wait on (the Speed Shoes'), as this client sees them now
local function shelfFlags(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, item in SharedCatalog.mysteryItems do
		local key = item.flag
		if key ~= nil then
			out[key] = LiveFlags.shown(
				key,
				ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key)
			)
		end
	end
	return out
end

local PAL = MenuFamily.pal -- the dark window palette (#1028)
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)
local TEAL = Color3.fromHex("2F7F86") -- Juniper's wagon (section 4c, look A)

export type Callbacks = {
	buy: (itemId: string, shownPrice: number) -> (),
	seen: () -> (), -- the first open: MarkMysterySeen clears the cart's "!"
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the cart
	-- #3699: whether the switch bagColours is on, and Save on the colour picker (SetBagColours). With either left
	-- out the owned Backpack's button stays "Owned"
	colours: (() -> boolean)?,
	saveColours: ((main: string, trim: string, kind: string?) -> ())?,
}

export type MysteryMarket = {
	frame: Frame,
	render: (self: MysteryMarket, state: Types.PlayerState) -> (),
	opened: (self: MysteryMarket) -> (),
	closed: (self: MysteryMarket) -> (),
	destroy: (self: MysteryMarket) -> (),
}

type Line = {
	id: string,
	frame: Frame,
	name: TextLabel,
	text: TextLabel,
	price: TextLabel?,
	note: TextLabel,
	buy: Button.Button,
	label: string,
	enabled: boolean?,
}

local MAX_SIZE = Vector2.new(500, 372)
local FEATURED_H = 146
local TEASER_H = 52
local ROW_H = 72
local PICTURE = 84
local SMALL_PICTURE = 46
local BUY_W = 104
local PENDING_SECONDS = 5
local GAP = Theme.sizes.gap
-- #3961: the family look (batch 1 mock): this week's sale as a tall picture card on the left, next week's teaser and
-- what is always on the shelf on the right
local FAMILY_SIZE = Vector2.new(640, 372)
local FEATURED_MIN = 214 -- the tall card's least height; a shorter window scrolls it
local FAMILY_PICTURE = 56

-- each item's picture until Model-Agent's art is in
local EMOJI: { [string]: string } = {
	backpack = "🎒",
	long_net = "🥅",
	speed_shoes = "👟", -- #3535
}
-- #2836 (Derek2: "make sure all our buttons/icons are high quality"): each item's drawn picture (ShopIcons.hud), over
-- its emoji once it loads; an item with no picture yet keeps the emoji
local ART: { [string]: string } = {
	backpack = "BigBackpack",
	long_net = "LongNet",
}

local function art(label: TextLabel, id: string)
	local name = ART[id]
	IconArt.setImage(label, if name then ShopIcons.hud(name) else nil, 0.8)
end

local MysteryMarketScreen = {}
MysteryMarketScreen.__index = MysteryMarketScreen

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = CARD.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function picture(
	parent: Instance,
	size: number,
	emoji: string,
	position: UDim2,
	anchor: Vector2
): TextLabel
	local tile = text({
		Name = "Picture",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 0,
		BackgroundColor3 = PAL.panel,
		TextSize = math.floor(size * 0.55),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = emoji,
		Parent = parent,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall), Parent = tile })
	return tile
end

function MysteryMarketScreen.new(callbacks: Callbacks): MysteryMarket
	local self = setmetatable({}, MysteryMarketScreen) :: any
	self._callbacks = callbacks
	self._state = nil :: Types.PlayerState?
	self._pending = nil :: string?
	self._token = 0
	self._open = false
	self._tick = 0
	self._lines = {} :: { Line }
	self._shape = ""
	self._buyH = Scale.tapHeight(40, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		dark = true,
		name = "MysteryMarket",
		title = MysteryLogic.TITLE,
		subtitle = MysteryLogic.SUBTITLE,
		color = TEAL,
		icon = MysteryLogic.ICON,
		image = ShopIcons.hud("MysteryMarket"), -- #2836: the drawn badge (the emoji until it loads)
		-- as tall as the screen allows, up to MAX_SIZE (as the Garden Nursery and the Oasis Spa): on a 705 x 338 phone
		-- the fixed height ran off the top, and the title icon sat under Roblox's menu buttons (#3518)
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", {
		MaxSize = if MenuFamily.on() then FAMILY_SIZE else MAX_SIZE,
		Parent = panel.frame,
	})
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame

	local body: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -22),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Outline.listPadding(8, 6),
	})
	self._body = body

	-- this week's featured item
	local featured: Frame = Create("Frame", {
		Name = "Featured",
		BackgroundColor3 = CARD.goldCard,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, FEATURED_H),
		LayoutOrder = 1,
		Parent = body,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(featured, Theme.sizes.stroke, Theme.colors.gold)
	self._featured = featured
	self._featuredPicture =
		picture(featured, PICTURE, "❓", UDim2.new(0, 12, 0.5, 0), Vector2.new(0, 0.5))
	local ribbon = text({
		Name = "Sale",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(48, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.red,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "SALE",
		TextColor3 = Theme.colors.white,
		Rotation = -8,
		ZIndex = 3,
		Parent = featured,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = ribbon })
	Outline.text(ribbon, 1)
	local left = 12 + PICTURE + 12
	local right = BUY_W + 24
	self._featuredName = text({
		Name = "Name",
		Position = UDim2.fromOffset(left, 12),
		Size = UDim2.new(1, -(left + 12), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = if MenuFamily.on() then CARD.text else Theme.colors.white,
		Parent = featured,
	})
	MenuFamily.outline(self._featuredName, 2)
	self._featuredText = text({
		Name = "Text",
		Position = UDim2.fromOffset(left, 40),
		Size = UDim2.new(1, -(left + 12), 0, 34),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = featured,
	})
	self._featuredPrice = text({
		Name = "Price",
		Position = UDim2.fromOffset(left, 76),
		Size = UDim2.new(1, -(left + right), 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = if MenuFamily.on() then CARD.gold else Theme.colors.gold,
		RichText = true,
		Parent = featured,
	})
	self._ends = text({
		Name = "Ends",
		Position = UDim2.fromOffset(left, 100),
		Size = UDim2.new(1, -(left + right), 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.text,
		Parent = featured,
	})
	self._featuredBuy = Button.new({
		name = "Buy",
		text = "",
		icon = Theme.icons.goldenFish,
		style = "primary",
		size = UDim2.fromOffset(BUY_W, self._buyH),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(1, -12, 1, -12),
		textSize = Theme.sizes.textBody + 1,
		parent = featured,
		onClick = function()
			self:_press(self._featuredId)
		end,
	})
	self._featuredId = nil :: string?
	self._featuredLabel = ""
	self._featuredEnabled = nil :: boolean?
	self._featuredNote = text({
		Name = "Note",
		Position = UDim2.fromOffset(left, 120),
		Size = UDim2.new(1, -(left + right), 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.gold,
		Parent = featured,
	})

	-- next week's sale, kept a mystery
	local teaser: Frame = Create("Frame", {
		Name = "Teaser",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TEASER_H),
		LayoutOrder = 2,
		Parent = body,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(teaser, Theme.sizes.stroke, CARD.cardStroke)
	local mark = picture(teaser, 36, "?", UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
	mark.FontFace = Theme.fonts.display
	mark.TextColor3 = Theme.colors.gold
	text({
		Name = "Title",
		Position = UDim2.fromOffset(56, 7),
		Size = UDim2.new(1, -66, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = "Next week's sale is a mystery",
		Parent = teaser,
	})
	self._next = text({
		Name = "Next",
		Position = UDim2.fromOffset(56, 27),
		Size = UDim2.new(1, -66, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		Parent = teaser,
	})

	self._othersTitle = text({
		Name = "OthersTitle",
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		Text = "Always on the shelf",
		LayoutOrder = 3,
		Parent = body,
	})
	local others: Frame = Create("Frame", {
		Name = "Others",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = body,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	self._others = others

	self._have = text({
		Name = "Have",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel.content,
	})
	if MenuFamily.on() then
		self:_family(body, featured, teaser, others)
	end
	return self :: MysteryMarket
end

-- #3961: two columns. The featured card stands tall on the left (picture on top, name, words, price, the week's end,
-- then a full width Buy); the teaser, "Always on the shelf" and its rows scroll on the right.
function MysteryMarketScreen._family(
	self: any,
	body: ScrollingFrame,
	featured: Frame,
	teaser: Frame,
	others: Frame
)
	local half = GAP / 2
	body.Size = UDim2.new(0.46, -half, 1, -22)
	featured.Size = UDim2.new(1, 0, 1, -14)
	Create("UISizeConstraint", { MinSize = Vector2.new(0, FEATURED_MIN), Parent = featured })
	local right: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Shelf",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.54, -half, 1, -22),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body.Parent,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Outline.listPadding(8, 6),
	})
	teaser.Parent = right
	self._othersTitle.Parent = right
	self._othersTitle.Text = "ALWAYS ON THE SHELF"
	others.Parent = right
	local picture: TextLabel = self._featuredPicture
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 10)
	picture.Size = UDim2.fromOffset(FAMILY_PICTURE, FAMILY_PICTURE)
	picture.TextSize = math.floor(FAMILY_PICTURE * 0.55)
	local y = 10 + FAMILY_PICTURE + 2
	local function place(label: TextLabel, top: number, height: number)
		label.Position = UDim2.fromOffset(10, top)
		label.Size = UDim2.new(1, -20, 0, height)
		label.TextXAlignment = Enum.TextXAlignment.Center
	end
	place(self._featuredName, y, 24)
	place(self._featuredText, y + 24, 16)
	self._featuredText.TextWrapped = false
	self._featuredText.TextTruncate = Enum.TextTruncate.AtEnd
	place(self._featuredPrice, y + 40, 20)
	place(self._ends, y + 60, 16)
	place(self._featuredNote, y + 76, 16)
	local buy = self._featuredBuy.instance
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -10)
	buy.Size = UDim2.new(1, -20, 0, self._buyH)
end

function MysteryMarketScreen._clearLines(self: any)
	for _, line: Line in self._lines do
		line.buy:destroy()
		line.frame:Destroy()
	end
	table.clear(self._lines)
end

function MysteryMarketScreen._buildLines(self: any, rows: { MysteryLogic.Row })
	self:_clearLines()
	for order, row in rows do
		local id = row.id
		local frame: Frame = Create("Frame", {
			Name = id,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, ROW_H),
			LayoutOrder = order,
			Parent = self._others,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		local small = picture(
			frame,
			SMALL_PICTURE,
			EMOJI[id] or "❓",
			UDim2.new(0, 9, 0.5, 0),
			Vector2.new(0, 0.5)
		)
		art(small, id)
		local left = 9 + SMALL_PICTURE + 10
		local right = BUY_W + 20
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(left, 7),
			Size = UDim2.new(1, -(left + right), 0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Text = row.name,
			Parent = frame,
		})
		-- Review-QA's Studio pass 2026-11-13: "Your net reaches a stud further." was cut at both sizes; the line
		-- folds onto two lines now, and the note sits under it
		local line = text({
			Name = "Text",
			Position = UDim2.fromOffset(left, 26),
			Size = UDim2.new(1, -(left + right), 0, 28),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd, -- a line longer than two (the Backpack's) ends in "..."
			TextYAlignment = Enum.TextYAlignment.Top,
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = CARD.subtext,
			Text = row.text,
			Parent = frame,
		})
		local note = text({
			Name = "Note",
			Position = UDim2.fromOffset(left, 53),
			Size = UDim2.new(1, -(left + right), 0, 16),
			FontFace = Theme.fonts.bodyBold,
			TextScaled = true, -- "Not enough golden fish" shrinks to its column instead of being cut
			TextColor3 = CARD.gold,
			Parent = frame,
		})
		Create(
			"UITextSizeConstraint",
			{ MaxTextSize = Theme.sizes.textTiny, MinTextSize = 8, Parent = note }
		)
		local buy = Button.new({
			name = "Buy",
			text = row.button,
			icon = Theme.icons.goldenFish,
			style = "primary",
			size = UDim2.fromOffset(BUY_W, self._buyH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -9, 0.5, 0),
			textSize = Theme.sizes.textBody,
			parent = frame,
			onClick = function()
				self:_press(id)
			end,
		})
		table.insert(self._lines, {
			id = id,
			frame = frame,
			name = name,
			text = line,
			note = note,
			buy = buy,
			label = row.button,
			enabled = nil,
		})
	end
end

-- The button's words and whether it can be pressed, with a buy out showing "...".
-- #3699: an owned Backpack's button opens the colour picker (`colours`: the switch is on). #4049: the Speed Shoes'
-- too, and the words are "Edit".
local function paintButton(
	button: Button.Button,
	row: MysteryLogic.Row,
	pending: boolean,
	busy: boolean,
	colours: boolean
): (string, boolean)
	local fish: TextLabel? = button.icon
	if colours and row.owned and BagColours.kindOf(row.id) ~= nil then
		if fish then
			fish.Visible = false
		end
		return BagColours.EDIT, true
	end
	local label = if pending then "..." else row.button
	if fish then
		fish.Visible = row.fish and not pending
	end
	return label, row.enabled and not busy
end

function MysteryMarketScreen._paint(self: any)
	local view = MysteryLogic.view(self._state, Workspace:GetServerTimeNow(), shelfFlags())
	local busy = self._pending ~= nil
	local colours = self:_colours()
	local featured = view.featured
	self._featured.Visible = featured ~= nil
	if featured ~= nil then
		self._featuredId = featured.id
		self._featuredName.Text = featured.name
		self._featuredText.Text = featured.text
		self._featuredPicture.Text = EMOJI[featured.id] or "❓"
		art(self._featuredPicture, featured.id)
		self._featuredPrice.Text = if featured.sale
			then string.format(
				'%d <font color="#B8A99C" size="14"><s>%d</s></font>',
				featured.price,
				featured.full
			)
			else tostring(featured.price)
		self._ends.Text = view.ends or ""
		self._featuredNote.Text = featured.note or ""
		self._featuredNote.TextColor3 = if featured.owned then CARD.good else CARD.gold
		local label, enabled =
			paintButton(self._featuredBuy, featured, self._pending == featured.id, busy, colours)
		if label ~= self._featuredLabel then
			self._featuredLabel = label
			self._featuredBuy:setText(label)
		end
		if enabled ~= self._featuredEnabled then
			self._featuredEnabled = enabled
			self._featuredBuy:setEnabled(enabled)
		end
	end
	self._next.Text = view.nextLine or ""
	local ids: { string } = {}
	for _, row in view.others do
		table.insert(ids, row.id)
	end
	local shape = table.concat(ids, ",")
	if shape ~= self._shape then
		self._shape = shape
		self:_buildLines(view.others)
	end
	self._othersTitle.Visible = #view.others > 0
	for index, row in view.others do
		local line: Line = self._lines[index]
		local label, enabled = paintButton(line.buy, row, self._pending == row.id, busy, colours)
		if label ~= line.label then
			line.label = label
			line.buy:setText(label)
		end
		if enabled ~= line.enabled then
			line.enabled = enabled
			line.buy:setEnabled(enabled)
		end
		line.note.Text = row.note or ""
		line.note.TextColor3 = if row.owned then CARD.good else CARD.gold
		local faded = if row.owned and not (colours and BagColours.kindOf(row.id) ~= nil)
			then 0.4
			else 0
		line.name.TextTransparency = faded
		line.text.TextTransparency = faded
	end
	self._have.Text = string.format("You have %s golden fish", ShortNumber.format(view.fish))
end

-- #3699: whether the owned Backpack's button opens the colour picker.
function MysteryMarketScreen._colours(self: any): boolean
	local callbacks: Callbacks = self._callbacks
	return callbacks.saveColours ~= nil and callbacks.colours ~= nil and callbacks.colours()
end

-- #3699: the colour picker in place of the shelf, and back. The picker is built on its first open.
function MysteryMarketScreen._showPicker(self: any, shown: boolean, kind: string?)
	local picker: any = self._picker
	if shown then
		if picker == nil then
			picker = BagColourPicker.new(self._panel.content, {
				save = function(main: string, trim: string, pickedKind: string)
					local save = (self._callbacks :: Callbacks).saveColours
					if save ~= nil then
						save(main, trim, pickedKind)
					end
				end,
				back = function()
					self:_showPicker(false)
				end,
			})
			self._picker = picker
		end
		local current: any = self._state
		local shoes = kind == "shoes"
		local saved = if current == nil
			then nil
			elseif shoes then current.shoeColours
			else current.bagColours
		picker:open(if type(saved) == "table" then saved else nil, if shoes then "shoes" else "bag")
	elseif picker ~= nil then
		picker:close()
	end
	self._body.Visible = not shown
	self._have.Visible = not shown
end

function MysteryMarketScreen._press(self: any, itemId: string?)
	if itemId == nil or self._pending ~= nil then
		return
	end
	local view = MysteryLogic.view(self._state, Workspace:GetServerTimeNow(), shelfFlags())
	local rows = table.clone(view.others)
	if view.featured ~= nil then
		table.insert(rows, view.featured)
	end
	for _, row in rows do
		local kind = BagColours.kindOf(itemId)
		if row.id == itemId and row.owned and kind ~= nil and self:_colours() then
			self:_showPicker(true, kind)
			return
		end
		if row.id == itemId and row.enabled then
			self._pending = itemId
			self._token += 1
			local token = self._token
			task.delay(PENDING_SECONDS, function()
				if self._token == token and self._pending ~= nil then
					self._pending = nil
					self:_paint()
				end
			end)
			self:_paint()
			self._callbacks.buy(itemId, row.price)
			return
		end
	end
end

-- Every ProfileSync answers the buy that was out (a buy or a refusal both sync).
function MysteryMarketScreen.render(self: any, state: Types.PlayerState)
	self._state = state
	if self._pending ~= nil then
		self._pending = nil
		self._token += 1
	end
	self:_paint()
	local picker: BagColourPicker.BagColourPicker? = self._picker
	if picker ~= nil then
		local saved = if (picker :: any)._kind == "shoes" -- #4049
			then (state :: any).shoeColours
			else (state :: any).bagColours
		picker:saved(if type(saved) == "table" then saved else nil) -- #3699: answers a Save that was out
	end
end

-- While open the countdowns move once a second and walking away closes it; the first open clears the cart's "!".
function MysteryMarketScreen.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_paint()
	local current: any = self._state
	if current ~= nil and current.mysterySeen == false then
		self._callbacks.seen()
	end
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

function MysteryMarketScreen.closed(self: any)
	self._open = false
	self._tick += 1
	self:_showPicker(false) -- #3699: the window opens on the shelf next time
end

function MysteryMarketScreen.destroy(self: any)
	self._open = false
	self._tick += 1
	self:_clearLines()
	if self._picker ~= nil then
		self._picker:destroy()
	end
	self._featuredBuy:destroy()
	self._panel:destroy()
end

return MysteryMarketScreen
