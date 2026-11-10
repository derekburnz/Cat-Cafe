--!strict
-- The intro cutscene's screen (F72, docs/design/cat-cafe/intro-cutscene.md section 4; Derek 2026-10-27 20:45: a
-- quick fly-through before a new player plays, the important things first, a small Skip after a couple of
-- seconds). The engineer's IntroController moves the camera and calls UI.intro; this draws over it:
--   letterbox bars   9% of the screen each, near black; they slide in on start and out over 0.45 s at the end
--   caption          one line just above the lower bar, popping from 0.9 to full size on each shot
--   shot dots        one per shot on the top bar (IntroLogic.SHOTS, from shared/Intro, up to MAX_SHOTS with the
--                    tackling lesson's tail, #2495), the current one gold
--   demo ring        shot 2's closing catch circle over the stray: PERFECT at 1.3 s, a sparkle to 2.0 s
--   job card         shot 4's four role buttons in miniature beside the cat; the given role lights with a tap
--   tip pop          #2242: the rich visitor shot's big gold "+$1,234" over the tip bag your copy grabs, rising and
--                    fading out
--   Skip             an outlined "Skip »" pill on the lower bar at the right, on screen from the start and dimmed,
--                    with a gold bar filling it over skipAfter (Derek 2026-10-28: "show a bar loading it's ability
--                    to be pressed make it 5 seconds"). Full, it brightens and pops; a tap, a click or gamepad B
--                    then fires callbacks.skip(shot) once, and the controller ends the intro and calls finish. An
--                    early press only shakes it. A replay starts full.
--   Next             #2182 (intro-cutscene.md 2b): a "Next ›" pill of the same size just left of Skip, shown from the
--                    first shot the controller gives a hold. From IntroLogic.NEXT_AFTER into a shot a press, a tap
--                    anywhere but Skip, Space, Enter or gamepad A fires callbacks.nextShot(shot) once for that shot.
--   read bar         #2182: a thin gold bar under the caption filling over the shot's hold, so a player sees when it
--                    moves on by itself
--   tackle cue       #2469: the tackling lesson's Tackle bar (TackleBar's look: dark pill, orange fill, 💨 TACKLE and
--                    the key cap) just over the caption, pressed as the staged lunge starts: it dips, flashes gold
--                    and empties as the real bar does after a tackle; on touch a 👆 taps it
-- #2198: a short lesson (the tackling one, Screens/TackleLesson) plays on the same screen with start's `shots` (its
-- dots), `skip = false` (no Skip: it is meant to be watched) and `onNext` (its own Next in place of callbacks.nextShot).
-- Numbers live in Components/IntroLogic.
--
-- Roblox terms: Camera:WorldToViewportPoint turns a world position into a screen pixel for the current camera,
-- and a ScreenGui with IgnoreGuiInset covers the whole screen (Roblox's top bar strip too), so the two agree.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local IntroLogic = require(script.Parent.Parent.Components.IntroLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Signal = require(script.Parent.Parent.Components.Signal)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	skip: (shot: number) -> (), -- Skip or gamepad B, once per play
	ended: (replay: boolean) -> (), -- the end began (finish, or the Skip fallback): bring the HUD back
	nextShot: ((shot: number) -> ())?, -- #2182: Next, a tap, Space, Enter or gamepad A, once a shot
}

export type Intro = {
	screenGui: ScreenGui,
	start: (self: Intro, options: Types.IntroOptions?) -> (),
	-- #1542: the third argument was the camp shot's title card; it is ignored (the shot and its cards are gone)
	-- #2182: `hold` is the shot's seconds on screen; the read bar fills over it and Next shows (nil: neither)
	setShot: (
		self: Intro,
		index: number,
		caption: string,
		_titleCard: string?,
		hold: number?
	) -> (),
	demoCatch: (self: Intro, worldPosition: Vector3) -> (),
	jobCard: (self: Intro, worldPosition: Vector3, role: string) -> (),
	tipPop: (self: Intro, worldPosition: Vector3, amount: number) -> (),
	tackleCue: (self: Intro, key: string?, pressIn: number?) -> (), -- #2469
	finish: (self: Intro) -> (),
	playing: (self: Intro) -> boolean,
	-- #3105: the loading screen while the camera is held still before the first shot (or before the first spawn)
	waiting: (self: Intro, on: boolean) -> (),
	destroy: (self: Intro) -> (),
}

