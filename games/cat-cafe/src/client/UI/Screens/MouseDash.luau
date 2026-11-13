--!strict
-- The Mouse Dash window (#3296, mouse-dash.md section 5; the rules are shared/MouseDash, the judging
-- MouseDashService's). With the `mouseDash` switch on it is the game the Cat Arcade's cabinet and Menu row open
-- (Derek 2026-11-11: "Swap this in for the current arcade game and vault the other one"). Two faces:
--   - the card: this player's best and titles, the last game's line, the arcade's ten prizes with today's ticks
--     (shared with Circle Streak), the leaderboard, the rule in plain words, Play with its cost ("Play (free)",
--     "Play (1 golden fish)"), a way to Circle Streak while that game is not vaulted (setOther) and the idea credit.
--   - the board, while a game runs: nine holes in a 3 x 3 grid, each a button of its own (never overlapping, 64 px
--     or more where the board allows), with the hearts, the score and the best in a strip kept clear of the holes
--     (Components/MouseDashLogic.layout; Derek 2026-11-11: the corner symbol was "too close to the possible spawn
--     and distracting"). Every animal is drawn centred in its hole and rises inside a clipping frame (Derek: "some
--     of the kittens/things look off centred also so make sure thats fixed for the game").
-- The UI only says which hole was tapped for which wave; the server stamps and judges it. What it sends back moves
-- the board: MouseDashWave puts animals up until their window ends, MouseDashJudged squashes a caught mouse, wakes a
-- tapped kitten or makes the paw dizzy, MouseDashGone takes down what got away, and the hearts and score are always
-- the server's numbers. Tap or click a hole; Q W E, A S D, Z X C on a keyboard; the gamepad's left stick points at a
-- hole (resting is the centre) and A bops it.
-- Stand-in faces (MouseDashLogic.FACES) until the picture sheet is uploaded. Motion-FX-Agent's Effects/MouseDashFx
-- plays over the holes when the build has it; nothing here needs it. Nothing is sold: no extra heart or continue.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local LeaderboardLogic = require(script.Parent.Parent.Components.LeaderboardLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local MouseDashLogic = require(script.Parent.Parent.Components.MouseDashLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("MouseDash"))

local PAL = MenuFamily.pal

local MAX_SIZE = Vector2.new(640, 720)
local ACTION_NAME = "CatCafeMouseDashKeys"
local RISE_SECONDS = 0.09 -- an animal's rise out of its hole
local PAW_SECONDS = 0.16 -- the paw's bop
local HIT_SECONDS = 0.22 -- a caught mouse shows its bopped picture this long
local FLOAT_SECONDS = 0.6 -- "+1" drifting up
local BANNER_SECONDS = 1.2
local OVER_SECONDS = 1.3 -- the board's last word before the card comes back
local GAP = Theme.sizes.gap
local CELLAR = Color3.fromHex("2A2140") -- the board: a dim cellar in the arcade's violet, so the animals stand out
local HOLE_COLOR = Color3.fromHex("3A2F57")
local PIT_COLOR = Color3.fromHex("15101F")
local HEART_FULL = "🐾" -- stand-ins, shown only until the picture sheet has loaded (IconArt does the same)
local PAW = "🐾"
local BACKDROP_SCALE = 1.1
local CLIP_HEIGHT = 0.9 -- of the pictures' frame: room above the hole for a risen animal
local RISE = 0.83 / CLIP_HEIGHT -- how far up its clip a risen animal sits (0.83 of the frame's width)
local HEART_COLOR = Color3.fromHex("FF8FB8")
local HEART_EMPTY = Color3.fromHex("5A4E78")
-- #3553, the cabinet look of Model-Agent's mock (Derek 2026-11-12: "that mock up is much better")
local INK = Color3.fromHex("2C1642")
local CREAM = Color3.fromHex("FFF6E5")
local MINT = Color3.fromHex("D6F0DC")
local TAG_PURPLE = Color3.fromHex("8E4FD0")
local GO_GREEN = Color3.fromHex("5CD678")
local BULB = Color3.fromHex("FFF078")
local SIGN_H = 58
local MENU_H = 112
local MASCOT = 104
local PRIZE_ROW_H = 56 -- a prize's row: its picture is 48 px (#3553: "at least 48 px on a phone")
local TOP_ROW_H = 36
local TWO_COLUMNS_FROM = 480 -- the prize list goes two wide on a card this wide
local POP = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

export type Callbacks = {
	play: () -> (),
	tap: (run: number, index: number, hole: number) -> (),
	quit: (run: number) -> (),
	close: () -> (),
	other: (() -> ())?, -- to Circle Streak's card
}

export type MouseDash = {
	frame: Frame,
	setState: (self: MouseDash, state: Rules.State) -> (),
	setFish: (self: MouseDash, fish: number) -> (),
	setOn: (self: MouseDash, on: boolean) -> (),
	setOther: (self: MouseDash, on: boolean) -> (),
	began: (self: MouseDash, run: number, hearts: number, firstAt: number, endsAt: number?) -> (),
	wave: (self: MouseDash, run: number, index: number, pops: { any }, hint: string?) -> (),
	judged: (
		self: MouseDash,
		run: number,
		index: number,
		tap: any,
		points: number,
		hearts: number,
		streak: number,
		milestones: { number },
		dizzyUntil: number
	) -> (),
	gone: (self: MouseDash, run: number, index: number, gone: { any }, hearts: number) -> (),
	over: (self: MouseDash, run: number, result: Rules.Result) -> (),
	playing: (self: MouseDash) -> boolean,
	onOpen: (self: MouseDash) -> (),
	onClose: (self: MouseDash) -> (),
	destroy: (self: MouseDash) -> (),
}

type Hole = {
	button: TextButton,
	pit: Frame, -- the stand-in pit, hidden once the pictures have loaded
	holeArt: ImageLabel,
	holeFront: ImageLabel,
	clip: Frame,
	animal: Frame,
	animalArt: ImageLabel,
	pawArt: ImageLabel,
	face: TextLabel,
	zzz: TextLabel,
	paw: TextLabel,
	ring: UIStroke,
	kind: string?, -- what is up, nil for an empty hole
	upAt: number,
	downAt: number,
}

local MouseDash = {}
MouseDash.__index = MouseDash

-- Motion-FX-Agent's effects, when the build has them (their PR may land before or after this one).
local Fx: any = nil
do
	local client: any = script.Parent.Parent.Parent
	local effects: Instance? = client:FindFirstChild("Effects")
	local found: Instance? = if effects ~= nil then effects:FindFirstChild("MouseDashFx") else nil
	if found ~= nil and found:IsA("ModuleScript") then
		local module: any = found
		local ok, loaded = pcall(function(): any
			return (require :: any)(module)
		end)
		if ok then
			Fx = loaded
		end
	end
end

local function fx(name: string, ...: any)
	local play = if Fx ~= nil then Fx[name] else nil
	if type(play) == "function" then
		pcall(play, ...)
	end
end

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextWrapped = true,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- One 256 px cell of the picture sheet (MouseDashLogic.CELLS).
local function setCell(label: ImageLabel, name: string)
	local cell = MouseDashLogic.CELLS[name]
	if cell ~= nil then
		label.ImageRectOffset = Vector2.new(cell[1], cell[2])
		label.ImageRectSize = Vector2.new(MouseDashLogic.CELL, MouseDashLogic.CELL)
	end
end

local function sheet(name: string, props: { [string]: any }): ImageLabel
	local label: ImageLabel = Create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = MouseDashLogic.SHEET,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
	})
	setCell(label, name)
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

-- A prize's picture (MouseDashLogic.prizePicture): the item's uploaded icon, or a glyph for a kind with none. Returns
-- the holder and a setter.
local function prizeArt(parent: Instance, name: string): (Frame, (prize: any) -> ())
	local holder: Frame =
		Create("Frame", { Name = name, BackgroundTransparency = 1, Parent = parent })
	local glyph = text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextWrapped = false,
		Parent = holder,
	})
	local image: ImageLabel = Create("ImageLabel", {
		Name = "Image",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	return holder,
		function(prize: any)
			local picture = MouseDashLogic.prizePicture(prize)
			glyph.Text = picture.glyph
			glyph.Visible = picture.image == nil
			image.Image = picture.image or ""
		end
end

-- Words that shrink to fit their box, never under 13 (9 px on the smallest phone's scale, ui-review).
local function fitted(props: { [string]: any }, most: number): TextLabel
	local label = text(props)
	label.TextScaled = true
	Create(
		"UITextSizeConstraint",
		{ MinTextSize = 13, MaxTextSize = math.max(most, 13), Parent = label }
	)
	return label
end

local function round(frame: GuiObject, radius: UDim?)
	Create("UICorner", { CornerRadius = radius or UDim.new(0, Theme.sizes.radius), Parent = frame })
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

function MouseDash.new(callbacks: Callbacks): MouseDash
	local self = setmetatable({}, MouseDash) :: any
	self._callbacks = callbacks
	self._state = nil :: Rules.State?
	self._fish = 0
	self._on = false
	self._run = nil :: number?
	self._index = 0 -- the wave that is up (0: none yet)
	self._points = 0
	self._hearts = 0
	self._dizzyUntil = 0
	self._level = 0
	self._last = nil :: Rules.Result?
	self._holes = {} :: { Hole }
	self._picked = 5 -- the gamepad's hole
	self._gamepad = false
	self._connections = {} :: { RBXScriptConnection }
	self._step = nil :: RBXScriptConnection?
	self._overToken = 0
	self._art = false -- the picture sheet has loaded (checked in _draw); the stand-ins show until then
	self._quit = nil :: number? -- the run this window closed on, until its MouseDashOver comes
	self._bannerToken = 0
	self._tab = nil :: string? -- "Prizes" or "Leaderboard" once pressed (#3553: no list on the base menu)
	self._nextAt = nil :: number?
	self._endsAt = nil :: number?

	local panel = Panel.new({
		dark = true,
		name = MouseDashLogic.WINDOW,
		title = "Cat Arcade",
		subtitle = Rules.NAME,
		color = Color3.fromHex("8E6BD8"),
		icon = "🐭",
		size = UDim2.fromScale(0.94, 0.9),
		onClose = function()
			callbacks.close()
		end,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame

	-- the card -------------------------------------------------------------------------------------------------------
	local card: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Card",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
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
	self._card = card
	-- the lit sign: a pink band, the game's name in yellow, a row of bulbs above and below (drawn, not a picture)
	local sign: Frame = Create("Frame", {
		Name = "Sign",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, SIGN_H),
		LayoutOrder = 1,
		Parent = card,
	}, {
		Create("UIGradient", {
			Color = ColorSequence.new(Color3.fromHex("FF6E96"), Color3.fromHex("FF8CB4")),
			Rotation = 90,
		}),
		Create("UIStroke", { Color = INK, Thickness = 2 }),
	})
	round(sign, UDim.new(0, 12))
	for _, y in { 8, SIGN_H - 8 } do
		for index = 1, 12 do
			local bulb: Frame = Create("Frame", {
				Name = "Bulb",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = BULB,
				BorderSizePixel = 0,
				Position = UDim2.new((index - 0.5) / 12, 0, 0, y),
				Size = UDim2.fromOffset(7, 7),
				Parent = sign,
			}, { Create("UIStroke", { Color = INK, Thickness = 1 }) })
			round(bulb, UDim.new(1, 0))
		end
	end
	fitted({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 0, 30),
		FontFace = Theme.fonts.display,
		TextColor3 = Color3.fromHex("FFE650"),
		TextWrapped = false,
		Text = string.upper(Rules.NAME),
		Parent = sign,
	}, 30)
	Create("UIStroke", { Color = INK, Thickness = 3, Parent = sign:FindFirstChild("Title") })

	-- the mascot on the cabinet's screen, and beside it the best, the free play and the next prize
	local menu: Frame = Create("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, MENU_H),
		LayoutOrder = 2,
		Parent = card,
	})
	local mascot: Frame = Create("Frame", {
		Name = "Mascot",
		BackgroundColor3 = CELLAR,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(MASCOT, MASCOT),
		Parent = menu,
	}, { Create("UIStroke", { Color = INK, Thickness = 2 }) })
	round(mascot, UDim.new(0, 12))
	text({
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		TextScaled = true,
		TextWrapped = false,
		Text = "🐭",
		Parent = mascot,
	})
	sheet("GoldMouse", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92),
		Parent = mascot,
	})
	local side = MASCOT + 10
	self._records = fitted({
		Name = "Records",
		Position = UDim2.fromOffset(side, 2),
		Size = UDim2.new(1, -side, 0, 28),
		FontFace = Theme.fonts.display,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = menu,
	}, Theme.sizes.textLarge)
	self._free = fitted({
		Name = "Free",
		BackgroundColor3 = GO_GREEN,
		BackgroundTransparency = 0,
		Position = UDim2.fromOffset(side, 32),
		Size = UDim2.new(1, -side, 0, 24),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = INK,
		TextWrapped = false,
		Parent = menu,
	}, Theme.sizes.textSmall)
	Create("UIStroke", {
		Color = INK,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = self._free,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		Parent = self._free,
	})
	round(self._free, UDim.new(0, 10))
	local nextCard: Frame = Create("Frame", {
		Name = "NextCard",
		BackgroundColor3 = CREAM,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(side, 60),
		Size = UDim2.new(1, -side, 0, 48),
		Parent = menu,
	}, { Create("UIStroke", { Color = INK, Thickness = 2 }) })
	round(nextCard, UDim.new(0, 10))
	local cardArt, setCardArt = prizeArt(nextCard, "Picture")
	cardArt.Position = UDim2.fromOffset(4, 4)
	cardArt.Size = UDim2.fromOffset(40, 40)
	self._setCardArt = setCardArt
	self._cardTag = text({
		Name = "Tag",
		Position = UDim2.fromOffset(50, 3),
		Size = UDim2.new(1, -56, 0, 15),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 13,
		TextColor3 = TAG_PURPLE,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "NEXT PRIZE",
		Parent = nextCard,
	})
	self._cardWords = fitted({
		Name = "Words",
		Position = UDim2.fromOffset(50, 18),
		Size = UDim2.new(1, -56, 0, 26),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = INK,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = nextCard,
	}, Theme.sizes.textBody)
	self._lastLine = text({
		Name = "LastGame",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = PAL.gold,
		Visible = false,
		LayoutOrder = 3,
		Parent = card,
	})
	local buttonH = Scale.tapHeight(math.max(Theme.sizes.touchMin, 56))
	self._play = Button.new({
		name = "Play",
		text = Rules.playText(false),
		style = "primary",
		size = UDim2.new(1, 0, 0, buttonH + 12),
		textSize = Theme.sizes.textLarge,
		parent = card,
		onClick = function()
			if self:_canPlay() then
				callbacks.play()
			end
		end,
	})
	self._play.instance.LayoutOrder = 4
	-- the grey mouse on the big button; a label, so a press goes through it to the button
	sheet("Mouse", {
		Name = "Mouse",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(buttonH, buttonH),
		ZIndex = 5,
		Parent = self._play.instance,
	})
	self._playText = nil :: string?
	self._why = text({
		Name = "Why",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.warn,
		Visible = false,
		LayoutOrder = 5,
		Parent = card,
	})
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, buttonH),
		LayoutOrder = 6,
		Parent = card,
	})
	self._tabs = {} :: { [string]: Button.Button }
	-- each with its own picture and colour (#3553): a pink gift, a blue trophy. A second press folds its list away.
	local looks: { { name: string, style: Button.Style, icon: string, image: string? } } = {
		{ name = "Prizes", style = "berry", icon = "🎁", image = MouseDashLogic.GIFT },
		{ name = "Leaderboard", style = "sky", icon = "🏆", image = ShopIcons.hud("RankUp") },
	}
	for index, look in looks do
		local tab = look.name
		self._tabs[tab] = Button.new({
			name = tab,
			text = tab,
			icon = look.icon,
			image = look.image,
			iconSize = math.floor(buttonH * 0.6),
			style = look.style,
			size = UDim2.new(0.5, -GAP / 2, 1, 0),
			position = UDim2.new((index - 1) * 0.5, (index - 1) * GAP / 2, 0, 0),
			textSize = Theme.sizes.textSmall + 1,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self._tab = if self._tab == tab then nil else tab
				self:_renderCard()
			end,
		})
	end
	-- the prizes, each with its picture, only once Prizes is pressed
	self._prizeList = Create("Frame", {
		Name = "PrizeList",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 7,
		Parent = card,
	})
	self._prizeGrid = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(6, 6),
		CellSize = UDim2.new(1, 0, 0, PRIZE_ROW_H),
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self._prizeList,
	})
	self._prizeRows = {} :: { [number]: any }
	for order, row in MouseDashLogic.prizeRows(nil) do
		local frame: Frame = Create("Frame", {
			Name = "Prize" .. row.at,
			BackgroundColor3 = CREAM,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = self._prizeList,
		})
		round(frame, UDim.new(0, 10))
		local stroke: UIStroke = Create("UIStroke", { Color = INK, Thickness = 2, Parent = frame })
		local art, setArt = prizeArt(frame, "Picture")
		art.Position = UDim2.fromOffset(4, 4)
		art.Size = UDim2.fromOffset(PRIZE_ROW_H - 8, PRIZE_ROW_H - 8)
		setArt(row.prize)
		fitted({
			Name = "PrizeName",
			Position = UDim2.fromOffset(PRIZE_ROW_H + 4, 7),
			Size = UDim2.new(1, -(PRIZE_ROW_H + 68), 0, 22),
			FontFace = Theme.fonts.bodyBold,
			TextColor3 = INK,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = row.name,
			Parent = frame,
		}, Theme.sizes.textBody)
		text({
			Name = "At",
			Position = UDim2.fromOffset(PRIZE_ROW_H + 4, 30),
			Size = UDim2.new(1, -(PRIZE_ROW_H + 68), 0, 16),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = TAG_PURPLE,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Score " .. row.at,
			Parent = frame,
		})
		-- "Earned" with its tick or "NEXT": words as well as colour, so neither carries the meaning alone
		local mark = text({
			Name = "Mark",
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromHex("FFD34D"),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(58, 22),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = INK,
			TextWrapped = false,
			Visible = false,
			Parent = frame,
		})
		round(mark, UDim.new(1, 0))
		self._prizeRows[row.at] = { frame = frame, stroke = stroke, mark = mark }
	end
	-- the leaderboard in the station menus' row look (Derek 2026-11-12: "leaderboard use the reworked station menu
	-- ones"): a round rank badge, gold, silver and bronze for the top three, the name, the score bold on the right, and
	-- a sky edge on the player's own row
	self._topList = Create("Frame", {
		Name = "TopList",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 8,
		Parent = card,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	self._topRows = {} :: { any }
	for index = 1, Rules.TOP do
		local frame: Frame = Create("Frame", {
			Name = "Top" .. index,
			BackgroundColor3 = Theme.colors.white,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, TOP_ROW_H),
			Visible = false,
			Parent = self._topList,
		})
		round(frame, UDim.new(0, 8))
		local edge: UIStroke = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.colors.sky,
			Thickness = 2,
			Enabled = false,
			Parent = frame,
		})
		local badge: Frame = Create("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = HEART_EMPTY,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(TOP_ROW_H - 10, TOP_ROW_H - 10),
			Parent = frame,
		}, { Create("UIStroke", { Color = INK, Thickness = 2 }) })
		round(badge, UDim.new(1, 0))
		local rank = text({
			Name = "Rank",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.white,
			TextWrapped = false,
			Parent = badge,
		})
		Create("UIStroke", { Color = INK, Thickness = 1.5, Parent = rank })
		local name = text({
			Name = "PlayerName",
			Position = UDim2.fromOffset(TOP_ROW_H + 4, 0),
			Size = UDim2.new(1, -(TOP_ROW_H + 4 + 110), 1, 0),
			FontFace = Theme.fonts.bodyBold,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local value = text({
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0, 100, 1, 0),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 2,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
		self._topRows[index] =
			{ frame = frame, edge = edge, badge = badge, rank = rank, name = name, value = value }
	end
	self._list = text({
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LineHeight = 1.25,
		RichText = true,
		Visible = false,
		LayoutOrder = 9,
		Parent = card,
	})
	text({
		Name = "Rule",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = MouseDashLogic.RULE_LINE,
		LayoutOrder = 10,
		Parent = card,
	})
	if callbacks.other ~= nil then
		self._other = Button.new({
			name = "CircleStreak",
			text = "Play Circle Streak",
			style = "ghost",
			size = UDim2.new(1, 0, 0, buttonH),
			textSize = Theme.sizes.textSmall + 1,
			parent = card,
			onClick = callbacks.other,
		})
		self._other.instance.LayoutOrder = 11
	end
	text({
		Name = "IdeaBy",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Text = Rules.IDEA_BY,
		LayoutOrder = 12,
		Parent = card,
	})

	-- the board ------------------------------------------------------------------------------------------------------
	local board: Frame = Create("Frame", {
		Name = "Board",
		BackgroundColor3 = CELLAR,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		Visible = false,
		Parent = panel.content,
	})
	round(board)
	self._board = board
	local hud: Frame = Create("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Parent = board,
	})
	self._hud = hud
	self._heartsFrame =
		Create("Frame", { Name = "Hearts", BackgroundTransparency = 1, Parent = hud })
	self._heartPads = {} :: { TextLabel }
	self._heartArt = {} :: { ImageLabel }
	for index = 1, Config.MouseDashHearts do
		self._heartPads[index] = text({
			Name = "Heart" .. index,
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset((index - 1) * 30, 0),
			TextSize = 20,
			TextWrapped = false,
			Text = HEART_FULL,
			TextColor3 = HEART_COLOR,
			Parent = self._heartsFrame,
		})
		self._heartArt[index] = sheet("Heart", { Name = "Art", Parent = self._heartPads[index] })
	end
	self._score = text({
		Name = "Score",
		FontFace = Theme.fonts.display,
		TextSize = 40,
		TextWrapped = false,
		Text = "0",
		Parent = hud,
	})
	-- the run's clock, where the best is (the best shows only when the server sends no clock)
	self._time = text({
		Name = "Time",
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextWrapped = false,
		Visible = false,
		Parent = hud,
	})
	self._best = text({
		Name = "Best",
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextWrapped = false,
		Parent = hud,
	})
	-- #3553 (Derek: "just show next reward with an image in top banner when playing"): the next prize only, with
	-- its picture and a bar of how close the score is. Placed by MouseDashLogic.layout, clear of every hole.
	local nextBanner: Frame = Create("Frame", {
		Name = "NextPrize",
		BackgroundColor3 = CREAM,
		BorderSizePixel = 0,
		Visible = false,
		Parent = board,
	}, { Create("UIStroke", { Color = INK, Thickness = 2 }) })
	round(nextBanner, UDim.new(0, 12))
	self._nextBanner = nextBanner
	self._nextScale = Create("UIScale", { Parent = nextBanner })
	local nextArt, setNextArt = prizeArt(nextBanner, "Picture")
	self._nextArt = nextArt
	self._setNextArt = setNextArt
	self._nextTag = text({
		Name = "Tag",
		FontFace = Theme.fonts.bodyBold,
		TextSize = 13,
		TextColor3 = TAG_PURPLE,
		TextWrapped = false,
		Text = "NEXT",
		Parent = nextBanner,
	})
	self._nextWords = fitted({
		Name = "Words",
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = INK,
		Parent = nextBanner,
	}, 13)
	local bar: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = nextBanner,
	})
	round(bar, UDim.new(1, 0))
	self._nextBar = bar
	self._nextFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = GO_GREEN,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	round(self._nextFill, UDim.new(1, 0))
	self._nextCount = text({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 13,
		TextColor3 = Theme.colors.white,
		TextWrapped = false,
		ZIndex = 2,
		Parent = bar,
	})
	-- the cellar floor, a little wider than the holes so its cheese and buttons sit at the edge between the rows
	-- (Derek: nothing distracting near where the animals come up)
	self._backdrop = Create("ImageLabel", {
		Name = "Backdrop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = MouseDashLogic.BACKDROP,
		ScaleType = Enum.ScaleType.Stretch,
		Parent = board,
	})
	local grid: Frame =
		Create("Frame", { Name = "Grid", BackgroundTransparency = 1, Parent = board })
	self._grid = grid
	for index = 1, Rules.HOLES do
		local button: TextButton = Create("TextButton", {
			Name = "Hole" .. index,
			AutoButtonColor = false,
			BackgroundColor3 = HOLE_COLOR,
			BorderSizePixel = 0,
			Text = "",
			Parent = grid,
		})
		round(button)
		local ring: UIStroke = Create(
			"UIStroke",
			{ Color = PAL.gold, Thickness = 3, Enabled = false, Parent = button }
		)
		-- The pictures' frame. It sits low in the button so a risen animal's ears stay inside its own button (a tap
		-- on them must not land on the hole above): Model-Agent's placement is the hole filling the frame, the
		-- animal 0.95 of its width, cut off 60% of the way down and risen 0.83 of the width.
		local art: Frame = Create("Frame", {
			Name = "Art",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.22),
			Size = UDim2.fromScale(0.95, 0.95),
			Parent = button,
		})
		local holeArt = sheet("Hole", { Name = "HoleArt", Parent = art })
		-- the stand-in pit until the sheet has loaded, where the picture's hole is
		local pit: Frame = Create("Frame", {
			Name = "Pit",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PIT_COLOR,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.3),
			Parent = art,
		})
		round(pit, UDim.new(1, 0))
		-- everything that pops up is centred in this frame, which cuts it off at the hole's front edge
		local clip: Frame = Create("Frame", {
			Name = "Clip",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.6),
			Size = UDim2.fromScale(1, CLIP_HEIGHT),
			Parent = art,
		})
		local animal: Frame = Create("Frame", {
			Name = "Animal",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.95, 0.95),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Visible = false,
			Parent = clip,
		})
		round(animal, UDim.new(1, 0))
		local animalArt = sheet("Mouse", { Name = "Art", Parent = animal })
		local face = text({
			Name = "Face",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			TextScaled = true,
			TextWrapped = false,
			Parent = animal,
		})
		local holeFront = sheet("HoleFront", { Name = "HoleFront", ZIndex = 2, Parent = art })
		local zzz = text({
			Name = "Zzz",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.new(1, 0, 0, 16),
			FontFace = Theme.fonts.bodyBold,
			TextSize = 13,
			TextWrapped = false,
			Text = "Zzz",
			Visible = false,
			Parent = button,
		})
		-- the paw lands on the middle of the button, where the tap is aimed
		local paw = text({
			Name = "Paw",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			TextScaled = true,
			TextWrapped = false,
			Text = PAW,
			Visible = false,
			ZIndex = 4,
			Parent = button,
		})
		local pawArt = sheet("PawBop", {
			Name = "Art",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.2, 1.2),
			ZIndex = 4,
			Parent = paw,
		})
		table.insert(
			self._connections,
			-- on the press, not the release (Activated): a 0.40 s window is too short to spend on a finger lifting.
			-- MouseButton1Down is also a touch landing on the button.
			button.MouseButton1Down:Connect(function()
				self:_tap(index)
			end)
		)
		self._holes[index] = {
			button = button,
			pit = pit,
			holeArt = holeArt,
			holeFront = holeFront,
			clip = clip,
			animal = animal,
			animalArt = animalArt,
			pawArt = pawArt,
			face = face,
			zzz = zzz,
			paw = paw,
			ring = ring,
			kind = nil,
			upAt = 0,
			downAt = 0,
		}
	end
	-- #3765 (Derek 2026-11-13: the banners "pop up on top of the game and should be moved higher up so we can see"):
	-- Ready, Faster!, the kitten hint and Prize: sit in the window's header, beside the title and clear of the close
	-- button, never over a hole. On a phone held sideways the board fills the window, so the header is the only room.
	local header = panel.body:FindFirstChild("Header") :: Frame?
	self._banner = text({
		Name = "Banner",
		AnchorPoint = if header ~= nil then Vector2.new(1, 0.5) else Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromHex("15101F"),
		BackgroundTransparency = 0.15,
		Position = if header ~= nil
			then UDim2.new(1, -(panel.closeReach + 14), 0.5, 0)
			else UDim2.new(0.5, 0, 0, 6),
		Size = if header ~= nil
			then UDim2.new(0.58, -panel.closeReach, 1, -8)
			else UDim2.new(0.8, 0, 0, 34),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextWrapped = false,
		TextScaled = true,
		Visible = false,
		ZIndex = 6,
		Parent = header or board,
	})
	round(self._banner, UDim.new(0, 12))
	table.insert(
		self._connections,
		board:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_layout()
		end)
	)
	table.insert(
		self._connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				self._run ~= nil
				and input.UserInputType == Enum.UserInputType.Gamepad1
				and input.KeyCode == Enum.KeyCode.Thumbstick1
			then
				self._gamepad = true
				self:_pick(MouseDashLogic.stickHole(input.Position.X, input.Position.Y))
			end
		end)
	)
	self:_layout()
	self:_renderCard()
	return self :: MouseDash
