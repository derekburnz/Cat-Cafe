--!strict
-- #4062 The Dragon Keep window (Castle late station; Design-Agent/notes/ticket-booth-and-dragon-keep.md section 2, the
-- station menus picture Derek OK'd 2026-11-14 00:43 UTC). The cocoa station look with three pill tabs:
-- - Slots: Cinder's card (name and stage, the warmth bar, a green Give cats), the five card slots (a locked one reads
--   "Stage 4"), the set line and, while a hand waits, a gold strip that opens it. From stage 3 a row of four scale
--   colours.
-- - Binder N/54: every card in family order. One you own shows its words; one you don't is a "?" in its family's
--   colour. Tap an owned card, then a slot, to put it there (free swaps).
-- - Give cats: the cats that may move in, weakest first, each with its Warmth. Tap to pick; "Spare Commons" and
--   "Repeats" pick for you (never a working, gold, rainbow or Legendary and better cat, and one copy of each cat
--   stays). A pick with special cats asks once ("Tap again"). Cats "move into the Keep": never any other word.
-- The hand: three cards over the window with the card odds under them (a random pick, earned only, so the odds show).
-- Tap one to take it. A Rekindle hand then asks which slot it replaces (or the binder only), and offers "Keep my cards"
-- for 25 golden fish. Motion-FX's Effects/CardFlip deals the cards when it is there.
--   DragonKeep.new(callbacks)   built hidden; the UI registers its frame as the "DragonKeep" modal
--   :setView(view, cats, busy) :opened() :closed() :destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local DragonKeepLogic = require(script.Parent.Parent.Components.DragonKeepLogic)
local FitText = require(script.Parent.Parent.Components.FitText)
local GridFit = require(script.Parent.Parent.Components.GridFit)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any
local SharedKeep = require(Shared:WaitForChild("DragonKeep")) :: any

local PAL = MenuFamily.pal
local CARD = MenuFamily.card

export type Callbacks = {
	give: (uids: { string }, confirmed: boolean) -> (),
	pick: (index: number, slot: number?) -> (),
	keep: () -> (),
	slot: (cardId: string, slot: number) -> (),
	colour: (colour: string) -> (),
	close: () -> (),
}

export type DragonKeep = {
	frame: Frame,
	setView: (
		self: DragonKeep,
		view: any,
		cats: { [string]: any }?,
		busy: { [string]: boolean }?
	) -> (),
	showTab: (self: DragonKeep, tab: string) -> (),
	opened: (self: DragonKeep) -> (),
	closed: (self: DragonKeep) -> (),
	destroy: (self: DragonKeep) -> (),
}

local MAX_SIZE = Vector2.new(820, 560)
local GAP = Theme.sizes.gap
local TAB_H = 30
local DRAGON_W = 200
local SLOT_MIN = 72
local BINDER_CELL = 104
local BINDER_H = 92
local GIVE_CELL = 92
local GIVE_H = 112
local HAND_W = 170
local HAND_H = 210
local ASK_SECONDS = 4 -- the special cats' "Tap again" waits this long
local PURPLE = Color3.fromHex("9A6BE0") -- the Keep's dragon purple edge (the station menus picture)
local COLOURS: { [string]: Color3 } = {
	ruby = Color3.fromHex("D8344A"),
	sapphire = Color3.fromHex("3C6FE0"),
	emerald = Color3.fromHex("2FA866"),
	amethyst = Color3.fromHex("9A5BD8"),
}
local TABS = {
	{ id = "slots", name = "Slots" },
	{ id = "binder", name = "Binder" },
	{ id = "give", name = "Give cats" },
}

local DragonKeep = {}
DragonKeep.__index = DragonKeep

local function text(props: { [string]: any }): TextLabel
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
	return Create("TextLabel", merged)
end

local function card(props: { [string]: any }, edge: Color3?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("Frame", merged, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = edge or CARD.cardStroke, Thickness = 2 }),
	})
end

local function scroller(name: string, parent: Instance): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Parent = parent,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
end