local BAR = IntroLogic.BAR
local BAR_TRANSPARENCY = 0.08 -- near black, the world just showing through
local BARS_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OUT = IntroLogic.OUT_SECONDS
local BARS_OUT = TweenInfo.new(OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CAPTION_POP = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SIDE = 24 -- design pixels kept clear at the screen's sides
-- #3105 (Derek2 11-10, on two new players leaving at the tutorial's start: "makes me think issues loading or smth",
-- then "a quick loading screen maybe"): while the intro waits for the Alleyway to stream in, and before the first
-- spawn, the camera holds still, for up to 7.5 s on a slow phone, and a still picture with no words looks frozen. A
-- loading screen covers it: the game's name, a cat, three paws that light in turn and "Loading" with dots that
-- tick, so it is plainly alive. It slides away the moment its caller says the wait is over, and by itself after
-- WAIT_LIMIT whatever its caller does, so it never holds a player longer than the load.
local WAIT_TITLE = "Catch a Cat Cafe"
local WAIT_TEXT = "Loading"
local WAIT_TICK = 0.4 -- seconds a dot and a paw
local WAIT_LIMIT = 20 -- seconds
local WAIT_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local WAIT_PAWS = 3
local WAIT_PAW_DIM = 0.75
local CAPTION_HEIGHT = 44
local CAPTION_TEXT = 30
local DOT = 10
local DOT_NOW = 14
local DOT_GAP = 8
local SKIP_WIDTH = 116
local SKIP_ACTION = "CatCafeIntroSkip"
local NEXT_ACTION = "CatCafeIntroNext" -- #2182: Space, Enter and gamepad A
local SKIP_DIM = 0.5 -- Skip's label and outline while its bar fills
local SKIP_POP = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true) -- to 1.1 and back
-- #2702: Skip's one flash as it turns ready, and the gold ring spreading SKIP_RING_GROW px out from it
local SKIP_FLASH = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SKIP_RING = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SKIP_RING_GROW = 36
local SKIP_SHAKE = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true)
-- shot 4's job card: four role tiles beside the cat, a little right of it and up
local JOB_TILE = 44
local JOB_GAP = 6
local JOB_PAD = 8
local JOB_OFFSET = Vector2.new(70, -60)
-- the demo ring in the catch circles' look (Screens/CatchCircles)
local RING_RADIUS = IntroLogic.RING_RADIUS
local RING_THICKNESS = 4
local GOOD_BAND = 14
local PERFECT_BAND = 5
local SPARKLES = 8
local SPARKLE_REACH = RING_RADIUS + 36
local SPARKLE_OUT = TweenInfo.new(
	IntroLogic.END - IntroLogic.CLOSE,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local Intro = {}
Intro.__index = Intro

-- A ring from `inner` to `outer` radius: a circle of the inner radius with its stroke outside it, as the catch
-- circles are drawn.
local function ring(
	name: string,
	inner: number,
	outer: number,
	color: Color3,
	transparency: number,
	parent: Instance
): (Frame, UIStroke)
	local frame: Frame = Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(inner * 2, inner * 2),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local stroke: UIStroke = Create("UIStroke", {
		Color = color,
		Thickness = math.max(1, outer - inner),
		Transparency = transparency,
		Parent = frame,
	})
	return frame, stroke
end

-- Eight gold diamonds flying out from the ring as PERFECT pops, gone by the end of the demo.
local function sparkle(holder: Frame)
	for index = 1, SPARKLES do
		local angle = (index - 1) / SPARKLES * math.pi * 2
		local dx, dy = math.cos(angle), math.sin(angle)
		local spark: Frame = Create("Frame", {
			Name = "Sparkle",
			BackgroundColor3 = Theme.colors.gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, dx * RING_RADIUS, 0.5, dy * RING_RADIUS),
			Rotation = 45,
			Size = UDim2.fromOffset(10, 10),
			Parent = holder,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 2) }) })
		Tween.to(spark, SPARKLE_OUT, {
			Position = UDim2.new(0.5, dx * SPARKLE_REACH, 0.5, dy * SPARKLE_REACH),
			Size = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
		})
	end
end

