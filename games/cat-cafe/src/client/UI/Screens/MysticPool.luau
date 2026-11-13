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
-- result. The server decides every roll and payment; this only asks. Nothing here is sold for Robux. Words in
-- Components/MysticPoolLogic.

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
local PENDING_SECONDS = 4
local ROW_H = 68 -- #3700: three lines (name, rarity and level, trait)
local PICKER_TALL = 680 -- #3700: the card grows to at most this while the cat list shows, so about six rows fit
local SCREEN_ROOM = 16 -- px kept clear above and below the grown card
local SORT_W = 86
local TOOL_PAD = 5
local FACE = 44
local TOOL_H = Scale.tapHeight(Theme.sizes.touchMin)
local CHIP_W = 78
local WIDE_CHIP_W = 96 -- "No trait", "Has trait"
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
local remembered = { sort = CatPickLogic.DEFAULT_SORT, flipped = false }

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
	local rarity = text({
		Name = "Rarity",
		Position = UDim2.fromOffset(8, 27),
		Size = UDim2.new(1, -16, 0, 15),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny,
		ZIndex = z + 1,
		Parent = frame,
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
	card.name.TextColor3 = if trait.has then MenuFamily.onCard(color) else CARD.subtext
	local rarity = if trait.has then trait.rarity else none or ""
	card.rarity.Text = if head ~= nil and rarity ~= ""
		then head .. " · " .. rarity
		else head or rarity
	card.rarity.TextColor3 = if trait.has then MenuFamily.onCard(color) else CARD.subtext
	for index, label in card.lines do
		label.Text = trait.lines[index] or ""
	end
	local stroke = card.frame:FindFirstChildWhichIsA("UIStroke") :: UIStroke?
	if stroke then
		stroke.Color = if trait.has then color else CARD.cardStroke
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
	local contentH = TILE_H + GAP + (buttonH + 4) + 4 + WORDS_H + 4 + buttonH
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
		size = UDim2.fromOffset(TILE_W, buttonH + 4),
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
		size = UDim2.new(1, -(TILE_W + ODDS_W + GAP * 2), 0, buttonH + 4),
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
		size = UDim2.fromOffset(ODDS_W, buttonH + 4),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, rollTop),
		textSize = Theme.sizes.textSmall + 1,
		parent = content,
		onClick = function()
			self._oddsSheet.Visible = true
		end,
	})
	local lineTop = rollTop + buttonH + 4 + 4
	self._why = text({
		Name = "Why",
		Position = UDim2.fromOffset(0, lineTop),
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.text,
		Parent = content,
	})
	oddsLines(content, lineTop + 18, 1)
	-- the station's free tokens
	local tokenTop = lineTop + WORDS_H + 4
	self._tokens = text({
		Name = "Tokens",
		Position = UDim2.fromOffset(0, tokenTop),
		Size = UDim2.new(1, -(120 + GAP), 0, buttonH),
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

	-- the cat list behind Pick a cat (#3700, cat-picker.md): the search and Back on one row, then one row of chips
	-- that scrolls sideways (Sort, then Show, then how many cats show), then the list
	local picker = sheet("Picker", content, 5)
	self._picker = picker
	self._back = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(96, TOOL_H),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = picker,
		zIndex = 6,
		onClick = function()
			self:_showPicker(false)
		end,
	})
	local search: TextBox = Create("TextBox", {
		Name = "Search",
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(1, 0),
		Size = UDim2.new(1, -(96 + 8), 0, TOOL_H),
		ClearTextOnFocus = false,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = CARD.text,
		PlaceholderColor3 = CARD.subtext,
		PlaceholderText = "🔍 Pick a cat for a trait",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 6,
		Parent = picker,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
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
	local toolTop = TOOL_H + 4
	local tools: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Tools",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, toolTop),
		Size = UDim2.new(1, 0, 0, TOOL_H + TOOL_PAD * 2 + 4),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 6,
		Parent = picker,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- room for the chips' outlines inside the row's own edge
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, TOOL_PAD),
			PaddingRight = UDim.new(0, TOOL_PAD),
			PaddingTop = UDim.new(0, TOOL_PAD),
		}),
	})
	local order = 0
	local function word(name: string, words: string, width: number): TextLabel
		order += 1
		return text({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(width, TOOL_H),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			Text = words,
			ZIndex = 6,
			Parent = tools,
		})
	end
	word("SortWord", "Sort", 34)
	self._sorts = {} :: { [string]: Button.Button }
	for _, sort in CatPickLogic.SORTS do
		order += 1
		self._sorts[sort] = Button.new({
			name = "Sort" .. sort,
			text = sort,
			style = "ghost",
			size = UDim2.fromOffset(SORT_W, TOOL_H),
			layoutOrder = order,
			textSize = Theme.sizes.textSmall,
			parent = tools,
			zIndex = 6,
			sound = "uiTab",
			onClick = function()
				self:_setSort(sort)
			end,
		})
	end
	word("ShowWord", "Show", 40)
	self._chips = {} :: { [string]: Button.Button }
	for _, filter in CatPickLogic.FILTERS do
		order += 1
		self._chips[filter] = Button.new({
			name = (string.gsub(filter, " ", "")),
			text = filter,
			style = if filter == "All" then "gold" else "ghost",
			size = UDim2.fromOffset(if #filter > 7 then WIDE_CHIP_W else CHIP_W, TOOL_H),
			layoutOrder = order,
			textSize = Theme.sizes.textSmall,
			parent = tools,
			zIndex = 6,
			sound = "uiTab",
			onClick = function()
				self:_setFilter(filter)
			end,
		})
	end
	self._count = word("Count", "", 96)
	local listTop = toolTop + TOOL_H + TOOL_PAD * 2 + 4 + 4
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
		Text = MysticPoolLogic.EQUAL_LINE
			.. " Rolls cost golden fish or Trait Tokens, never Robux.",
		ZIndex = 12,
		Parent = odds,
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
		self:_clearRows()
		return
	end
	self._search.Text = ""
	self._query = ""
	self._searchToken += 1
	self:_setFilter("All", true)
	self:_paintSorts()
	self:_buildRows()
end

function MysticPool._setFilter(self: any, filter: string, quiet: boolean?)
	self._filter = filter
	for name, chip: Button.Button in self._chips do
		chip:setStyle(if name == filter then "gold" else "ghost")
	end
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
	local rarityName = CatPickLogic.rarity(cat)
	local rarity = Theme.rarityColor(rarityName)
	local frame: Frame = Create("Frame", {
		Name = cat.uid,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, math.max(ROW_H, self._buttonH + 8)),
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
		Size = UDim2.fromOffset(FACE, FACE),
		ZIndex = 7,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = rarity, Thickness = 3 }),
	})
	local left = 14 + FACE + 10
	text({
		Name = "Name",
		Position = UDim2.fromOffset(left, 4),
		Size = UDim2.new(1, -(left + 114), 0, 20),
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
		Position = UDim2.fromOffset(left, 25),
		Size = UDim2.new(1, -(left + 114), 0, 18),
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
		TextColor3 = PAL.text,
		TextSize = Theme.sizes.textSmall,
		ZIndex = 7,
		Parent = facts,
	})
	-- its trait in the rarity's colour, so the list shows which cats still have none
	local trait = MysticPoolLogic.card(cat.trait)
	text({
		Name = "Trait",
		Position = UDim2.fromOffset(left, 45),
		Size = UDim2.new(1, -(left + 114), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = if trait.has
			then MenuFamily.onCard(Color3.fromHex(trait.color))
			else CARD.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if trait.has then "Trait: " .. trait.name else trait.name,
		ZIndex = 7,
		Parent = frame,
	})
	local uid = cat.uid
	local button = Button.new({
		name = "Pick",
		text = "Pick",
		style = "primary",
		size = UDim2.fromOffset(100, self._buttonH),
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
		else "No cat matches. Try another name or Show: All."
	self._empty.Visible = none or (shown == 0 and built)
	local count: TextLabel = self._count
	count.Text = if none or not built then "" else CatPickLogic.count(shown)
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
				self:_paint()
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
	for _, chip: Button.Button in self._chips do
		chip:destroy()
	end
	for _, chip: Button.Button in self._sorts do
		chip:destroy()
	end
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
