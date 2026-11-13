--!strict
-- The Cat Arcade window (#3062, Circle Streak; the rules are shared/Arcade, the judging ArcadeService's). The cabinet
-- in the Town Square and the Menu list's Arcade row open it. Two faces:
--   - the card: this player's best and the server's, the last game's line ("Score 37 · Best 52 · Server best 61
--     (Sam)"), the ten prizes with the ones already paid today ticked, the once-a-day rule in plain words (no
--     countdown, Monetization-Agent's conditions), Play with a FREE pill for the first game of the UTC day (#3296), then the fish coin and "x1", and the idea credit (Arcade.IDEA_BY) (Derek2 2026-11-10: "remember
--     to feature the player since he suggested").
--   - the board, while a game runs: the circles the server sends (ArcadeBlock) close onto their rings at their spots,
--     and a tap anywhere on the board, Space or the gamepad's A presses the circle closing now. The UI only says which
--     circle a press was for; the server stamps and judges it, and its grade (ArcadeJudged) clears the circle with
--     VFX-Agent's ArcadeFx.hit, moves the big points counter and, at a milestone, plays ArcadeFx.milestone with the
--     prize's name for 1.5 s. Nothing shows outside the window: no toasts (#3080).
-- #3338 (Derek2: "little symbols beside rewards so its easy to tell and add a more cool Play button", "the menu is
-- bigger for the game the background of game is much cooler aswell of as the banner better ... show next milestone
-- on the top while playing"): each prize row leads with the item's own picture (the golden fish coin, the food's, the
-- potion flask, the crate's); Play is a bold ▶ PLAY with the cost on a golden-fish pill and ArcadeFx.shine sweeping
-- across it while a game can start; the window is bigger, its header runs violet into neon pink, the board is an
-- arcade night with a neon grid and a pink edge, the next prize shows under the points and the milestone banner sits
-- on a dark pill.
-- Closing the window mid game ends it (the quit callback, ArcadeQuit); the card then shows how it went.
--
-- Bands: the closing circle moves at a constant speed, so the Good window of w seconds is a band w x speed pixels
-- wide outside the ring.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArcadeFx = require(script.Parent.Parent.Parent.Effects.ArcadeFx)
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local SmoothClock = require(script.Parent.Parent.Components.SmoothClock)
local Theme = require(script.Parent.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArcadeRules = require(Shared:WaitForChild("Arcade"))
local Config = require(Shared:WaitForChild("Config")) :: any
local SharedTypes = require(Shared:WaitForChild("Types"))

local PAL = MenuFamily.pal

local MAX_SIZE = Vector2.new(640, 720) -- #3338: was 500 x 560
local RING = 34 -- the ring's radius in px
-- #3359: the board's cat pattern (group-owned picture, upload-image.yml), its tile size, how faint and its drift
local BG_TILE = "rbxassetid://103715872453589"
local BG_TILE_PX = 300
local BG_SEEN = 0.82
local BG_DRIFT = 8 -- px a second
local START_SCALE = 3 -- the closing circle starts this many times the ring's size
local PREVIEW = 0.35 -- seconds a ring's faint outline shows before its circle starts closing
local BANNER_SECONDS = 1.5
local OVER_SECONDS = 1.2 -- the board's last word before the card comes back
local GAP = Theme.sizes.gap
local GRID_LINES = 10 -- #3338: the board's neon grid, this many cells each way
local GRID_SEEN = 0.88 -- its lines' see-through share
local ACTION_NAME = "CatCafeArcadePress" -- Space and the gamepad's A press while the board is up, and don't jump
local RULE_LINE = "Perfect +2, Good +1. One miss ends the game. Your first game each day is free, and each prize "
	.. "pays once a day; a new day starts at midnight UTC."
local PLAY_TEXT = "PLAY"
local COST = Config.ArcadeCostFish or 1
local PRIZE_PIC = 26 -- #3338: the picture leading each prize row
local PILL_W = 64 -- the cost pill on Play
local FREE_TEXT = "FREE" -- #3296: the pill while today's free game is there
local TAB_H = 40 -- #3338: the Prizes / Leaderboard tabs
local TOP_LINE_H = 32 -- one leaderboard line
local SCORE_W = 150 -- its score, room for "100 in 58 circles"
-- the top three ranks in gold, silver and bronze
local RANK_COLORS: { [number]: Color3 } = {
	Color3.fromHex("FFD34D"),
	Color3.fromHex("D7DCE6"),
	Color3.fromHex("E2A26B"),
}
local READY_TEXT = "Ready?"
local HINT_TEXT = "Tap when the circle meets the ring"

export type Callbacks = {
	play: () -> (),
	press: (run: number, block: number, index: number) -> (),
	quit: (run: number) -> (),
	close: () -> (),
}

export type Arcade = {
	frame: Frame,
	setState: (self: Arcade, state: ArcadeRules.State) -> (),
	setFish: (self: Arcade, fish: number) -> (),
	setOn: (self: Arcade, on: boolean) -> (),
	block: (
		self: Arcade,
		run: number,
		block: number,
		circles: { SharedTypes.CatchCircle },
		windows: SharedTypes.CatchWindows,
		points: number
	) -> (),
	judged: (
		self: Arcade,
		run: number,
		block: number,
		index: number,
		grade: SharedTypes.RingGrade,
		points: number,
		milestones: { number }
	) -> (),
	over: (self: Arcade, run: number, result: ArcadeRules.Result) -> (),
	playing: (self: Arcade) -> boolean,
	onOpen: (self: Arcade) -> (),
	onClose: (self: Arcade) -> (),
	destroy: (self: Arcade) -> (),
}

type Ring = {
	circle: SharedTypes.CatchCircle,
	holder: Frame,
	closing: Frame,
	pressed: boolean,
	judged: boolean,
}

local Arcade = {}
Arcade.__index = Arcade

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function round(frame: GuiObject, radius: UDim?)
	Create("UICorner", { CornerRadius = radius or UDim.new(0, Theme.sizes.radius), Parent = frame })
end

-- #3338: the picture and the glyph standing in for it beside a prize: the golden fish coin, a food's own picture, the
-- potion's flask or the crate's own (the pictures the other prize chips draw, Components/ShopIcons).
local function prizePicture(raw: unknown): (string?, string)
	local prize: { [string]: any } = if type(raw) == "table" then raw :: any else {}
	if type(prize.fish) == "number" then
		return ShopIcons.prize("fish"), Theme.icons.goldenFish
	end
	local function first(kind: string): string?
		local bag = prize[kind]
		if type(bag) ~= "table" then
			return nil
		end
		local id = next(bag)
		return if type(id) == "string" then id else nil
	end
	local lure = first("lures")
	if lure ~= nil then
		return ShopIcons.food(lure), Theme.foodIcons[lure] or Theme.icons.food
	end
	local potion = first("potions")
	if potion ~= nil then
		return ShopIcons.potion(potion), Theme.icons.potion
	end
	local crate = first("crates")
	if crate ~= nil then
		return ShopIcons.crate(crate) or ShopIcons.clean("Crate"), Theme.icons.crate
	end
	return nil, "🎁"
end

-- #3338: the words under the points while playing: the next prize not yet paid today above `points`.
local function nextPrize(points: number, today: { number }): string
	for _, milestone in ArcadeRules.milestones() do
		if milestone.at > points and table.find(today, milestone.at) == nil then
			return string.format("Next prize: %s at %d", milestone.name, milestone.at)
		end
	end
	return "All of today's prizes won!"
end

-- #3359: server time eased from frame to frame (Components/SmoothClock), so the closing circle never hops when the
-- clock sync corrects GetServerTimeNow(); the presses and the board read the same clock as the drawing
local clock = SmoothClock.new(function(): number
	return Workspace:GetServerTimeNow()
end)
local function now(): number
	return clock:now()
end

function Arcade.new(callbacks: Callbacks): Arcade
	local self = setmetatable({}, Arcade) :: any
	self._callbacks = callbacks
	self._state = nil :: ArcadeRules.State?
	self._fish = 0
	self._on = true
	self._run = nil :: number?
	self._blockNo = 0
	self._rings = {} :: { Ring }
	self._windows = nil :: SharedTypes.CatchWindows?
	self._points = 0
	self._last = nil :: ArcadeRules.Result?
	self._connections = {} :: { RBXScriptConnection }
	self._step = nil :: RBXScriptConnection?
	self._overToken = 0
	self._bannerToken = 0

	local panel = Panel.new({
		dark = true,
		name = "Arcade",
		title = ArcadeRules.NAME,
		subtitle = "Circle Streak",
		color = Color3.fromHex("8E6BD8"), -- arcade purple
		icon = "🕹️",
		image = ShopIcons.clean("Arcade"), -- #3347: the drawn joystick over the emoji
		size = UDim2.fromScale(0.94, 0.9),
		onClose = function()
			callbacks.close()
		end,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	-- #3338 (Derek2: "the banner better"): the header runs arcade violet into neon pink, left to right
	local found = panel.frame:FindFirstChild("Header", true)
	if found ~= nil and found:IsA("Frame") then
		local header = found :: Frame
		local neon = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("7A55E0")),
			ColorSequenceKeypoint.new(0.6, Color3.fromHex("B05FE0")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("FF6FB5")),
		})
		header.BackgroundColor3 = Color3.new(1, 1, 1)
		local shade = header:FindFirstChild("Shade")
		if shade ~= nil and shade:IsA("UIGradient") then
			(shade :: UIGradient).Rotation = 0
			(shade :: UIGradient).Color = neon
		end
		local square = header:FindFirstChild("Square")
		if square ~= nil and square:IsA("Frame") then
			(square :: Frame).BackgroundColor3 = Color3.new(1, 1, 1)
			Create("UIGradient", { Color = neon, Parent = square })
		end
	end
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame

	-- the card
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
	self._records = text({
		Name = "Records",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		LayoutOrder = 1,
		Parent = card,
	})
	self._lastLine = text({
		Name = "LastGame",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = PAL.gold,
		Visible = false,
		LayoutOrder = 2,
		Parent = card,
	})
	-- #3338 (Derek2: the leaderboard button): two tabs over the list, today's prizes or the arcade's top players
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_H),
		LayoutOrder = 5,
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._tab = "prizes"
	self._prizesTab = Button.new({
		name = "PrizesTab",
		text = "Prizes today",
		icon = "🎁",
		style = "gold",
		size = UDim2.new(0.5, -GAP / 2, 0, TAB_H),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		parent = tabs,
		onClick = function()
			self:_showTab("prizes")
		end,
	})
	self._topTab = Button.new({
		name = "LeaderboardTab",
		text = "Leaderboard",
		icon = "🏆",
		style = "ghost",
		size = UDim2.new(0.5, -GAP / 2, 0, TAB_H),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		parent = tabs,
		onClick = function()
			self:_showTab("top")
		end,
	})
	local top: Frame = Create("Frame", {
		Name = "Leaderboard",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 6,
		Parent = card,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	self._top = top
	self._topLines = {} :: { Frame }
	for rank = 1, ArcadeRules.TOP do
		local line: Frame = Create("Frame", {
			Name = "Line" .. rank,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, TOP_LINE_H),
			Visible = false,
			LayoutOrder = rank,
			Parent = top,
		})
		round(line, UDim.new(0, Theme.sizes.radiusSmall))
		text({
			Name = "Rank",
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 40, 1, 0),
			FontFace = Theme.fonts.display,
			TextColor3 = RANK_COLORS[rank] or PAL.subtext,
			TextWrapped = false,
			Parent = line,
		})
		text({
			Name = "Name",
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -(52 + SCORE_W + 16), 1, 0),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = line,
		})
		text({
			Name = "Score",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.new(0, SCORE_W, 1, 0),
			FontFace = Theme.fonts.display,
			TextColor3 = PAL.gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			Parent = line,
		})
		table.insert(self._topLines, line)
	end
	self._topEmpty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "No scores yet. Play to be the first!",
		LayoutOrder = ArcadeRules.TOP + 1,
		Parent = top,
	})
	local grid: Frame = Create("Frame", {
		Name = "Prizes",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = card,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -GAP / 2, 0, 34), -- #3338: room for the prize's picture
			CellPadding = UDim2.fromOffset(GAP, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._prizeGrid = grid
	self._prizeRows = {} :: { [number]: TextLabel }
	for order, milestone in ArcadeRules.milestones() do
		local chip: Frame = Create("Frame", {
			Name = "Prize" .. milestone.at,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = grid,
		})
		round(chip, UDim.new(0, Theme.sizes.radiusSmall))
		local picture = text({
			Name = "Picture",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(PRIZE_PIC, PRIZE_PIC),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 18,
			Parent = chip,
		})
		local image, glyph = prizePicture(milestone.prize)
		IconArt.set(picture, glyph, 0.9)
		if image ~= nil then
			IconArt.setImage(picture, image, 0.95)
		end
		self._prizeRows[milestone.at] = text({
			Name = "Words",
			Position = UDim2.fromOffset(PRIZE_PIC + 10, 0),
			Size = UDim2.new(1, -(PRIZE_PIC + 14), 1, 0),
			TextSize = Theme.sizes.textSmall,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = string.format("%d · %s", milestone.at, milestone.name),
			Parent = chip,
		})
	end
	text({
		Name = "Rule",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = RULE_LINE,
		LayoutOrder = 7,
		Parent = card,
	})
	self._playButton = Button.new({
		name = "Play",
		text = PLAY_TEXT,
		icon = "▶", -- #3338: a bold play symbol
		style = "gold",
		size = UDim2.new(1, 0, 0, 56),
		textSize = Theme.sizes.textLarge + 4,
		layoutOrder = 3,
		parent = card,
		onClick = function()
			if self._run == nil and self:_canPlay() then
				callbacks.play()
			end
		end,
	})
	-- #3338: the cost on a dark pill at the button's right, the golden fish coin and "x1"
	local pill: Frame = Create("Frame", {
		Name = "Cost",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, -2),
		Size = UDim2.fromOffset(PILL_W, 32),
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = self._playButton.face,
	})
	round(pill, UDim.new(1, 0))
	local coin = text({
		Name = "Fish",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		ZIndex = 6,
		Parent = pill,
	})
	IconArt.set(coin, Theme.icons.goldenFish, 0.9)
	local fishImage = ShopIcons.prize("fish")
	if fishImage ~= nil then
		IconArt.setImage(coin, fishImage, 0.95)
	end
	self._coin = coin
	self._amount = text({
		Name = "Amount",
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -34, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "x" .. tostring(COST),
		ZIndex = 6,
		Parent = pill,
	})
	self._shine = ArcadeFx.shine(self._playButton.face, UDim.new(0, Theme.sizes.radius))
	self._why = text({
		Name = "Why",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.warn,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		LayoutOrder = 4,
		Parent = card,
	})
	text({
		Name = "IdeaBy",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = ArcadeRules.IDEA_BY .. " 🕹️",
		LayoutOrder = 8,
		Parent = card,
	})

	-- the board
	local board: TextButton = Create("TextButton", {
		Name = "Board",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHex("231B2E"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ClipsDescendants = true,
		Visible = false,
		Parent = panel.content,
	})
	round(board)
	-- #3338 (Derek2: "the background of game is much cooler"): an arcade night, deep violet into midnight blue, a
	-- faint neon grid and a glowing pink edge
	board.BackgroundColor3 = Color3.new(1, 1, 1)
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("3A1F5C")),
			ColorSequenceKeypoint.new(0.55, Color3.fromHex("1E1640")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("0E1530")),
		}),
		Parent = board,
	})
	Create("UIStroke", {
		Color = Color3.fromHex("FF6FB5"),
		Thickness = 3,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = board,
	})
	local grid: Frame = Create("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = board,
	})
	for i = 1, GRID_LINES - 1 do
		local share = i / GRID_LINES
		for _, across in { true, false } do
			Create("Frame", {
				Name = "Line",
				BackgroundColor3 = Color3.fromHex("6FE3FF"),
				BackgroundTransparency = GRID_SEEN,
				BorderSizePixel = 0,
				Position = if across then UDim2.fromScale(share, 0) else UDim2.fromScale(0, share),
				Size = if across then UDim2.new(0, 1, 1, 0) else UDim2.new(1, 0, 0, 1),
				ZIndex = 1,
				Parent = grid,
			})
		end
	end
	-- #3359 (Derek2 2026-11-11: "the background is too dull have some sort of cat themed background"): Motion-FX-Agent's
	-- seamless tile of neon paws, cat faces and stars (assets/cat-cafe/ui/textures/UI_ArcadeBg_Tile.png), faint so
	-- the gold rings stay the brightest thing on the board (Design-Agent: 10 to 15% over the base). One tile wider
	-- and taller than the board, so _draw can drift it a tile's length and wrap unseen.
	self._pattern = Create("ImageLabel", {
		Name = "Pattern",
		BackgroundTransparency = 1,
		Image = BG_TILE,
		ImageTransparency = BG_SEEN,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(BG_TILE_PX, BG_TILE_PX),
		Position = UDim2.fromOffset(-BG_TILE_PX, -BG_TILE_PX),
		Size = UDim2.new(1, BG_TILE_PX, 1, BG_TILE_PX),
		ZIndex = 1,
		Parent = board,
	})
	self._board = board
	self._pointsLabel = text({
		Name = "Points",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0, 220, 0, 48),
		FontFace = Theme.fonts.display,
		TextSize = 44,
		TextColor3 = PAL.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Text = "0",
		ZIndex = 4,
		Parent = board,
	})
	Outline.text(self._pointsLabel, 2)
	self._outOf = text({
		Name = "OutOf",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0, 220, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = string.format("of %d", Config.ArcadeMaxPoints or 100),
		ZIndex = 4,
		Parent = board,
	})
	-- #3338 (Derek2: "show next milestone on the top while playing")
	self._nextLabel = text({
		Name = "NextPrize",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Color3.fromHex("FFD86B"),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Text = "",
		ZIndex = 4,
		Parent = board,
	})
	Outline.text(self._nextLabel, 1)
	self._banner = text({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 34),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 5,
		Visible = false,
		Parent = board,
	})
	Outline.text(self._banner, 2)
	-- #3338: the milestone banner on a dark pill with a gold edge
	self._banner.BackgroundTransparency = 0.25
	self._banner.BackgroundColor3 = Color3.fromHex("140C24")
	round(self._banner, UDim.new(1, 0))
	Create("UIStroke", {
		Color = PAL.gold,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = self._banner,
	})
	self._ringsFolder = Create("Frame", {
		Name = "Rings",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = board,
	})
	table.insert(
		self._connections,
		board.Activated:Connect(function()
			self:_press()
		end)
	)
	self:_renderCard()
	return self :: Arcade