function Intro.new(parent: Instance, callbacks: Callbacks): Intro
	local self = setmetatable({}, Intro) :: any
	self._callbacks = callbacks
	self._alive = true
	self._playing = false
	self._replay = false
	self._skipped = false
	self._skipShown = false
	self._skipReady = false -- the bar is full, so a press skips
	self._shot = 0
	self._caption = nil :: string?
	self._token = 0 -- one per start and finish, so a late timer cannot touch a newer play
	self._ring = nil :: Frame?
	self._ringLoop = nil :: RBXScriptConnection?
	self._job = nil :: Frame?
	self._jobLoop = nil :: RBXScriptConnection?
	self._connections = {} :: { RBXScriptConnection }
	self._shotAt = 0 -- #2182: os.clock() when the shot showing began
	self._nextShown = false
	self._nexted = 0 -- the shot a Next already moved on from, so one shot takes one press
	self._shots = IntroLogic.SHOTS -- #2198: this play's shot count (a lesson has fewer)
	self._onNext = nil :: ((shot: number) -> ())? -- #2198: this play's Next, in place of callbacks.nextShot

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeIntro",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 50, -- over the popups (40) and everything else while it plays
		Enabled = false,
	})
	self.screenGui = screenGui

	local function bar(name: string): Frame
		return Create("Frame", {
			Name = name,
			BackgroundColor3 = Theme.colors.black,
			BackgroundTransparency = BAR_TRANSPARENCY,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, BAR),
			Parent = screenGui,
		})
	end
	self._top = bar("TopBar")
	self._bottom = bar("BottomBar")
	self._lowerBar = IntroLogic.lowerBar(Scale.isTouch()) -- #2394: none on touch, more camera
	self._bottom.Visible = self._lowerBar
	local topBar = IntroLogic.topBar(Scale.isTouch()) -- #2702: none on touch either, just the dots
	self._top.Visible = topBar

	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = screenGui,
	})
	self._root = root
	self._uiScale = Scale.bind(root)

	-- #2182: a tap anywhere under Next and Skip moves on, as Next does (only once Next shows)
	local tap: TextButton = Create("TextButton", {
		Name = "Tap",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = root,
	})
	self._tap = tap
	table.insert(
		self._connections,
		tap.Activated:Connect(function()
			self:_next()
		end)
	)

	self._ringLayer = Create("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})

	-- the shot dots, centred on the top bar, or DOTS_TOP under the top edge with none (#2702)
	local dots: Frame = Create("Frame", {
		Name = "Dots",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = if topBar
			then UDim2.fromScale(0.5, BAR / 2)
			else UDim2.new(0.5, 0, 0, IntroLogic.DOTS_TOP),
		Size = UDim2.fromOffset(IntroLogic.MAX_SHOTS * (DOT_NOW + DOT_GAP), DOT_NOW),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, DOT_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._dots = {} :: { Frame }
	for index = 1, IntroLogic.MAX_SHOTS do -- #2495: room for the lesson's tail; _renderDots hides the rest
		self._dots[index] = Create("Frame", {
			Name = "Dot" .. index,
			BackgroundColor3 = Theme.colors.paper,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(DOT, DOT),
			Parent = dots,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		if not topBar then
			Outline.border(self._dots[index], 2) -- #2702: over the world, not a black bar
		end
	end

	-- the caption, just above the lower bar; a long one shrinks to stay on one line
	local caption: TextLabel = Create("TextLabel", {
		Name = "Caption",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - BAR, -10),
		Size = UDim2.new(1, -2 * SIDE, 0, CAPTION_HEIGHT),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextScaled = true,
		Text = "",
		Parent = root,
	}, { Create("UITextSizeConstraint", { MaxTextSize = CAPTION_TEXT, MinTextSize = 14 }) })
	Outline.text(caption, 3)
	self._captionLabel = caption
	self._captionScale = Create("UIScale", { Parent = caption })

	-- #2182: the read bar under the caption, filling over the shot's hold
	local read: Frame = Create("Frame", {
		Name = "ReadBar",
		BackgroundColor3 = Theme.colors.paper,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - BAR, -4),
		Size = UDim2.fromOffset(IntroLogic.READ_WIDTH, IntroLogic.READ_HEIGHT),
		Visible = false,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._read = read
	self._readFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = read,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._readTween = nil :: Tween?

	-- Skip: a dark pill with a light outline on the lower bar at the right, and a gold bar filling it
	local skip: TextButton = Create("TextButton", {
		Name = "Skip",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		ClipsDescendants = true,
		Size = UDim2.fromOffset(SKIP_WIDTH, IntroLogic.SKIP_HEIGHT),
		Visible = false,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._skipStroke = Outline.border(skip, 2, Theme.colors.paper)
	self._skipScale = Create("UIScale", { Parent = skip })
	self._skipFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = skip,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local skipLabel: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 20,
		TextColor3 = Theme.colors.white,
		Text = "Skip »",
		ZIndex = 2,
		Parent = skip,
	})
	self._skipLabelStroke = Outline.text(skipLabel, 2)
	self._skipButton = skip
	self._skipLabel = skipLabel
	table.insert(
		self._connections,
		skip.Activated:Connect(function()
			self:_skip()
		end)
	)

	-- #2182: Next, the same pill as Skip with no bar, just left of it
	local nextButton: TextButton = Create("TextButton", {
		Name = "Next",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(SKIP_WIDTH, IntroLogic.SKIP_HEIGHT),
		Visible = false,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(nextButton, 2, Theme.colors.paper)
	local nextLabel: TextLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 20,
		TextColor3 = Theme.colors.white,
		Text = "Next ›",
		Parent = nextButton,
	})
	Outline.text(nextLabel, 2)
	self._nextButton = nextButton
	self._nextScale = Create("UIScale", { Parent = nextButton })
	table.insert(
		self._connections,
		nextButton.Activated:Connect(function()
			self:_next()
		end)
	)

	self._scaleConnection = Scale.changed:Connect(function()
		self:_layout()
	end) :: Signal.Connection
	self:_layout()
	screenGui.Parent = parent

	-- #3105: the loading screen, in a ScreenGui of its own so it shows without the bars and never touches a play
	self._waiting = false
	self._waitToken = 0
	local waitGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeIntroWait",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 50,
		Enabled = false,
	})
	self._waitGui = waitGui
	local cover: Frame = Create("Frame", {
		Name = "Cover",
		Active = true, -- taps stop here: nothing under a loading screen opens
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = waitGui,
	})
	self._waitCover = cover
	local waitRoot: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = cover,
	})
	self._waitScale = Scale.bind(waitRoot)
	Create("TextLabel", {
		Name = "Cat",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -44),
		Size = UDim2.fromOffset(96, 84),
		FontFace = Theme.fonts.display,
		TextSize = 72,
		Text = "🐱",
		Parent = waitRoot,
	})
	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * SIDE, 0, 56),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.gold,
		TextSize = 44,
		Text = WAIT_TITLE,
		Parent = waitRoot,
	})
	Outline.text(title, 3)
	self._waitPaws = {} :: { TextLabel }
	for index = 1, WAIT_PAWS do
		self._waitPaws[index] = Create("TextLabel", {
			Name = "Paw" .. index,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (index - (WAIT_PAWS + 1) / 2) * 44, 0.5, 40),
			Size = UDim2.fromOffset(40, 36),
			FontFace = Theme.fonts.display,
			TextSize = 28,
			TextTransparency = WAIT_PAW_DIM,
			Text = "🐾",
			Parent = waitRoot,
		})
	end
	-- left-aligned in a fixed box, so the word stays put while the dots tick
	self._waitLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 8, 0.5, 86),
		Size = UDim2.fromOffset(104, 28),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.ink,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = WAIT_TEXT .. "...",
		Parent = waitRoot,
	})
	waitGui.Parent = parent
	return self :: Intro