end

-- Places the strip and the nine holes for the board's size now (MouseDashLogic.layout).
function MouseDash._layout(self: any)
	-- AbsoluteSize is in screen pixels; the offsets below are in the window's own units (its root's UIScale)
	local scale = math.max(Scale.get(), 0.01)
	local size: Vector2 = self._board.AbsoluteSize / scale
	if size.X < 40 or size.Y < 40 then
		return
	end
	local layout = MouseDashLogic.layout(size.X, size.Y)
	local hud: Frame = self._hud
	hud.Position = UDim2.fromOffset(layout.hudX, layout.hudY)
	hud.Size = UDim2.fromOffset(layout.hudW, layout.hudH)
	local hearts: Frame = self._heartsFrame
	hearts.Size = UDim2.fromOffset(86, 26)
	local score: TextLabel = self._score
	local best: TextLabel = self._best
	if layout.side == "left" then
		-- a column: hearts, the score, the best, the next prize, all centred
		hearts.AnchorPoint = Vector2.new(0.5, 0)
		hearts.Position = UDim2.new(0.5, 0, 0, 4)
		score.AnchorPoint = Vector2.new(0.5, 0)
		score.Position = UDim2.new(0.5, 0, 0, 36)
		score.Size = UDim2.new(1, 0, 0, 44)
		best.AnchorPoint = Vector2.new(0.5, 0)
		best.Position = UDim2.new(0.5, 0, 0, 82)
		best.Size = UDim2.new(1, 0, 0, 18)
		self._time.AnchorPoint = Vector2.new(0.5, 0)
		self._time.Position = UDim2.new(0.5, 0, 0, 80)
		self._time.Size = UDim2.new(1, 0, 0, 22)
	else
		-- a row: hearts on the left, the score in the middle, the best on the right
		hearts.AnchorPoint = Vector2.new(0, 0.5)
		hearts.Position = UDim2.new(0, 2, 0.5, 0)
		score.AnchorPoint = Vector2.new(0.5, 0.5)
		score.Position = UDim2.fromScale(0.5, 0.5)
		score.Size = UDim2.new(0, 90, 1, 0)
		best.AnchorPoint = Vector2.new(1, 0.5)
		best.Position = UDim2.new(1, -2, 0.5, 0)
		best.Size = UDim2.new(0, 80, 0, 18)
		self._time.AnchorPoint = Vector2.new(1, 0.5)
		self._time.Position = UDim2.new(1, -2, 0.5, 0)
		self._time.Size = UDim2.new(0, 80, 0, 22)
	end
	-- the next prize's banner (#3553)
	local banner: Frame = self._nextBanner
	local art: Frame = self._nextArt
	local tag: TextLabel = self._nextTag
	local words: TextLabel = self._nextWords
	local bar: Frame = self._nextBar
	banner.Visible = layout.banner ~= "none"
	banner.Position = UDim2.fromOffset(layout.bannerX, layout.bannerY)
	banner.Size = UDim2.fromOffset(layout.bannerW, layout.bannerH)
	tag.Visible = layout.banner ~= "small"
	words.Visible = layout.banner ~= "small"
	if layout.banner == "row" then
		-- picture, then "NEXT" over the prize's words, then the bar
		art.AnchorPoint = Vector2.new(0, 0.5)
		art.Position = UDim2.new(0, 6, 0.5, 0)
		art.Size = UDim2.fromOffset(32, 32)
		tag.Position = UDim2.fromOffset(44, 2)
		tag.Size = UDim2.new(1, -140, 0, 15)
		tag.TextXAlignment = Enum.TextXAlignment.Left
		words.Position = UDim2.fromOffset(44, 17)
		words.Size = UDim2.new(1, -140, 0, 20)
		words.TextXAlignment = Enum.TextXAlignment.Left
		bar.AnchorPoint = Vector2.new(1, 0.5)
		bar.Position = UDim2.new(1, -8, 0.5, 0)
		bar.Size = UDim2.fromOffset(84, 18)
	else
		-- a block in the strip's column: picture, "NEXT", the words on two lines, the bar
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.new(0.5, 0, 0, 5)
		art.Size = UDim2.fromOffset(34, 34)
		tag.Position = UDim2.fromOffset(0, 39)
		tag.Size = UDim2.new(1, 0, 0, 15)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		words.Position = UDim2.fromOffset(4, 54)
		words.Size = UDim2.new(1, -8, 0, 30)
		words.TextXAlignment = Enum.TextXAlignment.Center
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, -5)
		bar.Size = UDim2.new(1, -12, 0, 18)
	end
	local grid: Frame = self._grid
	grid.Position = UDim2.fromOffset(layout.gridX, layout.gridY)
	grid.Size = UDim2.fromOffset(layout.grid, layout.grid)
	local backdrop: ImageLabel = self._backdrop
	backdrop.Position =
		UDim2.fromOffset(layout.gridX + layout.grid / 2, layout.gridY + layout.grid / 2)
	backdrop.Size = UDim2.fromOffset(layout.grid * BACKDROP_SCALE, layout.grid * BACKDROP_SCALE)
	for index, hole: Hole in self._holes do
		local x, y = MouseDashLogic.holeAt(layout, index)
		hole.button.Position = UDim2.fromOffset(x - layout.gridX, y - layout.gridY)
		hole.button.Size = UDim2.fromOffset(layout.hole, layout.hole)
	end
