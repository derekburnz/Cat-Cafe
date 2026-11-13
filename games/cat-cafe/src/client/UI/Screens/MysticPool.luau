--!strict
-- The Mystic Pool's card (#3196, #3314, trait-station.md sections 1 and 3), opened by UI.mysticPool.open(). Sage
-- Sorrel gives a cat one trait:
--   the picked cat on the left (its picture, name and level, with Pick a cat / Change cat) and its trait's card on
--     the right (name in the rarity's colour, rarity and one line per effect, or "No trait yet");
--   Roll under them ("Free roll (5 left)", "Re-roll · 1 Trait Token", "Roll · 10 golden fish"), greyed with the
--     reason while the player cannot pay, and Odds beside it: the rarity odds, one tap from Roll;
--   the odds line, always on the card, and what the player has ("2 Trait Tokens · 34 golden fish");
--   the station's free tokens ("1 Trait Token ready" with Collect, or "Next free token in 3h 12m").
-- Pick a cat turns the card to the player's cats, as the Oasis Spa's list (#3136): a search box, All / Resting /
-- Working and a face per row, built a few a frame and with faces only near the visible rows, so hundreds of cats stay
-- light. After a re-roll the old trait and the new one show side by side with Keep old and Take new, styled the same
-- so neither is pushed; nothing else can be pressed until one is picked (the server holds the roll). A roll's answer
-- is the next PlayerState: the buttons rest until it shows (MysticPoolLogic.stamp) or PENDING_SECONDS, then
-- `callbacks.play` (the pool's animation, Effects/MysticPool) runs with a tap to skip, and the card shows the
-- result. The server decides every roll and payment; this only asks. #3864: once the free rolls are used, the Trait
-- Token bundles are offered once a session on a sheet of their own, with the roll's full odds and "No thanks"
-- (MysticPoolLogic.bundles; only when the server's `bundles` says so); a pick opens Roblox's own purchase prompt.
-- Words in Components/MysticPoolLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CatPickLogic = require(script.Parent.Parent.Components.CatPickLogic)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local LateStationsLogic = require(script.Parent.Parent.Components.LateStationsLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local MysticPoolLogic = require(script.Parent.Parent.Components.MysticPoolLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits")) :: any

local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	roll: (uid: string) -> (),
	choose: (takeNew: boolean) -> (),
	collect: () -> (),
	close: () -> (),
	-- the pool's animation for a roll that gave `rarity` ("rare"); calls onReveal once when the card may show and
	-- returns its skip. nil (or a nil skip) shows the card at once
	play: ((uid: string, rarity: string, onReveal: () -> ()) -> (() -> ())?)?,
	far: (() -> boolean)?, -- true once the player has walked away from the pool: the card closes
	-- #3702: while the pool's animation plays the card goes away and the screen's edges are shaded; `onTap` is a
	-- tap anywhere (the skip). Returns the function that brings the card back. nil keeps the old sheet on the card
	shade: ((onTap: () -> ()) -> () -> ())?,
	-- #3864: a bundle's Buy, with its developer product id (Roblox's purchase prompt); nil hides the offer
	buy: ((productId: number) -> ())?,
}

export type MysticPool = {
	frame: Frame,
	render: (self: MysticPool, state: Types.PlayerState) -> (),
	pick: (self: MysticPool, uid: string?) -> (),
	opened: (self: MysticPool) -> (),
	closed: (self: MysticPool) -> (),
	destroy: (self: MysticPool) -> (),
}

type TraitCard = {
	frame: Frame,
	name: TextLabel,
	rarity: TextLabel,
	lines: { TextLabel },
}

type Row = {
	frame: Frame,
	disc: Frame,
	button: Button.Button,
	cat: any,
	portrait: CatPortrait.CatPortrait?,
	loaded: boolean,
}

local MAX_WIDTH = 540
local CHROME = 62 -- the panel's header and padding around its content
local PICTURE = 48
local TILE_W = 150
local TILE_H = 100 -- the cat's tile and the trait's card
local ODDS_W = 84
local WORDS_H = 18 + 28 -- what the player has (or why Roll is grey), then the odds on two lines
-- #3848 (Derek 2026-11-13: "the collect trait reroll button is cutoff a bit on mobile"): on a short screen the card
-- reached the screen's bottom edge, so the line of what the player has moves beside Collect, over the token line, and
-- the Roll row and the spaces between rows are a little shorter
local SHORT_WORDS_H = 28
local PENDING_SECONDS = 4
local RETRY_SECONDS = 1.5 -- #3875: a tap on a grey choice after this sends it again
local ROW_H = 68 -- #3700: three lines (name, rarity and level, trait)
local PICKER_TALL = 680 -- #3700: the card grows to at most this while the cat list shows, so about six rows fit
local SCREEN_ROOM = 16 -- px kept clear above and below the grown card
local SORT_W = 80 -- #3874: "Rarity ▼" fits
local BACK_W = 64
local FILTER_W = 72
local TOOL_PAD = 2 -- room for the outlines inside the row's own edge
local TOOL_GAP = 4
local MENU_PAD = 8
local MENU_GAP = 6
local MENU_WORD_W = 46
local CHIP_W = 80
local WIDE_CHIP_W = 92 -- "No trait", "Has trait"
local SEARCH_HINT = "🔍 Search"
-- #3874: on a short screen a row has two lines (name and trait on top, the tags under) and a slimmer Pick, so about
-- twice as many cats show at once
local SHORT_ROW_H = 54
local SHORT_FACE = 36
local SHORT_PICK_W = 72
local SHORT_PICK_H = 38 -- drawn; on a touch screen its pad still reaches a finger's 44 px (Button's Hit)
local FACE = 44
local TOOL_H = Scale.tapHeight(Theme.sizes.touchMin)
local FIRST_ROWS = 12
local ROWS_PER_FRAME = 20
local FACES_PER_PASS = 15
local FACE_MARGIN = 240
local FACE_KEEP = 720
local SEARCH_WAIT = 0.15
local EFFECT_LINES = 3 -- a Mythic has three effects
local GAP = Theme.sizes.gap

local MysticPool = {}
MysticPool.__index = MysticPool

-- #3700: the list's order is remembered for the session
-- #3864: `offered`, once the token offer has shown this session (a "No thanks" holds for the session)
local remembered = { sort = CatPickLogic.DEFAULT_SORT, flipped = false, offered = false }

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

-- #3950 (Derek 2026-11-13: "the trait doesn't show rarity very well ... maybe bold it and make it stronger colored"):
-- a trait's rarity is shown on a pill filled with its own colour, never as pale words. The words on it are white,
-- or dark ink on a light fill (Legendary's gold), so they read on every rarity.
local function inkOn(fill: Color3): Color3
	local light = 0.299 * fill.R + 0.587 * fill.G + 0.114 * fill.B
	return if light > 0.62 then Theme.colors.ink else Theme.colors.white
end
-- a trait's name in its rarity's colour on the cream card: the colour itself, a little deeper so pale ones read
local function deep(color: Color3): Color3
	return if MenuFamily.on() then color:Lerp(Theme.colors.ink, 0.35) else color
end

-- A page over the card's content: a little past its edges (and the bottom row's button lips), so nothing under it
-- shows.
local function sheet(name: string, parent: Instance, z: number): Frame
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.new(1, 8, 1, 16),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 12),
		}),
	})