function DragonKeep.new(callbacks: Callbacks): DragonKeep
	local self = setmetatable({}, DragonKeep) :: any
	self._callbacks = callbacks
	self._view = nil :: any
	self._cats = nil :: { [string]: any }?
	self._busy = nil :: { [string]: boolean }?
	self._tab = "slots"
	self._picked = {} :: { [string]: boolean }
	self._asking = false
	self._askToken = 0
	self._chosen = nil :: string? -- a binder card picked, waiting for its slot
	self._handPick = nil :: number? -- a Rekindle hand's card picked, waiting for its slot
	self._handKey = ""
	self._dealt = ""
	self._buyH = Scale.tapHeight(40, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		dark = true,
		name = "DragonKeep",
		title = "Dragon Keep",
		subtitle = "Spare cats move in and keep Cinder warm",
		color = Color3.fromHex("6A3FB0"),
		icon = "🐉",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	-- the pill tabs
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_H),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	self._tabButtons = {} :: { [string]: any }
	for order, tab in TABS do
		self._tabButtons[tab.id] = Button.new({
			name = "Tab_" .. tab.id,
			text = tab.name,
			style = if tab.id == self._tab then "purple" else "ghost",
			size = UDim2.fromOffset(if tab.id == "binder" then 128 else 104, TAB_H),
			textSize = Theme.sizes.textSmall,
			layoutOrder = order,
			parent = tabs,
			onClick = function()
				self:showTab(tab.id)
			end,
		})
	end
	local pages: Frame = Create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TAB_H + GAP),
		Size = UDim2.new(1, 0, 1, -(TAB_H + GAP)),
		Parent = content,
	})
	self._pages = pages
	self:_buildSlots(pages)
	self:_buildBinder(pages)
	self:_buildGive(pages)
	self:_buildHand(content)
	self:showTab("slots")
	return self :: DragonKeep
end

----------------------------------------------------------------------------------------------------
-- Slots
----------------------------------------------------------------------------------------------------

function DragonKeep._buildSlots(self: any, pages: Frame)
	local page: Frame = Create("Frame", {
		Name = "SlotsPage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = pages,
	})
	self._slotsPage = page
	-- Cinder's card
	local dragon = card({
		Name = "Dragon",
		Size = UDim2.new(0, DRAGON_W, 1, 0),
	}, PURPLE)
	dragon.Parent = page
	self._dragonPicture = text({
		Name = "Picture",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0.42, 0),
		TextScaled = true,
		Text = "🐉",
		Parent = dragon,
	})
	self._dragonName = text({
		Name = "Name",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -(8 + self._buyH + 8 + 18 + 10)),
		Size = UDim2.new(1, -16, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = dragon,
	})
	FitText.shrink(self._dragonName)
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = CARD.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -(8 + self._buyH + 8 + 18 + 2)),
		Size = UDim2.new(1, -28, 0, 6),
		Parent = dragon,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._warmthFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._warmthText = text({
		Name = "Warmth",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -(8 + self._buyH + 6)),
		Size = UDim2.new(1, -16, 0, 18),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = CARD.subtext,
		Parent = dragon,
	})
	FitText.shrink(self._warmthText)
	Button.new({
		name = "GiveCats",
		text = "Give cats",
		style = "primary",
		size = UDim2.new(1, -16, 0, self._buyH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		textSize = Theme.sizes.textBody,
		parent = dragon,
		onClick = function()
			self:showTab("give")
		end,
	})
	-- the right side: slots, the colour row, the sets line and the hand strip
	local right: Frame = Create("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(DRAGON_W + GAP, 0),
		Size = UDim2.new(1, -(DRAGON_W + GAP), 1, 0),
		Parent = page,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local slotRow: Frame = Create("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 104),
		LayoutOrder = 1,
		Parent = right,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._slotRow = slotRow
	self._slotTiles = {} :: { any }
	for index = 1, DragonKeepLogic.SLOTS do
		local tile: TextButton = Create("TextButton", {
			Name = "Slot" .. index,
			AutoButtonColor = false,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Size = UDim2.new(0.2, -5, 1, 0),
			LayoutOrder = index,
			Text = "",
			Parent = slotRow,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UISizeConstraint", { MinSize = Vector2.new(SLOT_MIN * 0.75, 0) }),
		})
		local stroke = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = CARD.cardStroke,
			Thickness = 2,
			Parent = tile,
		})
		local icon = text({
			Name = "Icon",
			Position = UDim2.new(0, 4, 0, 6),
			Size = UDim2.new(1, -8, 0, 36),
			TextScaled = true,
			Parent = tile,
		})
		local label = text({
			Name = "Label",
			Position = UDim2.new(0, 4, 0, 46),
			Size = UDim2.new(1, -8, 1, -50),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny + 1,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = tile,
		})
		FitText.shrink(label)
		tile.Activated:Connect(function()
			self:_slotTapped(index)
		end)
		self._slotTiles[index] = { tile = tile, stroke = stroke, icon = icon, label = label }
	end
	local colours: Frame = Create("Frame", {
		Name = "Colours",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 2,
		Visible = false,
		Parent = right,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	self._colourRow = colours
	text({
		Name = "Title",
		Size = UDim2.fromOffset(96, 30),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Scale colour",
		LayoutOrder = 0,
		Parent = colours,
	})
	self._colourDots = {} :: { [string]: any }
	for order, id in SharedKeep.COLOURS do
		local dot: TextButton = Create("TextButton", {
			Name = "Colour_" .. id,
			AutoButtonColor = false,
			BackgroundColor3 = COLOURS[id] or Theme.colors.gold,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(28, 28),
			LayoutOrder = order,
			Text = "",
			Parent = colours,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local ring = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.colors.white,
			Thickness = 0,
			Parent = dot,
		})
		dot.Activated:Connect(function()
			self._callbacks.colour(id)
		end)
		self._colourDots[id] = ring
	end
	local sets = card({
		Name = "Sets",
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 3,
		BackgroundColor3 = PAL.card,
	}, PAL.cardStroke)
	sets.Parent = right
	self._setsLine = text({
		Name = "Line",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sets,
	})
	FitText.shrink(self._setsLine)
	self._chooseLine = text({
		Name = "Choose",
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 4,
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = PAL.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = right,
	})
	-- a Rekindle card picked: it may go to the binder only, leaving the slots as they are
	self._binderOnly = Button.new({
		name = "BinderOnly",
		text = "Keep it in the binder only",
		style = "ghost",
		size = UDim2.new(1, 0, 0, 30),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 5,
		parent = right,
		onClick = function()
			local pick = self._handPick
			if pick ~= nil then
				self._handPick = nil
				self._callbacks.pick(pick, nil)
				self:_paint()
			end
		end,
	})
	self._binderOnly.instance.Visible = false
	local strip: TextButton = Create("TextButton", {
		Name = "HandStrip",
		AutoButtonColor = false,
		BackgroundColor3 = PAL.goldCard,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 6,
		Text = "",
		Visible = false,
		Parent = right,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.colors.gold,
			Thickness = 2,
		}),
	})
	self._strip = strip
	self._stripTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = strip,
	})
	FitText.shrink(self._stripTitle)
	local stripLine = text({
		Name = "Line",
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Tap to see your cards",
		Parent = strip,
	})
	FitText.shrink(stripLine)
	strip.Activated:Connect(function()
		self:_showHand(true)
	end)