end

-- The Skip pill grows to a finger's size on touch and sits on the lower bar however tall the screen is; with no
-- lower bar (touch, #2394) it sits NO_BAR_EDGE over the bottom edge and the caption and read bar just over it.
function Intro._layout(self: any)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Scale.DESIGN
	local noBar = not self._lowerBar
	local height, below = IntroLogic.skipPlace(viewport.Y, Scale.get(), Scale.isTouch(), noBar)
	if noBar then
		local pillTop = below + height
		self._captionLabel.Position = UDim2.new(0.5, 0, 1, -(pillTop + 10))
		self._read.Position = UDim2.new(0.5, 0, 1, -(pillTop + 4))
	end
	local width = SKIP_WIDTH + height - IntroLogic.SKIP_HEIGHT
	self._skipButton.Size = UDim2.fromOffset(width, height)
	self._skipButton.Position = UDim2.new(1, -SIDE, 1, -below)
	-- #2182: Next the same size, just left of Skip
	self._nextButton.Size = UDim2.fromOffset(width, height)
	self._nextButton.Position = UDim2.new(1, -(SIDE + width + IntroLogic.NEXT_GAP), 1, -below)
end

function Intro._renderDots(self: any)
	for index, dot: Frame in self._dots do
		dot.Visible = index <= self._shots -- #2198: a lesson's fewer dots, still centred
		local look = IntroLogic.dot(index, self._shot)
		local size = if look == "now" then DOT_NOW else DOT
		dot.Size = UDim2.fromOffset(size, size)
		dot.BackgroundColor3 = if look == "now" then Theme.colors.gold else Theme.colors.paper
		dot.BackgroundTransparency = if look == "next" then 0.6 else 0
	end
end

-- Plays from the top: bars in, dots reset, Skip after skipAfter seconds (IntroLogic.skipAfter).
-- #3105: shows the loading screen, or slides it away. A play slides it away (start), and so does WAIT_LIMIT.
function Intro.waiting(self: any, on: boolean)
	local show = on and self._alive and not self._playing
	if show == self._waiting then
		return
	end
	self._waiting = show
	self._waitToken += 1
	local token = self._waitToken
	local cover: Frame = self._waitCover
	if not show then
		local out = Tween.to(cover, WAIT_OUT, { Position = UDim2.fromScale(0, -1) })
		out.Completed:Once(function()
			if self._alive and token == self._waitToken then
				self._waitGui.Enabled = false
			end
		end)
		return
	end
	cover.Position = UDim2.fromScale(0, 0)
	self._waitGui.Enabled = true
	task.spawn(function()
		local tick = 0
		local began = os.clock()
		while self._alive and self._waiting and token == self._waitToken do
			if os.clock() - began > WAIT_LIMIT then
				self:waiting(false)
				return
			end
			self._waitLabel.Text = WAIT_TEXT .. string.rep(".", tick % 4)
			for index, paw in self._waitPaws :: { TextLabel } do
				paw.TextTransparency = if index == tick % WAIT_PAWS + 1 then 0 else WAIT_PAW_DIM
			end
			tick += 1
			task.wait(WAIT_TICK)
		end
	end)
end

function Intro.start(self: any, options: Types.IntroOptions?)
	self:waiting(false) -- #3105: the wait is over
	self._token += 1
	local token = self._token
	self:_clearRing()
	self:_clearJob()
	self:_clearTip()
	self:_clearCue()
	self:_hideSkip()
	self:_hideNext()
	self._playing = true
	self._replay = options ~= nil and options.replay == true
	self._skipped = false
	self._shot = 0
	self._shots = IntroLogic.shotCount(options)
	self._onNext = if options then options.onNext else nil
	self._caption = nil
	self._captionLabel.Text = ""
	self._root.Visible = true
	self:_renderDots()
	self:_layout()
	self._top.Position = UDim2.fromScale(0, -BAR)
	self._bottom.Position = UDim2.fromScale(0, 1)
	Tween.to(self._top, BARS_IN, { Position = UDim2.fromScale(0, 0) })
	Tween.to(self._bottom, BARS_IN, { Position = UDim2.fromScale(0, 1 - BAR) })
	self.screenGui.Enabled = true
	if options ~= nil and options.skip == false then
		return -- #2198: a lesson has no Skip
	end
	local wait = IntroLogic.skipAfter(options)
	self:_showSkip(wait)
	if wait > 0 then
		task.delay(wait, function()
			if self._alive and self._playing and token == self._token then
				self:_readySkip(true)
			end
		end)
	end
end

-- A new shot: its dot turns gold and its caption pops; the same shot and caption again changes nothing. #1542 (Derek):
-- the camp shot and its area title cards are gone, so a third argument is ignored. #2182: with a `hold` the read bar
-- fills over it from the shot's start and Next shows.
function Intro.setShot(
	self: any,
	index: number,
	caption: string,
	_titleCard: string?,
	hold: number?
)
	if not self._playing then
		return
	end
	local shot = math.clamp(math.floor(index), 1, self._shots)
	local newShot = shot ~= self._shot
	if newShot or caption ~= self._caption then
		self._captionLabel.Text = caption
		self._captionScale.Scale = 0.9
		Tween.to(self._captionScale, CAPTION_POP, { Scale = 1 })
	end
	if newShot then
		self._shotAt = os.clock()
	end
	self._shot = shot
	self._caption = caption
	self:_renderDots()
	local seconds = IntroLogic.hold(hold)
	if seconds == nil then
		self:_stopRead()
		self._read.Visible = false
		return
	end
	self:_showNext()
	if newShot or not self._read.Visible then
		self:_stopRead()
		self._read.Visible = true
		local fill: Frame = self._readFill
		fill.Size = UDim2.fromScale(IntroLogic.skipFill(os.clock() - self._shotAt, seconds), 1)
		self._readTween = Tween.to(
			fill,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(1, 1) }
		)
	end