end

-- A trait's card: a small heading ("Trait", "Now", "New"), the name in the rarity's colour, the rarity and a line
-- per effect.
local function traitCard(
	name: string,
	parent: Instance,
	position: UDim2,
	size: UDim2,
	z: number
): TraitCard
	local frame: Frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		ZIndex = z,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	local title = text({
		Name = "Name",
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		ZIndex = z + 1,
		Parent = frame,
	})
	-- #3950: "Now · Epic" on a pill of the rarity's colour, centred under the name
	local rarity = text({
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 27),
		Size = UDim2.fromOffset(0, 17),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny + 1,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = z + 1,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
	})
	local lines: { TextLabel } = {}
	for index = 1, EFFECT_LINES do
		lines[index] = text({
			Name = "Effect" .. index,
			Position = UDim2.fromOffset(8, 28 + index * 17),
			Size = UDim2.new(1, -16, 0, 17),
			TextSize = Theme.sizes.textSmall,
			ZIndex = z + 1,
			Parent = frame,
		})
	end
	return { frame = frame, name = title, rarity = rarity, lines = lines }
end

-- The odds, always on the card: two short lines at `top`.
local function oddsLines(parent: Instance, top: number, z: number)
	for index, words in MysticPoolLogic.ODDS_LINES do
		text({
			Name = if index == 1 then "OddsLine" else "OddsLine" .. index,
			Position = UDim2.fromOffset(0, top + (index - 1) * 14),
			Size = UDim2.new(1, 0, 0, 14),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = PAL.subtext,
			Text = words,
			ZIndex = z,
			Parent = parent,
		})
	end
end

-- `rarity` is the line under the name: the trait's rarity, or `none` for a card without one ("Now: no trait").
local function fill(card: TraitCard, trait: MysticPoolLogic.Card, head: string?, none: string?)
	local color = Color3.fromHex(trait.color)
	card.name.Text = trait.name
	card.name.TextColor3 = if trait.has then deep(color) else CARD.subtext
	local rarity = if trait.has then trait.rarity else none or ""
	card.rarity.Text = if head ~= nil and rarity ~= ""
		then head .. " · " .. rarity
		else head or rarity
	-- #3950: the rarity on a pill of its colour, a thick border of it and a faint wash of it over the card
	card.rarity.BackgroundTransparency = if trait.has then 0 else 1
	card.rarity.BackgroundColor3 = color
	card.rarity.TextColor3 = if trait.has then inkOn(color) else CARD.subtext
	for index, label in card.lines do
		label.Text = trait.lines[index] or ""
	end
	card.frame.BackgroundColor3 = if trait.has then CARD.card:Lerp(color, 0.12) else CARD.card
	local stroke = card.frame:FindFirstChildWhichIsA("UIStroke") :: UIStroke?
	if stroke then
		stroke.Color = if trait.has then color else CARD.cardStroke
		stroke.Thickness = if trait.has then 4 else Theme.sizes.stroke
	end
end