end

function DragonKeep._paintSlots(self: any)
	local view = self._view
	self._dragonName.Text = DragonKeepLogic.title(view)
	local words, share = DragonKeepLogic.warmth(view)
	self._warmthText.Text = words
	self._warmthFill.Size = UDim2.fromScale(share, 1)
	for _, slot in DragonKeepLogic.slots(view) do
		local tile = self._slotTiles[slot.index]
		local def = if slot.card then SharedKeep.card(slot.card) else nil
		local family = if def then def.family else nil
		tile.icon.Text = if slot.locked
			then "🔒"
			elseif family then DragonKeepLogic.FAMILY_ICONS[family] or "✨"
			else "+"
		tile.label.Text = slot.label
		tile.label.TextColor3 = if slot.locked then CARD.subtext else CARD.text
		tile.tile.BackgroundColor3 = if slot.locked then PAL.card else CARD.card
		local chosen = self._chosen ~= nil or self._handPick ~= nil
		tile.stroke.Color = if family
			then DragonKeepLogic.FAMILY_COLOURS[family]
			elseif chosen and not slot.locked then Theme.colors.gold
			else CARD.cardStroke
		tile.stroke.Thickness = if family or (chosen and not slot.locked) then 3 else 2
	end
	local stage = if view then view.stage or 0 else 0
	self._colourRow.Visible = stage >= SharedKeep.COLOUR_STAGE
	for id, ring in self._colourDots do
		ring.Thickness = if view and view.colour == id then 3 else 0
	end
	self._setsLine.Text = DragonKeepLogic.setsLine(view)
	local chosenName = nil
	if self._chosen then
		local def = SharedKeep.card(self._chosen)
		chosenName = if def then def.name else nil
	end
	self._chooseLine.Visible = chosenName ~= nil
	self._chooseLine.Text = if chosenName
		then ("Tap a slot to put %s there"):format(chosenName)
		else ""
	local hands = if view then view.hands or 0 else 0
	local waiting = view ~= nil and #(view.hand or {}) > 0
	self._strip.Visible = waiting
	if waiting then
		local count: number = if type(hands) == "number" then math.max(hands, 1) else 1
		local kind: string = if view.handKind == "rekindle" then "Rekindle hand" else "card pick"
		self._stripTitle.Text = "✨ "
			.. tostring(count)
			.. " "
			.. kind
			.. (if count > 1 then "s" else "")
			.. " ready"
	end