end

function Intro._stopRead(self: any)
	local running: Tween? = self._readTween
	if running then
		running:Cancel()
		self._readTween = nil
	end
end

-- #2182: Next, the tap layer and Space, Enter and gamepad A, from the first shot with a hold to the end.
function Intro._showNext(self: any)
	if self._nextShown then
		return
	end
	self._nextShown = true
	self._nextButton.Visible = true
	self._tap.Visible = true
	ContextActionService:BindActionAtPriority(
		NEXT_ACTION,
		function(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				self:_next()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.Return,
		Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.ButtonA
	)
end

function Intro._hideNext(self: any)
	if self._nextShown then
		ContextActionService:UnbindAction(NEXT_ACTION)
	end
	self._nextShown = false
	self._nexted = 0
	self._nextButton.Visible = false
	self._tap.Visible = false
	self:_stopRead()
	self._read.Visible = false
end

-- #2182: fires callbacks.nextShot once for the shot showing, from IntroLogic.NEXT_AFTER into it; earlier presses do
-- nothing. After Next on the last shot the screen ends itself if the controller has not, as after a Skip.
function Intro._next(self: any)
	local shot = self._shot
	if
		not self._playing
		or self._skipped
		or not self._nextShown
		or shot < 1
		or self._nexted == shot
	then
		return
	end
	if not IntroLogic.canNext(os.clock() - self._shotAt) then
		return
	end
	self._nexted = shot
	Sound.play("uiClick")
	self._nextScale.Scale = 0.92
	Tween.to(self._nextScale, Tween.POP, { Scale = 1 })
	local callback = self._onNext or self._callbacks.nextShot
	if callback then
		callback(shot)
	end
	if shot >= self._shots then
		local token = self._token
		task.delay(IntroLogic.SKIP_FALLBACK, function()
			if self._alive and self._playing and token == self._token then
				self:finish()
			end
		end)
	end
end

-- Shot 2's demo catch over the stray: the circle closes onto its ring in 1.3 s, PERFECT pops with the catch
-- sound and a gold sparkle, and it all fades by 2.0 s. It follows the stray's screen position while the camera
-- pushes in, and hides while the point is behind the camera.
function Intro.demoCatch(self: any, worldPosition: Vector3)
	self:_clearRing()
	if not self._playing then
		return
	end
	local holder: Frame = Create("Frame", {
		Name = "DemoRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		Parent = self._ringLayer,
	})
	local scale: UIScale = Create("UIScale", { Parent = holder })
	ring(
		"GoodBand",
		RING_RADIUS - GOOD_BAND,
		RING_RADIUS + GOOD_BAND,
		Theme.colors.good,
		0.45,
		holder
	)
	ring(
		"PerfectBand",
		RING_RADIUS - PERFECT_BAND,
		RING_RADIUS + PERFECT_BAND,
		Theme.colors.gold,
		0.1,
		holder
	)
	local half = RING_THICKNESS / 2
	local _, ringStroke =
		ring("Ring", RING_RADIUS - half, RING_RADIUS + half, Theme.colors.paper, 0, holder)
	local start = IntroLogic.START_RADIUS
	local closer = ring("Closer", start, start + RING_THICKNESS, Theme.colors.paper, 0, holder)
	local grade: TextLabel = Create("TextLabel", {
		Name = "Grade",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -(RING_RADIUS + 8)),
		Size = UDim2.fromOffset(180, 36),
		FontFace = Theme.fonts.display,
		TextSize = 30,
		TextColor3 = Theme.colors.gold,
		Text = "PERFECT!",
		Visible = false,
		Parent = holder,
	})
	Outline.text(grade, 3)
	self._ring = holder

	local started = os.clock()
	local popped = false
	local fading = false
	self._ringLoop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= IntroLogic.END then
			self:_clearRing()
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local point = camera:WorldToViewportPoint(worldPosition)
			local viewport = camera.ViewportSize
			holder.Visible = point.Z > 0 and viewport.X > 0 and viewport.Y > 0
			if holder.Visible then
				holder.Position = UDim2.fromScale(point.X / viewport.X, point.Y / viewport.Y)
			end
		end
		local radius = IntroLogic.closerRadius(t)
		closer.Size = UDim2.fromOffset(radius * 2, radius * 2)
		if not popped and t >= IntroLogic.CLOSE then
			popped = true
			closer.Visible = false
			ringStroke.Color = Theme.colors.gold
			grade.Visible = true
			Tween.popIn(grade, 0.6)
			scale.Scale = 1.12
			Tween.to(scale, Tween.POP, { Scale = 1 })
			Sound.play("circlePerfect")
			sparkle(holder)
		end
		if not fading and t >= IntroLogic.FADE_FROM then
			fading = true
			for _, part in holder:GetDescendants() do
				if part:IsA("UIStroke") then
					Tween.to(part, FADE, { Transparency = 1 })
				elseif part:IsA("TextLabel") then
					Tween.to(part, FADE, { TextTransparency = 1 })
				end
			end
		end
	end)