end

function Arcade._canPlay(self: any): boolean
	local state: ArcadeRules.State? = self._state
	if state == nil or not state.loaded or self._on ~= true then
		return false
	end
	if state.free == true then
		return true -- #3296: today's free game
	end
	return self._fish >= (Config.ArcadeCostFish or 1)
end

function Arcade._renderCard(self: any)
	local state: ArcadeRules.State? = self._state
	local best = if state ~= nil then state.best else 0
	local bestCircles = if state ~= nil then state.bestCircles else 0
	local records = "Best "
		.. (if best > 0 then ArcadeRules.words(best, bestCircles) else "none yet")
	if state ~= nil and state.serverBest > 0 then
		records ..= " · Server best " .. ArcadeRules.words(state.serverBest, state.serverCircles)
		if state.serverName ~= nil then
			records ..= " (" .. state.serverName .. ")"
		end
	end
	if state ~= nil and state.legend then
		records ..= "\n⭐ " .. ArcadeRules.LEGEND_TITLE
	end
	self._records.Text = records
	local last: ArcadeRules.Result? = self._last
	if last ~= nil then
		local line = ArcadeRules.cardLine(last)
		if last.win then
			line = "You reached " .. tostring(Config.ArcadeMaxPoints or 100) .. "! " .. line
		elseif last.newBest then
			line = "New best! " .. line
		end
		self._lastLine.Text = line
		self._lastLine.Visible = true
	else
		self._lastLine.Visible = false
	end
	self:_renderTop()
	local today: { number } = if state ~= nil then state.today else {}
	for at, words in self._prizeRows do
		local milestone = ArcadeRules.milestoneAt(at)
		local name: string = if milestone ~= nil then milestone.name else ""
		local paid = table.find(today, at) ~= nil
		local tick: string = if paid then "  ✓" else ""
		words.Text = tostring(at) .. " · " .. name .. tick
		words.TextColor3 = if paid then PAL.subtext else PAL.text
	end
	local why: string? = nil
	if not self._on then
		why = "The Cat Arcade is closed for now"
	elseif state == nil or not state.loaded then
		why = "Waking the arcade up..."
	elseif state.free ~= true and self._fish < (Config.ArcadeCostFish or 1) then
		why = "You need a golden fish 🐟 to play. Catch cats to earn them."
	end
	-- #3296: the pill reads FREE (no fish coin) while today's free game is there, else the fish coin and "x1"
	local free = state ~= nil and state.free == true
	self._coin.Visible = not free
	self._amount.Position = UDim2.fromOffset(if free then 4 else 30, 0)
	self._amount.Size = UDim2.new(1, if free then -8 else -34, 1, 0)
	self._amount.Text = if free then FREE_TEXT else "x" .. tostring(COST)
	self._why.Text = why or ""
	self._why.Visible = why ~= nil
	local can = why == nil and self._run == nil
	self._playButton:setEnabled(can)
	self._shine(can and self.frame.Visible) -- #3338