end

function MouseDash._canPlay(self: any): boolean
	local state: Rules.State? = self._state
	if not self._on or state == nil or not state.loaded or self._run ~= nil then
		return false
	end
	return state.free or self._fish >= 1
end

function MouseDash._renderCard(self: any)
	local state: Rules.State? = self._state
	self._records.Text = MouseDashLogic.records(state)
	local last = MouseDashLogic.lastLine(self._last)
	self._lastLine.Text = last
	self._lastLine.Visible = last ~= ""
	local free = state ~= nil and state.free
	local playText = Rules.playText(free)
	if self._playText ~= playText then
		self._playText = playText
		self._play:setText(playText)
	end
	self._play:setEnabled(self:_canPlay())
	local other: Button.Button? = self._other
	if other ~= nil then
		other.instance.Visible = self._otherOn == true
	end
	local why = ""
	if not self._on then
		why = "Mouse Dash is closed for now"
	elseif state ~= nil and state.loaded and not free and self._fish < 1 then
		why = "You need 1 golden fish to play again today"
	end
	self._why.Text = why
	self._why.Visible = why ~= ""
	local today = if state ~= nil then state.today else nil
	-- the menu's free play pill and next prize (the first one not earned today above nothing: what to play for)
	local freeLine = MouseDashLogic.freeLine(state)
	self._free.Text = freeLine
	self._free.Visible = freeLine ~= ""
	self._free.BackgroundColor3 = if free then GO_GREEN else HEART_EMPTY
	self._free.TextColor3 = if free then INK else Theme.colors.white
	local nextRow = MouseDashLogic.nextRow(0, today)
	self._setCardArt(if nextRow ~= nil then nextRow.prize else nil)
	self._cardTag.Text = if nextRow ~= nil then "NEXT PRIZE" else ""
	self._cardWords.Text = if nextRow ~= nil
		then MouseDashLogic.bannerWords(nextRow) .. " points"
		else MouseDashLogic.ALL_EARNED
	-- the prizes, each with its picture; two wide where the card has the room
	local showPrizes = self._tab == "Prizes"
	self._prizeList.Visible = showPrizes
	if showPrizes then
		local wide = self._card.AbsoluteSize.X / math.max(Scale.get(), 0.01) >= TWO_COLUMNS_FROM
		self._prizeGrid.CellSize = if wide
			then UDim2.new(0.5, -3, 0, PRIZE_ROW_H)
			else UDim2.new(1, 0, 0, PRIZE_ROW_H)
		for _, row in MouseDashLogic.prizeRows(today) do
			local view = self._prizeRows[row.at]
			if view ~= nil then
				local isNext = nextRow ~= nil and nextRow.at == row.at
				view.frame.BackgroundColor3 = if row.paid then MINT else CREAM
				view.stroke.Color = if isNext then Color3.fromHex("E0A800") else INK
				view.stroke.Thickness = if isNext then 3 else 2
				view.mark.Visible = row.paid or isNext
				view.mark.Text = if row.paid then "✅ Earned" else "NEXT"
				view.mark.BackgroundTransparency = if row.paid then 1 else 0
			end
		end
	end
	local showTop = self._tab == "Leaderboard"
	local shown = 0
	local top: any = if showTop and state ~= nil then state.top else nil
	for index, view in self._topRows do
		local row: any = if type(top) == "table" then top[index] else nil
		local has = type(row) == "table"
		view.frame.Visible = has
		if has then
			shown += 1
			local medal = LeaderboardLogic.medal(row.rank)
			view.badge.BackgroundColor3 = if medal ~= nil then Theme.medals[medal] else HEART_EMPTY
			view.rank.Text = tostring(row.rank)
			view.name.Text = tostring(row.name)
			view.value.Text = Rules.words(row.points, row.seconds)
			view.edge.Enabled = row.me == true
		end
	end
	self._topList.Visible = showTop and shown > 0
	self._list.Text = if showTop and shown == 0 then "No scores yet. Be the first!" else ""
	self._list.Visible = showTop and shown == 0