end

function Intro._clearRing(self: any)
	local loop: RBXScriptConnection? = self._ringLoop
	if loop then
		loop:Disconnect()
		self._ringLoop = nil
	end
	local holder: Frame? = self._ring
	if holder then
		holder:Destroy()
		self._ring = nil
	end
end

-- Shot 4's job card beside the cat at `worldPosition`: the four role tiles in miniature, `role`'s lighting up
-- with a tap JOB_TAP later, the card gone JOB_GONE after it showed, as the cat takes its spot. It follows the
-- cat's screen position and hides while the point is behind the camera.
function Intro.jobCard(self: any, worldPosition: Vector3, role: string)
	self:_clearJob()
	if not self._playing then
		return
	end
	local count = #IntroLogic.ROLES
	local card: Frame = Create("Frame", {
		Name = "JobCard",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(
			count * JOB_TILE + (count - 1) * JOB_GAP + 2 * JOB_PAD,
			JOB_TILE + 2 * JOB_PAD
		),
		Visible = false,
		Parent = self._ringLayer,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, JOB_PAD),
			PaddingRight = UDim.new(0, JOB_PAD),
			PaddingTop = UDim.new(0, JOB_PAD),
			PaddingBottom = UDim.new(0, JOB_PAD),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, JOB_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Outline.border(card, 3)
	local lit: Frame? = nil
	for index, id in IntroLogic.ROLES do
		local tile: Frame = Create("Frame", {
			Name = id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(JOB_TILE, JOB_TILE),
			Parent = card,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			Create("TextLabel", {
				Name = "Glyph",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.body,
				TextSize = 24,
				Text = Theme.roleIcons[id] or "",
			}),
		})
		Outline.border(tile, 2)
		if id == role then
			lit = tile
		end
	end
	self._job = card

	local started = os.clock()
	local tapped, leaving = false, false
	self._jobLoop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local camera = Workspace.CurrentCamera
		if camera then
			local point = camera:WorldToViewportPoint(worldPosition)
			local viewport = camera.ViewportSize
			card.Visible = point.Z > 0 and viewport.X > 0 and viewport.Y > 0
			if card.Visible then
				-- the screen point as a fraction of the screen, the offset in design pixels like the card
				card.Position = UDim2.new(
					point.X / viewport.X,
					JOB_OFFSET.X,
					point.Y / viewport.Y,
					JOB_OFFSET.Y
				)
			end
		end
		if not tapped and t >= IntroLogic.JOB_TAP then
			tapped = true
			if lit then
				lit.BackgroundColor3 = Theme.colors.good
				Tween.popIn(lit, 0.8)
			end
			Sound.play("uiClick")
		end
		if not leaving and t >= IntroLogic.JOB_GONE - Tween.SETTLE.Time then
			leaving = true
			Tween.popOut(card, function()
				if self._job == card then
					self:_clearJob()
				end
			end)
		end
	end)
	Tween.popIn(card, 0.6)
end

function Intro._clearJob(self: any)
	local loop: RBXScriptConnection? = self._jobLoop
	if loop then
		loop:Disconnect()
		self._jobLoop = nil
	end
	local card: Frame? = self._job
	if card then
		card:Destroy()
		self._job = nil
	end
end

-- #2242 (Derek2 11-07: "add the rare customers chance to the tutorial scene like rich customer tips"): the rich
-- visitor shot's grab, a big gold "+$1,234" (`amount`, the tip at Tier 1 rates the controller works out) popping in
-- over the tip bag at `worldPosition`, rising TIP_RISE and fading out by TIP_GONE. It follows the bag's screen point
-- and hides while it is behind the camera. Only shown: the intro pays nothing.
function Intro.tipPop(self: any, worldPosition: Vector3, amount: number)
	self:_clearTip()
	if not self._playing then
		return
	end
	local pop: TextLabel = Create("TextLabel", {
		Name = "TipPop",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(260, 52),
		FontFace = Theme.fonts.display,
		TextSize = 44,
		TextColor3 = Theme.colors.gold,
		Text = "+" .. Format.money(math.max(0, math.floor(amount))),
		Visible = false,
		Parent = self._ringLayer,
	})
	Outline.text(pop, 3)
	self._tip = pop
	Sound.play("richTip")
	local started = os.clock()
	self._tipLoop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= IntroLogic.TIP_GONE then
			self:_clearTip()
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local point = camera:WorldToViewportPoint(worldPosition)
			local viewport = camera.ViewportSize
			pop.Visible = point.Z > 0 and viewport.X > 0 and viewport.Y > 0
			if pop.Visible then
				local rise = IntroLogic.TIP_RISE * math.min(1, t / IntroLogic.TIP_FADE_FROM)
				pop.Position = UDim2.new(point.X / viewport.X, 0, point.Y / viewport.Y, -12 - rise)
			end
		end
		local fade = math.clamp(
			(t - IntroLogic.TIP_FADE_FROM) / (IntroLogic.TIP_GONE - IntroLogic.TIP_FADE_FROM),
			0,
			1
		)
		pop.TextTransparency = fade
	end)
	Tween.popIn(pop, 0.6)
