--!strict
-- The net's closing circles (F26, data-model section 10). The server sends the schedule: each circle
-- appears at startsAt and closes onto its ring at startsAt + shrinkSeconds, in server time, at a screen
-- position. The player presses (tap anywhere, E, Space, click or the gamepad's A) as each circle meets
-- its ring. The UI only says which circle a press was for; the server stamps the time on arrival and
-- judges it. Grades drawn before showResult are hints from this device; showResult replaces them with
-- the server's scores.
--
-- Bands: the closing circle moves at a constant speed, so a timing window of w seconds is a band of
-- w x speed pixels either side of the ring. Good is the wide green band, Perfect the thin gold one.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

export type Header = {
	catName: string?,
	rarity: string?,
	stars: number?,
	shiny: boolean?,
	title: string?, -- replaces the hint line, e.g. "Catch it as it falls!" on a tree rescue
}

export type CatchCircles = {
	screenGui: ScreenGui,
	show: (
		self: CatchCircles,
		circles: { Types.CatchCircle },
		windows: Types.CatchWindows,
		header: Header?,
		onPress: (index: number) -> ()
	) -> (),
	showResult: (
		self: CatchCircles,
		scores: { number },
		chance: number,
		success: boolean,
		failText: string?,
		onDone: (() -> ())?
	) -> (),
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
	closer: Frame,
	closerStroke: UIStroke,
	ring: Frame,
	ringStroke: UIStroke,
	number: TextLabel,
	grade: TextLabel,
	judged: boolean,
	pressed: boolean,
}

local RING_RADIUS = 46 -- design pixels at 1280 x 720
local START_RADIUS = RING_RADIUS * 3
local PREVIEW_SECONDS = 0.35 -- the ring fades in this long before its circle starts
local CLOSER_THICKNESS = 4
local RING_THICKNESS = 4
-- data-model CatchLatencyCapSeconds (0.15): the server stops waiting for a circle's press this long
-- after the good window closes. Read from Config once the engineer adds it.
local LATENCY_CAP: number = Config.CatchLatencyCapSeconds
local RESULT_SECONDS = 1.6
local NO_RESULT_TIMEOUT = 4 -- hide if the server's result has not come this long after the last target
local ACTION_NAME = "CatCafeCatchPress"
local PRESS_KEYS =
	{ Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }

local GRADE_TEXT: { [string]: string } = { perfect = "Perfect!", good = "Good", miss = "Miss" }
local GRADE_COLOR: { [string]: Color3 } = {
	perfect = Theme.colors.gold,
	good = Theme.colors.good,
	miss = Theme.colors.warn,
}

local CatchCircles = {}
CatchCircles.__index = CatchCircles

local function now(): number
	return Workspace:GetServerTimeNow()
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
	self._onPress = nil :: ((index: number) -> ())?
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

	-- Result banner: per-circle grades sit on the circles, the chance and the outcome sit here
	local banner: Frame = Create("Frame", {
		Name = "Result",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(320, 74),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 2 }),
	})
	self._banner = banner
	self._chance = Create("TextLabel", {
		Name = "Chance",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		Text = "",
		Parent = banner,
	})
	self._outcome = Create("TextLabel", {
		Name = "Outcome",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 36),
		FontFace = Theme.fonts.display,
		TextSize = 28,
		TextColor3 = Theme.hud.text,
		Text = "",
		Parent = banner,
	})

	self._circleLayer = Create("Frame", {
		Name = "Circles",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})

	if parent then
		screenGui.Parent = parent
	end
	return self :: CatchCircles
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
	band("GoodBand", RING_RADIUS - good, RING_RADIUS + good, Theme.colors.good, 0.45, holder)
	band(
		"PerfectBand",
		RING_RADIUS - perfect,
		RING_RADIUS + perfect,
		Theme.colors.gold,
		0.1,
		holder
	)
	local ring = circleFrame("Ring", RING_RADIUS - RING_THICKNESS / 2, holder)
	local ringStroke: UIStroke = Create(
		"UIStroke",
		{ Color = Theme.colors.paper, Thickness = RING_THICKNESS, Parent = ring }
	)
	local closer = circleFrame("Closer", START_RADIUS, holder)
	local closerStroke: UIStroke = Create("UIStroke", {
		Color = Theme.colors.paper,
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
		Parent = holder,
	})
	local grade: TextLabel = Create("TextLabel", {
		Name = "Grade",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -(RING_RADIUS + 10)),
		Size = UDim2.fromOffset(160, 32),
		FontFace = Theme.fonts.display,
		TextSize = 24,
		TextColor3 = Theme.colors.paper,
		TextStrokeColor3 = Theme.colors.ink,
		TextStrokeTransparency = 0.3,
		Text = "",
		Visible = false,
		Parent = holder,
	})
	return {
		circle = circle,
		target = circle.startsAt + shrink,
		speed = speed,
		holder = holder,
		closer = closer,
		closerStroke = closerStroke,
		ring = ring,
		ringStroke = ringStroke,
		number = number,
		grade = grade,
		judged = false,
		pressed = false,
	}
end