end

function MouseDash.setState(self: any, state: Rules.State)
	self._state = state
	self:_renderCard()
	self:_renderTop()
end

function MouseDash.setFish(self: any, fish: number)
	if self._fish ~= fish then
		self._fish = fish
		self:_renderCard()
	end
end

function MouseDash.setOn(self: any, on: boolean)
	self._on = on
	self:_renderCard()
end

-- Whether Circle Streak can still be played (its `circleStreak` switch): shows the way back to its card.
function MouseDash.setOther(self: any, on: boolean)
	self._otherOn = on
	self:_renderCard()
end

function MouseDash.playing(self: any): boolean
	return self._run ~= nil
end

-- The strip: hearts, score, best and the next prize, always the server's numbers.
function MouseDash._renderTop(self: any)
	local state: Rules.State? = self._state
	self._score.Text = tostring(self._points)
	self._best.Text = if state ~= nil and state.best > 0 then "Best " .. state.best else ""
	-- the banner: the next prize, its picture and how close the score is; a small pop as one is passed
	local row = MouseDashLogic.nextRow(self._points, if state ~= nil then state.today else nil)
	self._nextWords.Text = MouseDashLogic.bannerWords(row)
	self._nextTag.Text = if row ~= nil then "NEXT" else ""
	self._setNextArt(if row ~= nil then row.prize else nil)
	local share, count = MouseDashLogic.progress(self._points, row)
	self._nextFill.Size = UDim2.fromScale(share, 1)
	self._nextCount.Text = count
	local at = if row ~= nil then row.at else 0
	if self._run ~= nil and self._nextAt ~= nil and self._nextAt ~= at then
		local scale: UIScale = self._nextScale
		scale.Scale = 1.18
		Tween.to(scale, POP, { Scale = 1 })
		fx("prize", self._nextBanner)
	end
	self._nextAt = at
	for index, pad: TextLabel in self._heartPads do
		local full = index <= self._hearts
		local picture: ImageLabel? = self._heartArt[index]
		if picture ~= nil then
			setCell(picture, if full then "Heart" else "HeartEmpty")
		end
		pad.TextColor3 = if full then HEART_COLOR else HEART_EMPTY
		pad.TextTransparency = if self._art then 1 elseif full then 0 else 0.55
	end