end

-- #2469: the tackling lesson's Tackle bar over the caption, as TackleBar draws it, with `key` on its cap ("" for
-- none: on touch the bar is the button). `pressIn` seconds on it is pressed as the staged lunge starts: it dips,
-- flashes gold and empties, and on touch a finger taps it. nil clears it.
local CUE_WIDTH = 220
local CUE_INSET = 4
local CUE_GAP = 12 -- px over the caption's top
local CUE_ROUND = 72 -- #2510: the touch cue's round button
function Intro.tackleCue(self: any, key: string?, pressIn: number?)
	self:_clearCue()
	if key == nil or not self._playing then
		return
	end
	local touch = Scale.isTouch()
	-- #2510: on touch the cue is the round Tackle button the player will tap, not the bar
	local height = if touch then CUE_ROUND else 34
	local caption: TextLabel = self._captionLabel
	local bar: Frame = Create("Frame", {
		Name = "TackleCue",
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = caption.Position + UDim2.fromOffset(0, -(CAPTION_HEIGHT + CUE_GAP)),
		Size = UDim2.fromOffset(if touch then CUE_ROUND else CUE_WIDTH, height),
		ZIndex = 5,
		Parent = self._root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(bar, Theme.sizes.outline, Theme.hud.stroke)
	local press = Create("UIScale", { Parent = bar })
	local glow: UIStroke = Create("UIStroke", {
		Name = "Glow",
		Color = Theme.colors.gold,
		Thickness = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = bar,
	})
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.warn,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(CUE_INSET, CUE_INSET),
		Size = UDim2.new(1, -2 * CUE_INSET, 1, -2 * CUE_INSET),
		ZIndex = 6,
		Parent = bar,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.shade(fill, 0.22)
	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
		Text = if touch then "💨\nTACKLE" else "💨 TACKLE",
		TextScaled = touch,
		ZIndex = 8,
		Parent = bar,
	})
	if touch then
		word.AnchorPoint = Vector2.new(0.5, 0.5)
		word.Position = UDim2.fromScale(0.5, 0.5)
		word.Size = UDim2.fromScale(0.72, 0.6)
	end
	Outline.text(word, 2)
	if key ~= "" then
		local cap: TextLabel = Create("TextLabel", {
			Name = "Key",
			BackgroundColor3 = Theme.colors.paper,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, CUE_INSET + 2, 0.5, 0),
			Size = UDim2.fromOffset(height - 2 * CUE_INSET - 2, height - 2 * CUE_INSET - 2),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.ink,
			Text = key,
			ZIndex = 9,
			Parent = bar,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
		Outline.border(cap, 2)
	end
	Tween.popIn(bar, 0.85)
	self._cue = bar
	task.delay(math.max(pressIn or 0, 0), function()
		if self._cue ~= bar then
			return
		end
		bar:SetAttribute("Pressed", true)
		if touch then
			local finger: TextLabel = Create("TextLabel", {
				Name = "Finger",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.62, 0, 0.45, 0),
				Size = UDim2.fromOffset(40, 40),
				FontFace = Theme.fonts.display,
				TextSize = 34,
				Text = "👆",
				ZIndex = 10,
				Parent = bar,
			})
			Tween.popIn(finger, 0.6)
		end
		-- the press: a dip and back, a gold flash round it, and the fill emptying as a used Tackle's does
		Tween.to(
			press,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 0.88 }
		)
		task.delay(0.1, function()
			if self._cue == bar then
				Tween.to(
					press,
					TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				)
			end
		end)
		glow.Thickness = 4
		Tween.to(
			glow,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Thickness = 0 }
		)
		Tween.to(
			fill,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.new(0, 0, 1, -2 * CUE_INSET) }
		)
	end)
end

function Intro._clearCue(self: any)
	local cue: Frame? = self._cue
	if cue then
		cue:Destroy()
		self._cue = nil
	end
end

function Intro._clearTip(self: any)
	local loop: RBXScriptConnection? = self._tipLoop
	if loop then
		loop:Disconnect()
		self._tipLoop = nil
	end
	local pop: TextLabel? = self._tip
	if pop then
		pop:Destroy()
		self._tip = nil
	end
end