function CatchCircles.show(
	self: any,
	circles: { Types.CatchCircle },
	windows: Types.CatchWindows,
	header: Header?,
	onPress: (index: number) -> ()
)
	self:hide()
	self._token += 1
	self._windows = { perfect = math.max(0, windows.perfect), good = math.max(0, windows.good) }
	self._onPress = onPress
	self._next = 1
	self._active = true
	self._awaitingResult = false
	self._lastTarget = 0

	local info: Header = header or {}
	local rarity = info.rarity or "Common"
	local name = info.catName or "Stray cat"
	if info.stars then
		name ..= "  " .. Format.stars(info.stars :: number)
	end
	self._name.Text = name
	self._rarity.Text = if info.shiny then rarity .. "  ·  Shiny" else rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	self._hint.Text = info.title
		or (
			if Scale.isTouch()
				then "Tap anywhere as each circle meets its ring"
				else "Press E or click as each circle meets its ring"
		)
	self._header.UIStroke.Color = if info.shiny then Theme.colors.gold else Theme.hud.stroke
	self._banner.Visible = false

	for index, circle in circles do
		local view = self:_buildView(index, circle)
		table.insert(self._views, view)
		self._lastTarget = math.max(self._lastTarget, view.target)
	end

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

	self.screenGui.Enabled = true
	Tween.popIn(self._header, 0.9)
	self._loop = RunService.RenderStepped:Connect(function()
		self:_step(now())
	end)
	self:_step(now())
end

-- Per frame: place each closer, time out circles nobody pressed, give up if the result never comes.
-- RenderStepped (not Heartbeat) so the drawn circle matches the frame the player sees when they press.
function CatchCircles._step(self: any, t: number)
	local windows: Types.CatchWindows = self._windows
	for _, view in self._views :: { CircleView } do
		local circle = view.circle
		local visible = t >= circle.startsAt - PREVIEW_SECONDS
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
		local view: CircleView? = self._views[self._next]
		if not view then
			return
		end
		if t <= view.target + windows.good + LATENCY_CAP then
			return
		end
		self:_showGrade(self._next, "miss", false)
		view.closer.Visible = false
		self._next += 1
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
		onPress(index)
	end
end

function CatchCircles._showGrade(self: any, index: number, grade: Types.CircleGrade, final: boolean)
	local view: CircleView? = self._views[index]
	if not view then
		return
	end
	view.judged = true
	view.grade.Text = GRADE_TEXT[grade]
	view.grade.TextColor3 = GRADE_COLOR[grade]
	view.grade.TextTransparency = if final then 0 else 0.25
	view.grade.Visible = true
	view.closerStroke.Color = GRADE_COLOR[grade]
	view.ringStroke.Color = GRADE_COLOR[grade]
	if final then
		Tween.popIn(view.grade, 0.6)
	end
end

-- Local hint for a circle, or nil while it is open. Tests and the demo read it.
function CatchCircles.gradeLocal(self: any, index: number): Types.CircleGrade?
	local view: CircleView? = self._views[index]
	if not view or not view.judged then
		return nil
	end
	local text = view.grade.Text
	for grade, label in GRADE_TEXT do
		if label == text then
			return grade :: Types.CircleGrade
		end
	end
	return nil
end

-- The server's verdict (CatchResult): scores per circle (1, 0.5 or 0), the chance (0 to 1) and the roll.
-- failText is the outcome line on a failed roll ("It got away", "Missed, try again"). onDone runs after the
-- banner has shown, when the overlay hides.
function CatchCircles.showResult(
	self: any,
	scores: { number },
	chance: number,
	success: boolean,
	failText: string?,
	onDone: (() -> ())?
)
	if not self._active then
		if onDone then
			onDone()
		end
		return
	end
	self._token += 1
	local token = self._token
	self._awaitingResult = true
	ContextActionService:UnbindAction(ACTION_NAME)
	for index, view in self._views :: { CircleView } do
		local score = scores[index] or 0
		local grade: Types.CircleGrade = if score >= 1
			then "perfect"
			elseif score >= 0.5 then "good"
			else "miss"
		view.pressed = true
		view.closer.Visible = false
		self:_showGrade(index, grade, true)
	end
	local percentText = tostring(math.floor(math.clamp(chance, 0, 1) * 100 + 0.5)) .. "%"
	self._chance.Text = "Catch chance " .. percentText
	self._outcome.Text = if success then "Caught!" else (failText or "It got away")
	self._outcome.TextColor3 = if success then Theme.colors.good else Theme.colors.warn
	self._banner.UIStroke.Color = if success then Theme.colors.good else Theme.colors.warn
	self._banner.Visible = true
	Tween.popIn(self._banner, 0.8)
	self._hint.Text = if success then "Carry it home to check in" else ""
	task.delay(RESULT_SECONDS, function()
		if self._token ~= token then
			return
		end
		self:hide()
		if onDone then
			onDone()
		end
	end)
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
	self._banner.Visible = false
	self.screenGui.Enabled = false
end

function CatchCircles.destroy(self: any)
	self:hide()
	self._tapConnection:Disconnect()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return CatchCircles