end

-- #3338: shows today's prizes or the leaderboard under the Play button.
function Arcade._showTab(self: any, tab: string)
	self._tab = tab
	self._prizesTab:setStyle(if tab == "prizes" then "gold" else "ghost")
	self._topTab:setStyle(if tab == "top" then "gold" else "ghost")
	self._prizeGrid.Visible = tab == "prizes"
	self._top.Visible = tab == "top"
end

-- #3338: the leaderboard's lines from the state's top players.
function Arcade._renderTop(self: any)
	local state: ArcadeRules.State? = self._state
	local rows: { ArcadeRules.Row } = if state ~= nil and state.top ~= nil then state.top else {}
	for index, line in self._topLines :: { Frame } do
		local row = rows[index]
		line.Visible = row ~= nil
		if row ~= nil then
			local rank = line:FindFirstChild("Rank") :: TextLabel
			local name = line:FindFirstChild("Name") :: TextLabel
			local score = line:FindFirstChild("Score") :: TextLabel
			rank.Text = "#" .. row.rank
			name.Text = if row.me then row.name .. " (you)" else row.name
			score.Text = ArcadeRules.words(row.points, row.circles)
			line.BackgroundColor3 = if row.me then PAL.goldCard else PAL.card
		end
	end
	self._topEmpty.Visible = #rows == 0