end

function MouseDash._say(self: any, words: string, seconds: number?)
	self._bannerToken += 1
	local token = self._bannerToken
	self._banner.Text = words
	self._banner.Visible = words ~= ""
	if seconds ~= nil then
		task.delay(seconds, function()
			if self._bannerToken == token then
				self._banner.Visible = false
			end
		end)
	end
end

local function clearHole(hole: Hole)
	hole.kind = nil
	hole.animal.Visible = false
	hole.zzz.Visible = false
end

function MouseDash._clearHoles(self: any)
	for _, hole: Hole in self._holes do
		clearHole(hole)
		hole.paw.Visible = false
	end
end

-- The gamepad's hole, ringed once a stick has moved.
function MouseDash._pick(self: any, index: number)
	self._picked = index
	for at, hole: Hole in self._holes do
		hole.ring.Enabled = self._gamepad and at == index
	end
end

function MouseDash._showBoard(self: any, shown: boolean)
	self._board.Visible = shown
	self._card.Visible = not shown
	if shown and self._step == nil then
		self:_layout()
		self._step = RunService.RenderStepped:Connect(function()
			self:_draw()
		end)
		ContextActionService:BindActionAtPriority(
			ACTION_NAME,
			function(
				_name: string,
				inputState: Enum.UserInputState,
				input: InputObject
			): Enum.ContextActionResult
				if inputState == Enum.UserInputState.Begin then
					if input.KeyCode == Enum.KeyCode.ButtonA then
						self._gamepad = true
						self:_pick(self._picked)
						self:_tap(self._picked)
					else
						local hole = MouseDashLogic.keyHole(input.KeyCode.Name)
						if hole ~= nil then
							self:_tap(hole)
						end
					end
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonA,
			Enum.KeyCode.Q,
			Enum.KeyCode.W,
			Enum.KeyCode.E,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Z,
			Enum.KeyCode.X,
			Enum.KeyCode.C
		)
	elseif not shown and self._step ~= nil then
		(self._step :: RBXScriptConnection):Disconnect()
		self._step = nil
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

