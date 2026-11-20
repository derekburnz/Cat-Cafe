--!strict
-- #4062 The Dragon Keep window (Castle late station; Design-Agent/notes/ticket-booth-and-dragon-keep.md section 2, the
-- station menus picture Derek OK'd 2026-11-14 00:43 UTC). The cocoa station look with three pill tabs:
-- - Slots: Cinder's card (name and stage, the warmth bar, a green Give cats), the five card slots (a locked one reads
--   "Stage 4"), the set line and, while a hand waits, a gold strip that opens it. From stage 3 a row of four scale
--   colours.
-- - Binder N/54: every card in family order. One you own shows its words; one you don't is a "?" in its family's
--   colour. Tap an owned card, then a slot, to put it there (free swaps).
-- - Give cats: the cats that may move in, weakest first, each with its Warmth. Tap to pick; "All Common" to
--   "All Mythical" pick every cat of that rarity (#4566: never a locked or working cat). A pick with special cats
--   asks once ("Tap again"). Cats "move into the Keep": never any other word.
-- The hand: three cards over the window with the card odds under them (a random pick, earned only, so the odds show).
-- Tap one to take it. A Rekindle hand then asks which slot it replaces (or the binder only; #4571 dropped "Keep my
-- cards"). Motion-FX's Effects/CardFlip deals the cards when it is there.
--   DragonKeep.new(callbacks)   built hidden; the UI registers its frame as the "DragonKeep" modal
--   :setView(view, cats, busy) :opened() :closed() :destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local DragonKeepLogic = require(script.Parent.Parent.Components.DragonKeepLogic)
local FitText = require(script.Parent.Parent.Components.FitText)
local GridFit = require(script.Parent.Parent.Components.GridFit)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
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
local TAB_H = 36 -- a tap target (ui-review: 36 px or more)
local DRAGON_W = 200
local SLOT_MIN = 72
local BINDER_CELL = 104
local BINDER_H = 92
local GIVE_CELL = 92
-- #4566: the give picker's pick-all buttons, commonest first, and the line under them
local PICK_RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
local PICK_UNDER_H = 30
local PICK_NOTE = "Locked cats and cats at work stay."
local GIVE_H = 112
local HAND_W = 170
local HAND_H = 210
local ASK_SECONDS = 4 -- the special cats' "Tap again" waits this long
local PURPLE = Color3.fromHex("9A6BE0") -- the Keep's dragon purple edge (the station menus picture)
-- #5433 Binder, #5434 Sets, #5435 Slots (Derek 2026-11-19: "make the binder menu look a little better with symbols in
-- the card for what set type it is", "make the set menu a bit cleaner", "make dragon keep menu better"): with
-- `keepLook` on, every card, set row and slot shows its family picture, the slots show their bonus and the sets line
-- is a row of family pictures with counts. Off, each tab is as before.
local LOOK_FLAG = "LiveFlag_keepLook"
local SLOT_ROW_H = 104
local SLOT_ROW_LOOK_H = 150
local SETS_LOOK_H = 66
local MARK = 22 -- a Binder card's corner picture
local GHOST = 48 -- a card not found yet: its family picture, faded, behind the words
local GHOST_FADE = 0.6
local BAND_TOP = 20 -- a card not found yet: a dark band under its family name and "Not found yet"
local BAND_H = 34
local BAND_COLOUR = Color3.fromHex("16161D")
local BAND_FADE = 0.25
local UNFOUND_TEXT = Color3.fromHex("F4EEFF")
local SET_ICON = 32
local PIP = 10
local TAG_W = 58

local function lookOn(): boolean
	return ReplicatedStorage:GetAttribute(LOOK_FLAG) == true
end

-- a label that draws a card family's picture (Icon_DragonFamily_*), or nothing for no family
local function familyArt(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Text = "",
		TextScaled = true,
		Visible = false,
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end
local COLOURS: { [string]: Color3 } = {
	ruby = Color3.fromHex("D8344A"),
	sapphire = Color3.fromHex("3C6FE0"),
	emerald = Color3.fromHex("2FA866"),
	amethyst = Color3.fromHex("9A5BD8"),
}
local TABS = {
	{ id = "slots", name = "Slots" },
	{ id = "binder", name = "Binder" },
	{ id = "sets", name = "Sets" }, -- #4576
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
	self._reading = nil :: number? -- #4561: the filled slot whose card's words show under the slots
	self._open = false
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
		image = ShopIcons.clean("DragonKeep"), -- #4417: the station's clean picture
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
			size = UDim2.fromOffset(
				if tab.id == "binder" then 128 elseif tab.id == "sets" then 80 else 104,
				TAB_H
			),
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
	self:_buildSets(pages)
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
		Size = UDim2.new(1, 0, 0, SLOT_ROW_H),
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
		local bonus = text({ -- #5435: the slotted card's words, with keepLook on
			Name = "Bonus",
			Position = UDim2.new(0, 6, 0, 66),
			Size = UDim2.new(1, -12, 1, -70),
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = CARD.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Visible = false,
			Parent = tile,
		})
		FitText.shrink(bonus)
		tile.Activated:Connect(function()
			self:_slotTapped(index)
		end)
		self._slotTiles[index] =
			{ tile = tile, stroke = stroke, icon = icon, label = label, bonus = bonus }
	end
	local colours: Frame = Create("Frame", {
		Name = "Colours",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Scale.tapHeight(36)),
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
		Size = UDim2.fromOffset(96, 36),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Scale colour",
		LayoutOrder = 0,
		Parent = colours,
	})
	self._colourDots = {} :: { [string]: any }
	for order, id in SharedKeep.COLOURS do
		-- the button is a finger's reach (Scale.tapHeight) around a 30 px dot
		local reach = Scale.tapHeight(36)
		local hit: TextButton = Create("TextButton", {
			Name = "Colour_" .. id,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(reach, reach),
			LayoutOrder = order,
			Text = "",
			Parent = colours,
		})
		local dot: Frame = Create("Frame", {
			Name = "Dot",
			BackgroundColor3 = COLOURS[id] or Theme.colors.gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(30, 30),
			Parent = hit,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local ring = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.colors.white,
			Thickness = 0,
			Parent = dot,
		})
		hit.Activated:Connect(function()
			self._callbacks.colour(id)
		end)
		self._colourDots[id] = ring
	end
	local sets = card({
		Name = "Sets",
		Size = UDim2.new(1, 0, 0, Scale.tapHeight(36)), -- #4576: a tap target now (it opens the Sets tab)
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
	self._setsCard = sets
	-- #5435: with keepLook on, the six families as pictures with their counts in place of the line
	local chips: Frame = Create("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		Visible = false,
		Parent = sets,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._setChipRow = chips
	self._setChips = {} :: { [string]: any }
	for order, family in DragonKeepLogic.FAMILIES do
		local chip: Frame = Create("Frame", {
			Name = "Chip_" .. family,
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / #DragonKeepLogic.FAMILIES, 0, 1, 0),
			LayoutOrder = order,
			Parent = chips,
		})
		local art = familyArt({
			Name = "Art",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(SET_ICON, SET_ICON),
			Visible = true,
			Parent = chip,
		})
		IconArt.setImage(art, ShopIcons.dragonFamily(family))
		local count = text({
			Name = "Count",
			Position = UDim2.new(0, 0, 0, SET_ICON),
			Size = UDim2.new(1, 0, 1, -SET_ICON),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			Parent = chip,
		})
		FitText.shrink(count)
		self._setChips[family] = { art = art, count = count }
	end
	-- #4576: the line opens the Sets tab
	local setsHit: TextButton = Create("TextButton", {
		Name = "OpenSets",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 3,
		Parent = sets,
	})
	setsHit.Activated:Connect(function()
		self:showTab("sets")
	end)
	self._chooseLine = text({
		Name = "Choose",
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y, -- #4561: a card's words may take two lines
		TextWrapped = true,
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
		size = UDim2.new(1, 0, 0, 36),
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
		Size = UDim2.new(1, 0, 0, Scale.tapHeight(48)),
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
	-- #4412: Cinder's portrait for the stage reached; the Egg (no stage yet) keeps the 🐉
	IconArt.setImage(
		self._dragonPicture,
		ShopIcons.dragonStage(if view then view.stageName else nil)
	)
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
		-- #4415: a slotted card's family picture over its emoji; a lock or an empty slot keeps its glyph
		IconArt.setImage(tile.icon, if family then ShopIcons.dragonFamily(family) else nil)
		tile.label.Text = slot.label
		tile.label.TextColor3 = if slot.locked then CARD.subtext else CARD.text
		-- #5435: with keepLook on, the name on one line and the card's bonus under it
		local look = lookOn()
		tile.bonus.Visible = look and def ~= nil
		tile.bonus.Text = if def then def.text or "" else ""
		tile.label.Size = if look then UDim2.new(1, -8, 0, 18) else UDim2.new(1, -8, 1, -50)
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
	-- #5435: the sets as pictures with counts, a lit set in gold
	local look = lookOn()
	self._slotRow.Size = UDim2.new(1, 0, 0, if look then SLOT_ROW_LOOK_H else SLOT_ROW_H)
	self._setsCard.Size = UDim2.new(1, 0, 0, if look then SETS_LOOK_H else Scale.tapHeight(36))
	self._setsLine.Visible = not look
	self._setChipRow.Visible = look
	if look then
		for _, info in DragonKeepLogic.setRows(view) do
			local chip = self._setChips[info.family]
			if chip then
				chip.count.Text = info.count
				chip.count.TextColor3 = if info.level > 0 then Theme.colors.gold else PAL.subtext
			end
		end
	end
	local chosenName = nil
	if self._chosen then
		local def = SharedKeep.card(self._chosen)
		chosenName = if def then def.name else nil
	end
	-- #4561 (Derek 2026-11-15: "click your current equipped one to view and read what it does"): a tapped filled slot's
	-- card, its name and words, until another tap
	local reading = nil
	if chosenName == nil and self._reading ~= nil and view ~= nil then
		local id = (view.slots or {})[self._reading]
		local def = if type(id) == "string" then SharedKeep.card(id) else nil
		if def then
			local words = def.text or ""
			if words ~= "" and not string.find(words, "[%.!?]$") then
				words ..= "."
			end
			reading = ("%s: %s Tap again to swap it."):format(def.name, words)
		else
			self._reading = nil
		end
	end
	self._chooseLine.Visible = chosenName ~= nil or reading ~= nil
	self._chooseLine.Text = if chosenName
		then ("Tap a slot to put %s there"):format(chosenName)
		else reading or ""
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
	-- #4561: a filled slot's first tap shows what its card does; the second (or an empty slot) opens the binder
	local held = if view ~= nil then (view.slots or {})[index] else nil
	local filled = type(held) == "string" and held ~= ""
	if filled and self._reading ~= index then
		self._reading = index
		self:_paint()
		return
	end
	self._reading = nil
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
		-- #5433: the family's picture in the corner, and big and faded behind a card not found yet
		local picture = ShopIcons.dragonFamily(entry.family)
		local mark = familyArt({
			Name = "Mark",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(MARK, MARK),
			ZIndex = 2,
			Parent = cell,
		})
		IconArt.setImage(mark, picture)
		local ghost = familyArt({
			Name = "Ghost",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(GHOST, GHOST),
			ZIndex = 0,
			Parent = cell,
		})
		IconArt.setImage(ghost, picture)
		IconArt.setTransparency(ghost, GHOST_FADE)
		-- Sync check: the purple words were hard to read over the faded picture, so they sit on a band
		local band = Create("Frame", {
			Name = "Band",
			Position = UDim2.fromOffset(0, BAND_TOP),
			Size = UDim2.new(1, 0, 0, BAND_H),
			BackgroundColor3 = BAND_COLOUR,
			BackgroundTransparency = BAND_FADE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
			Parent = cell,
		})
		rarity.ZIndex = 2
		words.ZIndex = 2
		cell.Activated:Connect(function()
			self:_binderTapped(entry.id)
		end)
		self._binderCells[entry.id] = {
			cell = cell,
			stroke = stroke,
			name = name,
			rarity = rarity,
			words = words,
			mark = mark,
			ghost = ghost,
			band = band,
		}
	end
end

function DragonKeep._paintBinder(self: any)
	local view = self._view
	local look = lookOn()
	for _, entry in DragonKeepLogic.binder(view) do
		local cell = self._binderCells[entry.id]
		if cell == nil then
			continue
		end
		cell.mark.Visible = look and entry.owned
		cell.ghost.Visible = look and not entry.owned
		cell.band.Visible = look and not entry.owned
		local family = DragonKeepLogic.FAMILY_NAMES[entry.family] or entry.family
		if entry.owned then
			cell.name.Text = entry.name
			cell.rarity.Text = entry.rarity .. " · " .. family
			cell.rarity.TextColor3 =
				MenuFamily.rarity(if entry.rarity == "Mythic" then "Mythical" else entry.rarity)
			cell.words.TextColor3 = CARD.subtext
			cell.words.Text = if entry.slot
				then ("In slot %d. %s"):format(entry.slot, entry.text)
				else entry.text
			cell.cell.BackgroundColor3 = CARD.card
		else
			cell.name.Text = if look then "" else "?" -- #5433: the faded picture says what it is
			cell.rarity.Text = family
			cell.rarity.TextColor3 = if look then UNFOUND_TEXT else CARD.subtext
			cell.words.Text = "Not found yet"
			cell.words.TextColor3 = if look then UNFOUND_TEXT else CARD.subtext
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
-- Sets (#4576, Derek 2026-11-15 18:36 UTC: "no way to see set bonuses right now")
----------------------------------------------------------------------------------------------------

local SET_ROW_H = 72

function DragonKeep._buildSets(self: any, pages: Frame)
	local page: Frame = Create("Frame", {
		Name = "SetsPage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = pages,
	})
	self._setsPage = page
	local intro = text({
		Name = "Intro",
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Put cards of one family in your slots: 3 light its set, all 5 light the full set too.",
		Parent = page,
	})
	FitText.shrink(intro)
	local list = scroller("Sets", page)
	list.Position = UDim2.fromOffset(0, 24)
	list.Size = UDim2.new(1, 0, 1, -24)
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	self._setRows = {} :: { [string]: any }
	for order, family in DragonKeepLogic.FAMILIES do
		local colour = DragonKeepLogic.FAMILY_COLOURS[family] or PURPLE
		local row = card({
			Name = "Set_" .. family,
			Size = UDim2.new(1, -8, 0, SET_ROW_H),
			LayoutOrder = order,
			BackgroundColor3 = PAL.card,
		}, colour)
		row.Parent = list
		local title = text({
			Name = "Title",
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(0, 110, 0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = PAL.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		FitText.shrink(title)
		local count = text({
			Name = "Count",
			Position = UDim2.fromOffset(10, 34),
			Size = UDim2.new(0, 110, 0, 22),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		FitText.shrink(count)
		-- #5434: with keepLook on, the family picture, the name beside it, pips for the cards in and tagged lines
		local art = familyArt({
			Name = "Art",
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(SET_ICON, SET_ICON),
			Parent = row,
		})
		IconArt.setImage(art, ShopIcons.dragonFamily(family))
		local pips: Frame = Create("Frame", {
			Name = "Pips",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 48),
			Size = UDim2.fromOffset(5 * (PIP + 4), PIP),
			Visible = false,
			Parent = row,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local dots: { Frame } = {}
		for index = 1, (SharedKeep.SET_FULL or SharedKeep.SET_SIZE) do
			dots[index] = Create("Frame", {
				Name = "Pip" .. index,
				BackgroundColor3 = PAL.subtext,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(PIP, PIP),
				LayoutOrder = index,
				Parent = pips,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		local function tag(name: string, words: string, y: number): Frame
			local made: Frame = Create("Frame", {
				Name = name,
				BackgroundColor3 = colour,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(128, y + 6),
				Size = UDim2.fromOffset(TAG_W, 20),
				Visible = false,
				Parent = row,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			text({
				Name = "Words",
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.bodyBold,
				TextSize = Theme.sizes.textTiny + 1,
				TextColor3 = Theme.colors.white,
				Text = words,
				Parent = made,
			})
			return made
		end
		local function line(name: string, y: number): TextLabel
			local label = text({
				Name = name,
				Position = UDim2.fromOffset(128, y),
				Size = UDim2.new(1, -138, 0, 32),
				TextSize = Theme.sizes.textSmall,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.None,
				Parent = row,
			})
			FitText.shrink(label)
			return label
		end
		self._setRows[family] = {
			row = row,
			stroke = row:FindFirstChildWhichIsA("UIStroke"),
			title = title,
			count = count,
			three = line("Three", 4),
			five = line("Five", 37),
			art = art,
			pips = pips,
			dots = dots,
			threeTag = tag("ThreeTag", SharedKeep.SET_SIZE .. " cards", 4),
			fiveTag = tag("FiveTag", (SharedKeep.SET_FULL or SharedKeep.SET_SIZE) .. " cards", 37),
		}
	end
end

function DragonKeep._paintSets(self: any)
	local lit = Theme.colors.gold
	for _, info in DragonKeepLogic.setRows(self._view) do
		local made = self._setRows[info.family]
		if made == nil then
			continue
		end
		-- #5434: keepLook on: picture, plain name, pips and tagged lines with the "N cards: " taken off
		local look = lookOn()
		local name = DragonKeepLogic.FAMILY_NAMES[info.family] or info.family
		made.title.Text = if look then name else info.title
		made.title.Position = UDim2.fromOffset(if look then 10 + SET_ICON + 6 else 10, 6)
		made.title.Size = UDim2.new(0, if look then 110 - SET_ICON - 6 else 110, 0, 26)
		made.title.TextColor3 = if look and info.level > 0 then lit else PAL.text
		made.art.Visible = look
		made.pips.Visible = look
		made.count.Visible = not look
		local inSlots = tonumber(string.match(info.count, "^(%d+)")) or 0
		for index, dot in made.dots do
			dot.BackgroundColor3 = if index <= inSlots then lit else PAL.cardStroke
		end
		local lineX = if look then 128 + TAG_W + 6 else 128
		made.three.Position = UDim2.fromOffset(lineX, 4)
		made.three.Size = UDim2.new(1, -(lineX + 10), 0, 32)
		made.five.Position = UDim2.fromOffset(lineX, 37)
		made.five.Size = UDim2.new(1, -(lineX + 10), 0, 32)
		local function words(full: string): string
			return if look then (string.gsub(full, "^%d+ cards: ", "")) else full
		end
		made.count.Text = info.count .. " in your slots"
		made.count.TextColor3 = if info.level > 0 then lit else PAL.subtext
		made.three.Text = (if info.level >= SharedKeep.SET_SIZE then "✓ " else "")
			.. words(info.three)
		made.three.TextColor3 = if info.level >= SharedKeep.SET_SIZE then lit else PAL.text
		made.threeTag.Visible = look
		local five = info.five
		made.five.Visible = five ~= nil
		made.fiveTag.Visible = look and five ~= nil
		if five ~= nil then
			local full = info.level > SharedKeep.SET_SIZE
			made.five.Text = (if full then "✓ " else "") .. words(five)
			made.five.TextColor3 = if full then lit else PAL.text
		end
		if made.stroke then
			made.stroke.Thickness = if info.level > 0 then 3 else 2
		end
	end
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
		Size = UDim2.new(1, 0, 0, 36),
		Parent = page,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	-- #4566 (Derek 2026-11-15): one button per rarity picks every cat of it (locked and working cats stay)
	for index, rarity in PICK_RARITIES do
		Button.new({
			name = "All" .. rarity,
			text = "All " .. rarity,
			style = "ghost",
			size = UDim2.new(1 / #PICK_RARITIES, -5, 1, 0),
			textSize = Theme.sizes.textSmall,
			layoutOrder = index,
			parent = top,
			onClick = function()
				self:_pickRarity(rarity)
			end,
		})
	end
	local under: Frame = Create("Frame", {
		Name = "Under",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36 + 4),
		Size = UDim2.new(1, 0, 0, PICK_UNDER_H),
		Parent = page,
	})
	-- Sync-Agent's sweep 2026-11-15: only the MOST_SHOWN weakest cats show, so a big collection hid every gold and
	-- rainbow cat. This flips the order so the strongest show first.
	self._strong = false
	self._orderButton = Button.new({
		name = "Order",
		text = "Strongest first",
		style = "ghost",
		size = UDim2.new(0, 132, 1, 0),
		position = UDim2.new(1, -(72 + 6 + 132), 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = under,
		onClick = function()
			self._strong = not self._strong
			self._orderButton:setText(if self._strong then "Weakest first" else "Strongest first")
			self:_paintGive()
		end,
	})
	Button.new({
		name = "Clear",
		text = "Clear",
		style = "ghost",
		size = UDim2.new(0, 72, 1, 0),
		position = UDim2.new(1, -72, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = under,
		onClick = function()
			self._picked = {}
			self._asking = false
			self._giveNote.Text = PICK_NOTE
			self:_paintGive()
		end,
	})
	self._giveNote = text({
		Name = "Note",
		Size = UDim2.new(1, -(72 + 6 + 132 + 8), 1, 0),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = PICK_NOTE,
		Parent = under,
	})
	FitText.shrink(self._giveNote)
	local list = scroller("Cats", page)
	list.Position = UDim2.fromOffset(0, 36 + 4 + PICK_UNDER_H + 6)
	list.Size = UDim2.new(1, 0, 1, -(36 + 4 + PICK_UNDER_H + 6 + self._buyH + 8))
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
	return DragonKeepLogic.candidates(
		self._cats,
		self._busy,
		ReplicatedStorage:GetAttribute("LiveFlag_" .. SharedKeep.NO_EVENT_FLAG) == true -- #5428
	)
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
	if self._strong then
		local flipped: { DragonKeepLogic.Candidate } = {}
		for index = #list, 1, -1 do
			table.insert(flipped, list[index])
		end
		list = flipped
	end
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

function DragonKeep._pickRarity(self: any, rarity: string)
	local list = self:_candidates()
	local total = 0
	for _ in self._cats or {} do
		total += 1
	end
	self._picked = {}
	local uids = DragonKeepLogic.byRarity(list, rarity, total)
	for _, uid in uids do
		self._picked[uid] = true
	end
	self._giveNote.Text = if #uids == 0
		then string.format("No unlocked %s cats can move in.", rarity)
		else PICK_NOTE
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
		Size = UDim2.new(1, -60, 0, 36),
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
		size = UDim2.fromOffset(72, 36),
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
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -(42 + 18 + 6 + self._buyH + 6)),
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
	-- #4571 (Derek 2026-11-15): no "Keep my cards". A taken card can go to the binder only, so the slots never change.
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
	self._setsPage.Visible = tab == "sets"
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
	-- a new hand while the window is open (a stage reached from the give page) comes up over it at once
	if now ~= before and now ~= "" and self._open then
		self:_showHand(true)
	end
end

function DragonKeep._paint(self: any)
	self:_paintSlots()
	self:_paintBinder()
	self:_paintSets()
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
	self._open = true
	self._chosen = nil
	self._handPick = nil
	self:showTab("slots")
	-- a hand waiting opens over the window
	self:_showHand(true)
end

function DragonKeep.closed(self: any)
	self._reading = nil -- #4561: a reopened window starts with no card read
	self._open = false
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