end

-- #3338: the next prize under the points, from today's paid prizes as the card last had them.
function Arcade._showNext(self: any)
	local state: ArcadeRules.State? = self._state
	self._nextLabel.Text = nextPrize(self._points, if state ~= nil then state.today else {})
end

function Arcade.setState(self: any, state: ArcadeRules.State)
	self._state = state
	self:_renderCard()
end

function Arcade.setFish(self: any, fish: number)
	if type(fish) == "number" and fish ~= self._fish then
		self._fish = fish
		self:_renderCard()
	end
end

function Arcade.setOn(self: any, on: boolean)
	self._on = on
	self:_renderCard()
end

function Arcade.playing(self: any): boolean
	return self._run ~= nil
end

function Arcade._clearRings(self: any)
	for _, ring in self._rings do
		ring.holder:Destroy()
	end
	self._rings = {}
end

function Arcade._showBoard(self: any, shown: boolean)
	self._board.Visible = shown
	if shown then
		self._shine(false) -- #3338: no shine under the board
	end
	self._card.Visible = not shown
	if shown and self._step == nil then
		self._step = RunService.RenderStepped:Connect(function()
			self:_draw()
		end)
		ContextActionService:BindActionAtPriority(
			ACTION_NAME,
			function(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
				if inputState == Enum.UserInputState.Begin then
					self:_press()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Space,
			Enum.KeyCode.ButtonA
		)
	elseif not shown and self._step ~= nil then
		(self._step :: RBXScriptConnection):Disconnect()
		self._step = nil
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

function Arcade._say(self: any, words: string, seconds: number?)
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

function Arcade.block(
	self: any,
	run: number,
	block: number,
	circles: { SharedTypes.CatchCircle },
	windows: SharedTypes.CatchWindows,
	points: number
)
	if type(circles) ~= "table" or type(windows) ~= "table" then
		return
	end
	local first = self._run ~= run
	self._run = run
	self._blockNo = block
	self._windows = windows
	self._points = points
	self._pointsLabel.Text = tostring(points)
	self:_showNext() -- #3338
	self:_clearRings()
	self._overToken += 1
	for _, circle in circles do
		local holder: Frame = Create("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(circle.x, circle.y),
			Size = UDim2.fromOffset(RING * 2, RING * 2),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 2,
			Parent = self._ringsFolder,
		})
		-- the Good band outside the ring, the ring, and the circle closing onto it
		local speed = RING * (START_SCALE - 1) / math.max(circle.shrinkSeconds, 0.05)
		local band = math.clamp(windows.good * speed, 2, RING)
		local goodBand: Frame = Create("Frame", {
			Name = "Good",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = holder,
		})
		round(goodBand, UDim.new(1, 0))
		Create("UIStroke", {
			Color = Theme.colors.mint,
			Thickness = band,
			Transparency = 0.55,
			Parent = goodBand,
		})
		local ring: Frame = Create("Frame", {
			Name = "Target",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromHex("3A2D4A"),
			BackgroundTransparency = 0.2,
			ZIndex = 3,
			Parent = holder,
		})
		round(ring, UDim.new(1, 0))
		Create("UIStroke", { Color = PAL.gold, Thickness = 4, Parent = ring })
		local closing: Frame = Create("Frame", {
			Name = "Closing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(START_SCALE, START_SCALE),
			BackgroundTransparency = 1,
			ZIndex = 4,
			Parent = holder,
		})
		round(closing, UDim.new(1, 0))
		Create("UIStroke", { Color = PAL.text, Thickness = 3, Parent = closing })
		table.insert(self._rings, {
			circle = circle,
			holder = holder,
			closing = closing,
			pressed = false,
			judged = false,
		})
	end
	if first then
		self._last = nil
		self:_say(READY_TEXT, math.max(0.4, circles[1].startsAt - now()))
		task.delay(math.max(0, circles[1].startsAt - now()), function()
			if self._run == run and self._blockNo == 1 then
				self:_say(HINT_TEXT, 2)
			end
		end)
		ArcadeFx.goldenFish(self._pointsLabel)
	end
	self:_showBoard(true)
	self:_renderCard()
