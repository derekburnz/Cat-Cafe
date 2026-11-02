--!nocheck
--[[
	ui-shim: a screen for the UI gate (uigate.mjs). It sits on world-shim.luau, which already has instances,
	properties, Clone, attributes and the value types, and adds what the UI needs to build and lay out its windows
	in the cloud:
	  - a client: Players.LocalPlayer with a PlayerGui, RunService:IsClient(), GuiService, UserInputService,
	    TextService and a camera whose ViewportSize is the screen being checked;
	  - signals that work (Connect, Once, Wait, Fire), property and attribute changed signals, and a virtual clock:
	    task.wait, task.delay and task.defer queue on it, Heartbeat steps with it, and advance(seconds) runs it;
	  - tweens that jump to their goal at once and fire Completed when their time is up;
	  - Roblox's 2D layout: Size and Position in scale and offset, AnchorPoint, UIScale, UIPadding, UIListLayout,
	    UIGridLayout, UISizeConstraint, UIAspectRatioConstraint, AutomaticSize, ScrollingFrame canvases,
	    ClipsDescendants and TextScaled with UITextSizeConstraint. AbsoluteSize, AbsolutePosition,
	    AbsoluteContentSize, AbsoluteCanvasSize, AbsoluteWindowSize and TextBounds read from it.
	Text is measured with average glyph widths per font, not real font files, so a text size is right to about 10%.

	Called with (worldShim, profile). profile = { width, height, touch, inset }.
]]

local World, profile = ...
local I = World.internals
local state, methods, InstanceMT, isA = I.state, I.methods, I.InstanceMT, I.isA
local env = I.env
local V = I.values
local Vector2, Color3, Font, Enum = V.Vector2, V.Color3, V.Font, V.Enum

local UIShim = {}
UIShim.errors = {}
UIShim.warnings = {}

local function note(list, text)
	if #list < 400 then
		table.insert(list, text)
	end
end

------------------------------------------------------------------------------------------------------------------
-- Classes the world shim does not know

local SUPER = I.SUPER
for className, super in
	{
		ScrollingFrame = "GuiObject",
		ViewportFrame = "GuiObject",
		CanvasGroup = "GuiObject",
		VideoFrame = "GuiObject",
		UIListLayout = "UIGridStyleLayout",
		UIGridLayout = "UIGridStyleLayout",
		UIPageLayout = "UIGridStyleLayout",
		UITableLayout = "UIGridStyleLayout",
		UIGridStyleLayout = "UILayout",
		UILayout = "UIComponent",
		UIPadding = "UIComponent",
		UIScale = "UIComponent",
		UIGradient = "UIComponent",
		UIFlexItem = "UIComponent",
		UISizeConstraint = "UIConstraint",
		UIAspectRatioConstraint = "UIConstraint",
		UITextSizeConstraint = "UIConstraint",
		UIConstraint = "UIComponent",
		UIDragDetector = "UIComponent",
		PlayerGui = "BasePlayerGui",
		BasePlayerGui = "Instance",
		Player = "Instance",
		Tween = "TweenBase",
		TweenBase = "Instance",
	}
do
	SUPER[className] = super
end

------------------------------------------------------------------------------------------------------------------
-- Value types the world shim keeps generic

local UDim = {}
local UDimMT = { __type = "UDim" }
UDimMT.__index = UDimMT
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMT)
end
UDimMT.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UDimMT.__add = function(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end
UDimMT.__sub = function(a, b)
	return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset)
end
UDimMT.__unm = function(a)
	return UDim.new(-a.Scale, -a.Offset)
end

local UDim2 = {}
local UDim2MT = { __type = "UDim2" }
local udim2methods = {}
UDim2MT.__index = function(self, key)
	if key == "Width" then
		return rawget(self, "X")
	elseif key == "Height" then
		return rawget(self, "Y")
	end
	return udim2methods[key]