-- The picture sheet is in: the stand-in tiles, pits, faces and paw prints give way to the pictures.
function MouseDash._useArt(self: any)
	self._art = true
	for _, hole: Hole in self._holes do
		hole.button.BackgroundTransparency = 1
		hole.pit.Visible = false
		hole.animal.BackgroundTransparency = 1
		hole.face.Visible = false
		hole.zzz.Visible = false -- the napping kitten's picture has its own Zzz
		hole.paw.TextTransparency = 1
	end
	self:_renderTop()
end

-- Every frame: each animal rises over RISE_SECONDS and is gone when its window ends (the server's MouseDashGone
-- says what that cost).
function MouseDash._draw(self: any)
	local at = now()
	local clock, low = MouseDashLogic.timeLeft(if self._run ~= nil then self._endsAt else nil, at)
	local time: TextLabel = self._time
	if time.Text ~= clock then
		time.Text = clock
		time.TextColor3 = if low then PAL.warn else PAL.text
	end
	time.Visible = clock ~= ""
	self._best.Visible = clock == ""
	if not self._art and (self._holes[1] :: Hole).holeArt.IsLoaded then
		self:_useArt()
	end
	for _, hole: Hole in self._holes do
		if hole.kind ~= nil then
			if at >= hole.downAt then
				clearHole(hole)
			else
				local up = math.clamp((at - hole.upAt) / RISE_SECONDS, 0, 1)
				-- centred left to right; from under the clip's edge up to sitting in it
				hole.animal.Position = UDim2.fromScale(0.5, 1 - up * RISE)
			end
		end
	end
	local dizzy = at < self._dizzyUntil
	if self._dizzy ~= dizzy then
		self._dizzy = dizzy
		self._grid.Rotation = 0
		for _, hole: Hole in self._holes do
			if self._art then
				hole.holeArt.ImageTransparency = if dizzy then 0.5 else 0
				hole.holeFront.ImageTransparency = if dizzy then 0.5 else 0
			else
				hole.button.BackgroundTransparency = if dizzy then 0.45 else 0
			end
		end
	end