end

function DragonKeep._slotTapped(self: any, index: number)
	local view = self._view
	local open = if view then #(view.slots or {}) else 0
	if index > open then
		return
	end
	if self._handPick ~= nil then
		local pick = self._handPick
		self._handPick = nil
		self._callbacks.pick(pick, index)
		self:_paint()
		return
	end
	if self._chosen ~= nil then
		local id = self._chosen
		self._chosen = nil
		if view.slots[index] ~= id then
			self._callbacks.slot(id, index)
		end
		self:_paint()
		return
	end
	-- an empty or filled slot with nothing chosen opens the binder to pick for it
	self:showTab("binder")
end

----------------------------------------------------------------------------------------------------
-- Binder
----------------------------------------------------------------------------------------------------

function DragonKeep._buildBinder(self: any, pages: Frame)
	local page = scroller("BinderPage", pages)
	page.Visible = false
	self._binderPage = page
	local layout: UIGridLayout = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	GridFit.fit(page, layout, BINDER_CELL, 6, function()
		return BINDER_H
	end)
	self._binderCells = {} :: { [string]: any }
	for order, entry in DragonKeepLogic.binder(nil) do
		local cell: TextButton = Create("TextButton", {
			Name = "Card_" .. entry.id,
			AutoButtonColor = false,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Text = "",
			Parent = page,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		})
		local stroke = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = DragonKeepLogic.FAMILY_COLOURS[entry.family],
			Thickness = 2,
			Parent = cell,
		})
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			Parent = cell,
		})
		FitText.shrink(name)
		local rarity = text({
			Name = "Rarity",
			Position = UDim2.fromOffset(6, 22),
			Size = UDim2.new(1, -12, 0, 14),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny,
			Parent = cell,
		})
		local words = text({
			Name = "Words",
			Position = UDim2.fromOffset(6, 38),
			Size = UDim2.new(1, -12, 1, -42),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = CARD.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = cell,
		})
		FitText.shrink(words)
		cell.Activated:Connect(function()
			self:_binderTapped(entry.id)
		end)
		self._binderCells[entry.id] =
			{ cell = cell, stroke = stroke, name = name, rarity = rarity, words = words }
	end
end