end

function Arcade._draw(self: any)
	-- #3359: the pattern drifts slowly down and right, a tile's length and round again; still with Reduce Motion
	if not GuiService.ReducedMotionEnabled then
		local shift = (os.clock() * BG_DRIFT) % BG_TILE_PX
		self._pattern.Position = UDim2.fromOffset(shift - BG_TILE_PX, shift - BG_TILE_PX)
	end
	local t = now()
	for _, ring in self._rings do
		if ring.judged then
			ring.holder.Visible = false
			continue
		end
		local circle = ring.circle
		local start = circle.startsAt
		local shown = t >= start - PREVIEW
		ring.holder.Visible = shown
		if shown then
			local left = math.clamp(1 - (t - start) / circle.shrinkSeconds, -0.3, 1)
			local scale = 1 + (START_SCALE - 1) * math.max(left, 0)
			ring.closing.Size = UDim2.fromScale(scale, scale)
			ring.closing.Visible = t >= start and not ring.pressed
		end
	end
end

-- The press goes to the earliest circle this device hasn't pressed that has started closing.
function Arcade._press(self: any)
	local run: number? = self._run
	if run == nil then
		return
	end
	local t = now()
	for index, ring in self._rings do
		if not ring.pressed and not ring.judged then
			if t < ring.circle.startsAt then
				return -- nothing closing yet: a press in the gap counts for nothing
			end
			ring.pressed = true
			self._callbacks.press(run, self._blockNo, index)
			return
		end
	end