end

-- A tap on a hole: the paw bops it at once; the server says what it hit.
function MouseDash._tap(self: any, index: number)
	local run: number? = self._run
	local hole: Hole? = self._holes[index]
	if run == nil or hole == nil then
		return
	end
	hole.paw.Visible = true
	fx("bounce", hole.paw, "squash")
	task.delay(PAW_SECONDS, function()
		hole.paw.Visible = false
	end)
	-- nothing is sent before the first wave or while the paw is dizzy (the server would drop it anyway)
	if self._index < 1 or now() < self._dizzyUntil then
		return
	end
	self._callbacks.tap(run, self._index, index)
	-- #3951 (Derek 2026-11-13: "the smacking ... feels delayed now, it used to feel instant"): a mouse that is up
	-- shows its bopped picture and goes down at once, not after the server's answer comes back. The server still
	-- judges the tap: the points, the "+1" and the catch sparkle wait for MouseDashJudged.
	local kind = hole.kind
	local art = if kind ~= nil and kind ~= "kitten" then MouseDashLogic.ART[kind] else nil
	if art ~= nil and now() < hole.downAt then
		setCell(hole.animalArt, art.hit)
		hole.downAt = math.min(hole.downAt, now() + HIT_SECONDS)
	end
end

function MouseDash._float(_self: any, hole: Hole, words: string, color: Color3)
	local label = text({
		Name = "Float",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(1, 0.4),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextWrapped = false,
		Text = words,
		TextColor3 = color,
		ZIndex = 5,
		Parent = hole.button,
	})
	Outline.text(label)
	task.delay(FLOAT_SECONDS, function()
		label:Destroy()
	end)
end

-- MouseDashBegan: the board comes up with full hearts and "Ready?" until the first wave.
function MouseDash.began(self: any, run: number, hearts: number, firstAt: number, endsAt: number?)
	self._run = run
	self._endsAt = endsAt -- the run's clock (nil from an older server: the best shows in its place)
	self._index = 0
	self._points = 0
	self._hearts = hearts
	self._dizzyUntil = 0
	self._level = 0
	self._overToken += 1
	self:_clearHoles()
	self:_showBoard(true)
	self:_renderTop()
	self:_say(MouseDashLogic.READY, math.max(0.3, firstAt - now()))