function DragonKeep._paintBinder(self: any)
	local view = self._view
	for _, entry in DragonKeepLogic.binder(view) do
		local cell = self._binderCells[entry.id]
		if cell == nil then
			continue
		end
		local family = DragonKeepLogic.FAMILY_NAMES[entry.family] or entry.family
		if entry.owned then
			cell.name.Text = entry.name
			cell.rarity.Text = entry.rarity .. " · " .. family
			cell.rarity.TextColor3 =
				MenuFamily.rarity(if entry.rarity == "Mythic" then "Mythical" else entry.rarity)
			cell.words.Text = if entry.slot
				then ("In slot %d. %s"):format(entry.slot, entry.text)
				else entry.text
			cell.cell.BackgroundColor3 = CARD.card
		else
			cell.name.Text = "?"
			cell.rarity.Text = family
			cell.rarity.TextColor3 = CARD.subtext
			cell.words.Text = "Not found yet"
			cell.cell.BackgroundColor3 = PAL.card
		end
		cell.stroke.Thickness = if self._chosen == entry.id then 4 elseif entry.slot then 3 else 2
		cell.stroke.Color = if self._chosen == entry.id
			then Theme.colors.gold
			else DragonKeepLogic.FAMILY_COLOURS[entry.family]
	end
	local button = self._tabButtons.binder
	button:setText(("Binder %d/%d"):format(DragonKeepLogic.ownedCount(view), #SharedKeep.CARDS))
end

function DragonKeep._binderTapped(self: any, id: string)
	local view = self._view
	if view == nil or (view.binder or {})[id] ~= true then
		return
	end
	if #(view.slots or {}) == 0 then
		return
	end
	self._handPick = nil
	self._chosen = id
	self:showTab("slots") -- then a slot tap puts it there
end

----------------------------------------------------------------------------------------------------
-- Give cats
----------------------------------------------------------------------------------------------------

function DragonKeep._buildGive(self: any, pages: Frame)
	local page: Frame = Create("Frame", {
		Name = "GivePage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = pages,
	})
	self._givePage = page
	local top: Frame = Create("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = page,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	Button.new({
		name = "Commons",
		text = "Spare Commons",
		style = "ghost",
		size = UDim2.fromOffset(132, 30),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 1,
		parent = top,
		onClick = function()
			self:_quick("commons")
		end,
	})
	Button.new({
		name = "Repeats",
		text = "Repeats",
		style = "ghost",
		size = UDim2.fromOffset(100, 30),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 2,
		parent = top,
		onClick = function()
			self:_quick("repeats")
		end,
	})
	Button.new({
		name = "Clear",
		text = "Clear",
		style = "ghost",
		size = UDim2.fromOffset(72, 30),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 3,
		parent = top,
		onClick = function()
			self._picked = {}
			self._asking = false
			self:_paintGive()
		end,
	})
	self._giveNote = text({
		Name = "Note",
		Size = UDim2.new(1, -330, 0, 30),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 4,
		Text = "Locked cats stay. One copy of each cat stays with the quick picks.",
		Parent = top,
	})
	FitText.shrink(self._giveNote)
	local list = scroller("Cats", page)
	list.Position = UDim2.fromOffset(0, 30 + 6)
	list.Size = UDim2.new(1, 0, 1, -(30 + 6 + self._buyH + 8))
	self._giveList = list
	local layout: UIGridLayout = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	GridFit.fit(list, layout, GIVE_CELL, 6, function()
		return GIVE_H
	end)
	self._giveCells = {} :: { any }
	self._empty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 40),
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		Text = "No cats can move in right now.",
		Visible = false,
		Parent = page,
	})
	self._empty.Position = UDim2.fromOffset(0, 60)
	self._giveButton = Button.new({
		name = "Give",
		text = "Pick cats to move in",
		style = "primary",
		size = UDim2.new(1, 0, 0, self._buyH),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.fromScale(0.5, 1),
		textSize = Theme.sizes.textBody,
		enabled = false,
		parent = page,
		onClick = function()
			self:_give()
		end,
	})
end

function DragonKeep._giveCell(self: any, index: number): any
	local made = self._giveCells[index]
	if made then
		return made
	end
	local cell: TextButton = Create("TextButton", {
		Name = "Cat" .. index,
		AutoButtonColor = false,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Text = "",
		Parent = self._giveList,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = CARD.cardStroke,
		Thickness = 2,
		Parent = cell,
	})
	local portrait = CatPortrait.new({
		parent = cell,
		size = UDim2.fromOffset(52, 52),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 4),
		still = true,
		head = true,
	})
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(4, 58),
		Size = UDim2.new(1, -8, 0, 16),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny + 1,
		Parent = cell,
	})
	FitText.shrink(name)
	local warmth = text({
		Name = "Warmth",
		Position = UDim2.fromOffset(4, 74),
		Size = UDim2.new(1, -8, 0, 16),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = MenuFamily.onCard(Theme.colors.goldDark),
		Parent = cell,
	})
	local tag = text({
		Name = "Tag",
		Position = UDim2.fromOffset(4, 92),
		Size = UDim2.new(1, -8, 0, 14),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		Parent = cell,
	})
	local check = text({
		Name = "Check",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.goodDark,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "✓",
		Visible = false,
		ZIndex = 3,
		Parent = cell,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = check })
	made = {
		cell = cell,
		stroke = stroke,
		portrait = portrait,
		name = name,
		warmth = warmth,
		tag = tag,
		check = check,
		uid = nil :: string?,
		shown = "",
	}
	cell.Activated:Connect(function()
		local uid = made.uid
		if uid == nil then
			return
		end
		self._picked[uid] = if self._picked[uid] then nil else true
		self._asking = false
		self:_paintGive()
	end)
	self._giveCells[index] = made
	return made
end

function DragonKeep._candidates(self: any): { DragonKeepLogic.Candidate }
	return DragonKeepLogic.candidates(self._cats, self._busy)
end