-- Skip on screen from the start, dimmed, its bar filling over `wait` seconds; with no wait it is ready at once.
-- Gamepad B is bound from the start too, so an early press can shake the pill.
function Intro._showSkip(self: any, wait: number)
	self._skipShown = true
	local skip: TextButton = self._skipButton
	skip.Visible = true
	self._skipScale.Scale = 1
	skip.Rotation = 0
	local fill: Frame = self._skipFill
	fill.Size = UDim2.fromScale(IntroLogic.skipFill(0, wait), 1)
	if wait > 0 then
		self:_readySkip(false)
		Tween.to(
			fill,
			TweenInfo.new(wait, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(1, 1) }
		)
	else
		self:_readySkip(nil)
	end
	ContextActionService:BindActionAtPriority(
		SKIP_ACTION,
		function(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				self:_skip()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonB
	)
end

-- Skip's look: dimmed while its bar fills (false), full once ready (true pops it to 1.1 and back; nil, a
-- replay's, does not).
function Intro._readySkip(self: any, ready: boolean?)
	self._skipReady = ready ~= false
	local alpha = if ready == false then SKIP_DIM else 0
	self._skipStroke.Transparency = alpha
	self._skipLabel.TextTransparency = alpha
	self._skipLabelStroke.Transparency = alpha
	if ready == true then
		self._skipFill.Size = UDim2.fromScale(1, 1)
		Tween.to(self._skipScale, SKIP_POP, { Scale = 1.1 })
	end
	if ready ~= false then
		self:_flashSkip()
	end
end

-- #2702 (Derek2 11-09: "make the tutorial cutscene skip button more obvious maybe one quick flash on the bottom right
-- when its ready"): once, as Skip turns ready, a white flash over the pill and a gold ring spreading out from it. With
-- Reduce Motion on, the flash alone.
function Intro._flashSkip(self: any)
	local skip: TextButton = self._skipButton
	local flash: Frame = Create("Frame", {
		Name = "Flash",
		BackgroundColor3 = Theme.colors.white,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = skip,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Tween.to(flash, SKIP_FLASH, { BackgroundTransparency = 1 })
	task.delay(SKIP_FLASH.Time + 0.05, function()
		flash:Destroy()
	end)
	if GuiService.ReducedMotionEnabled then
		return
	end
	local size = skip.Size
	local ring: Frame = Create("Frame", {
		Name = "SkipRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = skip.Position + UDim2.fromOffset(-size.X.Offset / 2, -size.Y.Offset / 2),
		Size = size,
		ZIndex = 3,
		Parent = skip.Parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local stroke = Outline.border(ring, 4, Theme.colors.gold)
	Tween.to(ring, SKIP_RING, { Size = size + UDim2.fromOffset(SKIP_RING_GROW, SKIP_RING_GROW) })
	Tween.to(stroke, SKIP_RING, { Transparency = 1 })
	task.delay(SKIP_RING.Time + 0.05, function()
		ring:Destroy()
	end)
end

function Intro._hideSkip(self: any)
	if self._skipShown then
		ContextActionService:UnbindAction(SKIP_ACTION)
	end
	self._skipShown = false
	self._skipReady = false
	self._skipButton.Visible = false
end

-- Fires callbacks.skip once with the shot showing. If the controller has not ended the intro SKIP_FALLBACK
-- seconds later (a script error mid-intro), the screen ends itself so the HUD comes back.
function Intro._skip(self: any)
	if not self._playing or self._skipped or not self._skipShown then
		return
	end
	if not self._skipReady then
		-- the bar is still filling: a small shake, nothing else
		local skip: TextButton = self._skipButton
		skip.Rotation = 0
		Tween.to(skip, SKIP_SHAKE, { Rotation = 5 })
		return
	end
	self._skipped = true
	Sound.play("uiClick")
	Tween.to(self._skipLabel, FADE, { TextTransparency = 0.5 })
	local token = self._token
	self._callbacks.skip(IntroLogic.skipShot(self._shot))
	task.delay(IntroLogic.SKIP_FALLBACK, function()
		if self._alive and self._playing and token == self._token then
			self:finish()
		end
	end)
end

-- The end: the caption, dots and Skip go at once and the bars slide off over OUT_SECONDS while the HUD comes
-- back under them (callbacks.ended).
function Intro.finish(self: any)
	if not self._playing then
		return
	end
	self._playing = false
	self._token += 1
	local token = self._token
	self:_clearRing()
	self:_clearJob()
	self:_clearTip()
	self:_clearCue()
	self:_hideSkip()
	self:_hideNext()
	self._root.Visible = false
	Tween.to(self._top, BARS_OUT, { Position = UDim2.fromScale(0, -BAR) })
	Tween.to(self._bottom, BARS_OUT, { Position = UDim2.fromScale(0, 1) })
	task.delay(IntroLogic.OUT_SECONDS, function()
		if self._alive and token == self._token then
			self.screenGui.Enabled = false
		end
	end)
	self._callbacks.ended(self._replay)
end

function Intro.playing(self: any): boolean
	return self._playing
end

function Intro.destroy(self: any)
	self._alive = false
	self._playing = false
	self:_clearRing()
	self:_clearJob()
	self:_clearTip()
	self:_clearCue()
	self:_hideSkip()
	self:_hideNext()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._scaleConnection:Disconnect()
	Scale.unbind(self._uiScale)
	Scale.unbind(self._waitScale)
	self._waitGui:Destroy()
	self.screenGui:Destroy()
end

return Intro