end

-- MouseDashWave: these animals are up now, each until its own window ends.
function MouseDash.wave(self: any, run: number, index: number, pops: { any }, hint: string?)
	if self._run ~= run or type(pops) ~= "table" then
		return
	end
	self._index = index
	for _, hole: Hole in self._holes do
		clearHole(hole)
	end
	for _, pop in pops do
		local hole: Hole? = if type(pop) == "table" then self._holes[pop.hole] else nil
		local look = if type(pop) == "table" then MouseDashLogic.FACES[pop.kind] else nil
		if hole ~= nil and look ~= nil and type(pop.downAt) == "number" then
			hole.kind = pop.kind
			hole.upAt = now() -- it rises from when it reaches this screen
			hole.downAt = pop.downAt
			hole.face.Text = look.face
			hole.animal.BackgroundColor3 = Color3.fromHex(look.color)
			setCell(hole.animalArt, MouseDashLogic.ART[pop.kind].up)
			hole.animal.Position = UDim2.fromScale(0.5, 1)
			hole.animal.Visible = true
			hole.zzz.Visible = pop.kind == "kitten" and not self._art
			fx("pop", hole.button, pop.kind)
			fx("bounce", hole.animal, "pop")
		end
	end
	if hint ~= nil then
		self:_say(hint, 2.5)
	end
end

-- MouseDashJudged: what a tap did.
function MouseDash.judged(
	self: any,
	run: number,
	_index: number,
	tap: any,
	points: number,
	hearts: number,
	streak: number,
	milestones: { number },
	dizzyUntil: number
)
	if self._run ~= run or type(tap) ~= "table" then
		return
	end
	local hole: Hole? = self._holes[tap.hole]
	local lost = hearts < self._hearts
	local won = hearts > self._hearts
	self._points = points
	self._hearts = hearts
	self._dizzyUntil = if type(dizzyUntil) == "number" then dizzyUntil else 0
	if hole ~= nil then
		if tap.outcome == "catch" then
			-- the bopped picture (stars round its head) for a moment, then down
			local art = MouseDashLogic.ART[tostring(tap.kind)]
			if hole.kind ~= nil and art ~= nil then
				setCell(hole.animalArt, art.hit)
				hole.downAt = math.min(hole.downAt, now() + HIT_SECONDS)
			else
				clearHole(hole)
			end
			local golden = tap.kind == "golden"
			self:_float(
				hole,
				"+" .. tostring(tap.gain),
				if golden then Color3.fromHex("FFD34D") else PAL.text
			)
			fx("catch", hole.button, points, tap.kind, streak)
		elseif tap.outcome == "kitten" then
			hole.zzz.Visible = false
			hole.face.Text = "🙀"
			setCell(hole.animalArt, MouseDashLogic.ART.kitten.hit) -- awake, with its "!"
			hole.downAt = math.min(hole.downAt, now() + 0.35)
			fx("wrong", hole.button, "kitten")
		elseif tap.outcome == "empty" then
			self:_float(hole, "💫", PAL.text)
			fx("wrong", hole.button, "empty")
		end
	end
	if lost or won then
		local pad: TextLabel? = self._heartPads[if lost then hearts + 1 else hearts]
		if pad ~= nil then
			fx("heart", pad, won)
		end
	end
	local level = Rules.step(points)
	if level > self._level then
		self._level = level
		self:_say(MouseDashLogic.FASTER, BANNER_SECONDS)
		fx("faster", self._score, level)
	end
	if type(milestones) == "table" and #milestones > 0 then
		local state: Rules.State? = self._state
		if state ~= nil then
			for _, at in milestones do
				if table.find(state.today, at) == nil then
					table.insert(state.today, at)
				end
			end
		end
		for _, row in MouseDashLogic.prizeRows(nil) do
			if row.at == milestones[#milestones] then
				self:_say("Prize: " .. row.name, BANNER_SECONDS + 0.4)
			end
		end
	end
	self:_renderTop()
end

-- MouseDashGone: these got away (or ducked back).
function MouseDash.gone(self: any, run: number, _index: number, gone: { any }, hearts: number)
	if self._run ~= run or type(gone) ~= "table" then
		return
	end
	for _, entry in gone do
		local hole: Hole? = if type(entry) == "table" then self._holes[entry.hole] else nil
		if hole ~= nil then
			clearHole(hole)
			if entry.kind == "mouse" then
				fx("escape", hole.button)
			end
		end
	end
	if hearts < self._hearts then
		local pad: TextLabel? = self._heartPads[hearts + 1]
		if pad ~= nil then
			fx("heart", pad, false)
		end
	end
	self._hearts = hearts
	self:_renderTop()
end

-- MouseDashOver: the board's last word, then the card with how it went.
function MouseDash.over(self: any, run: number, result: Rules.Result)
	if self._quit == run and self._run == nil then
		-- the game this window closed on (onClose): only its result is news
		self._quit = nil
		self._last = result
		self:_renderCard()
		return
	end
	if self._run ~= run then
		return
	end
	self._run = nil
	self._index = 0
	self._last = result
	self:_clearHoles()
	if type(result) == "table" then
		self._points = result.points
		self:_renderTop()
		local words = MouseDashLogic.endWords(result)
		self:_say(words)
		if result.newBest == true or result.win == true then
			fx("best", self._score, if result.win == true then words else nil)
		end
	end
	self._overToken += 1
	local token = self._overToken
	local wait = if type(result) == "table" and result.reason == "quit" then 0 else OVER_SECONDS
	task.delay(wait, function()
		if self._overToken == token and self._run == nil then
			self:_say("")
			self:_showBoard(false)
			self:_renderCard()
		end
	end)
end

function MouseDash.onOpen(self: any)
	if self._run == nil then
		self:_showBoard(false)
	end
	self:_renderCard()
end

-- Closing mid game ends it where it stands. The board, its frame loop and its keys go at once, without waiting
-- for the server's MouseDashOver (a late or lost answer must not leave W A S D swallowed with the window shut).
-- That answer still fills the card's "last game" line when it comes (over, by _quit).
function MouseDash.onClose(self: any)
	local run: number? = self._run
	if run ~= nil then
		self._callbacks.quit(run)
		self._quit = run
		self._run = nil
		self._index = 0
		self._overToken += 1
		self:_clearHoles()
		self:_say("")
		self:_showBoard(false)
		self:_renderCard()
	end
end

function MouseDash.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	if self._step ~= nil then
		(self._step :: RBXScriptConnection):Disconnect()
		ContextActionService:UnbindAction(ACTION_NAME)
	end
	self._play:destroy()
	for _, tab: Button.Button in self._tabs do
		tab:destroy()
	end
	if self._other ~= nil then
		self._other:destroy()
	end
	self._panel:destroy()
end

return MouseDash