end
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then
		-- UDim2.new(UDim, UDim)
		return setmetatable({ X = UDim.new(xs.Scale, xs.Offset), Y = UDim.new(xo.Scale, xo.Offset) }, UDim2MT)
	end
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UDim2MT)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function udim2methods.Lerp(a, b, t)
	return UDim2.new(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end
UDim2MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UDim2MT.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim2MT.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UDim2MT.__tostring = function(u)
	return string.format("{%g, %g}, {%g, %g}", u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset)
end

local Rect = {}
local RectMT = { __type = "Rect" }
RectMT.__index = function(self, key)
	if key == "Width" then
		return self.Max.X - self.Min.X
	elseif key == "Height" then
		return self.Max.Y - self.Min.Y
	end
	return nil
end
function Rect.new(a, b, c, d)
	if type(a) == "number" then
		return setmetatable({ Min = Vector2.new(a, b), Max = Vector2.new(c, d) }, RectMT)
	end
	return setmetatable({ Min = a or Vector2.zero, Max = b or Vector2.zero }, RectMT)
end

local TweenInfo = {}
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return setmetatable({
		Time = time or 1,
		EasingStyle = style or Enum.EasingStyle.Quad,
		EasingDirection = direction or Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}, { __type = "TweenInfo" })
end

-- Vector2 extras the world shim leaves out
local V2 = getmetatable(Vector2.new(0, 0))
local v2index = V2.__index
local v2extra = {
	Min = function(a, ...)
		local x, y = a.X, a.Y
		for _, b in { ... } do
			x, y = math.min(x, b.X), math.min(y, b.Y)
		end
		return Vector2.new(x, y)
	end,
	Max = function(a, ...)
		local x, y = a.X, a.Y
		for _, b in { ... } do
			x, y = math.max(x, b.X), math.max(y, b.Y)
		end
		return Vector2.new(x, y)
	end,
	Abs = function(a)
		return Vector2.new(math.abs(a.X), math.abs(a.Y))
	end,
	Floor = function(a)
		return Vector2.new(math.floor(a.X), math.floor(a.Y))
	end,
	Ceil = function(a)
		return Vector2.new(math.ceil(a.X), math.ceil(a.Y))
	end,
	Cross = function(a, b)
		return a.X * b.Y - a.Y * b.X
	end,
	FuzzyEq = function(a, b, eps)
		eps = eps or 1e-5
		return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps
	end,
}
V2.__index = function(self, key)
	local extra = v2extra[key]
	if extra then
		return extra
	end
	return v2index(self, key)
end
V2.__unm = function(a)
	return Vector2.new(-a.X, -a.Y)
end
V2.__tostring = function(a)
	return string.format("%g, %g", a.X, a.Y)
end

env.UDim = UDim
env.UDim2 = UDim2
env.Rect = Rect
env.TweenInfo = TweenInfo

------------------------------------------------------------------------------------------------------------------
-- The virtual clock and task

local clock = 0
local queue = {}
local seq = 0
local cancelled = setmetatable({}, { __mode = "k" })
local BASE_TIME = 1793534400 -- 2026-11-01 12:00 UTC, so dates and day counts are the same every run

local function reportError(err, thread)
	local trace = thread and debug.traceback(thread) or ""
	note(UIShim.errors, tostring(err) .. (if trace ~= "" then "\n" .. trace else ""))
end

local function resume(thread, ...)
	if cancelled[thread] or coroutine.status(thread) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		reportError(err, thread)
	end
end

local function schedule(at, thread, ...)
	seq += 1
	table.insert(queue, { at = at, seq = seq, thread = thread, args = table.pack(...) })
end

local function threadOf(f)
	if type(f) == "thread" then
		return f
	end
	return coroutine.create(f)
end

local task = {}
function task.spawn(f, ...)
	local thread = threadOf(f)
	resume(thread, ...)
	return thread
end
function task.defer(f, ...)
	local thread = threadOf(f)
	schedule(clock, thread, ...)
	return thread
end
function task.delay(seconds, f, ...)
	local thread = threadOf(f)
	schedule(clock + (seconds or 0), thread, ...)
	return thread
end
function task.wait(seconds)
	seconds = math.max(seconds or 0, 1 / 60)
	if not coroutine.isyieldable() then
		clock += seconds
		return seconds
	end
	local start = clock
	schedule(clock + seconds, coroutine.running())
	coroutine.yield()
	return clock - start
end
function task.cancel(thread)
	if type(thread) == "thread" then
		cancelled[thread] = true
	end
end
function task.synchronize() end
function task.desynchronize() end

env.task = task
env.wait = task.wait
env.delay = function(seconds, f)
	return task.delay(seconds, f)
end
env.spawn = function(f)
	return task.defer(f)
end
env.tick = function()
	return BASE_TIME + clock
end
env.time = function()
	return clock
end
env.elapsedTime = env.time
local realOs = os
env.os = setmetatable({
	time = function(t)
		if t ~= nil then
			return realOs.time(t)
		end
		return math.floor(BASE_TIME + clock)
	end,
	clock = function()
		return clock
	end,
}, { __index = realOs })
env.DateTime = {
	now = function()
		local now = BASE_TIME + clock
		return { UnixTimestamp = math.floor(now), UnixTimestampMillis = math.floor(now * 1000) }
	end,
	fromUnixTimestamp = function(t)
		return { UnixTimestamp = t, UnixTimestampMillis = t * 1000 }
	end,
}
env.warn = function(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[index] = tostring(select(index, ...))
	end
	note(UIShim.warnings, table.concat(parts, " "))
end
env.print = function() end
math.randomseed(7)

------------------------------------------------------------------------------------------------------------------
-- Signals

local ConnMT = { __type = "RBXScriptConnection" }
ConnMT.__index = ConnMT
function ConnMT:Disconnect()
	self.Connected = false
end

local SignalMT = { __type = "RBXScriptSignal" }
SignalMT.__index = SignalMT
local function newSignal()
	return setmetatable({ handlers = {}, waiting = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	local conn = setmetatable({ Connected = true, fn = fn }, ConnMT)
	table.insert(self.handlers, conn)
	return conn
end
SignalMT.ConnectParallel = SignalMT.Connect
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Connected = false
		fn(...)
	end)
	return conn
end
function SignalMT:Wait()
	local thread = coroutine.running()
	table.insert(self.waiting, thread)
	return coroutine.yield()
end
local function fire(signal, ...)
	if signal == nil then
		return
	end
	local live = {}
	for _, conn in signal.handlers do
		if conn.Connected then
			table.insert(live, conn)
		end
	end
	signal.handlers = live
	for _, conn in live do
		if conn.Connected then
			task.spawn(conn.fn, ...)
		end
	end
	local waiting = signal.waiting
	signal.waiting = {}
	for _, thread in waiting do
		resume(thread, ...)
	end
end
UIShim.newSignal = newSignal
UIShim.fire = fire

local EVENT_NAMES = {}
for name in I.EVENTS do
	EVENT_NAMES[name] = true
end
for _, name in
	{
		"InputChanged",
		"MouseButton1Up",
		"MouseButton2Click",
		"MouseButton2Down",
		"MouseButton2Up",
		"MouseMoved",
		"MouseWheelForward",
		"MouseWheelBackward",
		"TouchTap",
		"TouchLongPress",
		"TouchPan",
		"TouchSwipe",
		"TouchStarted",
		"TouchMoved",
		"SelectionGained",
		"SelectionLost",
		"FocusLost",
		"Focused",
		"ReturnPressedFromOnScreenKeyboard",
		"MessageOut",
		"PromptTriggered",
		"PromptTriggerEnded",
		"PromptButtonHoldBegan",
		"PreRender",
		"PostSimulation",
		"LastInputTypeChanged",
		"WindowFocused",
		"WindowFocusReleased",
		"TextBoundsChanged",
		"Idled",
		"OnInvoke",
		"MenuOpened",
		"MenuClosed",
		"DragStart",
		"DragContinue",
		"DragEnd",
		"PageEnter",
		"PageLeave",
		"Stopped",
		"DidLoop",
		"Loaded",
		"Paused",
		"Resumed",
		"GamepadConnected",
		"GamepadDisconnected",
		"JumpRequest",
		"TextBoxFocused",
		"TextBoxFocusReleased",
		"DeviceRotationChanged",
		"PointerAction",
		"ViewportSizeChanged",
	}
do
	EVENT_NAMES[name] = true
end

local eventSignals = setmetatable({}, { __mode = "k" })
local function eventOf(instance, name)
	local map = eventSignals[instance]
	if map == nil then
		map = {}
		eventSignals[instance] = map
	end
	local signal = map[name]
	if signal == nil then
		signal = newSignal()
		map[name] = signal
	end
	return signal
end
UIShim.eventOf = eventOf

local propSignals = setmetatable({}, { __mode = "k" })
local attrSignals = setmetatable({}, { __mode = "k" })
local computedWatch = {} -- instance -> { [prop]: lastValue } for computed props someone listens to

local COMPUTED_PROPS = {
	AbsoluteSize = true,
	AbsolutePosition = true,
	AbsoluteContentSize = true,
	AbsoluteCanvasSize = true,
	AbsoluteWindowSize = true,
	TextBounds = true,
	TextFits = true,
	AbsoluteCellSize = true,
	AbsoluteCellCount = true,
}

function methods.GetPropertyChangedSignal(self, prop)
	local map = propSignals[self]
	if map == nil then
		map = {}
		propSignals[self] = map
	end
	local signal = map[prop]
	if signal == nil then
		signal = newSignal()
		map[prop] = signal
		if COMPUTED_PROPS[prop] then
			local watch = computedWatch[self]
			if watch == nil then
				watch = {}
				computedWatch[self] = watch
			end
			watch[prop] = false -- read on the next settle
		end
	end
	return signal
end
function methods.GetAttributeChangedSignal(self, name)
	local map = attrSignals[self]
	if map == nil then
		map = {}
		attrSignals[self] = map
	end
	local signal = map[name]
	if signal == nil then
		signal = newSignal()
		map[name] = signal
	end
	return signal
end
function methods.SetAttribute(self, name, value)
	local attrs = state[self].attrs
	local old = attrs[name]
	attrs[name] = value
	if old ~= value then
		local map = attrSignals[self]
		if map then
			fire(map[name])
		end
		local events = eventSignals[self]
		if events then
			fire(events.AttributeChanged, name)
		end
	end
end

------------------------------------------------------------------------------------------------------------------
-- Defaults Roblox gives GUI instances

local function enum(t, item)
	return Enum[t][item]
end

local WHITE = Color3.fromRGB(255, 255, 255)
local GUI_DEFAULTS = {
	Size = UDim2.new(0, 100, 0, 100),
	Position = UDim2.new(0, 0, 0, 0),
	AnchorPoint = Vector2.new(0, 0),
	Rotation = 0,
	AutomaticSize = enum("AutomaticSize", "None"),
	BackgroundColor3 = WHITE,
	BorderColor3 = Color3.fromRGB(27, 42, 53),
	BorderSizePixel = 1,
	ClipsDescendants = false,
	Active = false,
	Selectable = false,
	Interactable = true,
	AutoButtonColor = true,
	Modal = false,
	Selected = false,
	SizeConstraint = enum("SizeConstraint", "RelativeXY"),
	TextColor3 = Color3.fromRGB(0, 0, 0),
	TextWrapped = false,
	TextTruncate = enum("TextTruncate", "None"),
	TextXAlignment = enum("TextXAlignment", "Center"),
	TextYAlignment = enum("TextYAlignment", "Center"),
	RichText = false,
	TextStrokeTransparency = 1,
	TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
	LineHeight = 1,
	MaxVisibleGraphemes = -1,
	FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
	PlaceholderText = "",
	PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
	ClearTextOnFocus = true,
	MultiLine = false,
	TextEditable = true,
	ShowNativeInput = true,
	CursorPosition = 1,
	Image = "",
	ImageColor3 = WHITE,
	ImageTransparency = 0,
	ImageRectOffset = Vector2.new(0, 0),
	ImageRectSize = Vector2.new(0, 0),
	ScaleType = enum("ScaleType", "Stretch"),
	SliceCenter = Rect.new(0, 0, 0, 0),
	SliceScale = 1,
	TileSize = UDim2.new(1, 0, 1, 0),
	ResampleMode = enum("ResamplerMode", "Default"),
	CanvasSize = UDim2.new(0, 0, 2, 0),
	CanvasPosition = Vector2.new(0, 0),
	ScrollBarThickness = 12,
	ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0),
	ScrollBarImageTransparency = 0,
	ScrollingDirection = enum("ScrollingDirection", "XY"),
	AutomaticCanvasSize = enum("AutomaticSize", "None"),
	ScrollingEnabled = true,
	ElasticBehavior = enum("ElasticBehavior", "WhenScrollable"),
	VerticalScrollBarInset = enum("ScrollBarInset", "None"),
	HorizontalScrollBarInset = enum("ScrollBarInset", "None"),
	VerticalScrollBarPosition = enum("VerticalScrollBarPosition", "Right"),
	TopImage = "",
	MidImage = "",
	BottomImage = "",
	GroupTransparency = 0,
	GroupColor3 = WHITE,
	Ambient = Color3.fromRGB(200, 200, 200),
	LightColor = Color3.fromRGB(140, 140, 140),
	LightDirection = V.Vector3.new(-1, -1, -1),
	DisplayOrder = 0,
	IgnoreGuiInset = false,
	ResetOnSpawn = true,
	ZIndexBehavior = enum("ZIndexBehavior", "Sibling"),
	ScreenInsets = enum("ScreenInsets", "CoreUISafeInsets"),
	ClipToDeviceSafeArea = true,
	SafeAreaCompatibility = enum("SafeAreaCompatibility", "FullscreenExtension"),
	AlwaysOnTop = false,
	StudsOffset = V.Vector3.new(0, 0, 0),
	ExtentsOffset = V.Vector3.new(0, 0, 0),
	MaxDistance = math.huge,
	LightInfluence = 1,
	Face = enum("NormalId", "Front"),
	SizingMode = enum("SurfaceGuiSizingMode", "FixedSize"),
	CanvasSize2 = nil,
}
local COMPONENT_DEFAULTS = {
	Scale = 1,
	Padding = UDim.new(0, 0),
	SortOrder = enum("SortOrder", "LayoutOrder"),
	HorizontalAlignment = enum("HorizontalAlignment", "Left"),
	VerticalAlignment = enum("VerticalAlignment", "Top"),
	HorizontalFlex = enum("UIFlexAlignment", "None"),
	VerticalFlex = enum("UIFlexAlignment", "None"),
	ItemLineAlignment = enum("ItemLineAlignment", "Automatic"),
	Wraps = false,
	CellSize = UDim2.new(0, 100, 0, 100),
	CellPadding = UDim2.new(0, 5, 0, 5),
	FillDirectionMaxCells = 0,
	StartCorner = enum("StartCorner", "TopLeft"),
	PaddingTop = UDim.new(0, 0),
	PaddingBottom = UDim.new(0, 0),
	PaddingLeft = UDim.new(0, 0),
	PaddingRight = UDim.new(0, 0),
	MinSize = Vector2.new(0, 0),
	MaxSize = Vector2.new(math.huge, math.huge),
	AspectRatio = 1,
	AspectType = enum("AspectType", "FitWithinMaxSize"),
	DominantAxis = enum("DominantAxis", "Width"),
	MaxTextSize = 100,
	MinTextSize = 1,
	Thickness = 1,
	Color = WHITE,
	Transparency = 0,
	ApplyStrokeMode = enum("ApplyStrokeMode", "Contextual"),
	LineJoinMode = enum("LineJoinMode", "Round"),
	CornerRadius = UDim.new(0, 8),
	Offset = Vector2.new(0, 0),
	Rotation = 0,
}

local CLASS_DEFAULTS = {
	UIListLayout = { FillDirection = enum("FillDirection", "Vertical") },
	UIGridLayout = { FillDirection = enum("FillDirection", "Horizontal") },
	UIPageLayout = { FillDirection = enum("FillDirection", "Horizontal") },
	ScrollingFrame = { ClipsDescendants = true, Active = true, Selectable = true },
	CanvasGroup = { ClipsDescendants = true },
	ViewportFrame = { ClipsDescendants = false },
	TextButton = { Active = true, Selectable = true, Text = "Button" },
	ImageButton = { Active = true, Selectable = true },
	TextBox = { Active = true, Selectable = true, Text = "TextBox" },
	TextLabel = { Text = "Label" },
	Camera = {
		FieldOfView = 70,
		CFrame = V.CFrame.new(0, 10, 0),
		CameraType = enum("CameraType", "Custom"),
	},
	UIStroke = { Color = Color3.fromRGB(0, 0, 0) },
}

local function defaultFor(self, key)
	local className = state[self].ClassName
	local own = CLASS_DEFAULTS[className]
	if own and own[key] ~= nil then
		return own[key]
	end
	if isA(className, "GuiBase2d") then
		return GUI_DEFAULTS[key]
	elseif isA(className, "UIComponent") then
		return COMPONENT_DEFAULTS[key]
	end
	return nil
end

------------------------------------------------------------------------------------------------------------------
-- Layout

-- The layout is incremental: a property change marks the instance and every ancestor (subDirty), and computeAll
-- re-places only what is marked or whose box moved. A full pass per change made the UI's build quadratic.
local layoutDirty = true
local subDirty = {} -- instance -> true while it or something under it changed since it was last placed
local cache = setmetatable({}, { __mode = "k" }) -- GuiObject -> { x, y, w, h, k, clip, ... } in screen pixels
local layoutInfo = setmetatable({}, { __mode = "k" }) -- UILayout -> { w, h, cellW, cellH, count }
local playerGui -- set below
local computeAll -- forward

local function rawProp(self, key)
	local value = state[self].props[key]
	if value == nil then
		value = I.DEFAULTS[key]
		if value == nil then
			value = defaultFor(self, key)
		end
	end
	return value
end

local function childrenOf(self)
	return state[self].children
end

local function classOf(self)
	return state[self].ClassName
end

local function isGuiObject(self)
	return isA(classOf(self), "GuiObject")
end

-- GuiObject children, looking through Folders the way Roblox does
local function guiChildren(self, out)
	out = out or {}
	for _, child in childrenOf(self) do
		local className = classOf(child)
		if isA(className, "GuiObject") then
			table.insert(out, child)
		elseif className == "Folder" then
			guiChildren(child, out)
		end
	end
	return out
end

local function firstChildOf(self, className)
	for _, child in childrenOf(self) do
		if classOf(child) == className then
			return child
		end
	end
	return nil
end

local function uiScaleOf(self)
	local scale = firstChildOf(self, "UIScale")
	if scale then
		local value = rawProp(scale, "Scale")
		if type(value) == "number" and value > 0 then
			return value
		end
	end
	return 1
end

local function layoutOf(self)
	for _, child in childrenOf(self) do
		local className = classOf(child)
		if className == "UIListLayout" or className == "UIGridLayout" or className == "UIPageLayout" or className == "UITableLayout" then
			return child
		end
	end
	return nil
end

local function enumName(value)
	if type(value) == "table" then
		return value.Name
	end
	return tostring(value)
end

local function udim(value, size, k)
	return value.Scale * size + value.Offset * k
end

local function padding(self, w, h, k)
	local pad = firstChildOf(self, "UIPadding")
	if not pad then
		return 0, 0, 0, 0
	end
	return udim(rawProp(pad, "PaddingLeft"), w, k),
		udim(rawProp(pad, "PaddingRight"), w, k),
		udim(rawProp(pad, "PaddingTop"), h, k),
		udim(rawProp(pad, "PaddingBottom"), h, k)
end

local function applyConstraints(self, w, h, k)
	for _, child in childrenOf(self) do
		local className = classOf(child)
		if className == "UISizeConstraint" then
			local minS, maxS = rawProp(child, "MinSize"), rawProp(child, "MaxSize")
			w = math.clamp(w, minS.X * k, math.max(minS.X * k, maxS.X * k))
			h = math.clamp(h, minS.Y * k, math.max(minS.Y * k, maxS.Y * k))
		end
	end
	for _, child in childrenOf(self) do
		if classOf(child) == "UIAspectRatioConstraint" then
			local ratio = rawProp(child, "AspectRatio")
			if ratio and ratio > 0 then
				local aspectType = enumName(rawProp(child, "AspectType"))
				local dominant = enumName(rawProp(child, "DominantAxis"))
				if aspectType == "ScaleWithParentSize" then
					if dominant == "Height" then
						w = h * ratio
					else
						h = w / ratio
					end
				elseif h > 0 and w / h > ratio then
					w = h * ratio
				else
					h = w / ratio
				end
			end
		end
	end
	return w, h
end

-- Text: average glyph widths in ems per font family, emoji wider
local GLYPH = {
	FredokaOne = 0.56,
	Nunito = 0.52,
	SourceSansPro = 0.48,
	GothamSSm = 0.58,
	Montserrat = 0.58,
	Arial = 0.5,
	BuilderSans = 0.5,
}
local function familyName(self)
	local face = rawProp(self, "FontFace")
	local family = face and face.Family or ""
	return string.match(family, "families/([%w]+)%.json") or string.match(tostring(family), "Enum%.Font%.(%w+)") or tostring(family)
end
UIShim.familyName = familyName

local function plainText(self)
	local text = rawProp(self, "Text") or ""
	if text == "" and classOf(self) == "TextBox" then
		text = rawProp(self, "PlaceholderText") or ""
	end
	if rawProp(self, "RichText") then
		text = string.gsub(text, "<[^>]->", "")
		text = string.gsub(text, "&lt;", "<")
		text = string.gsub(text, "&gt;", ">")
		text = string.gsub(text, "&amp;", "&")
	end
	return text
end
UIShim.plainText = plainText

local function lineWidth(line, size, em)
	local width = 0
	for _, code in utf8.codes(line) do
		if code >= 0x1F000 then
			width += 1.15 -- emoji
		elseif (code >= 0x2600 and code <= 0x27BF) or (code >= 0x2B00 and code <= 0x2BFF) then
			width += 0.95 -- symbols such as a star or a heart
		elseif code == 0xFE0F or code == 0x200D then
			width += 0
		elseif code == 32 then
			width += 0.28
		elseif code >= 65 and code <= 90 then
			width += em * 1.18
		elseif code == 105 or code == 108 or code == 49 or code == 46 or code == 44 or code == 39 or code == 33 then
			width += em * 0.55
		else
			width += em
		end
	end
	return width * size
end

-- the lines a text breaks into at `size` within `maxWidth` (nil: no wrapping), and the widest line
local function wrapText(text, size, em, maxWidth)
	local lines, widest = 0, 0
	for paragraph in string.gmatch(text .. "\n", "(.-)\n") do
		if maxWidth == nil then
			lines += 1
			widest = math.max(widest, lineWidth(paragraph, size, em))
		else
			local current = ""
			local any = false
			for word in string.gmatch(paragraph, "%S+") do
				local candidate = if current == "" then word else current .. " " .. word
				if lineWidth(candidate, size, em) <= maxWidth or current == "" then
					current = candidate
				else
					lines += 1
					widest = math.max(widest, lineWidth(current, size, em))
					current = word
				end
				any = true
			end
			lines += 1
			widest = math.max(widest, lineWidth(current, size, em))
			local _ = any
		end
	end
	return lines, widest
end

local function textConstraint(self)
	return firstChildOf(self, "UITextSizeConstraint")
end

-- the size text renders at, in screen pixels, in a box of w x h (screen pixels) under scale k
local function renderedTextSize(self, w, h, k)
	local text = plainText(self)
	local em = GLYPH[familyName(self)] or 0.5
	local constraint = textConstraint(self)
	if rawProp(self, "TextScaled") then
		local maxSize = 100 * k
		local minSize = 1
		if constraint then
			maxSize = math.min(maxSize, (rawProp(constraint, "MaxTextSize") or 100) * k)
			minSize = (rawProp(constraint, "MinTextSize") or 1) * k
		end
		if text == "" then
			return maxSize
		end
		local wrap = rawProp(self, "TextWrapped")
		local lo, hi = 1, math.max(1, math.floor(maxSize))
		local best = 1
		while lo <= hi do
			local mid = math.floor((lo + hi) / 2)
			local lines, widest = wrapText(text, mid, em, if wrap then w else nil)
			if widest <= w + 0.5 and lines * mid * (rawProp(self, "LineHeight") or 1) <= h + 0.5 then
				best = mid
				lo = mid + 1
			else
				hi = mid - 1
			end
		end
		return math.max(best, minSize)
	end
	local size = (rawProp(self, "TextSize") or 14) * k
	if constraint then
		size = math.clamp(size, (rawProp(constraint, "MinTextSize") or 1) * k, (rawProp(constraint, "MaxTextSize") or 100) * k)
	end
	-- text draws at whole pixel sizes, so under a UIScale a row's width does not shrink smoothly with the scale. Code
	-- that resizes from its own width can then flip between two sizes every frame (the prize rows Derek saw shake
	-- on 2026-10-28); the jitter check catches that only if the shim snaps too.
	return math.max(1, math.floor(size + 0.5))
end

local function textExtent(self, size, maxWidth)
	local text = plainText(self)
	if text == "" then
		return 0, 0
	end
	local em = GLYPH[familyName(self)] or 0.5
	local lines, widest = wrapText(text, size, em, maxWidth)
	return widest, lines * size * (rawProp(self, "LineHeight") or 1)
end

local function isTextObject(self)
	local className = classOf(self)
	return className == "TextLabel" or className == "TextButton" or className == "TextBox"
end

local function autoAxes(self, prop)
	local name = enumName(rawProp(self, prop or "AutomaticSize"))
	return name == "X" or name == "XY", name == "Y" or name == "XY"
end

local measure -- forward
local arrange -- forward

-- what the children (and text) need, in screen pixels, for a box of aw x ah under scale kk, padding included
local function contentExtent(self, aw, ah, kk)
	local pl, pr, pt, pb = padding(self, aw, ah, kk)
	local iw, ih = math.max(0, aw - pl - pr), math.max(0, ah - pt - pb)
	local ex, ey = 0, 0
	if isTextObject(self) then
		local size = renderedTextSize(self, iw, ih, kk)
		local autoX = autoAxes(self)
		local tw, th = textExtent(self, size, if rawProp(self, "TextWrapped") and not autoX then iw else nil)
		ex, ey = math.max(ex, tw), math.max(ey, th)
	end
	local layout = layoutOf(self)
	if layout then
		local _, cw, ch = arrange(self, layout, iw, ih, kk)
		ex, ey = math.max(ex, cw), math.max(ey, ch)
	else
		for _, child in guiChildren(self) do
			if rawProp(child, "Visible") ~= false then
				local cw, ch = measure(child, iw, ih, kk)
				local pos, ap = rawProp(child, "Position"), rawProp(child, "AnchorPoint")
				local right = udim(pos.X, iw, kk) - ap.X * cw + cw
				local bottom = udim(pos.Y, ih, kk) - ap.Y * ch + ch
				ex, ey = math.max(ex, right), math.max(ey, bottom)
			end
		end
	end
	return ex + pl + pr, ey + pt + pb
end

-- a GuiObject's size in screen pixels inside a parent content box of pw x ph under scale k; also the scale its
-- children see (k times its own UIScale)
function measure(self, pw, ph, k, depth)
	depth = (depth or 0) + 1
	local size = rawProp(self, "Size")
	local constraintMode = enumName(rawProp(self, "SizeConstraint"))
	local refW, refH = pw, ph
	if constraintMode == "RelativeXX" then
		refH = pw
	elseif constraintMode == "RelativeYY" then
		refW = ph
	end
	local w = udim(size.X, refW, k)
	local h = udim(size.Y, refH, k)
	w, h = applyConstraints(self, w, h, k)
	local u = uiScaleOf(self)
	local kk = k * u
	local autoX, autoY = autoAxes(self)
	if (autoX or autoY) and depth < 40 then
		local cw, ch = contentExtent(self, w * u, h * u, kk)
		if autoX then
			w = math.max(w, cw / u)
		end
		if autoY then
			h = math.max(h, ch / u)
		end
		w, h = applyConstraints(self, w, h, k)
	end
	return math.max(0, w * u), math.max(0, h * u), kk
end

local function sortedLayoutChildren(self, layout)
	local list = {}
	local index = {}
	for i, child in guiChildren(self) do
		if rawProp(child, "Visible") ~= false then
			table.insert(list, child)
			index[child] = i
		end
	end
	local byName = enumName(rawProp(layout, "SortOrder")) == "Name"
	table.sort(list, function(a, b)
		if byName then
			local na, nb = state[a].Name, state[b].Name
			if na ~= nb then
				return na < nb
			end
		else
			local la, lb = rawProp(a, "LayoutOrder") or 0, rawProp(b, "LayoutOrder") or 0
			if la ~= lb then
				return la < lb
			end
		end
		return index[a] < index[b]
	end)
	return list
end

-- places a layout's children in a content box of iw x ih: { [child] = { x, y, w, h, k } } relative to the box,
-- and the content size
function arrange(self, layout, iw, ih, kk)
	local placed = {}
	local children = sortedLayoutChildren(self, layout)
	local className = classOf(layout)
	local hAlign = enumName(rawProp(layout, "HorizontalAlignment"))
	local vAlign = enumName(rawProp(layout, "VerticalAlignment"))
	local horizontal = enumName(rawProp(layout, "FillDirection")) == "Horizontal"
	if className == "UIGridLayout" then
		local cell, gap = rawProp(layout, "CellSize"), rawProp(layout, "CellPadding")
		local cw, ch = udim(cell.X, iw, kk), udim(cell.Y, ih, kk)
		local gx, gy = udim(gap.X, iw, kk), udim(gap.Y, ih, kk)
		local maxCells = rawProp(layout, "FillDirectionMaxCells") or 0
		local perLine
		if horizontal then
			perLine = math.max(1, math.floor((iw + gx + 0.01) / math.max(1, cw + gx)))
		else
			perLine = math.max(1, math.floor((ih + gy + 0.01) / math.max(1, ch + gy)))
		end
		if maxCells > 0 then
			perLine = math.min(perLine, maxCells)
		end
		local n = #children
		local lines = math.ceil(n / perLine)
		local across = math.min(n, perLine)
		local contentW, contentH
		if horizontal then
			contentW = across * cw + math.max(0, across - 1) * gx
			contentH = lines * ch + math.max(0, lines - 1) * gy
		else
			contentW = lines * cw + math.max(0, lines - 1) * gx
			contentH = across * ch + math.max(0, across - 1) * gy
		end
		local ox = if hAlign == "Center" then (iw - contentW) / 2 elseif hAlign == "Right" then iw - contentW else 0
		local oy = if vAlign == "Center" then (ih - contentH) / 2 elseif vAlign == "Bottom" then ih - contentH else 0
		for i, child in children do
			local a, b = (i - 1) % perLine, math.floor((i - 1) / perLine)
			local col, row = if horizontal then a else b, if horizontal then b else a
			placed[child] = { x = ox + col * (cw + gx), y = oy + row * (ch + gy), w = cw, h = ch, k = kk * uiScaleOf(child) }
		end
		layoutInfo[layout] = { w = contentW, h = contentH, cellW = cw, cellH = ch, count = n, perLine = perLine }
		return placed, contentW, contentH
	end
	-- UIListLayout (and page or table layouts, read as a list)
	local gapUDim = rawProp(layout, "Padding") or UDim.new(0, 0)
	local gap = udim(gapUDim, if horizontal then iw else ih, kk)
	local wraps = rawProp(layout, "Wraps") == true
	local sizes = {}
	for _, child in children do
		local w, h, ck = measure(child, iw, ih, kk)
		sizes[child] = { w = w, h = h, k = ck }
	end
	-- lines (one unless Wraps)
	local lineList = { { items = {}, main = 0, cross = 0 } }
	for _, child in children do
		local s = sizes[child]
		local main, cross = if horizontal then s.w else s.h, if horizontal then s.h else s.w
		local line = lineList[#lineList]
		local limit = if horizontal then iw else ih
		if wraps and #line.items > 0 and line.main + gap + main > limit + 0.5 then
			line = { items = {}, main = 0, cross = 0 }
			table.insert(lineList, line)
		end
		if #line.items > 0 then
			line.main += gap
		end
		table.insert(line.items, child)
		line.main += main
		line.cross = math.max(line.cross, cross)
	end
	local contentMain, contentCross = 0, 0
	for i, line in lineList do
		contentMain = math.max(contentMain, line.main)
		contentCross += line.cross + (if i > 1 then gap else 0)
	end
	local crossCursor = 0
	if horizontal then
		crossCursor = if vAlign == "Center" then (ih - contentCross) / 2 elseif vAlign == "Bottom" then ih - contentCross else 0
	else
		crossCursor = if hAlign == "Center" then (iw - contentCross) / 2 elseif hAlign == "Right" then iw - contentCross else 0
	end
	for _, line in lineList do
		local cursor
		if horizontal then
			cursor = if hAlign == "Center" then (iw - line.main) / 2 elseif hAlign == "Right" then iw - line.main else 0
		else
			cursor = if vAlign == "Center" then (ih - line.main) / 2 elseif vAlign == "Bottom" then ih - line.main else 0
		end
		for _, child in line.items do
			local s = sizes[child]
			local x, y
			if horizontal then
				x = cursor
				local free = (if #lineList == 1 then ih else line.cross) - s.h
				y = crossCursor + (if vAlign == "Center" then free / 2 elseif vAlign == "Bottom" then free else 0)
				if #lineList == 1 then
					y = if vAlign == "Center" then (ih - s.h) / 2 elseif vAlign == "Bottom" then ih - s.h else 0
				end
				cursor += s.w + gap
			else
				y = cursor
				x = if hAlign == "Center" then (iw - s.w) / 2 elseif hAlign == "Right" then iw - s.w else 0
				if #lineList > 1 then
					x = crossCursor
				end
				cursor += s.h + gap
			end
			placed[child] = { x = x, y = y, w = s.w, h = s.h, k = s.k }
		end
		crossCursor += line.cross + gap
	end
	local cw, ch = if horizontal then contentMain else contentCross, if horizontal then contentCross else contentMain
	layoutInfo[layout] = { w = cw, h = ch }
	return placed, cw, ch
end

local function intersect(a, b)
	if a == nil then
		return b
	end
	if b == nil then
		return a
	end
	return { math.max(a[1], b[1]), math.max(a[2], b[2]), math.min(a[3], b[3]), math.min(a[4], b[4]) }
end

local place -- forward
local function placeChildren(self, x, y, aw, ah, kk, clip, inScroll, gui)
	local className = classOf(self)
	local childClip = clip
	if className == "ScrollingFrame" or rawProp(self, "ClipsDescendants") == true then
		childClip = intersect(clip, { x, y, x + aw, y + ah })
	end
	local originX, originY, boxW, boxH = x, y, aw, ah
	local scroll = inScroll
	if className == "ScrollingFrame" then
		scroll = true
		local canvas = rawProp(self, "CanvasSize")
		local cw, ch = udim(canvas.X, aw, kk), udim(canvas.Y, ah, kk)
		local autoX, autoY = autoAxes(self, "AutomaticCanvasSize")
		if autoX or autoY then
			-- children measure against the canvas, which is never smaller than the window
			local ew, eh =
				contentExtent(self, if autoX then 0 else math.max(cw, aw), if autoY then 0 else math.max(ch, ah), kk)
			if autoX then
				cw = math.max(cw, ew)
			end
			if autoY then
				ch = math.max(ch, eh)
			end
		end
		local bar = (rawProp(self, "ScrollBarThickness") or 12) * kk
		local direction = enumName(rawProp(self, "ScrollingDirection"))
		local windowW, windowH = aw, ah
		if ch > ah + 0.5 and direction ~= "X" then
			windowW = aw - bar
		end
		if cw > aw + 0.5 and direction ~= "Y" then
			windowH = ah - bar
		end
		-- AbsoluteCanvasSize is at least AbsoluteWindowSize: a CanvasSize of 0 still lets a row fill the width
		cw, ch = math.max(cw, windowW), math.max(ch, windowH)
		local canvasPos = rawProp(self, "CanvasPosition") or Vector2.zero
		local maxX, maxY = math.max(0, cw - windowW), math.max(0, ch - windowH)
		local sx = math.clamp(canvasPos.X, 0, maxX)
		local sy = math.clamp(canvasPos.Y, 0, maxY)
		local entry = cache[self]
		entry.canvasW, entry.canvasH, entry.windowW, entry.windowH = cw, ch, windowW, windowH
		originX, originY, boxW, boxH = x - sx, y - sy, cw, ch
	end
	local pl, pr, pt, pb = padding(self, boxW, boxH, kk)
	local cx, cy = originX + pl, originY + pt
	local iw, ih = math.max(0, boxW - pl - pr), math.max(0, boxH - pt - pb)
	local layout = layoutOf(self)
	if layout then
		local placed = arrange(self, layout, iw, ih, kk)
		for child, p in placed do
			place(child, cx + p.x, cy + p.y, p.w, p.h, p.k, childClip, scroll, gui)
		end
		-- hidden children still get a box so AbsoluteSize reads something
		for _, child in guiChildren(self) do
			if placed[child] == nil then
				local w, h, ck = measure(child, iw, ih, kk)
				place(child, cx, cy, w, h, ck, childClip, scroll, gui)
			end
		end
	else
		for _, child in guiChildren(self) do
			local w, h, ck = measure(child, iw, ih, kk)
			local pos, ap = rawProp(child, "Position"), rawProp(child, "AnchorPoint")
			local px = cx + udim(pos.X, iw, kk) - ap.X * w
			local py = cy + udim(pos.Y, ih, kk) - ap.Y * h
			place(child, px, py, w, h, ck, childClip, scroll, gui)
		end
	end
end

local function sameClip(a, b)
	if a == b then
		return true
	end
	if a == nil or b == nil then
		return false
	end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

function place(self, x, y, aw, ah, kk, clip, inScroll, gui)
	local old = cache[self]
	if
		old ~= nil
		and not subDirty[self]
		and old.x == x
		and old.y == y
		and old.w == aw
		and old.h == ah
		and old.k == kk
		and old.scroll == inScroll
		and old.gui == gui
		and sameClip(old.clip, clip)
	then
		return -- nothing under it changed and its box is where it was
	end
	subDirty[self] = nil
	cache[self] = { x = x, y = y, w = aw, h = ah, k = kk, clip = clip, scroll = inScroll, gui = gui }
	placeChildren(self, x, y, aw, ah, kk, clip, inScroll, gui)
end

local INSET = profile.inset or 58

local function screenRect(gui)
	if rawProp(gui, "IgnoreGuiInset") == true or enumName(rawProp(gui, "ScreenInsets")) == "None" then
		return 0, 0, profile.width, profile.height
	end
	return 0, INSET, profile.width, profile.height - INSET
end

local function layoutScreenGui(gui)
	local x, y, w, h = screenRect(gui)
	local k = uiScaleOf(gui)
	if cache[gui] ~= nil and not subDirty[gui] then
		return
	end
	subDirty[gui] = nil
	cache[gui] = { x = x, y = y, w = w, h = h, k = k, gui = gui }
	for _, child in guiChildren(gui) do
		local cw, ch, ck = measure(child, w, h, k)
		local pos, ap = rawProp(child, "Position"), rawProp(child, "AnchorPoint")
		place(child, x + udim(pos.X, w, k) - ap.X * cw, y + udim(pos.Y, h, k) - ap.Y * ch, cw, ch, ck, nil, false, gui)
	end
end

-- BillboardGui and SurfaceGui: a canvas of their own size, so code that reads AbsoluteSize there gets numbers
local function layoutWorldGui(gui)
	local size = rawProp(gui, "Size") or UDim2.new(0, 200, 0, 50)
	local w, h = math.max(1, size.X.Offset), math.max(1, size.Y.Offset)
	if classOf(gui) == "SurfaceGui" then
		w, h = 800, 600
	end
	if cache[gui] ~= nil and not subDirty[gui] then
		return
	end
	subDirty[gui] = nil
	cache[gui] = { x = 0, y = 0, w = w, h = h, k = 1, gui = gui, world = true }
	placeChildren(gui, 0, 0, w, h, 1, nil, false, gui)
	for _, child in guiChildren(gui) do
		cache[child].world = true
	end
end

local function walkGuis(root, out)
	for _, child in childrenOf(root) do
		local className = classOf(child)
		if className == "ScreenGui" or className == "BillboardGui" or className == "SurfaceGui" then
			table.insert(out, child)
		end
		walkGuis(child, out)
	end
	return out
end

function computeAll()
	if not layoutDirty then
		return
	end
	layoutDirty = false
	-- the client's screens and the world's billboards (not ReplicatedStorage's 464 asset models)
	local guis = walkGuis(playerGui, {})
	walkGuis(World.service("Workspace"), guis)
	for _, gui in guis do
		if classOf(gui) == "ScreenGui" then
			layoutScreenGui(gui)
		else
			layoutWorldGui(gui)
		end
	end
end

local function boxOf(self)
	computeAll()
	local entry = cache[self]
	if entry == nil then
		-- not under any LayerCollector: lay it out on its own against the screen
		local w, h, k = measure(self, profile.width, profile.height, 1)
		entry = { x = 0, y = 0, w = w, h = h, k = k }
	end
	return entry
end
UIShim.boxOf = boxOf

local function computed(self, key)
	local className = classOf(self)
	if key == "AbsoluteSize" or key == "AbsolutePosition" then
		if not (isA(className, "GuiBase2d")) then
			return nil
		end
		local box = boxOf(self)
		if key == "AbsoluteSize" then
			return Vector2.new(box.w, box.h)
		end
		-- GUI space starts under the top bar inset, as in Roblox
		return Vector2.new(box.x, box.y - INSET)
	elseif key == "AbsoluteRotation" then
		return 0
	elseif key == "AbsoluteContentSize" then
		if not isA(className, "UILayout") then
			return nil
		end
		computeAll()
		local info = layoutInfo[self]
		return if info then Vector2.new(info.w, info.h) else Vector2.zero
	elseif key == "AbsoluteCellSize" then
		computeAll()
		local info = layoutInfo[self]
		return if info and info.cellW then Vector2.new(info.cellW, info.cellH) else Vector2.zero
	elseif key == "AbsoluteCellCount" then
		computeAll()
		local info = layoutInfo[self]
		return if info and info.perLine then Vector2.new(info.perLine, math.ceil(info.count / info.perLine)) else Vector2.zero
	elseif key == "AbsoluteCanvasSize" or key == "AbsoluteWindowSize" then
		if className ~= "ScrollingFrame" then
			return nil
		end
		local box = boxOf(self)
		if key == "AbsoluteCanvasSize" then
			return Vector2.new(box.canvasW or box.w, box.canvasH or box.h)
		end
		return Vector2.new(box.windowW or box.w, box.windowH or box.h)
	elseif key == "TextBounds" or key == "TextFits" then
		if not isTextObject(self) then
			return nil
		end
		local box = boxOf(self)
		local pl, pr, pt, pb = padding(self, box.w, box.h, box.k)
		local iw, ih = math.max(0, box.w - pl - pr), math.max(0, box.h - pt - pb)
		local size = renderedTextSize(self, iw, ih, box.k)
		local tw, th = textExtent(self, size, if rawProp(self, "TextWrapped") then iw else nil)
		if key == "TextBounds" then
			return Vector2.new(tw, th)
		end
		return tw <= iw + 0.5 and th <= ih + 0.5
	end
	return nil
end

------------------------------------------------------------------------------------------------------------------
-- Instance access: computed props, events, defaults, change signals

local GENERIC_EVENTS = {
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	AncestryChanged = true,
	Destroying = true,
	AttributeChanged = true,
}
local classMethod -- set with the client methods below

local worldIndex = InstanceMT.__index
local worldNewIndex = InstanceMT.__newindex

InstanceMT.__index = function(self, key)
	if COMPUTED_PROPS[key] or key == "AbsoluteRotation" then
		local value = computed(self, key)
		if value ~= nil then
			return value
		end
	end
	local own = classMethod(self, key)
	if own ~= nil then
		return own
	end
	if EVENT_NAMES[key] and methods[key] == nil and (GENERIC_EVENTS[key] or I.findChild(self, key) == nil) then
		return eventOf(self, key)
	end
	local value = worldIndex(self, key)
	if value == nil then
		return defaultFor(self, key)
	end
	return value
end

-- properties that never move a box (the snapshot reads them fresh), so a fade or a colour tween costs nothing
local NO_GEOMETRY = {
	BackgroundColor3 = true,
	BackgroundTransparency = true,
	BorderColor3 = true,
	TextColor3 = true,
	TextTransparency = true,
	TextStrokeColor3 = true,
	TextStrokeTransparency = true,
	ImageColor3 = true,
	ImageTransparency = true,
	ImageRectOffset = true,
	ImageRectSize = true,
	Image = true,
	ZIndex = true,
	Rotation = true,
	Active = true,
	Selectable = true,
	AutoButtonColor = true,
	GroupTransparency = true,
	GroupColor3 = true,
	Color = true,
	Transparency = true,
	Offset = true,
	Thickness = true,
	Enabled = true,
	ScrollBarImageColor3 = true,
	ScrollBarImageTransparency = true,
	PlaybackState = true,
	Interactable = true,
	PlaceholderColor3 = true,
	DisplayOrder = true,
}

-- set while UIShim.watch runs: instance -> property -> { changes, values, distinct, last }
local recording = nil

local function valueKey(value)
	local kind = type(value)
	if kind == "number" then
		return string.format("%.3f", value)
	elseif kind == "table" then
		local mt = getmetatable(value)
		if mt and mt.__tostring then
			return tostring(value)
		end
		local parts = {}
		for _, field in { "X", "Y", "Z", "R", "G", "B", "Scale", "Offset" } do
			local part = rawget(value, field)
			if part == nil then
				local ok, got = pcall(function()
					return value[field]
				end)
				part = if ok then got else nil
			end
			if part ~= nil then
				table.insert(parts, field .. "=" .. valueKey(part))
			end
		end
		return if #parts > 0 then table.concat(parts, ",") else tostring(value)
	end
	return tostring(value)
end

local function markDirty(node)
	layoutDirty = true
	while node ~= nil do
		subDirty[node] = true
		local s = state[node]
		node = s and s.Parent
	end
end

InstanceMT.__newindex = function(self, key, value)
	local s = state[self]
	local old
	if key == "Parent" then
		old = s.Parent
	elseif key ~= "Name" then
		old = s.props[key]
	end
	worldNewIndex(self, key, value)
	if recording and old ~= value then
		local perInstance = recording[self]
		if perInstance == nil then
			perInstance = {}
			recording[self] = perInstance
		end
		local entry = perInstance[key]
		if entry == nil then
			entry = { changes = 0, values = {}, distinct = 0, last = valueKey(old) }
			entry.values[entry.last] = true
			entry.distinct = 1
			perInstance[key] = entry
		end
		local shown = valueKey(value)
		if shown ~= entry.last then
			entry.changes += 1
			entry.last = shown
		end
		if not entry.values[shown] then
			entry.values[shown] = true
			entry.distinct += 1
		end
	end
	if key == "Parent" then
		if old ~= nil then
			markDirty(old)
		end
		markDirty(self)
	elseif not NO_GEOMETRY[key] then
		markDirty(self)
	end
	if old ~= value then
		local map = propSignals[self]
		if map and map[key] then
			fire(map[key])
		end
		local events = eventSignals[self]
		if events and events.Changed then
			fire(events.Changed, key)
		end
		if key == "Parent" then
			if old ~= nil and eventSignals[old] then
				fire(eventSignals[old].ChildRemoved, self)
			end
			if value ~= nil and eventSignals[value] then
				fire(eventSignals[value].ChildAdded, self)
			end
			if events and events.AncestryChanged then
				fire(events.AncestryChanged, self, value)
			end
		end
	end
end

-- computed props people listen to: fire their changed signals when the layout moves them
local function fireComputed()
	for instance, watch in computedWatch do
		if state[instance] == nil or state[instance].destroyed then
			computedWatch[instance] = nil
			continue
		end
		for prop, last in watch do
			local now = computed(instance, prop)
			local same = false
			if last ~= false and now ~= nil then
				if typeof(now) == "boolean" then
					same = now == last
				else
					same = math.abs(now.X - last.X) < 0.01 and math.abs(now.Y - last.Y) < 0.01
				end
			end
			if not same and now ~= nil then
				watch[prop] = now
				if last ~= false or true then
					local map = propSignals[instance]
					if map then
						fire(map[prop])
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------------------------------
-- Methods the client needs. Most belong to one class (TweenService:Create, Tween:Play); they are moved into
-- CLASS_METHODS below so a child of the same name ("Create" in UI/Components) still resolves on other classes.

function methods.IsClient()
	return true
end
function methods.IsServer()
	return false
end
function methods.IsStudio()
	return false
end
function methods.GetServerTimeNow()
	return BASE_TIME + clock
end
function methods.Destroy(self)
	local s = state[self]
	for _, child in table.clone(s.children) do
		methods.Destroy(child)
	end
	if s.Parent ~= nil then
		InstanceMT.__newindex(self, "Parent", nil)
	end
	s.destroyed = true
	local events = eventSignals[self]
	if events and events.Destroying then
		fire(events.Destroying)
	end
	subDirty[self] = nil
end
function methods.WaitForChild(self, name, timeout)
	local child = I.findChild(self, name)
	if child ~= nil then
		return child
	end
	if not coroutine.isyieldable() then
		return nil
	end
	-- wait on ChildAdded like Roblox; a timeout gives nil, no timeout waits for good
	local thread = coroutine.running()
	local done = false
	local conn
	conn = eventOf(self, "ChildAdded"):Connect(function(added)
		if not done and state[added].Name == name then
			done = true
			conn:Disconnect()
			resume(thread, added)
		end
	end)
	if timeout then
		task.delay(timeout, function()
			if not done then
				done = true
				conn:Disconnect()
				resume(thread, nil)
			end
		end)
	end
	return coroutine.yield()
end

local function makeTween(instance, info, goals)
	local tween = I.newInstance("Tween")
	state[tween].props.PlaybackState = Enum.PlaybackState.Begin
	state[tween].tween = { instance = instance, info = info or TweenInfo.new(), goals = goals or {} }
	return tween
end
function methods.Create(self, instance, info, goals)
	return makeTween(instance, info, goals)
end
function methods.Play(self)
	local data = state[self].tween
	if data == nil then
		return
	end
	-- jump to the goal: the gate looks at where things end up
	for key, value in data.goals do
		data.instance[key] = value
	end
	state[self].props.PlaybackState = Enum.PlaybackState.Playing
	local info = data.info
	local repeats = info.RepeatCount or 0
	if repeats < 0 then
		return
	end
	local total = ((info.Time or 0) + (info.DelayTime or 0)) * (repeats + 1) * (if info.Reverses then 2 else 1)
	task.delay(total, function()
		if state[self].props.PlaybackState == Enum.PlaybackState.Playing then
			state[self].props.PlaybackState = Enum.PlaybackState.Completed
			fire(eventOf(self, "Completed"), Enum.PlaybackState.Completed)
		end
	end)
end
function methods.Cancel(self)
	if state[self].tween then
		state[self].props.PlaybackState = Enum.PlaybackState.Cancelled
	end
end
function methods.Pause(self)
	if state[self].tween then
		state[self].props.PlaybackState = Enum.PlaybackState.Paused
	end
end
function methods.Fire(self, ...)
	local className = classOf(self)
	if className == "BindableEvent" then
		fire(eventOf(self, "Event"), ...)
	end
end
function methods.GetTextSize(_, text, size, font, frameSize)
	local em = 0.5
	local lines, widest = wrapText(text or "", size or 14, em, frameSize and frameSize.X < 1e6 and frameSize.X or nil)
	return Vector2.new(widest, lines * (size or 14))
end
function methods.GetTextBoundsAsync(_, params)
	local face = params.Font
	local family = face and string.match(face.Family or "", "families/([%w]+)%.json") or ""
	local em = GLYPH[family] or 0.5
	local width = params.Width
	local lines, widest = wrapText(params.Text or "", params.Size or 14, em, if width and width > 0 then width else nil)
	return Vector2.new(widest, lines * (params.Size or 14))
end
function methods.GetGuiInset()
	return Vector2.new(0, INSET), Vector2.new(0, 0)
end
function methods.GetMouseLocation()
	return Vector2.new(profile.width / 2, profile.height / 2)
end
function methods.GetLastInputType()
	return if profile.touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseMovement
end
function methods.GetFocusedTextBox()
	return nil
end
function methods.GetConnectedGamepads()
	return {}
end
function methods.GetNavigationGamepads()
	return {}
end
function methods.IsKeyDown()
	return false
end
function methods.IsMouseButtonPressed()
	return false
end
function methods.GetKeysPressed()
	return {}
end
function methods.IsFocused()
	return false
end
function methods.CaptureFocus() end
function methods.ReleaseFocus() end
function methods.BindAction() end
function methods.BindActionAtPriority() end
function methods.UnbindAction() end
function methods.SetTitle() end
function methods.SetImage() end
function methods.SetPosition() end
function methods.GetGuiObjectsAtPosition()
	return {}
end
function methods.GetLogHistory()
	return {}
end
function methods.CanSendGameInviteAsync()
	return false
end
function methods.PromptGameInvite() end
function methods.PromptProductPurchase() end
function methods.PromptGamePassPurchase() end
function methods.UserOwnsGamePassAsync()
	return false
end
function methods.IsInGroup()
	return false
end
function methods.GetRankInGroup()
	return 0
end
function methods.GetMouse()
	return { X = profile.width / 2, Y = profile.height / 2, Hit = V.CFrame.new(), Target = nil, Icon = "" }
end
function methods.GetPlayerByUserId(_, userId)
	if userId == 1 then
		return UIShim.player
	end
	return nil
end
function methods.GetPlayers(self)
	if classOf(self) == "Players" then
		return { UIShim.player }
	end
	return {}
end
function methods.WorldToViewportPoint()
	return V.Vector3.new(-1000, -1000, -1), false
end
methods.WorldToScreenPoint = methods.WorldToViewportPoint
function methods.ViewportPointToRay()
	return { Origin = V.Vector3.new(0, 0, 0), Direction = V.Vector3.new(0, 0, -1), Unit = nil }
end
methods.ScreenPointToRay = methods.ViewportPointToRay
function methods.CreatePath()
	local path = I.newInstance("Path")
	state[path].props.Status = Enum.PathStatus.NoPath
	return path
end
function methods.ComputeAsync() end
function methods.GetWaypoints()
	return {}
end
function methods.InputHoldBegin() end
function methods.InputHoldEnd() end
function methods.GetValue()
	return 0
end
function methods.LoadAnimation()
	local track = I.newInstance("AnimationTrack")
	return track
end
function methods.AdjustSpeed() end
function methods.PreloadAsync() end
function methods.GetPartsInPart()
	return {}
end
function methods.GetPartBoundsInRadius()
	return {}
end

local OWNERS = {
	IsClient = { "RunService" },
	IsServer = { "RunService" },
	IsStudio = { "RunService" },
	GetServerTimeNow = { "Workspace" },
	Create = { "TweenService" },
	GetValue = { "TweenService" },
	Play = { "Tween", "Sound", "AnimationTrack" },
	Cancel = { "Tween" },
	Pause = { "Tween", "Sound" },
	Fire = { "BindableEvent" },
	GetTextSize = { "TextService" },
	GetTextBoundsAsync = { "TextService" },
	GetGuiInset = { "GuiService" },
	GetMouseLocation = { "UserInputService" },
	GetLastInputType = { "UserInputService" },
	GetFocusedTextBox = { "UserInputService" },
	GetConnectedGamepads = { "UserInputService" },
	GetNavigationGamepads = { "UserInputService" },
	IsKeyDown = { "UserInputService" },
	IsMouseButtonPressed = { "UserInputService" },
	GetKeysPressed = { "UserInputService" },
	IsFocused = { "TextBox" },
	CaptureFocus = { "TextBox" },
	ReleaseFocus = { "TextBox" },
	BindAction = { "ContextActionService" },
	BindActionAtPriority = { "ContextActionService" },
	UnbindAction = { "ContextActionService" },
	SetTitle = { "ContextActionService" },
	SetImage = { "ContextActionService" },
	SetPosition = { "ContextActionService" },
	GetGuiObjectsAtPosition = { "PlayerGui", "StarterGui" },
	GetLogHistory = { "LogService" },
	CanSendGameInviteAsync = { "SocialService" },
	PromptGameInvite = { "SocialService" },
	PromptProductPurchase = { "MarketplaceService" },
	PromptGamePassPurchase = { "MarketplaceService" },
	UserOwnsGamePassAsync = { "MarketplaceService" },
	IsInGroup = { "Player" },
	GetRankInGroup = { "Player" },
	GetMouse = { "Player" },
	GetPlayerByUserId = { "Players" },
	GetPlayers = { "Players", "Team" },
	WorldToViewportPoint = { "Camera" },
	WorldToScreenPoint = { "Camera" },
	ViewportPointToRay = { "Camera" },
	ScreenPointToRay = { "Camera" },
	CreatePath = { "PathfindingService" },
	ComputeAsync = { "Path" },
	GetWaypoints = { "Path" },
	InputHoldBegin = { "ProximityPrompt" },
	InputHoldEnd = { "ProximityPrompt" },
	LoadAnimation = { "Humanoid", "Animator", "AnimationController" },
	AdjustSpeed = { "AnimationTrack" },
	PreloadAsync = { "ContentProvider" },
	GetPartsInPart = { "Workspace", "WorldModel" },
	GetPartBoundsInRadius = { "Workspace", "WorldModel" },
}
local CLASS_METHODS = {}
for name, owners in OWNERS do
	CLASS_METHODS[name] = { owners = owners, fn = methods[name] }
	methods[name] = nil -- the world shim's own (a no-op Play, TweenService Create) would shadow children too
end

function classMethod(self, key)
	local entry = CLASS_METHODS[key]
	if entry == nil then
		return nil
	end
	local className = classOf(self)
	for _, owner in entry.owners do
		if className == owner or isA(className, owner) then
			return entry.fn
		end
	end
	return nil
end

------------------------------------------------------------------------------------------------------------------
-- The client: player, PlayerGui, services

local Players = World.service("Players")
local player = I.newInstance("Player")
state[player].Name = "Tester"
state[player].props.DisplayName = "Tester"
state[player].props.UserId = 1
state[player].props.AccountAge = 100
state[player].props.LocaleId = "en-us"
state[player].props.MembershipType = Enum.MembershipType.None
I.setParent(player, Players)
state[Players].props.LocalPlayer = player
state[Players].props.MaxPlayers = 12
playerGui = I.newInstance("PlayerGui")
state[playerGui].Name = "PlayerGui"
I.setParent(playerGui, player)
UIShim.player = player
UIShim.playerGui = playerGui

local camera = World.service("Workspace").CurrentCamera
state[camera].props.ViewportSize = Vector2.new(profile.width, profile.height)

local GuiService = World.service("GuiService")
state[GuiService].props.ReducedMotionEnabled = false
state[GuiService].props.PreferredTextSize = Enum.PreferredTextSize.Medium
state[GuiService].props.MenuIsOpen = false
state[GuiService].props.TopbarInset = Rect.new(Vector2.new(184, 0), Vector2.new(profile.width - 16, INSET))
state[GuiService].props.ViewportDisplaySize = Enum.DisplaySize.Medium

local UserInputService = World.service("UserInputService")
state[UserInputService].props.TouchEnabled = profile.touch == true
state[UserInputService].props.KeyboardEnabled = not profile.touch
state[UserInputService].props.MouseEnabled = not profile.touch
state[UserInputService].props.GamepadEnabled = false
state[UserInputService].props.AccelerometerEnabled = profile.touch == true
state[UserInputService].props.GyroscopeEnabled = false
state[UserInputService].props.VREnabled = false
state[UserInputService].props.MouseIconEnabled = true
state[UserInputService].props.PreferredInput = if profile.touch
	then Enum.PreferredInput.Touch
	else Enum.PreferredInput.KeyboardAndMouse
state[UserInputService].props.OnScreenKeyboardVisible = false
state[UserInputService].props.OnScreenKeyboardSize = Vector2.zero

local RunService = World.service("RunService")
local SoundService = World.service("SoundService")
state[SoundService].props.AmbientReverb = Enum.ReverbType.NoReverb
World.service("TextService")
World.service("ContextActionService")
World.service("SocialService")
World.service("MarketplaceService")
World.service("LogService")
World.service("PathfindingService")
World.service("ProximityPromptService")
World.service("TeleportService")
World.service("StarterGui")
World.service("Debris")

------------------------------------------------------------------------------------------------------------------
-- Running the clock

local FRAME = 1 / 20

local function runDue(upTo)
	local guard = 0
	while true do
		local bestIndex, best = nil, nil
		for index, item in queue do
			if item.at <= upTo and (best == nil or item.at < best.at or (item.at == best.at and item.seq < best.seq)) then
				bestIndex, best = index, item
			end
		end
		if best == nil then
			return
		end
		table.remove(queue, bestIndex)
		clock = math.max(clock, best.at)
		resume(best.thread, table.unpack(best.args, 1, best.args.n))
		guard += 1
		if guard > 20000 then
			note(UIShim.errors, "ui-shim: more than 20000 queued resumes in one frame, a loop that never waits")
			table.clear(queue)
			return
		end
	end
end

-- runs the clock forward `seconds`, a frame at a time: due threads, Heartbeat and layout change signals
function UIShim.advance(seconds)
	local target = clock + seconds
	while clock < target - 1e-9 do
		local frameEnd = math.min(target, clock + FRAME)
		runDue(frameEnd)
		local dt = frameEnd - clock
		clock = frameEnd
		local events = eventSignals[RunService]
		if events then
			fire(events.PreRender, dt)
			fire(events.RenderStepped, dt)
			fire(events.Stepped, clock, dt)
			fire(events.PreSimulation, dt)
			fire(events.Heartbeat, dt)
			fire(events.PostSimulation, dt)
		end
		computeAll()
		fireComputed()
	end
end

-- runs the clock `seconds` while recording every property write under the PlayerGui, then lists what kept
-- changing back and forth: at least `minChanges` changes between only two or three values. Steady animations
-- (a bob, a countdown, a slow blink) take many values or change rarely, and writing the same value again is no
-- change, so they pass. One line per finding: path TAB property TAB changes TAB distinct values
function UIShim.watch(seconds, minChanges)
	recording = {}
	UIShim.advance(seconds)
	local found = {}
	for instance, props in recording do
		local s = state[instance]
		if s == nil or s.destroyed then
			continue
		end
		local inGui, node, names = false, instance, {}
		while node ~= nil do
			if node == playerGui then
				inGui = true
				break
			end
			table.insert(names, 1, state[node].Name)
			node = state[node].Parent
		end
		if not inGui then
			continue
		end
		for key, entry in props do
			if entry.changes >= (minChanges or 6) and entry.distinct <= 3 then
				table.insert(
					found,
					table.concat(names, "/") .. "\t" .. key .. "\t" .. entry.changes .. "\t" .. entry.distinct
				)
			end
		end
	end
	recording = nil
	table.sort(found)
	return table.concat(found, "\n")
end

function UIShim.now()
	return clock
end

-- runs fn on a thread the clock can pause, then the clock for `settle` seconds
function UIShim.run(fn, settle)
	local thread = coroutine.create(fn)
	resume(thread)
	UIShim.advance(settle or 0)
end

function UIShim.require(path)
	return World.require(World.find(path))
end

------------------------------------------------------------------------------------------------------------------
-- The snapshot: every GuiObject a player would see, as JSON lines for uigate.mjs

local function jsonString(text)
	text = string.gsub(text, '[%c"\\]', function(c)
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		elseif c == "\n" then
			return "\\n"
		elseif c == "\t" then
			return "\\t"
		end
		return string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. text .. '"'
end

local function hex(color)
	if type(color) ~= "table" or color.R == nil then
		return "000000"
	end
	return string.format(
		"%02X%02X%02X",
		math.clamp(math.round(color.R * 255), 0, 255),
		math.clamp(math.round(color.G * 255), 0, 255),
		math.clamp(math.round(color.B * 255), 0, 255)
	)
end

local function num(x)
	return string.format("%.1f", x)
end

-- the middle of a ColorSequence or NumberSequence as the world shim stores them (the arguments to .new)
local function sequenceMid(value)
	if type(value) ~= "table" then
		return value
	end
	local items = value
	if type(value[1]) == "table" and value[1].R == nil and value[1].type == nil then
		items = {}
		for _, keypoint in value[1] do
			table.insert(items, keypoint[2])
		end
	end
	local first, last = items[1], items[#items]
	if first == nil then
		return nil
	end
	if type(first) == "number" then
		return (first + (last or first)) / 2
	end
	if type(first) == "table" and first.R ~= nil then
		last = last or first
		return Color3.new((first.R + last.R) / 2, (first.G + last.G) / 2, (first.B + last.B) / 2)
	end
	return nil
end

-- what the picture needs from a GuiObject's components: gradient, stroke, corner
local function looks(child, box)
	local out = {}
	for _, part in childrenOf(child) do
		local className = classOf(part)
		if rawProp(part, "Enabled") == false then
			continue
		end
		if className == "UIGradient" then
			out.gradColor = sequenceMid(rawProp(part, "Color"))
			out.gradT = sequenceMid(rawProp(part, "Transparency"))
		elseif className == "UIStroke" then
			out.stroke = rawProp(part, "Color")
			out.strokeT = rawProp(part, "Transparency") or 0
			out.strokeW = (rawProp(part, "Thickness") or 1) * box.k
			out.strokeBorder = enumName(rawProp(part, "ApplyStrokeMode")) == "Border" or not isTextObject(child)
		elseif className == "UICorner" then
			local radius = rawProp(part, "CornerRadius") or UDim.new(0, 8)
			out.corner = math.min(radius.Scale * math.min(box.w, box.h) + radius.Offset * box.k, math.min(box.w, box.h) / 2)
		end
	end
	return out
end

function UIShim.snapshot()
	computeAll()
	local lines = {}
	local guis = {}
	for _, child in childrenOf(playerGui) do
		if classOf(child) == "ScreenGui" then
			table.insert(guis, child)
		end
	end
	for _, gui in guis do
		if rawProp(gui, "Enabled") == false then
			continue
		end
		local order = rawProp(gui, "DisplayOrder") or 0
		local guiName = state[gui].Name
		local seen = 0
		local function walk(node, path, depth, groupAlpha)
			for _, child in guiChildren(node) do
				if rawProp(child, "Visible") == false then
					continue
				end
				local className = classOf(child)
				local alpha = groupAlpha
				if className == "CanvasGroup" then
					alpha = alpha * (1 - (rawProp(child, "GroupTransparency") or 0))
					if alpha <= 0.01 then
						continue
					end
				end
				local box = cache[child]
				if box == nil then
					continue
				end
				seen += 1
				local childPath = path .. "/" .. state[child].Name
				local fields = {
					'"gui":' .. jsonString(guiName),
					'"order":' .. tostring(order),
					'"path":' .. jsonString(childPath),
					'"class":' .. jsonString(className),
					'"x":' .. num(box.x),
					'"y":' .. num(box.y),
					'"w":' .. num(box.w),
					'"h":' .. num(box.h),
					'"depth":' .. tostring(depth),
					'"z":' .. tostring(rawProp(child, "ZIndex") or 1),
				}
				local look = looks(child, box)
				local bg = rawProp(child, "BackgroundColor3")
				local bgT = rawProp(child, "BackgroundTransparency") or 0
				if type(look.gradColor) == "table" and type(bg) == "table" and bg.R then
					bg = Color3.new(bg.R * look.gradColor.R, bg.G * look.gradColor.G, bg.B * look.gradColor.B)
				end
				if type(look.gradT) == "number" then
					bgT = 1 - (1 - bgT) * (1 - look.gradT)
				end
				table.insert(fields, '"bg":"' .. hex(bg) .. '"')
				table.insert(fields, '"bgT":' .. string.format("%.2f", 1 - (1 - bgT) * alpha))
				if look.corner and look.corner > 0.5 then
					table.insert(fields, '"r":' .. num(look.corner))
				end
				if look.stroke and look.strokeT < 0.95 then
					local key = if look.strokeBorder then '"bs"' else '"ts2"'
					table.insert(
						fields,
						key .. ':["' .. hex(look.stroke) .. '",' .. num(look.strokeW) .. "," .. string.format(
							"%.2f",
							(1 - look.strokeT) * alpha
						) .. "]"
					)
				end
				if box.clip then
					table.insert(
						fields,
						'"clip":[' .. num(box.clip[1]) .. "," .. num(box.clip[2]) .. "," .. num(box.clip[3]) .. "," .. num(box.clip[4]) .. "]"
					)
				end
				if box.scroll then
					table.insert(fields, '"scroll":true')
				end
				if className == "ScrollingFrame" then
					table.insert(fields, '"scroller":true')
				end
				local pressable = (isA(className, "GuiButton") or className == "TextBox")
					and rawProp(child, "Active") ~= false
					and rawProp(child, "Interactable") ~= false
				if pressable then
					table.insert(fields, '"press":true')
				end
				local image = rawProp(child, "Image")
				if (className == "ImageLabel" or className == "ImageButton") and image ~= "" then
					table.insert(fields, '"image":true')
					table.insert(
						fields,
						'"imageT":' .. string.format("%.2f", 1 - (1 - (rawProp(child, "ImageTransparency") or 0)) * alpha)
					)
					table.insert(fields, '"ic":"' .. hex(rawProp(child, "ImageColor3") or Color3.new(1, 1, 1)) .. '"')
				end
				if isTextObject(child) then
					local text = plainText(child)
					local textAlpha = (1 - (rawProp(child, "TextTransparency") or 0)) * alpha
					if text ~= "" and textAlpha > 0.05 then
						local pl, pr, pt, pb = padding(child, box.w, box.h, box.k)
						local iw, ih = math.max(0, box.w - pl - pr), math.max(0, box.h - pt - pb)
						local size = renderedTextSize(child, iw, ih, box.k)
						local tw, th = textExtent(child, size, if rawProp(child, "TextWrapped") then iw else nil)
						table.insert(fields, '"text":' .. jsonString(string.sub(text, 1, 120)))
						table.insert(fields, '"ts":' .. num(size))
						table.insert(fields, '"font":' .. jsonString(familyName(child)))
						table.insert(fields, '"tc":"' .. hex(rawProp(child, "TextColor3")) .. '"')
						table.insert(fields, '"ta":' .. string.format("%.2f", textAlpha))
						table.insert(fields, '"tw":' .. num(tw))
						table.insert(fields, '"th":' .. num(th))
						table.insert(fields, '"tx":' .. jsonString(enumName(rawProp(child, "TextXAlignment"))))
						if rawProp(child, "TextScaled") then
							table.insert(fields, '"scaled":true')
						end
						if rawProp(child, "TextWrapped") then
							table.insert(fields, '"wrap":true')
						end
						local truncate = enumName(rawProp(child, "TextTruncate"))
						if truncate ~= nil and truncate ~= "None" then
							table.insert(fields, '"trunc":true') -- Roblox ends it with "..." rather than spill
						end
					end
				end
				table.insert(lines, "{" .. table.concat(fields, ",") .. "}")
				walk(child, childPath, depth + 1, alpha)
			end
		end
		walk(gui, guiName, 1, 1)
		local _ = seen
	end
	return table.concat(lines, "\n")
end

-- the errors and warnings since the last call, one per line pair (kind, text) joined by NUL, and clears them
function UIShim.takeErrors()
	local out = {}
	for _, text in UIShim.errors do
		table.insert(out, "error\0" .. text)
	end
	for _, text in UIShim.warnings do
		table.insert(out, "warn\0" .. text)
	end
	table.clear(UIShim.errors)
	table.clear(UIShim.warnings)
	return table.concat(out, "\0\0")
end

function UIShim.screen()
	return profile.width, profile.height, INSET
end

return UIShim
