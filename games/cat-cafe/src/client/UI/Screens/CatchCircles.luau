--!strict
-- The net's closing circles (F26, data-model section 10). The server sends the schedule: each circle
-- appears at startsAt and closes onto its ring at startsAt + shrinkSeconds, in server time, at a screen
-- position. The player presses (tap anywhere, Space, click or the gamepad's A) as each circle meets
-- its ring. The UI only says which circle a press was for; the server stamps the time on arrival and
-- judges it. Grades drawn before showResult are hints from this device; showResult replaces them with
-- the server's grades.
--
-- Data-model section 10 step 5: the first Miss ends the catch and no Miss means caught. F93 (catch-rework.md
-- section 3), so nothing on screen can contradict the result:
--   - each circle clears the moment it is judged: its rings pop away, with no word on the spot (Derek 2026-11-03:
--     the words per circle, and a second one where the server's grade differed, read as random flashing)
--   - on the first Miss every circle still showing goes at once and presses stop, so no grade can flash after it.
--     #1727 (Derek2 11-06: circle 3's sound played with nothing on screen): a Miss this device called on a press is
--     only a guess (the server judges on its own clock), so the later circles stay up until the server's CatchJudged
--     for that press: a Good or Perfect there and the catch goes on, a Miss (or the CatchResult) clears them
--   - a strip of pips at the top of the screen, one per circle, fills with each grade's colour as it lands
--   - #3009: the header (the cat's name, rarity and hint) goes the moment the server's result comes, and a catch's
--     word shows for RESULT.caught.seconds (0.4 s), a bolt's for RESULT.missed.seconds (0.8 s)
--   - when the server's result comes, one word slams in over the strip (Components/CatchWords: PURRFECT!,
--     EXCELLENT!, GREAT! or "So close!"), then the strip and the word fade and the screen is clear by RESULT's seconds
-- The result word is the TextLabel Root.ResultWord, Visible only while it shows: Effects/Catch bursts off it in its
-- colour. The camera shake and the hiss are the vfx-animator's and the sound-designer's.
--
-- Catch v3 (#1884, catch-rework.md 7b to 7d), when CatchSchedule sends trustNeed (Header.trustNeed):
--   - a Miss no longer ends the catch: the rings keep coming until the server's CatchResult, and a trust bar over the
--     cat (Components/TrustBar) fills with each grade (Components/CatchTrust; CatchJudged carries the server's trust)
--   - #2060 (Derek2: "move across the screen so not only do you have to time it but find the next one each time"):
--     each ring sits at its own spot on screen (Components/CatchSpots, from the schedule's x, y), away from the one
--     before, so the player finds each ring as well as times it; the trust bar stays over the cat. The next ring's
--     faint outline shows LEAD_IN before it starts closing (PREVIEW_SECONDS elsewhere) and pops in, so the eye can
--     get there first. (Until #2060 the rings sat round the cat's head.)
--   - ring kinds: a "double" is two entries Config.DoubleRingGap apart drawn on the same spot, the second half in sky
--     blue with an "x2" tag (#2005 section 4: "the rapid rings are not clear"); a "paw" ring is red all over (its
--     bands and closing circle too) with a paw print in place of its number and "Don't swing!" under it (#2005), and
--     left alone it is judged "left" (+1 trust), not a Miss
--   - no progress strip; the finish (CatchResult's 6th value) picks the banner: PURRFECT! (gold), GREAT! (mint),
--     NICE! (cream) or "So close!" on a bolt. The banner is the TextLabel Root.FinishBanner (the ResultWord renamed, so
--     Effects' older burst off ResultWord doesn't also fire) and pops FINISH_DELAY after the result, as the net wrap
--     ends and VFX-Agent's burst (#1900) plays; a bolt shows at once.
-- Bands: the closing circle moves at a constant speed, so a timing window of w seconds is a band of
-- w x speed pixels either side of the ring. Good is the wide green band, Perfect the thin gold one.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local CatchSpots = require(script.Parent.Parent.Components.CatchSpots)
local CatchTrust = require(script.Parent.Parent.Components.CatchTrust)
local CatchWords = require(script.Parent.Parent.Components.CatchWords)
local Create = require(script.Parent.Parent.Components.Create)
local Moments = require(script.Parent.Parent.Parent.Moments)
local Motion = require(script.Parent.Parent.Components.Motion)
local Outline = require(script.Parent.Parent.Components.Outline)
local PipWindow = require(script.Parent.Parent.Components.PipWindow)
local Rainbow = require(script.Parent.Parent.Components.Rainbow)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local TrustBar = require(script.Parent.Parent.Components.TrustBar)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

export type Header = {
	catName: string?,
	rarity: string?,
	stars: number?,
	shiny: boolean?,
	rainbow: boolean?, -- F99: "Epic · Rainbow" and a turning rainbow edge
	title: string?, -- replaces the hint line, e.g. "Catch it as it falls!" on a tree rescue
	-- Catch v3 (#1884): CatchSchedule's trust; with trustNeed the catch runs on trust (see the top)
	trustStart: number?,
	trustNeed: number?,
	model: Model?, -- the stray, for the rings round its head and the trust bar over it
}

-- Catch v3's finish, CatchResult's 6th value (#1884)
export type Finish = {
	trust: number?,
	trustNeed: number?,
	finish: string?, -- "purrfect" | "great" | "nice" | "bolt"
	streak: number?,
}

-- The server's verdict (CatchResult): grades up to and including the first Miss. charmGain is what the Perfects
-- added; 0 or nil on a fail.
export type Outcome = {
	grades: { Types.CircleGrade },
	success: boolean,
	charmGain: number?,
	hint: string?, -- the line under the word in place of the usual one (F87: "Try again!" on a tutorial stray)
	finish: Finish?, -- Catch v3 (#1884)
}

export type CatchCircles = {
	screenGui: ScreenGui,
	show: (
		self: CatchCircles,
		circles: { Types.CatchCircle },
		windows: Types.CatchWindows,
		header: Header?,
		onPress: (index: number, grade: Types.CircleGrade?) -> (),
		strayId: string?
	) -> (),
	-- #1727: the server's grade for one press (CatchJudged), as it is judged
	judged: (
		self: CatchCircles,
		strayId: string,
		index: number,
		grade: Types.CircleGrade,
		trust: number?
	) -> (),
	setTrust: (self: CatchCircles, trustStart: number, trustNeed: number, model: Model?) -> (),
	strayId: (self: CatchCircles) -> string?,
	showResult: (self: CatchCircles, outcome: Outcome, onDone: (() -> ())?) -> (),
	gradeLocal: (self: CatchCircles, index: number) -> Types.CircleGrade?,
	isActive: (self: CatchCircles) -> boolean,
	hide: (self: CatchCircles) -> (),
	destroy: (self: CatchCircles) -> (),
}

type CircleView = {
	circle: Types.CatchCircle,
	target: number,
	speed: number, -- design pixels per second the closer travels
	holder: Frame,
	art: Frame, -- the bands, ring, closer and number: what pops away when the circle is judged
	scale: UIScale, -- on art
	closer: Frame,
	closerStroke: UIStroke,
	ring: Frame,
	ringStroke: UIStroke,
	number: TextLabel,
	hint: Types.CircleGrade?, -- the grade drawn: this device's guess, then the server's
	judged: boolean,
	pressed: boolean,
	paw: boolean, -- Catch v3: a paw ring, left alone for +1
	-- #2920: a held ring (a first catch's): it stops on its ring at `target` and waits until `until` for the press
	hold: boolean,
	holdUntil: number,
	prompt: TextLabel?, -- "Tap now!" and the like, pulsing under the held ring
	promptScale: UIScale?,
}

local RING_RADIUS = 46 -- design pixels at 1280 x 720
local START_RADIUS = RING_RADIUS * 3
local PREVIEW_SECONDS = 0.35 -- the ring fades in this long before its circle starts
local LEAD_IN = 0.55 -- Catch v3 (#2060): the next ring shows this long ahead, at its new spot, to be found in time
local CLOSER_THICKNESS = 4
local RING_THICKNESS = 4
-- data-model CatchLatencyCapSeconds (0.15): the server stops waiting for a circle's press this long
-- after the good window closes. Read from Config once the engineer adds it.
local LATENCY_CAP: number = Config.CatchLatencyCapSeconds
-- #3009 (Derek2 11-10: the word and the cat's banner "stay for too long on catch should disappear almost instantly
-- ... especially the banner should be instantly gone on mobile after it is caught"): the header goes the moment the
-- result comes, and a catch's word is a 0.4 s flash (it was 1.2 s, F93). A bolt's "So close!" keeps 0.8 s, since it
-- is the only thing on the catch screen that says the try failed.
local RESULT = {
	caught = { seconds = 0.4, fadeAt = 0.25 },
	missed = { seconds = 0.8, fadeAt = 0.5 },
}
-- the strip steps back under the result word so the word reads, then both fade from RESULT's fadeAt
local UNDER_WORD = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLEAR = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.In)
-- the progress strip at the top of the screen, over the header (which sits at 80; Roblox's buttons stop at 58 on
-- the left only, so the middle of the top edge is free)
local STRIP_TOP = 22
local PIP = 18
local PIP_GAP = 6
local STRIP_PAD = 9
local WORD_SIZE = Vector2.new(360, 60)
local FINISH_DELAY = 0.6 -- Catch v3: the net wrap's wobble before the banner pops (catch-rework.md 7d)
local PAW_COLOR = Color3.fromHex("E5484D")
local DOUBLE_COLOR = Theme.colors.sky -- #2005: a double ring's second half, so the two taps read apart
local NO_RESULT_TIMEOUT = 4 -- hide if the server's result has not come this long after the last target
local ACTION_NAME = "CatCafeCatchPress"
-- #2920: how long a held ring waits on its ring for the press when the schedule does not say (circle.holdSeconds)
local HOLD_SECONDS = 60
local HOLD_PULSE = 1.4 -- the prompt's pulses a second
local HOLD_HINT = "Wait for the circle to reach its ring"
-- E is not here: it is the hold-to-start key on the catch prompt, and letting go of it would land as a press
local PRESS_KEYS = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }

local GRADE_COLOR: { [string]: Color3 } = {
	perfect = Theme.colors.gold,
	good = Theme.colors.mint,
	miss = Theme.colors.disabled, -- soft grey
	left = Theme.colors.mint, -- Catch v3: a paw ring left alone
}
local RESULT_COLOR: { [string]: Color3 } = {
	purrfect = Theme.colors.gold,
	excellent = Theme.colors.gold,
	great = Theme.colors.mint,
	nice = Theme.colors.cream, -- #1884 Catch v3
	close = Theme.colors.disabled,
}
local WOBBLE = { 9, -8, 6, -4, 0 } -- design pixels, the MISS word shaking its head
local WOBBLE_STEP = TweenInfo.new(0.045, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local CatchCircles = {}
CatchCircles.__index = CatchCircles

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- A quick sideways shake, skipped when the player turned Screen shake off or asked for reduced motion.
local function wobble(label: GuiObject)
	if not Motion.canShake() then
		return
	end
	local base = label.Position
	local step = 0
	local function nextStep()
		step += 1
		local offset = WOBBLE[step]
		if offset == nil then
			return
		end
		local tween =
			Tween.to(label, WOBBLE_STEP, { Position = base + UDim2.fromOffset(offset, 0) })
		tween.Completed:Once(function()
			nextStep()
		end)
	end
	nextStep()
end

-- A judged circle's rings pop away; its word stays outside them.
local function clearCircle(view: CircleView)
	view.closer.Visible = false
	local art = view.art
	Tween.to(view.scale, CLEAR, { Scale = 0 }).Completed:Once(function()
		art.Visible = false
	end)
end

local function circleFrame(name: string, radius: number, parent: Instance): Frame
	return Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

-- An annulus from innerRadius to outerRadius: a circle of the inner radius with an outside stroke.
local function band(
	name: string,
	innerRadius: number,
	outerRadius: number,
	color: Color3,
	transparency: number,
	parent: Instance
): Frame
	local frame = circleFrame(name, math.max(1, innerRadius), parent)
	Create("UIStroke", {
		Color = color,
		Thickness = math.max(1, outerRadius - innerRadius),
		Transparency = transparency,
		Parent = frame,
	})
	return frame
end

-- x and y (0 to 1) map into the middle 64% by 50% of the screen so a circle never sits under the
-- money panel, the menu or a thumb.
local function screenPosition(circle: Types.CatchCircle): UDim2
	local x = math.clamp(circle.x, 0, 1)
	local y = math.clamp(circle.y, 0, 1)
	return UDim2.fromScale(0.18 + 0.64 * x, 0.25 + 0.5 * y)
end

function CatchCircles.new(parent: Instance): CatchCircles
	local self = setmetatable({}, CatchCircles) :: any
	self._views = {} :: { CircleView }
	self._windows = { perfect = 0, good = 0 } :: Types.CatchWindows
	self._next = 1
	self._active = false
	self._token = 0
	self._onPress = nil :: ((index: number, grade: Types.CircleGrade?) -> ())?
	self._loop = nil :: RBXScriptConnection?
	self._lastTarget = 0
	self._awaitingResult = false

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeCatchCircles",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, -- above modals (20), under toasts (30) and popups (40)
		Enabled = false,
	})
	self.screenGui = screenGui

	-- Taps anywhere count as presses. InputBegan fires on touch down, so a tap is not delayed to its release.
	local tap: TextButton = Create("TextButton", {
		Name = "Tap",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._tap = tap
	self._tapConnection = tap.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			self:_press()
		end
	end)

	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._root = root
	self._uiScale = Scale.bind(root)

	-- Header: the cat, its rarity and the instruction
	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80), -- the travel row hides during a catch; toasts start at 148
		Size = UDim2.fromOffset(380, 66),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create(
			"UIStroke",
			{ Color = Theme.hud.stroke, Transparency = Theme.hud.strokeTransparency }
		),
	})
	self._header = header
	self._headerRainbow = Rainbow.stroke(header:FindFirstChildOfClass("UIStroke") :: UIStroke)
	self._headerRainbow.Enabled = false
	self._name = Create("TextLabel", {
		Name = "CatName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -120, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = 20,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = header,
	})
	self._rarity = Create("TextLabel", {
		Name = "Rarity",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny + 1,
		Text = "",
		Parent = header,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	self._hint = Create("TextLabel", {
		Name = "Hint",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -28, 0, 22),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = header,
	})

	-- F93: the progress strip at the top, one pip per circle (built in show), and the result word over it
	local strip: Frame = Create("Frame", {
		Name = "Strip",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, STRIP_TOP),
		Size = UDim2.fromOffset(PIP + 2 * STRIP_PAD, PIP + 2 * STRIP_PAD),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, PIP_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._strip = strip
	self._stripTransparency = strip.BackgroundTransparency
	self._pips = {} :: { Frame }
	local word: TextLabel = Create("TextLabel", {
		Name = "ResultWord",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, STRIP_TOP + PIP / 2 + STRIP_PAD),
		Size = UDim2.fromOffset(WORD_SIZE.X, WORD_SIZE.Y),
		FontFace = Theme.fonts.display,
		TextSize = 46,
		TextColor3 = Theme.colors.gold,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	self._wordStroke = Outline.text(word, 4)
	self._word = word

	self._circleLayer = Create("Frame", {
		Name = "Circles",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})

	self._trustBar = TrustBar.new(screenGui) -- moved beside the screen (into PlayerGui) on show: see _placeBar
	self._v3 = false
	self._trust = 0
	self._need = 0
	self._model = nil :: Model?
	self._circles = {} :: { Types.CatchCircle }

	if parent then
		screenGui.Parent = parent
	end
	return self :: CatchCircles
end

-- Catch v3: the trust bar is a BillboardGui, which draws only outside a ScreenGui, so it lives beside this one.
function CatchCircles._placeBar(self: any)
	local gui: BillboardGui = self._trustBar.gui
	local home = self.screenGui.Parent
	if home ~= nil and gui.Parent ~= home then
		gui.Parent = home
	end
end

function CatchCircles._buildView(self: any, index: number, circle: Types.CatchCircle): CircleView
	local windows: Types.CatchWindows = self._windows
	local shrink = math.max(0.05, circle.shrinkSeconds)
	local speed = (START_RADIUS - RING_RADIUS) / shrink
	local good = math.min(RING_RADIUS - 6, windows.good * speed)
	local perfect = math.min(good, windows.perfect * speed)

	local holder: Frame = Create("Frame", {
		Name = "Circle" .. index,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = screenPosition(circle),
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		ZIndex = 10 - index, -- earlier circles on top
		Parent = self._circleLayer,
	})
	-- the circle itself, which pops away when it is judged; the grade word sits outside it so it stays a moment
	local art: Frame = Create("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		Parent = holder,
	})
	local scale: UIScale = Create("UIScale", { Parent = art })
	local kind = (circle :: any).kind
	local paw = kind == "paw"
	-- #2005 (Derek2: "make it the entire circle not just the perfect line"): a paw ring is red all over
	local second = kind == "double" and (circle :: any).half == 2
	local edge = if paw then PAW_COLOR elseif second then DOUBLE_COLOR else Theme.colors.paper
	local goodColor = if paw then PAW_COLOR else Theme.colors.good
	local perfectColor = if paw then PAW_COLOR else Theme.colors.gold
	band("GoodBand", RING_RADIUS - good, RING_RADIUS + good, goodColor, 0.45, art)
	band("PerfectBand", RING_RADIUS - perfect, RING_RADIUS + perfect, perfectColor, 0.1, art)
	local ring = circleFrame("Ring", RING_RADIUS - RING_THICKNESS / 2, art)
	local ringStroke: UIStroke =
		Create("UIStroke", { Color = edge, Thickness = RING_THICKNESS, Parent = ring })
	local closer = circleFrame("Closer", START_RADIUS, art)
	local closerStroke: UIStroke = Create("UIStroke", {
		Color = edge,
		Thickness = CLOSER_THICKNESS,
		Parent = closer,
	})
	local number: TextLabel = Create("TextLabel", {
		Name = "Number",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 40),
		FontFace = Theme.fonts.display,
		TextSize = 30,
		TextColor3 = Theme.colors.paper,
		TextStrokeColor3 = Theme.colors.ink,
		TextStrokeTransparency = 0.4,
		Text = tostring(index),
		Parent = art,
	})
	if paw then
		-- Catch v3: don't tap it. A paw print where the number was, and #2005's "Don't swing!" under it
		number.Text = "🐾"
		local warning: TextLabel = Create("TextLabel", {
			Name = "DontSwing",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, RING_RADIUS + 10),
			Size = UDim2.fromOffset(170, 30),
			FontFace = Theme.fonts.display,
			TextSize = 24,
			TextColor3 = Theme.colors.paper,
			Text = "Don't swing!",
			Parent = art,
		})
		Outline.text(warning, 3, Color3.fromHex("7A1F22"))
	elseif second then
		-- #2005: the second half of a double ring, in sky blue with an "x2" tag at its top right in place of a number
		-- (on the same spot as the first half's, the two numbers would print over each other)
		number.Text = ""
		local tag: TextLabel = Create("TextLabel", {
			Name = "Double",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.5, RING_RADIUS * 0.62, 0.5, -RING_RADIUS * 0.62),
			Size = UDim2.fromOffset(44, 30),
			FontFace = Theme.fonts.display,
			TextSize = 26,
			TextColor3 = DOUBLE_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "x2",
			Parent = art,
		})
		Outline.text(tag, 3)
	end
	-- #2920 (Derek2: "stop the minigame first circle when its over the circle and prompt them to click or press space
	-- now"): a held ring's prompt, under it, shown once the circle sits on its ring
	local held = circle.hold == true
	local holdFor = circle.holdSeconds
	local prompt: TextLabel? = nil
	local promptScale: UIScale? = nil
	if held then
		local label: TextLabel = Create("TextLabel", {
			Name = "HoldPrompt",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, RING_RADIUS + 12),
			Size = UDim2.fromOffset(240, 36),
			FontFace = Theme.fonts.display,
			TextSize = 30,
			TextColor3 = Theme.colors.gold,
			Text = "",
			Visible = false,
			Parent = art,
		})
		Outline.text(label, 3)
		prompt = label
		promptScale = Create("UIScale", { Parent = label })
	end
	local target = circle.startsAt + shrink
	return {
		circle = circle,
		target = target,
		speed = speed,
		holder = holder,
		art = art,
		scale = scale,
		closer = closer,
		closerStroke = closerStroke,
		ring = ring,
		ringStroke = ringStroke,
		number = number,
		hint = nil,
		judged = false,
		pressed = false,
		paw = paw,
		hold = held,
		holdUntil = if held
			then target + (if type(holdFor) == "number" and holdFor > 0
				then holdFor
				else HOLD_SECONDS)
			else target,
		prompt = prompt,
		promptScale = promptScale,
	}
end

-- #2920: the held ring's words for the device the player last used
function CatchCircles.holdWords(lastInput: Enum.UserInputType?): string
	local kind = lastInput or UserInputService:GetLastInputType()
	if kind == Enum.UserInputType.Touch then
		return "Tap now!"
	elseif kind == Enum.UserInputType.Keyboard then
		return "Press Space now!"
	elseif kind.Name:sub(1, 7) == "Gamepad" then
		return "Press A now!"
	end
	return if Scale.isTouch() and kind ~= Enum.UserInputType.MouseButton1
		then "Tap now!"
		else "Click now!"
end

-- The standing line under the cat's name for the device the player last used (#2871: a gamepad names A or R2).
function CatchCircles.hintWords(lastInput: Enum.UserInputType): string
	if lastInput.Name:sub(1, 7) == "Gamepad" then
		return "Press A or R2 as each circle meets its ring"
	end
	return if Scale.isTouch()
		then "Tap anywhere as each circle meets its ring"
		else "Press Space or click as each circle meets its ring"
end

function CatchCircles.show(
	self: any,
	circles: { Types.CatchCircle },
	windows: Types.CatchWindows,
	header: Header?,
	onPress: (index: number, grade: Types.CircleGrade?) -> (),
	strayId: string?
)
	self:hide()
	self._token += 1
	self._strayId = strayId
	self._doubt = nil :: number? -- #1727: the press this device called a Miss, until the server's CatchJudged for it
	self._windows = { perfect = math.max(0, windows.perfect), good = math.max(0, windows.good) }
	self._onPress = onPress
	self._next = 1
	self._active = true
	self._awaitingResult = false
	self._ended = false -- after this device's first Miss: the rest have gone and presses stop
	self._lastTarget = 0

	local info: Header = header or {}
	self._v3 = false
	local rarity = info.rarity or "Common"
	-- no charm stars after the name (F97 section 5: stars show nowhere now)
	-- #2110: the cat's own name with its coat ("Gold Forest Cat"), never just "Stray"; the coat's word is in the name,
	-- so the rarity pill says only the rarity
	self._name.Text = CatVariant.name(
		info.catName,
		if info.rainbow then "rainbow" elseif info.shiny then "gold" else "base"
	)
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	self._hint.Text = info.title or CatchCircles.hintWords(UserInputService:GetLastInputType())
	if circles[1] ~= nil and circles[1].hold == true and info.title == nil then
		self._hint.Text = HOLD_HINT -- #2920: the first catch's ring waits for the press, so no rush
	end
	self._header.UIStroke.Color = if info.rainbow
		then Theme.colors.white
		elseif info.shiny then Theme.colors.gold
		else Theme.hud.stroke
	self._headerRainbow.Enabled = info.rainbow == true

	self._circles = circles
	for index, circle in circles do
		local view = self:_buildView(index, circle)
		table.insert(self._views, view)
		self._lastTarget = math.max(self._lastTarget, view.holdUntil) -- #2920: a held ring waits past its target
		table.insert(
			self._pips,
			Create("Frame", {
				Name = "Pip" .. index,
				BackgroundColor3 = Theme.colors.cocoa,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Size = UDim2.fromOffset(PIP, PIP),
				Parent = self._strip,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = Theme.hud.stroke, Thickness = 2 }),
			})
		)
	end
	local count = #circles
	self._pipUpTo = 1
	self:_fitPips() -- #2332: at most PipWindow.MAX pips, sliding with the play
	self._strip.Visible = count > 0
	self._word.Name = "ResultWord"

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
		table.unpack(PRESS_KEYS)
	)

	self._tap.Visible = true
	self.screenGui.Enabled = true
	self._header.Visible = true -- #3009: the last result hid it
	Tween.popIn(self._header, 0.9)
	if count > 0 then
		Tween.popIn(self._strip, 0.9)
	end
	if type(info.trustNeed) == "number" then
		self:setTrust(info.trustStart or 0, info.trustNeed, info.model)
	end
	self._loop = RunService.RenderStepped:Connect(function()
		self:_step(now())
	end)
	self:_step(now())
end

-- Per frame: place each closer, time out circles nobody pressed, give up if the result never comes.
-- RenderStepped (not Heartbeat) so the drawn circle matches the frame the player sees when they press.
function CatchCircles._step(self: any, t: number)
	local windows: Types.CatchWindows = self._windows
	local lead = if self._v3 then LEAD_IN else PREVIEW_SECONDS
	for ringIndex, view in self._views :: { CircleView } do
		local circle = view.circle
		local visible = t >= circle.startsAt - lead
		if
			visible
			and not view.holder.Visible
			and self._v3
			and not view.judged
			and not Motion.reduced()
		then
			Tween.popIn(view.art, 0.6) -- #2060: the next ring pops in at its new spot (it just appears with reduced motion)
		end
		view.holder.Visible = visible
		if not visible then
			continue
		end
		if view.judged then
			continue
		end
		local started = t >= circle.startsAt
		view.closer.Visible = started
		view.ringStroke.Transparency = if started then 0 else 0.6
		if started then
			local radius = RING_RADIUS + (view.target - t) * view.speed
			radius = math.max(RING_RADIUS - windows.good * view.speed - 8, radius)
			if view.hold then
				-- #2920: the held ring stops on its ring and the prompt pulses until the press
				radius = math.max(RING_RADIUS, radius)
				local frozen = t >= view.target
				local prompt = view.prompt
				if prompt then
					if frozen and not prompt.Visible then
						prompt.Text = CatchCircles.holdWords()
						Moments.CircleHold:Fire(ringIndex) -- Sound's "now!" ping (#2928)
					end
					prompt.Visible = frozen
					local promptScale = view.promptScale
					if promptScale then
						promptScale.Scale = if frozen and not Motion.reduced()
							then 1 + 0.1 * math.sin((t - view.target) * HOLD_PULSE * 2 * math.pi)
							else 1
					end
				end
			end
			local diameter = 2 * (radius - CLOSER_THICKNESS / 2)
			view.closer.Size = UDim2.fromOffset(math.max(2, diameter), math.max(2, diameter))
		end
	end
	self:_expire(t)
	if self._awaitingResult == false and self._next > #self._views and #self._views > 0 then
		self._awaitingResult = true
		self._hint.Text = "Waiting for the result..."
	end
	if t > self._lastTarget + NO_RESULT_TIMEOUT and self._active then
		self:hide()
	end
end

-- Circles whose press window has closed on the server's terms count as misses here too, so the next
-- press goes to the next circle, the same order the server judges in.
function CatchCircles._expire(self: any, t: number)
	local windows: Types.CatchWindows = self._windows
	while true do
		local index: number = self._next
		local view: CircleView? = self._views[index]
		if
			not view
			or t
				<= (if view.hold then view.holdUntil else view.target + windows.good) + LATENCY_CAP
		then
			return
		end
		self._next = index + 1
		if self._v3 then
			-- Catch v3: an unpressed ring is a Miss and a paw ring left alone earns +1; the catch goes on
			if not view.judged then
				local grade: any = if view.paw then "left" else "miss"
				self:_trustBy(grade)
				self:_showGrade(index, grade, false)
			end
		elseif not self._ended then
			self:_showGrade(index, "miss", false)
			self:_endAfterMiss()
		end
	end
end

-- This device's first Miss (a press out of the bands or a circle nobody pressed): the server ends the catch on it
-- too, so every circle still showing goes now and no later press can draw a grade (catch-rework.md section 3). The
-- presses still go out (reviewer S101: the server judges on its own clock, so an edge press called a Miss here can
-- be Good there, and then it waits for the next circle's press). The server's result settles the words, the pips
-- and the result word.
function CatchCircles._endAfterMiss(self: any)
	self._ended = true
	for _, view in self._views :: { CircleView } do
		if not view.judged then
			view.judged = true
			clearCircle(view)
		end
	end
	if not self._awaitingResult then
		self._awaitingResult = true
		self._hint.Text = "Waiting for the result..."
	end
end

function CatchCircles._press(self: any)
	if not self._active then
		return
	end
	local t = now()
	self:_expire(t)
	local index: number = self._next
	local view: CircleView? = self._views[index]
	if not view then
		return
	end
	if t < view.circle.startsAt then
		return -- before the circle starts: the server ignores it too
	end
	if view.hold then
		-- #2920 (Derek2: "not even let the player click before its in the circle so you cant miss first one"): a
		-- press before the circle reaches the good band is dropped (the server drops it too, #2921), and any press from
		-- there until the hold runs out is a Perfect
		if t < view.target - self._windows.good then
			return
		end
		view.pressed = true
		if self._v3 then
			self:_trustBy("perfect")
		end
		local prompt = view.prompt
		if prompt then
			prompt.Visible = false
		end
		self:_showGrade(index, "perfect", false)
		self._next = index + 1
		local onPress = self._onPress
		if onPress then
			onPress(index, "perfect")
		end
		return
	end
	if self._v3 then
		-- Catch v3: every press is graded and the catch goes on whatever it was; a tapped paw ring is a Miss
		local held: Types.CatchWindows = self._windows
		local off = math.abs(t - view.target)
		local guess: Types.CircleGrade = if view.paw
			then "miss"
			elseif off <= held.perfect then "perfect"
			elseif off <= held.good then "good"
			else "miss"
		view.pressed = true
		self:_trustBy(guess)
		self:_showGrade(index, guess, false)
		self._next = index + 1
		local onPress = self._onPress
		if onPress then
			onPress(index, guess)
		end
		return
	end
	if self._doubt ~= nil and not self._ended then
		-- #1727: after a press this device called a Miss, before the server's word on it: sent with no grade (no grade
		-- sound, the server may have ended the catch) and the circle goes; its pip waits for its own CatchJudged
		local held: Types.CatchWindows = self._windows
		local off = math.abs(t - view.target)
		-- this device's guess, kept (not drawn) so a later Miss guess can be the next to wait on
		view.hint = if off <= held.perfect
			then "perfect"
			elseif off <= held.good then "good"
			else "miss"
		self._next = index + 1
		view.pressed = true
		if not view.judged then
			view.judged = true
			clearCircle(view)
		end
		local onPress = self._onPress
		if onPress then
			onPress(index, nil)
		end
		return
	end
	if self._ended then
		-- after this device's first Miss: sent with no grade (so no grade sound) and drawn nowhere
		self._next = index + 1
		view.pressed = true
		local onPress = self._onPress
		if onPress then
			onPress(index, nil)
		end
		return
	end
	local windows: Types.CatchWindows = self._windows
	local offset = math.abs(t - view.target)
	local grade: Types.CircleGrade = if offset <= windows.perfect
		then "perfect"
		elseif offset <= windows.good then "good"
		else "miss"
	view.pressed = true
	self:_showGrade(index, grade, false)
	self._next = index + 1
	local onPress = self._onPress
	if onPress then
		onPress(index, grade)
	end
	if grade == "miss" and self._doubt == nil then
		-- #1727: only a guess until the server's CatchJudged: the later circles stay up for now
		self._doubt = index
	end
end

-- #1727: the server's grade for one press (CatchJudged, catcher only, one per judged press). Its pip takes that
-- grade; a Miss ends the catch here as it did there (every circle still showing goes), and a Good or Perfect on the
-- press this device called a Miss lets the catch go on. An unpressed circle's expiry sends none: _expire and the
-- CatchResult cover that.
function CatchCircles.judged(
	self: any,
	strayId: string,
	index: number,
	grade: Types.CircleGrade,
	trust: number?
)
	if not self._active or self._ended or (self._strayId ~= nil and self._strayId ~= strayId) then
		return
	end
	if self._views[index] == nil then
		return
	end
	if self._v3 then
		-- Catch v3: the server's grade and its running trust; nothing ends here, CatchResult does
		self:_showGrade(index, grade, true)
		if type(trust) == "number" then
			self._trust = trust
			self._trustBar:set(trust, self._need)
		end
		return
	end
	self:_showGrade(index, grade, true)
	if grade == "miss" then
		self:_endAfterMiss()
	elseif self._doubt == index then
		self._doubt = nil
		-- a later press sent while in doubt that this device also called a Miss is the next one to wait on
		for later = index + 1, self._next - 1 do
			local view: CircleView? = self._views[later]
			if view and view.pressed and view.hint == "miss" then
				self._doubt = later
				break
			end
		end
	end
end

-- #2332: the strip's pips from PipWindow (the ring after the last judged one rightmost), and the strip sized to them.
function CatchCircles._fitPips(self: any)
	local first, last = PipWindow.range(#self._pips, self._pipUpTo or 1)
	for index, pip in self._pips :: { Frame } do
		pip.Visible = index >= first and index <= last
	end
	local shown = math.max(0, last - first + 1)
	self._strip.Size = UDim2.fromOffset(
		shown * PIP + math.max(0, shown - 1) * PIP_GAP + 2 * STRIP_PAD,
		PIP + 2 * STRIP_PAD
	)
end

-- The circle clears and its pip in the strip takes the grade's colour; the pip pops again only if the server's grade
-- differs from this device's guess. No word shows on the circle: the one result word comes at the end.
function CatchCircles._showGrade(
	self: any,
	index: number,
	grade: Types.CircleGrade,
	_final: boolean
)
	local view: CircleView? = self._views[index]
	if not view then
		return
	end
	local changed = view.hint ~= grade
	view.hint = grade
	if not view.judged then
		view.judged = true
		clearCircle(view)
	end
	if index + 1 > (self._pipUpTo or 1) then
		self._pipUpTo = index + 1
		self:_fitPips()
	end
	local pip: Frame? = self._pips[index]
	if pip then
		pip.BackgroundColor3 = GRADE_COLOR[grade]
		if changed then
			Tween.popIn(pip, 0.6)
		end
	end
end

-- Catch v3 (#1884): CatchSchedule's trust turns this catch onto trust, from show's header or as UIController's
-- UI.catch.trust hook hears it: the strip goes, the trust bar shows over `model`, and a Miss no longer ends it.
function CatchCircles.setTrust(self: any, trustStart: number, trustNeed: number, model: Model?)
	if not self._active or trustNeed <= 0 then
		return
	end
	self._v3 = true
	self._need = trustNeed
	self._trust = trustStart
	self._model = model
	self._ended = false
	self._doubt = nil
	self._strip.Visible = false -- the trust bar over the cat replaces the strip
	-- #2060: every ring at its own spot, away from the one before
	local spots = CatchSpots.spots(self._circles)
	for index, view in self._views :: { CircleView } do
		local spot: Vector2? = spots[index]
		if spot then
			view.holder.Position = UDim2.fromScale(spot.X, spot.Y)
		end
	end
	self._word.Name = "FinishBanner"
	self:_placeBar()
	self._trustBar:show(model, trustStart, trustNeed)
end

-- Catch v3: this device's guess moves the bar at once; the server's CatchJudged trust replaces it.
function CatchCircles._trustBy(self: any, grade: string)
	self._trust += CatchTrust.delta(grade)
	self._trustBar:set(self._trust, self._need)
end

-- Local hint for a circle, or nil while it is open. Tests and the demo read it.
function CatchCircles.gradeLocal(self: any, index: number): Types.CircleGrade?
	local view: CircleView? = self._views[index]
	return if view then view.hint else nil
end

-- The server's verdict. Each graded circle's pip takes the server's grade (it pops again only where this device
-- guessed differently), circles after the Miss go, every pip takes its server colour, and the result word slams in
-- over the strip (Components/CatchWords). #3009: the header goes at once (it stays only for a result with its own
-- hint, F87's "Try again!"), the strip and the word fade from RESULT's fadeAt and the overlay hides at its seconds;
-- onDone runs then.
function CatchCircles.showResult(self: any, outcome: Outcome, onDone: (() -> ())?)
	if not self._active then
		if onDone then
			onDone()
		end
		return
	end
	self._token += 1
	local token = self._token
	self._awaitingResult = true
	self._ended = true
	self._onPress = nil -- the catch is over: later taps go nowhere
	-- #2405 (Derek2: "for mobile people who need to click screen to move cant move for a second due to their screen
	-- being covered"): the full-screen tap catcher goes at once, so the result word and strip show over a screen that
	-- moves again (a thumbstick or a tap to move) instead of eating every touch for the result's 1.8 s
	self._tap.Visible = false
	ContextActionService:UnbindAction(ACTION_NAME)
	local grades = outcome.grades
	for index, view in self._views :: { CircleView } do
		view.pressed = true
		local grade: Types.CircleGrade? = grades[index]
		if grade ~= nil then
			self:_showGrade(index, grade, true)
		elseif not view.judged then
			-- after the Miss: the server never judged it
			view.judged = true
			clearCircle(view)
		end
	end
	for index, pip in self._pips :: { Frame } do
		if grades[index] == nil then
			pip.BackgroundColor3 = Theme.colors.cocoa
		end
	end

	-- the strip steps back so the word over it reads (its pips have their server colours by now)
	Tween.to(self._strip, UNDER_WORD, { BackgroundTransparency = 0.85 })
	for _, pip in self._pips :: { Frame } do
		Tween.to(pip, UNDER_WORD, { BackgroundTransparency = 0.6 })
		local stroke = pip:FindFirstChildOfClass("UIStroke")
		if stroke then
			Tween.to(stroke, UNDER_WORD, { Transparency = 0.7 })
		end
	end

	local success = outcome.success
	local finish: Finish? = outcome.finish
	local v3 = self._v3 or finish ~= nil
	local result = if v3
		then CatchWords.finish(if finish then finish.finish else nil, grades, success)
		else CatchWords.result(grades, success)
	local word: TextLabel = self._word
	word.Name = if v3 then "FinishBanner" else "ResultWord"
	word.Text = CatchWords.TEXT[result]
	word.TextColor3 = RESULT_COLOR[result]
	-- Catch v3: a catch's banner waits for the net wrap (FINISH_DELAY); a bolt shows at once
	local delay = if v3 and success then FINISH_DELAY else 0
	if v3 then
		local trust = if finish and type(finish.trust) == "number"
			then finish.trust
			else self._trust
		local need = if finish and type(finish.trustNeed) == "number"
			then finish.trustNeed
			else self._need
		self._trust = trust
		self._trustBar:set(trust, need)
		self._trustBar:finish(success)
	end
	local function slam()
		if self._token ~= token then
			return
		end
		word.TextTransparency = 0
		self._wordStroke.Transparency = 0
		word.Visible = true
		Tween.popIn(word, if result == "close" then 0.8 else 0.45)
		if result == "close" then
			wobble(word)
		end
	end
	if delay > 0 then
		task.delay(delay, slam)
	else
		slam()
	end
	-- #3009: the header is gone the moment the cat is caught or bolts (the carry banner and the "It got away!" toast
	-- say what comes next); only a result with its own line (F87's "Try again!") keeps it up to show that line
	if outcome.hint ~= nil then
		self._hint.Text = outcome.hint
	else
		self._header.Visible = false
	end

	local timing = if success then RESULT.caught else RESULT.missed
	local fade = TweenInfo.new(
		timing.seconds - timing.fadeAt,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(delay + timing.fadeAt, function()
		if self._token ~= token then
			return
		end
		Tween.to(word, fade, { TextTransparency = 1 })
		Tween.to(self._wordStroke, fade, { Transparency = 1 })
		Tween.to(self._strip, fade, { BackgroundTransparency = 1 })
		for _, pip in self._pips :: { Frame } do
			Tween.to(pip, fade, { BackgroundTransparency = 1 })
			local stroke = pip:FindFirstChildOfClass("UIStroke")
			if stroke then
				Tween.to(stroke, fade, { Transparency = 1 })
			end
		end
	end)
	task.delay(delay + timing.seconds, function()
		if self._token ~= token then
			return
		end
		self:hide()
		if onDone then
			onDone()
		end
	end)
end

function CatchCircles.strayId(self: any): string?
	return self._strayId
end

function CatchCircles.isActive(self: any): boolean
	return self._active
end

function CatchCircles.hide(self: any)
	self._token += 1
	self._active = false
	self._awaitingResult = false
	self._onPress = nil
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	ContextActionService:UnbindAction(ACTION_NAME)
	for _, view in self._views :: { CircleView } do
		view.holder:Destroy()
	end
	table.clear(self._views)
	for _, pip in self._pips :: { Frame } do
		pip:Destroy()
	end
	table.clear(self._pips)
	self._ended = false
	self._doubt = nil
	self._strayId = nil
	self._strip.Visible = false
	self._strip.BackgroundTransparency = self._stripTransparency
	self._word.Visible = false
	self._trustBar:hide()
	self._v3 = false
	self._model = nil
	self._circles = {}
	self.screenGui.Enabled = false
end

function CatchCircles.destroy(self: any)
	self:hide()
	self._trustBar:destroy()
	self._tapConnection:Disconnect()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return CatchCircles