function MysticPool.new(callbacks: Callbacks): MysticPool
	local self = setmetatable({}, MysticPool) :: any
	self._callbacks = callbacks
	self._view = nil :: any
	self._cats = {} :: { [string]: any }
	self._fish = 0
	self._uid = nil :: string? -- the picked cat
	self._pending = false
	self._pendingAt = 0
	self._pendingToken = 0
	self._stamp = nil :: string? -- MysticPoolLogic.stamp when the last press went out
	self._rolling = nil :: { uid: string, hadTrait: boolean }? -- a Roll waiting for its answer
	self._skip = nil :: (() -> ())? -- the running animation's skip
	self._lift = nil :: (() -> ())? -- #3702: ends the running reveal's shade and brings the card back
	self._playToken = 0
	self._open = false
	self._tick = 0
	self._picking = false
	self._rows = {} :: { Row }
	self._rowsKey = nil :: string?
	self._candidates = 0
	self._buildToken = 0
	self._query = ""
	self._filter = "All"
	self._sort = remembered.sort
	self._flipped = remembered.flipped
	self._searchToken = 0
	self._facesQueued = false
	local buttonH = Scale.tapHeight(40, Theme.sizes.buttonDepth)
	self._buttonH = buttonH
	-- the card is kept short (the smallest phone has about 320 px under Roblox's top bar): the cat and its trait,
	-- one row of buttons, three lines of words and the token row
	local short = Scale.isShort()
	self._short = short
	local wordsH = if short then SHORT_WORDS_H else WORDS_H
	local rowH = if short then buttonH else buttonH + 4 -- the Roll row; short: no extra 4 px
	local space = if short then 2 else 4 -- between the rows
	local contentH = TILE_H + GAP + rowH + space + wordsH + space + buttonH
	local height = contentH + CHROME

	local panel = Panel.new({
		dark = true,
		name = MysticPoolLogic.WINDOW,
		title = "Mystic Pool",
		subtitle = "Sage Sorrel gives each cat one trait",
		color = Theme.colors.sky,
		icon = "🔮",
		size = UDim2.new(1, 0, 0, height),
		onClose = callbacks.close,
	})
	self._height = height
	self._limit = Create("UISizeConstraint", {
		MaxSize = Vector2.new(MAX_WIDTH, height),
		Parent = panel.frame,
	})
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	-- the picked cat: its picture, name and level
	local tile: Frame = Create("Frame", {
		Name = "Cat",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(TILE_W, TILE_H),
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	self._portrait = CatPortrait.new({
		parent = tile,
		size = UDim2.fromOffset(PICTURE, PICTURE),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 6),
		still = true,
	})
	self._portraitKey = nil :: string?
	self._glyph = text({
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(PICTURE, PICTURE),
		FontFace = Theme.fonts.display,
		TextSize = 36,
		TextColor3 = CARD.subtext,
		Text = "+",
		Parent = tile,
	})
	self._catName = text({
		Name = "Name",
		Position = UDim2.fromOffset(6, PICTURE + 8),
		Size = UDim2.new(1, -12, 0, 20),
		FontFace = Theme.fonts.display,
		Parent = tile,
	})
	self._catLine = text({
		Name = "Line",
		Position = UDim2.fromOffset(6, PICTURE + 28),
		Size = UDim2.new(1, -12, 0, 16),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		Parent = tile,
	})

	self._trait = traitCard(
		"Trait",
		content,
		UDim2.fromOffset(TILE_W + GAP, 0),
		UDim2.new(1, -(TILE_W + GAP), 0, TILE_H),
		1
	)

	-- one row: Change cat under the cat, Roll, and Odds one tap away beside it
	local rollTop = TILE_H + GAP
	self._change = Button.new({
		name = "Change",
		text = "Pick a cat",
		style = "ghost",
		size = UDim2.fromOffset(TILE_W, rowH),
		position = UDim2.fromOffset(0, rollTop),
		textSize = Theme.sizes.textSmall + 1,
		parent = content,
		onClick = function()
			if not self._pending then
				self:_showPicker(true)
			end
		end,
	})
	self._changeText = nil :: string?
	self._roll = Button.new({
		name = "Roll",
		text = "Roll",
		style = "primary",
		size = UDim2.new(1, -(TILE_W + ODDS_W + GAP * 2), 0, rowH),
		position = UDim2.fromOffset(TILE_W + GAP, rollTop),
		textSize = Theme.sizes.textBody,
		parent = content,
		onClick = function()
			self:_rollPress()
		end,
	})
	self._rollText = nil :: string?
	self._oddsButton = Button.new({
		name = "Odds",
		text = "Odds",
		style = "ghost",
		size = UDim2.fromOffset(ODDS_W, rowH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, rollTop),
		textSize = Theme.sizes.textSmall + 1,
		parent = content,
		onClick = function()
			self._oddsSheet.Visible = true
		end,
	})
	local lineTop = rollTop + rowH + space
	local tokenTop = lineTop + wordsH + space
	-- short: the two lines share the token row's left side, what the player has on top and the token line under
	local half = math.floor(buttonH / 2)
	self._why = text({
		Name = "Why",
		Position = UDim2.fromOffset(0, if short then tokenTop else lineTop),
		Size = if short then UDim2.new(1, -(120 + GAP), 0, half) else UDim2.new(1, 0, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = if short then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextColor3 = PAL.text,
		Parent = content,
	})
	oddsLines(content, if short then lineTop else lineTop + 18, 1)
	-- the station's free tokens
	self._tokens = text({
		Name = "Tokens",
		Position = UDim2.fromOffset(0, if short then tokenTop + half else tokenTop),
		Size = UDim2.new(1, -(120 + GAP), 0, if short then buttonH - half else buttonH),
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = PAL.text,
		Parent = content,
	})
	self._collect = Button.new({
		name = "Collect",
		text = "Collect",
		style = "gold",
		size = UDim2.fromOffset(120, buttonH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, tokenTop),
		textSize = Theme.sizes.textSmall + 1,
		parent = content,
		onClick = function()
			self:_send(function()
				self._callbacks.collect()
			end)
		end,
	})

	-- the cat list behind Pick a cat (#3700, cat-picker.md). #3874 (Derek 2026-11-13: "make that just one small row on
	-- the top so I can see more cats", then "make it a search bar and a filter menu that they can pop up and close with
	-- an X. Make the default sort by money"): one row on top, a small search box, Filter and Back; Filter pops up the
	-- Sort and Show chips over the list with an X, and the list starts right under the row. The count is in the search
	-- box's hint
	local picker = sheet("Picker", content, 5)
	self._picker = picker
	local tools: Frame = Create("Frame", {
		Name = "Tools",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOOL_H),
		ZIndex = 6,
		Parent = picker,
	})
	self._back = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(BACK_W, TOOL_H),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -TOOL_PAD, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = tools,
		zIndex = 6,
		onClick = function()
			self:_showPicker(false)
		end,
	})
	self._filterButton = Button.new({
		name = "Filter",
		text = "Filter",
		style = "ghost",
		size = UDim2.fromOffset(FILTER_W, TOOL_H),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -(TOOL_PAD + BACK_W + TOOL_GAP), 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = tools,
		zIndex = 6,
		sound = "uiTab",
		onClick = function()
			self:_showMenu(not self._menu.Visible)
		end,
	})
	local searchRight = TOOL_PAD + BACK_W + TOOL_GAP + FILTER_W + TOOL_GAP
	local search: TextBox = Create("TextBox", {
		Name = "Search",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(1, 0),
		Size = UDim2.new(1, -(searchRight + 1), 0, TOOL_H),
		ClearTextOnFocus = false,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.text,
		PlaceholderColor3 = CARD.subtext,
		PlaceholderText = SEARCH_HINT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 6,
		Parent = tools,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) }),
	})
	Outline.border(search, Theme.sizes.stroke, CARD.cardStroke)
	self._search = search
	self._searchChanged = search:GetPropertyChangedSignal("Text"):Connect(function()
		self._query = search.Text
		self._searchToken += 1
		local token = self._searchToken
		task.delay(SEARCH_WAIT, function()
			if self._searchToken == token then
				self:_applyFilter()
			end
		end)
	end)
	local listTop = TOOL_H + 6

	-- the Filter pop-up: Sort (Money, Level, Rarity) with the X at the right, then Show on two rows; a chip works at
	-- once and the pop-up stays until the X or Filter
	local menuRows = 3
	local menuH = menuRows * TOOL_H + (menuRows - 1) * MENU_GAP + MENU_PAD * 2
	local menu: Frame = Create("Frame", {
		Name = "FilterMenu",
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 0, menuH),
		Active = true, -- taps on it never reach the rows under it
		Visible = false,
		ZIndex = 20,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIStroke", { Color = PAL.caramel, Thickness = 2 }),
	})
	self._menu = menu
	local function menuWord(words: string, row: number)
		text({
			Name = words .. "Word",
			Position = UDim2.fromOffset(MENU_PAD, MENU_PAD + (row - 1) * (TOOL_H + MENU_GAP)),
			Size = UDim2.fromOffset(MENU_WORD_W, TOOL_H),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if words == "" then "" else words,
			ZIndex = 21,
			Parent = menu,
		})
	end
	local function chip(
		name: string,
		words: string,
		row: number,
		x: number,
		width: number,
		onClick: () -> ()
	): Button.Button
		return Button.new({
			name = name,
			text = words,
			style = "ghost",
			size = UDim2.fromOffset(width, TOOL_H),
			position = UDim2.fromOffset(x, MENU_PAD + (row - 1) * (TOOL_H + MENU_GAP)),
			textSize = Theme.sizes.textSmall,
			parent = menu,
			zIndex = 21,
			sound = "uiTab",
			onClick = onClick,
		})
	end
	menuWord("Sort", 1)
	self._sorts = {} :: { [string]: Button.Button }
	local x = MENU_PAD + MENU_WORD_W
	for _, sort in CatPickLogic.MENU_SORTS do
		self._sorts[sort] = chip("Sort" .. sort, sort, 1, x, SORT_W, function()
			self:_setSort(sort)
		end)
		x += SORT_W + TOOL_GAP
	end
	self._menuClose = Button.new({
		name = "Close",
		text = "X",
		style = "danger",
		size = UDim2.fromOffset(TOOL_H, TOOL_H),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -MENU_PAD, 0, MENU_PAD),
		textSize = Theme.sizes.textBody,
		parent = menu,
		zIndex = 21,
		onClick = function()
			self:_showMenu(false)
		end,
	})
	menuWord("Show", 2)
	self._chips = {} :: { [string]: Button.Button }
	local row, at = 2, MENU_PAD + MENU_WORD_W
	for index, filter in CatPickLogic.MENU_FILTERS do
		if index == 4 then
			row, at = 3, MENU_PAD + MENU_WORD_W
		end
		local width = if #filter > 7 then WIDE_CHIP_W else CHIP_W
		self._chips[filter] = chip(
			(string.gsub(filter, " ", "")),
			filter,
			row,
			at,
			width,
			function()
				self:_setFilter(filter)
			end
		)
		at += width + TOOL_GAP
	end
	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 1, -listTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
		Parent = picker,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
	self._scrolled = (self._list :: ScrollingFrame)
		:GetPropertyChangedSignal("CanvasPosition")
		:Connect(function()
			self:_queueFaces()
		end)
	self._empty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, listTop + 20),
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		TextColor3 = PAL.subtext,
		Text = "",
		Visible = false,
		ZIndex = 6,
		Parent = picker,
	})

	-- #3874: the Filter pop-up goes in after the list, so it draws over the rows
	menu.Parent = picker

	-- a re-roll's choice: the old trait and the new one side by side
	local choice = sheet("Choice", content, 8)
	self._choice = choice
	self._choiceTitle = text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		ZIndex = 9,
		TextColor3 = PAL.text,
		Parent = choice,
	})
	local cardH = TILE_H
	self._old =
		traitCard("Old", choice, UDim2.fromOffset(0, 30), UDim2.new(0.5, -GAP / 2, 0, cardH), 9)
	self._new = traitCard(
		"New",
		choice,
		UDim2.new(0.5, GAP / 2, 0, 30),
		UDim2.new(0.5, -GAP / 2, 0, cardH),
		9
	)
	local function choose(takeNew: boolean): () -> ()
		return function()
			self:_send(function()
				self._callbacks.choose(takeNew)
			end)
		end
	end
	-- #3875: a tap on a grey Keep old or Take new once the wait is RETRY_SECONDS old sends the choice again (the
	-- server ignores a choice with nothing waiting)
	local function retry(takeNew: boolean): () -> ()
		return function()
			if self._pending and os.clock() - (self._pendingAt or 0) >= RETRY_SECONDS then
				self._pending = false
				self._pendingToken += 1
				choose(takeNew)()
			end
		end
	end
	-- the same style on both, so neither answer is pushed (spec section 1a, a young audience)
	self._keepOld = Button.new({
		name = "KeepOld",
		text = MysticPoolLogic.KEEP_OLD,
		style = "primary",
		size = UDim2.new(0.5, -GAP / 2, 0, buttonH + 4),
		position = UDim2.fromOffset(0, 30 + cardH + GAP),
		textSize = Theme.sizes.textBody,
		parent = choice,
		zIndex = 9,
		onClick = choose(false),
		onLocked = retry(false),
	})
	self._takeNew = Button.new({
		name = "TakeNew",
		text = MysticPoolLogic.TAKE_NEW,
		style = "primary",
		size = UDim2.new(0.5, -GAP / 2, 0, buttonH + 4),
		position = UDim2.new(0.5, GAP / 2, 0, 30 + cardH + GAP),
		textSize = Theme.sizes.textBody,
		parent = choice,
		zIndex = 9,
		onClick = choose(true),
		onLocked = retry(true),
	})
	oddsLines(choice, 30 + cardH + GAP + buttonH + 4 + 6, 9)

	-- the Odds list
	local odds = sheet("OddsList", content, 11)
	self._oddsSheet = odds
	text({
		Name = "Title",
		Size = UDim2.new(1, -110, 0, 32),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Trait odds for every roll",
		ZIndex = 12,
		TextColor3 = PAL.text,
		Parent = odds,
	})
	self._oddsBack = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(96, buttonH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = odds,
		zIndex = 12,
		onClick = function()
			odds.Visible = false
		end,
	})
	local rows = MysticPoolLogic.odds()
	for index, row in rows do
		local top = buttonH + 8 + (index - 1) * 30
		local line: Frame = Create("Frame", {
			Name = row.name,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = 12,
			Parent = odds,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			Create("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromHex(row.color),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				ZIndex = 13,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		})
		text({
			Name = "Name",
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -110, 1, 0),
			FontFace = Theme.fonts.bodyBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = row.name,
			ZIndex = 13,
			Parent = line,
		})
		text({
			Name = "Percent",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0, 70, 1, 0),
			FontFace = Theme.fonts.bodyBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = string.format("%d%%", row.percent),
			ZIndex = 13,
			Parent = line,
		})
	end
	text({
		Name = "Equal",
		Position = UDim2.fromOffset(0, buttonH + 8 + #rows * 30 + 4),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = MysticPoolLogic.EQUAL_LINE .. " Rolls cost golden fish or Trait Tokens.",
		ZIndex = 12,
		Parent = odds,
	})

	-- #3864: the Trait Token offer, once the free rolls are used (MysticPoolLogic.bundles)
	local offer = sheet("TokenOffer", content, 11)
	self._offerSheet = offer
	text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = MysticPoolLogic.OFFER_TITLE,
		ZIndex = 12,
		TextColor3 = PAL.text,
		Parent = offer,
	})
	text({
		Name = "Line",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = MysticPoolLogic.OFFER_LINE,
		ZIndex = 12,
		TextColor3 = PAL.text,
		Parent = offer,
	})
	oddsLines(offer, 30 + 34 + 2, 12) -- every roll's odds, before anything is bought (monetization-policy 2.1)
	local buyTop = 30 + 34 + 2 + 28 + GAP
	self._offerButtons = {} :: { Button.Button }
	for index = 1, #Traits.BUNDLES do
		local button = Button.new({
			name = "Bundle" .. index,
			text = "",
			style = "primary",
			size = UDim2.new(1 / #Traits.BUNDLES, -GAP / 2, 0, buttonH + 4),
			position = UDim2.new(
				(index - 1) / #Traits.BUNDLES,
				if index > 1 then GAP / 2 else 0,
				0,
				buyTop
			),
			textSize = Theme.sizes.textBody,
			parent = offer,
			zIndex = 12,
			onClick = function()
				local pick = self._offerBundles and self._offerBundles[index]
				local buy = callbacks.buy
				if pick ~= nil and buy ~= nil then
					buy(pick.id)
				end
			end,
		})
		table.insert(self._offerButtons, button)
	end
	self._offerBundles = nil :: { MysticPoolLogic.Bundle }?
	Button.new({
		name = "NoThanks",
		text = MysticPoolLogic.OFFER_NO,
		style = "ghost",
		size = UDim2.new(1, 0, 0, buttonH),
		position = UDim2.fromOffset(0, buyTop + buttonH + 4 + GAP),
		textSize = Theme.sizes.textSmall + 1,
		parent = offer,
		zIndex = 12,
		onClick = function()
			offer.Visible = false
		end,
	})

	-- while the pool's animation plays: a tap anywhere on the card skips to the result
	local rolling = sheet("Rolling", content, 14)
	self._rollingSheet = rolling
	text({
		Name = "Words",
		Position = UDim2.fromScale(0, 0.3),
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Text = "Sage Sorrel stirs the pool...",
		ZIndex = 15,
		TextColor3 = PAL.text,
		Parent = rolling,
	})
	text({
		Name = "Hint",
		Position = UDim2.new(0, 0, 0.3, 36),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = "Tap to skip",
		ZIndex = 15,
		Parent = rolling,
	})
	local skip: TextButton = Create("TextButton", {
		Name = "Skip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 16,
		Parent = rolling,
	})
	self._skipPressed = skip.Activated:Connect(function()
		local run: (() -> ())? = self._skip
		if run then
			run()
		end
	end)
	return self :: MysticPool
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

function MysticPool._cat(self: any): any
	local uid = self._uid
	return if uid ~= nil then self._cats[uid] else nil
end

function MysticPool._stampNow(self: any): string
	local cat = self:_cat()
	return MysticPoolLogic.stamp(self._view, self._fish, if cat ~= nil then cat.trait else nil)
end

-- Every press goes out once: the buttons rest until the state shows the server's answer (render), or
-- PENDING_SECONDS (a refusal changes nothing; its toast says why).
function MysticPool._send(self: any, fire: () -> ())
	if self._pending then
		return
	end
	self._pending = true
	self._pendingAt = os.clock()
	self._stamp = self:_stampNow()
	self._pendingToken += 1
	local token = self._pendingToken
	task.delay(PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending then
			self._pending = false
			self._rolling = nil
			self:_paint()
		end
	end)
	self:_paint()
	fire()
end

function MysticPool._rollPress(self: any)
	local cat = self:_cat()
	local uid = self._uid
	if cat == nil or uid == nil or self._pending then
		return
	end
	local roll = MysticPoolLogic.roll(self._view, cat.trait ~= nil, self._fish)
	if not roll.enabled then
		return
	end
	self._rolling = { uid = uid, hadTrait = cat.trait ~= nil }
	self:_send(function()
		self._callbacks.roll(uid)
	end)
end

-- The roll's answer has come: the pool plays it (a tap skips), then the card shows it. #3702: while it plays the
-- card is tucked away behind a soft shade at the screen's edges (callbacks.shade), so the pool is in full view, and
-- it pops back with the result when the animation ends or is skipped. Without the callback the card stays up
-- under its "stirs the pool" sheet, as before.
function MysticPool._reveal(self: any, uid: string, traitId: string)
	local play = (self._callbacks :: Callbacks).play
	if play == nil or not self._open then
		return
	end
	self._playToken += 1
	local token = self._playToken
	local done = false
	local lift: (() -> ())? = nil
	local function finish()
		if done then
			return
		end
		done = true
		local back: (() -> ())? = lift
		lift = nil
		if back then
			(back :: () -> ())()
		end
		if self._playToken == token then
			self._skip = nil
			self._lift = nil
			self._rollingSheet.Visible = false
		end
	end
	local skip = play(uid, MysticPoolLogic.rarityId(traitId), finish)
	if done or skip == nil then
		finish()
		return
	end
	local function skipNow()
		skip()
		finish()
	end
	self._skip = skipNow
	local shade = (self._callbacks :: Callbacks).shade
	if shade ~= nil then
		lift = shade(skipNow)
		self._lift = finish
	else
		self._rollingSheet.Visible = true
	end
end

function MysticPool._stopPlay(self: any)
	self._playToken += 1
	local skip: (() -> ())? = self._skip
	local lift: (() -> ())? = self._lift
	self._skip = nil
	self._lift = nil
	self._rollingSheet.Visible = false
	if skip then
		skip()
	end
	if lift then
		lift() -- the shade never outlives the card (closed, destroyed)
	end
end

function MysticPool._clearRows(self: any)
	self._buildToken += 1
	for _, entry: Row in self._rows do
		if entry.portrait then
			entry.portrait:destroy()
		end
		entry.button:destroy()
		entry.frame:Destroy()
	end
	table.clear(self._rows)
	self._rowsKey = nil
end

-- #3700: while the cat list shows the card grows to the room the screen has (at most PICKER_TALL), so about six rows
-- fit on a desktop; back on the card it is its own short height again.
function MysticPool._fit(self: any, tall: boolean)
	local frame: Frame = self.frame
	local limit: UISizeConstraint = self._limit
	local height: number = self._height
	if tall then
		local holder = frame.Parent
		local scale = Scale.get()
		if holder ~= nil and holder:IsA("GuiBase2d") and scale > 0 then
			local room = holder.AbsoluteSize.Y / scale - SCREEN_ROOM * 2
			height = math.clamp(room, height, PICKER_TALL)
		end
	end
	limit.MaxSize = Vector2.new(MAX_WIDTH, height)
	frame.Size = UDim2.new(1, 0, 0, height)
end

-- The cat list, or back to the card (false), which frees every row and face.
function MysticPool._showPicker(self: any, show: boolean)
	self._picking = show
	self._picker.Visible = show
	self:_fit(show)
	if not show then
		self:_showMenu(false)
		self:_clearRows()
		return
	end
	self._search.Text = ""
	self._query = ""
	self._searchToken += 1
	self._sort = CatPickLogic.menuSort(self._sort)
	self:_showMenu(false)
	self:_setFilter("All", true)
	self:_paintSorts()
	self:_buildRows()
end

-- #3874: the Filter pop-up opens over the list and closes with its X or Filter.
function MysticPool._showMenu(self: any, show: boolean)
	self._menu.Visible = show
	self:_paintFilterButton()
end

-- Filter is gold while its pop-up is open or a Show chip other than All is on, so a hidden filter is never a mystery.
function MysticPool._paintFilterButton(self: any)
	local on = self._menu.Visible or self._filter ~= "All"
	local words = if self._filter ~= "All" then "Filter •" else "Filter"
	local button: Button.Button = self._filterButton
	button:setStyle(if on then "gold" else "ghost")
	if self._filterWords ~= words then
		self._filterWords = words
		button:setText(words)
	end
end

function MysticPool._setFilter(self: any, filter: string, quiet: boolean?)
	self._filter = filter
	for name, chip: Button.Button in self._chips do
		chip:setStyle(if name == filter then "gold" else "ghost")
	end
	self:_paintFilterButton()
	if not quiet then
		self:_applyFilter()
	end
end

-- The Sort chips: the one in use is gold and shows which way it runs.
function MysticPool._paintSorts(self: any)
	for name, chip: Button.Button in self._sorts do
		local on = name == self._sort
		chip:setStyle(if on then "gold" else "ghost")
		chip:setText(if on then name .. (if self._flipped then " ▲" else " ▼") else name)
	end
end

-- A press on a Sort chip: another order, or the same one turned round.
function MysticPool._setSort(self: any, sort: string)
	if sort == self._sort then
		self._flipped = not self._flipped
	else
		self._sort = sort
		self._flipped = false
	end
	remembered.sort = self._sort
	remembered.flipped = self._flipped
	self:_paintSorts()
	self:_buildRows()
end

function MysticPool._row(self: any, order: number, cat: any): Row
	local short: boolean = self._short
	local face = if short then SHORT_FACE else FACE
	local pickW = if short then SHORT_PICK_W else 100
	local rarityName = CatPickLogic.rarity(cat)
	local rarity = Theme.rarityColor(rarityName)
	local frame: Frame = Create("Frame", {
		Name = cat.uid,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(
			1,
			0,
			0,
			if short then SHORT_ROW_H else math.max(ROW_H, self._buttonH + 8)
		),
		ZIndex = 6,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		-- the rarity's colour down the left edge
		Create("Frame", {
			Name = "Edge",
			BackgroundColor3 = rarity,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 6, 1, 0),
			ZIndex = 7,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 3) }) }),
	})
	local disc: Frame = Create("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(face, face),
		ZIndex = 7,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = rarity, Thickness = 3 }),
	})
	local left = 14 + face + (if short then 8 else 10)
	local right = pickW + 14 -- the Pick button and the space before it
	-- short (#3874): the name takes the top line's left part and the trait its right part, the tags go under
	local nameW = if short
		then UDim2.new(0.55, -math.floor((left + right) * 0.55), 0, 20)
		else UDim2.new(1, -(left + right), 0, 20)
	text({
		Name = "Name",
		Position = UDim2.fromOffset(left, if short then 3 else 4),
		Size = nameW,
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = CatPickLogic.title(cat),
		ZIndex = 7,
		Parent = frame,
	})
	-- the rarity's word on its colour (colour is never the only sign), the coat, then level, job and pay
	local facts: Frame = Create("Frame", {
		Name = "Facts",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(left, if short then 26 else 25),
		Size = UDim2.new(1, -(left + right), 0, 18),
		ZIndex = 7,
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local function tag(name: string, words: string, fill: Color3, ink: Color3, place: number)
		Create("TextLabel", {
			Name = name,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			FontFace = Theme.fonts.bodyBold,
			LayoutOrder = place,
			Size = UDim2.new(0, 0, 1, 0),
			Text = words,
			TextColor3 = ink,
			TextSize = Theme.sizes.textTiny,
			ZIndex = 7,
			Parent = facts,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		})
	end
	tag("Rarity", rarityName, rarity, Theme.rarityTextColor(rarityName), 1)
	local coat = CatPickLogic.coatTag(cat)
	if coat ~= nil then
		tag("Coat", coat, Theme.colors.gold, Theme.colors.ink, 2)
	end
	Create("TextLabel", {
		Name = "Line",
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		LayoutOrder = 3,
		Size = UDim2.new(0, 0, 1, 0),
		Text = CatPickLogic.line(cat, Format.rate(tonumber(cat.rating) or 0)),
		TextColor3 = CARD.text, -- on the row's card (cream in the family look: white did not read there)
		TextSize = Theme.sizes.textSmall,
		ZIndex = 7,
		Parent = facts,
	})
	-- its trait in the rarity's colour, so the list shows which cats still have none
	-- #3950: a trait shows as a bold pill of its rarity's colour; none is grey words
	local trait = MysticPoolLogic.card(cat.trait)
	local traitColor = Color3.fromHex(trait.color)
	local traitRow: Frame = Create("Frame", {
		Name = "TraitRow",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = if short
			then UDim2.new(0.55, left - math.floor((left + right) * 0.55) + 10, 0, 4) -- 4 px clear of "Lv 22"
			else UDim2.fromOffset(left, 45),
		Size = if short
			then UDim2.new(0.45, -(math.ceil((left + right) * 0.45) + 10), 0, 18)
			else UDim2.new(1, -(left + right), 0, 18),
		ZIndex = 7,
		Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if short
				then Enum.HorizontalAlignment.Right
				else Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if trait.has then
		text({
			Name = "Trait",
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = traitColor,
			Size = UDim2.new(0, 0, 1, 0),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = inkOn(traitColor),
			TextTruncate = Enum.TextTruncate.None,
			Text = if short then trait.name else "Trait: " .. trait.name,
			ZIndex = 7,
			Parent = traitRow,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		})
	else
		text({
			Name = "Trait",
			Size = UDim2.fromScale(1, 1),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = CARD.subtext,
			TextXAlignment = if short then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
			Text = trait.name,
			ZIndex = 7,
			Parent = traitRow,
		})
	end
	local uid = cat.uid
	local button = Button.new({
		name = "Pick",
		text = "Pick",
		style = "primary",
		size = UDim2.fromOffset(pickW, if short then SHORT_PICK_H else self._buttonH),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0.5, 0),
		textSize = Theme.sizes.textSmall + 1,
		parent = frame,
		zIndex = 7,
		onClick = function()
			self:_showPicker(false)
			self:pick(uid)
		end,
	})
	return { frame = frame, disc = disc, button = button, cat = cat, portrait = nil, loaded = false }
end

-- The first FIRST_ROWS at once, the rest ROWS_PER_FRAME a frame, so the list never stalls on a big collection.
function MysticPool._buildRows(self: any)
	self:_clearRows()
	local token = self._buildToken
	local cats = CatPickLogic.sorted(self._cats, self._sort, self._flipped)
	self._rowsKey = MysticPoolLogic.key(cats)
	self._candidates = #cats
	local function build(from: number, to: number)
		for order = from, to do
			local row = self:_row(order, cats[order])
			row.frame.Visible = CatPickLogic.match(row.cat, self._query, self._filter)
			table.insert(self._rows, row)
		end
	end
	build(1, math.min(#cats, FIRST_ROWS))
	self:_applyFilter()
	if #cats > FIRST_ROWS then
		task.spawn(function()
			local at = FIRST_ROWS
			while at < #cats do
				task.wait()
				if self._buildToken ~= token then
					return
				end
				build(at + 1, math.min(#cats, at + ROWS_PER_FRAME))
				at += ROWS_PER_FRAME
			end
			self:_applyFilter()
		end)
	end
end

-- The search and the chips only show and hide the rows that are there.
function MysticPool._applyFilter(self: any)
	local shown = 0
	for _, row: Row in self._rows do
		local visible = CatPickLogic.match(row.cat, self._query, self._filter)
		if row.frame.Visible ~= visible then
			row.frame.Visible = visible
		end
		if visible then
			shown += 1
		end
	end
	local none = self._candidates == 0
	local built = #self._rows >= self._candidates
	self._empty.Text = if none
		then "You have no cats yet. Catch one first."
		else "No cat matches. Try another name, or Filter: All."
	self._empty.Visible = none or (shown == 0 and built)
	-- #3874: the count sits in the search box's hint ("🔍 Search 42 cats")
	local search: TextBox = self._search
	search.PlaceholderText = if none or not built
		then SEARCH_HINT
		else SEARCH_HINT .. " " .. CatPickLogic.count(shown)
	self:_queueFaces()
end

function MysticPool._queueFaces(self: any)
	if self._facesQueued then
		return
	end
	self._facesQueued = true
	task.delay(0, function()
		self._facesQueued = false
		self:_loadFaces()
	end)
end

-- A row gets its face once it is within FACE_MARGIN of the visible part of the list, at most FACES_PER_PASS a look,
-- and loses it again past FACE_KEEP (as the Oasis Spa's list, #3136).
function MysticPool._loadFaces(self: any)
	local list: ScrollingFrame = self._list
	if not self._picking or not list:IsDescendantOf(game) then
		return
	end
	local top = list.AbsolutePosition.Y - FACE_MARGIN
	local bottom = list.AbsolutePosition.Y + list.AbsoluteSize.Y + FACE_MARGIN
	local made = 0
	for _, row: Row in self._rows do
		local y = row.frame.AbsolutePosition.Y
		local height = row.frame.AbsoluteSize.Y
		if row.loaded then
			local far = y + height < top - (FACE_KEEP - FACE_MARGIN)
				or y > bottom + (FACE_KEEP - FACE_MARGIN)
			if not row.frame.Visible or far then
				if row.portrait then
					row.portrait:destroy()
					row.portrait = nil
				end
				row.loaded = false
			end
			continue
		end
		if not row.frame.Visible or y + height < top or y > bottom then
			continue
		end
		if made >= FACES_PER_PASS then
			self:_queueFaces()
			return
		end
		made += 1
		local portrait = CatPortrait.new({
			parent = row.disc,
			size = UDim2.fromScale(1, 1),
			still = true,
			head = true,
			zIndex = 8,
		})
		portrait:set(Catalog.getCat(row.cat.catId), CatVariant.isGold(row.cat.variant))
		row.portrait = portrait
		row.loaded = true
	end
end

function MysticPool._syncRows(self: any)
	if not self._picking then
		return
	end
	local cats = CatPickLogic.sorted(self._cats, self._sort, self._flipped)
	if MysticPoolLogic.key(cats) ~= self._rowsKey then
		self:_buildRows()
	end
end

function MysticPool._paint(self: any)
	-- #3875 (Derek 2026-11-13: "sometimes the buttons for traits get stuck on gray"): a wait older than
	-- PENDING_SECONDS ends here too, by the clock, so a missed timer or a slow answer never leaves them grey
	if self._pending and os.clock() - (self._pendingAt or 0) > PENDING_SECONDS then
		self._pending = false
		self._pendingToken += 1
		self._rolling = nil
	end
	local view = self._view
	local cat = self:_cat()
	local resting: boolean = self._pending

	-- the picked cat
	self._portrait.frame.Visible = cat ~= nil
	self._glyph.Visible = cat == nil
	if cat ~= nil then
		local key = tostring(cat.catId) .. ":" .. tostring(cat.variant)
		if self._portraitKey ~= key then
			self._portraitKey = key
			self._portrait:set(Catalog.getCat(cat.catId), CatVariant.isGold(cat.variant))
		end
		self._catName.Text = LateStationsLogic.spaTitle(cat)
		local job = " · Resting"
		if cat.spotId ~= nil then
			job = " · Working"
		end
		self._catLine.Text = "Lv " .. tostring(tonumber(cat.level) or 1) .. job
	else
		self._catName.Text = "No cat picked"
		self._catLine.Text = ""
	end
	local changeText = if cat ~= nil then "Change cat" else "Pick a cat"
	if self._changeText ~= changeText then
		self._changeText = changeText
		self._change:setText(changeText)
		self._change:setStyle(if cat ~= nil then "ghost" else "primary")
	end
	self._change:setEnabled(not resting)
	fill(
		self._trait,
		MysticPoolLogic.card(if cat ~= nil then cat.trait else nil),
		nil,
		if cat ~= nil then "Roll to give this cat a trait" else "Pick a cat to see its trait"
	)

	-- Roll
	local roll = MysticPoolLogic.roll(view, cat ~= nil and cat.trait ~= nil, self._fish)
	local rollText = if resting then "..." else roll.text
	if self._rollText ~= rollText then
		self._rollText = rollText
		self._roll:setText(rollText)
	end
	self._roll:setEnabled(roll.enabled and cat ~= nil and not resting)
	local why = if not roll.enabled then roll.why else nil
	self._why.Text = why or MysticPoolLogic.haveLine(view, self._fish)
	self._why.TextColor3 = if why ~= nil then PAL.warn else PAL.text

	-- the free tokens
	local line, ready = MysticPoolLogic.tokens(view, now())
	self._tokens.Text = line
	self._tokens.TextColor3 = if ready then PAL.good else PAL.subtext
	self._collect:setEnabled(ready and not resting)

	-- a waiting re-roll takes the card until it is answered
	local waiting = MysticPoolLogic.pending(view, self._cats)
	self._choice.Visible = waiting ~= nil
	if waiting ~= nil then
		local theirs = self._cats[waiting.uid]
		self._choiceTitle.Text = if theirs ~= nil
			then "A new trait for " .. LateStationsLogic.spaTitle(theirs)
			else "A new trait"
		fill(self._old, waiting.old, "Now")
		fill(self._new, waiting.new, "New")
		self._keepOld:setEnabled(not resting)
		self._takeNew:setEnabled(not resting)
	end

	-- #3864: the token offer, once a session, when the card is at rest with the free rolls used
	if not resting and self._callbacks.buy ~= nil and self._open then
		local bundles = MysticPoolLogic.bundles(view, Config.ProductIds, remembered.offered)
		if bundles ~= nil then
			remembered.offered = true
			self._offerBundles = bundles
			for index, button in self._offerButtons do
				local pick = bundles[index]
				button.instance.Visible = pick ~= nil
				if pick ~= nil then
					button:setText(pick.label)
				end
			end
			self._offerSheet.Visible = true
		end
	end
end

-- The cat the card shows (nil for none); one that is gone is dropped.
function MysticPool.pick(self: any, uid: string?)
	self._uid = if uid ~= nil and self._cats[uid] ~= nil then uid else nil
	self:_paint()
end

function MysticPool.render(self: any, state: Types.PlayerState)
	local view: any = (state :: any).traits
	self._view = if type(view) == "table" then view else nil
	self._fish = state.goldenFish or 0
	self._cats = (state.cats or {}) :: any
	local uid = self._uid
	if uid ~= nil and self._cats[uid] == nil then
		self._uid = nil -- sold or traded away
	end
	-- the server's answer to the last press wakes the buttons; a roll's answer plays first
	if self._pending and self:_stampNow() ~= self._stamp then
		self._pending = false
		self._pendingToken += 1
		local rolling = self._rolling
		self._rolling = nil
		if rolling ~= nil then
			local cat = self._cats[rolling.uid]
			local rolled = MysticPoolLogic.rolled(
				self._view,
				rolling.uid,
				rolling.hadTrait,
				if cat ~= nil then cat.trait else nil
			)
			if rolled ~= nil then
				self:_reveal(rolling.uid, rolled)
			end
		end
	end
	self:_paint()
	self:_syncRows()
end

-- While open the token line moves on once a second, and walking away closes the card. A re-roll left waiting
-- (a rejoin, a closed card) shows its cat.
function MysticPool.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_showPicker(false)
	self._oddsSheet.Visible = false
	self._offerSheet.Visible = false
	local waiting = MysticPoolLogic.pending(self._view, self._cats)
	if waiting ~= nil and self._cats[waiting.uid] ~= nil then
		self._uid = waiting.uid
	end
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
				-- #3875: protected, so one bad repaint never stops the ticks that wake the buttons
				local ok, problem = pcall(self._paint, self)
				if not ok then
					warn("MysticPool paint: " .. tostring(problem))
				end
			end
		end
	end)
end

function MysticPool.closed(self: any)
	self._open = false
	self._tick += 1
	self:_stopPlay()
	self:_showPicker(false)
	self._oddsSheet.Visible = false
	self._offerSheet.Visible = false
end

function MysticPool.destroy(self: any)
	self._open = false
	self._tick += 1
	self._pendingToken += 1
	self:_stopPlay()
	self:_clearRows()
	self._searchChanged:Disconnect()
	self._scrolled:Disconnect()
	self._skipPressed:Disconnect()
	for _, chip: Button.Button in self._sorts do
		chip:destroy()
	end
	for _, chip: Button.Button in self._chips do
		chip:destroy()
	end
	self._filterButton:destroy()
	self._menuClose:destroy()
	self._portrait:destroy()
	self._change:destroy()
	self._roll:destroy()
	self._oddsButton:destroy()
	self._collect:destroy()
	self._back:destroy()
	self._keepOld:destroy()
	self._takeNew:destroy()
	self._oddsBack:destroy()
	self._panel:destroy()
end

return MysticPool