end

function Arcade.judged(
	self: any,
	run: number,
	block: number,
	index: number,
	grade: SharedTypes.RingGrade,
	points: number,
	milestones: { number }
)
	if run ~= self._run or block ~= self._blockNo then
		return
	end
	local ring: Ring? = self._rings[index]
	if ring ~= nil then
		ring.judged = true
		local fxGrade: ArcadeFx.Grade = if grade == "perfect"
			then "perfect"
			elseif grade == "good" then "good"
			else "miss"
		ArcadeFx.hit(ring.holder, fxGrade)
		task.defer(function()
			ring.holder.Visible = false
		end)
	end
	if type(points) == "number" then
		self._points = points
		self._pointsLabel.Text = tostring(points)
	end
	if type(milestones) == "table" and #milestones > 0 then
		local names: { string } = {}
		for _, at in milestones do
			local milestone = ArcadeRules.milestoneAt(at)
			if milestone ~= nil then
				table.insert(names, milestone.name)
			end
			ArcadeFx.milestone(self._pointsLabel, at)
			-- #3338: paid now, so the next prize line moves on before ArcadeState says so
			local state: ArcadeRules.State? = self._state
			if state ~= nil and type(at) == "number" and table.find(state.today, at) == nil then
				table.insert(state.today, at)
			end
		end
		if #names > 0 then
			self:_say("+ " .. table.concat(names, ", "), BANNER_SECONDS)
		end
	end
	self:_showNext() -- #3338
end

function Arcade.over(self: any, run: number, result: ArcadeRules.Result)
	if run ~= self._run or type(result) ~= "table" then
		return
	end
	self._run = nil
	self._last = result
	for _, ring in self._rings do
		ring.judged = true
	end
	self._pointsLabel.Text = tostring(result.points)
	self:_say(if result.win then "You did it! 🎉" else "Game over", OVER_SECONDS)
	self._overToken += 1
	local token = self._overToken
	task.delay(OVER_SECONDS, function()
		if self._overToken == token and self._run == nil then
			self:_clearRings()
			self:_showBoard(false)
		end
	end)
	self:_renderCard()
end

function Arcade.onOpen(self: any)
	if self._run == nil then
		self:_showBoard(false)
	end
	self:_renderCard()
end

-- Closing mid game ends it where it stands.
function Arcade.onClose(self: any)
	self._shine(false) -- #3338
	local run: number? = self._run
	if run ~= nil then
		self._callbacks.quit(run)
	end
end

function Arcade.destroy(self: any)
	self._shine(false)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	if self._step ~= nil then
		(self._step :: RBXScriptConnection):Disconnect()
		ContextActionService:UnbindAction(ACTION_NAME)
	end
	self._panel:destroy()
end

return Arcade
