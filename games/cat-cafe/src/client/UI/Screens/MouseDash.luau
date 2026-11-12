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
local MouseDashLogic = require(script.Parent.Parent.Components.MouseDashLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("MouseDash"))

local PAL = Theme.dark

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
	began: (self: MouseDash, run: number, hearts: number, firstAt: number) -> (),
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
	self._tab = "Prizes"

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
	local buttonH = Scale.tapHeight(Theme.sizes.touchMin)
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
	self._play.instance.LayoutOrder = 3
	self._playText = nil :: string?
	self._why = text({
		Name = "Why",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.warn,
		Visible = false,
		LayoutOrder = 4,
		Parent = card,
	})
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, buttonH),
		LayoutOrder = 5,
		Parent = card,
	})
	self._tabs = {} :: { [string]: Button.Button }
	for index, tab in { "Prizes", "Leaderboard" } do
		self._tabs[tab] = Button.new({
			name = tab,
			text = tab,
			style = if index == 1 then "gold" else "ghost",
			size = UDim2.new(0.5, -GAP / 2, 1, 0),
			position = UDim2.new((index - 1) * 0.5, (index - 1) * GAP / 2, 0, 0),
			textSize = Theme.sizes.textSmall + 1,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self._tab = tab
				self:_renderCard()
			end,
		})
	end
	self._list = text({
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LineHeight = 1.25,
		RichText = true,
		LayoutOrder = 6,
		Parent = card,
	})
	text({
		Name = "Rule",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = MouseDashLogic.RULE_LINE,
		LayoutOrder = 7,
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
		self._other.instance.LayoutOrder = 8
	end
	text({
		Name = "IdeaBy",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Text = Rules.IDEA_BY,
		LayoutOrder = 9,
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
	self._best = text({
		Name = "Best",
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextWrapped = false,
		Parent = hud,
	})
	self._next = text({
		Name = "NextPrize",
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Parent = hud,
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
	self._banner = text({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromHex("15101F"),
		BackgroundTransparency = 0.15,
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.8, 0, 0, 34),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextWrapped = false,
		TextScaled = true,
		Visible = false,
		ZIndex = 6,
		Parent = board,
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
	local nextPrize: TextLabel = self._next
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
		nextPrize.Visible = layout.hudH >= 170
		nextPrize.AnchorPoint = Vector2.new(0.5, 0)
		nextPrize.Position = UDim2.new(0.5, 0, 0, 106)
		nextPrize.Size = UDim2.new(1, 0, 0, 58)
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
		nextPrize.Visible = false
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
	for name, tab: Button.Button in self._tabs do
		tab:setStyle(if name == self._tab then "gold" else "ghost")
	end
	local lines: { string } = {}
	if self._tab == "Prizes" then
		for _, row in MouseDashLogic.prizeRows(if state ~= nil then state.today else nil) do
			table.insert(
				lines,
				string.format(
					"%s  <b>%d</b>  %s",
					if row.paid then "✅" else "▫️",
					row.at,
					row.name
				)
			)
		end
	else
		local top = if state ~= nil then state.top else nil
		if type(top) == "table" then
			for _, row in top do
				local line = string.format(
					"%d.  %s  <b>%s</b>",
					row.rank,
					row.name,
					Rules.words(row.points, row.seconds)
				)
				table.insert(lines, if row.me == true then "<b>" .. line .. "</b>" else line)
			end
		end
		if #lines == 0 then
			table.insert(lines, "No scores yet. Be the first!")
		end
	end
	self._list.Text = table.concat(lines, "\n")
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
	self._next.Text =
		MouseDashLogic.nextPrize(self._points, if state ~= nil then state.today else nil)
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
end

function MouseDash._float(self: any, hole: Hole, words: string, color: Color3)
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
function MouseDash.began(self: any, run: number, hearts: number, firstAt: number)
	self._run = run
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