function DragonKeep._paintGive(self: any)
	local list = self:_candidates()
	-- picks that are gone (moved in, traded, locked) drop out
	local still: { [string]: boolean } = {}
	for _, cand in list do
		if self._picked[cand.uid] then
			still[cand.uid] = true
		end
	end
	self._picked = still
	for index = 1, math.max(#self._giveCells, math.min(#list, DragonKeepLogic.MOST_SHOWN)) do
		local cand = if index <= DragonKeepLogic.MOST_SHOWN then list[index] else nil
		if cand == nil then
			local spare = self._giveCells[index]
			if spare then
				spare.cell.Visible = false
				spare.uid = nil
			end
			continue
		end
		local made = self:_giveCell(index)
		made.cell.Visible = true
		made.uid = cand.uid
		local key = cand.catId .. ":" .. (cand.variant or "")
		if made.shown ~= key then
			made.shown = key
			made.portrait:set(
				Catalog.getCat(cand.catId),
				cand.variant == "gold" or cand.variant == "rainbow"
			)
		end
		made.name.Text = cand.name
		made.warmth.Text = "+" .. DragonKeepLogic.commas(cand.warmth) .. " warmth"
		made.tag.Text = if cand.working
			then "Working"
			elseif cand.variant == "rainbow" then "Rainbow"
			elseif cand.variant == "gold" then "Gold"
			else cand.rarity
		local on = self._picked[cand.uid] == true
		made.check.Visible = on
		made.stroke.Color = if on then Theme.colors.good else CARD.cardStroke
		made.stroke.Thickness = if on then 3 else 2
	end
	self._empty.Visible = #list == 0
	local count, warmth, special = DragonKeepLogic.picked(list, self._picked)
	self._giveButton:setText(DragonKeepLogic.giveText(count, warmth, special, self._asking))
	self._giveButton:setEnabled(count > 0)
end

function DragonKeep._quick(self: any, kind: string)
	local list = self:_candidates()
	local total = 0
	for _ in self._cats or {} do
		total += 1
	end
	self._picked = {}
	for _, uid in DragonKeepLogic.quick(list, kind, total) do
		self._picked[uid] = true
	end
	self._asking = false
	self:_paintGive()
end

function DragonKeep._give(self: any)
	local list = self:_candidates()
	local count, _, special = DragonKeepLogic.picked(list, self._picked)
	if count == 0 then
		return
	end
	if special > 0 and not self._asking then
		self._asking = true
		self._askToken += 1
		local token = self._askToken
		self:_paintGive()
		task.delay(ASK_SECONDS, function()
			if self._askToken == token and self._asking then
				self._asking = false
				self:_paintGive()
			end
		end)
		return
	end
	local uids: { string } = {}
	for _, cand in list do
		if self._picked[cand.uid] then
			table.insert(uids, cand.uid)
		end
	end
	self._callbacks.give(uids, special > 0)
	self._picked = {}
	self._asking = false
	self:_paintGive()
end

----------------------------------------------------------------------------------------------------
-- The hand
----------------------------------------------------------------------------------------------------

function DragonKeep._buildHand(self: any, content: Frame)
	local shade: TextButton = Create("TextButton", {
		Name = "Hand",
		AutoButtonColor = false,
		BackgroundColor3 = PAL.panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Visible = false,
		ZIndex = 20,
		Parent = content,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._hand = shade
	self._handTitle = text({
		Name = "Title",
		Size = UDim2.new(1, -60, 0, 26),
		Position = UDim2.fromOffset(8, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = PAL.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = shade,
	})
	Outline.text(self._handTitle, 1)
	FitText.shrink(self._handTitle)
	Button.new({
		name = "Later",
		text = "Later",
		style = "ghost",
		size = UDim2.fromOffset(72, 26),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		textSize = Theme.sizes.textSmall,
		zIndex = 21,
		parent = shade,
		onClick = function()
			self:_showHand(false)
		end,
	})
	local row: Frame = Create("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -(32 + 18 + 6 + self._buyH + 6)),
		ZIndex = 21,
		Parent = shade,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._handRow = row
	self._handCards = {} :: { any }
	for index = 1, SharedKeep.HAND_SIZE do
		local holder: TextButton = Create("TextButton", {
			Name = "Card" .. index,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.3, 0, 1, 0),
			LayoutOrder = index,
			Text = "",
			ZIndex = 21,
			Parent = row,
		}, {
			Create("UIAspectRatioConstraint", { AspectRatio = HAND_W / HAND_H }),
			Create("UISizeConstraint", { MaxSize = Vector2.new(HAND_W, HAND_H) }),
		})
		-- Motion-FX's CardFlip: a Back shown first and a Front hidden first, each filling the card
		local back: Frame = Create("Frame", {
			Name = "Back",
			BackgroundColor3 = Color3.fromHex("4A2F78"),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 22,
			Parent = holder,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = PURPLE, Thickness = 3 }),
		})
		text({
			Name = "Mark",
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			Text = "🐉",
			ZIndex = 23,
			Parent = back,
		})
		local front: Frame = Create("Frame", {
			Name = "Front",
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 22,
			Parent = holder,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		-- the family edge as a Frame behind the front (CardFlip puts its own RarityEdge UIStroke on Front)
		local edge: Frame = Create("Frame", {
			Name = "FamilyBand",
			BackgroundColor3 = PURPLE,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 22,
			Parent = front,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		local family = text({
			Name = "Family",
			Size = UDim2.new(1, -8, 1, 0),
			Position = UDim2.fromOffset(4, 0),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.white,
			ZIndex = 23,
			Parent = edge,
		})
		Outline.text(family, 1)
		local name = text({
			Name = "Name",
			Position = UDim2.new(0, 6, 0, 36),
			Size = UDim2.new(1, -12, 0, 24),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			ZIndex = 23,
			Parent = front,
		})
		FitText.shrink(name)
		local rarity = text({
			Name = "Rarity",
			Position = UDim2.new(0, 6, 0, 60),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			ZIndex = 23,
			Parent = front,
		})
		local words = text({
			Name = "Words",
			Position = UDim2.new(0, 8, 0, 82),
			Size = UDim2.new(1, -16, 1, -90),
			TextSize = Theme.sizes.textSmall,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 23,
			Parent = front,
		})
		FitText.shrink(words)
		local ring = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.colors.gold,
			Thickness = 0,
			Parent = holder,
		})
		holder.Activated:Connect(function()
			self:_handTapped(index)
		end)
		self._handCards[index] = {
			holder = holder,
			back = back,
			front = front,
			edge = edge,
			family = family,
			name = name,
			rarity = rarity,
			words = words,
			ring = ring,
		}
	end
	self._oddsLine = text({
		Name = "Odds",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -(self._buyH + 6)),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = PAL.subtext,
		ZIndex = 21,
		Parent = shade,
	})
	FitText.shrink(self._oddsLine)
	local foot: Frame = Create("Frame", {
		Name = "Foot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, self._buyH),
		ZIndex = 21,
		Parent = shade,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._takeButton = Button.new({
		name = "Take",
		text = "Tap a card",
		style = "primary",
		size = UDim2.new(0.5, 0, 1, 0),
		textSize = Theme.sizes.textBody,
		enabled = false,
		layoutOrder = 1,
		zIndex = 22,
		parent = foot,
		onClick = function()
			self:_take()
		end,
	})
	self._keepButton = Button.new({
		name = "KeepCards",
		text = "Keep my cards · 🐟 " .. tostring(SharedKeep.KEEP_FISH),
		style = "ghost",
		size = UDim2.new(0.4, 0, 1, 0),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 2,
		zIndex = 22,
		parent = foot,
		onClick = function()
			self._handPick = nil
			self._selected = nil
			self._callbacks.keep()
			self:_showHand(false)
		end,
	})
end

function DragonKeep._paintHand(self: any)
	local view = self._view
	local hand = if view then view.hand or {} else {}
	local rekindle = view ~= nil and view.handKind == "rekindle"
	self._handTitle.Text = if rekindle
		then "Rekindle: pick a card"
		else ("%s reached a new stage: pick a card"):format(DragonKeepLogic.NAME)
	for index, made in self._handCards do
		local id = hand[index]
		local def = if id then SharedKeep.card(id) else nil
		made.holder.Visible = def ~= nil
		if def then
			made.edge.BackgroundColor3 = DragonKeepLogic.FAMILY_COLOURS[def.family] or PURPLE
			made.family.Text = (DragonKeepLogic.FAMILY_ICONS[def.family] or "")
				.. " "
				.. (DragonKeepLogic.FAMILY_NAMES[def.family] or def.family)
			made.name.Text = def.name
			made.rarity.Text = def.rarity
			made.rarity.TextColor3 =
				MenuFamily.rarity(if def.rarity == "Mythic" then "Mythical" else def.rarity)
			made.words.Text = def.text
		end
		made.ring.Thickness = if self._selected == index then 4 else 0
	end
	self._oddsLine.Text = DragonKeepLogic.oddsLine(if view then view.odds else nil)
	self._keepButton.instance.Visible = rekindle
	local selected = if self._selected then hand[self._selected] else nil
	local def = if selected then SharedKeep.card(selected) else nil
	self._takeButton:setText(
		if def
			then (if rekindle
				then "Take " .. def.name .. ", then pick a slot"
				else "Take " .. def.name)
			else "Tap a card"
	)
	self._takeButton:setEnabled(def ~= nil)
end

-- The cards are dealt face down and flip (Effects/CardFlip, when it is there); a hand seen before shows face up.
function DragonKeep._deal(self: any)
	local view = self._view
	local hand = if view then view.hand or {} else {}
	local key = table.concat(hand, ",")
	if key == self._dealt then
		return
	end
	self._dealt = key
	local client: Instance = script.Parent.Parent.Parent :: Instance
	local effects = client:FindFirstChild("Effects")
	local flipModule = if effects then effects:FindFirstChild("CardFlip") else nil
	if flipModule == nil or not flipModule:IsA("ModuleScript") then
		return
	end
	local ok, CardFlip = pcall(require, flipModule)
	if not ok or type(CardFlip) ~= "table" or type(CardFlip.deal) ~= "function" then
		return
	end
	local cards: { GuiObject } = {}
	local rarities: { string } = {}
	for index, id in hand do
		local def = SharedKeep.card(id)
		local made = self._handCards[index]
		if def and made then
			made.back.Visible = true
			made.front.Visible = false
			table.insert(cards, made.holder)
			table.insert(rarities, string.lower(def.rarity))
		end
	end
	pcall(CardFlip.deal, cards, rarities, function() end, function() end)
end

function DragonKeep._showHand(self: any, on: boolean)
	local view = self._view
	local has = view ~= nil and #(view.hand or {}) > 0
	self._hand.Visible = on and has
	if self._hand.Visible then
		self:_paintHand()
		self:_deal()
	end
end

function DragonKeep._handTapped(self: any, index: number)
	self._selected = index
	self:_paintHand()
end

function DragonKeep._take(self: any)
	local view = self._view
	local index = self._selected
	if view == nil or index == nil then
		return
	end
	self._selected = nil
	if view.handKind == "rekindle" and #(view.slots or {}) > 0 then
		-- then a slot: the Slots tab asks, and a binder-only choice is a tap on the hand's strip again
		self._handPick = index
		self._chosen = nil
		self:_showHand(false)
		self:showTab("slots")
		return
	end
	self._callbacks.pick(index, nil)
	self:_showHand(false)
end

----------------------------------------------------------------------------------------------------

function DragonKeep.showTab(self: any, tab: string)
	self._tab = tab
	self._slotsPage.Visible = tab == "slots"
	self._binderPage.Visible = tab == "binder"
	self._givePage.Visible = tab == "give"
	for id, button in self._tabButtons do
		button:setStyle(if id == tab then "purple" else "ghost")
	end
	self:_paint()
end

function DragonKeep.setView(
	self: any,
	view: any,
	cats: { [string]: any }?,
	busy: { [string]: boolean }?
)
	local before = if self._view then table.concat(self._view.hand or {}, ",") else ""
	self._view = view
	self._cats = cats
	self._busy = busy
	local now = if view then table.concat(view.hand or {}, ",") else ""
	if now ~= before then
		self._selected = nil
		if now == "" then
			self._handPick = nil
			self._hand.Visible = false
		end
	end
	self:_paint()
end

function DragonKeep._paint(self: any)
	self:_paintSlots()
	self:_paintBinder()
	if self._tab == "give" then
		self:_paintGive()
	end
	if self._hand.Visible then
		self:_paintHand()
	end
	local pick = self._handPick
	self._binderOnly.instance.Visible = pick ~= nil
	if pick ~= nil then
		self._strip.Visible = false
		self._chooseLine.Visible = true
		self._chooseLine.Text =
			"Tap the slot the new card replaces (the old card stays in your binder)"
	end
end

function DragonKeep.opened(self: any)
	self._chosen = nil
	self._handPick = nil
	self:showTab("slots")
	-- a hand waiting opens over the window
	self:_showHand(true)
end

function DragonKeep.closed(self: any)
	self._chosen = nil
	self._handPick = nil
	self._selected = nil
	self._asking = false
	self._hand.Visible = false
end

function DragonKeep.destroy(self: any)
	for _, made in self._giveCells do
		made.portrait:destroy()
	end
	self._panel:destroy()
end

return DragonKeep
