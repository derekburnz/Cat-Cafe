--!strict
-- #4325 (Derek 2026-11-14: "I think the admin events are not flashy enough because people always leave"; and of
-- the preview "yeah those look better"). An admin event (Bowl Frenzy, Cat Storm, Money Storm and the rest, read from
-- the AdminEvent* attributes on ReplicatedStorage by Effects/AdminEventLogic) now takes the screen and the world:
--   1. the last three seconds before it starts: a big 3, 2, 1 in the middle of a dimmed screen;
--   2. as it starts (or as a late joiner first sees it): its name, the reward in big plain words and why to stay,
--      over a band in the event's colour with a sparkle burst, for about three seconds;
--   3. while it runs: the world takes the event's colour (a ColorCorrectionEffect of this client's own, eased in and
--      out), and ONE small strip under the top bar says the reward, the time left and, once there is any, what the
--      player has earned ("x4 MONEY" over "4:12 left   +$12,340"; the amount only in a money event, Derek 22:55:
--      "no need for the money showing on the events not related to money"). Derek 2026-11-14 22:54: "the ui is still on the
--      screen too much in the events and the intro can [be] over the top ... but the money amount everywhere on
--      screen is too much": the splash stays loud, and after it this strip is all that is left on the screen;
--   4. its last minute: the strip turns red and says LEFT!, steady (#4603: no swell, Derek found it annoying);
--   5. as it ends: a card with what the player earned.
-- Effects/AdminAir rains the event's motes round the player the whole time (AdminFlashLogic.rainOf).
--
-- Nothing here can be tapped and no object is active, so it covers no button; all of it draws over the HUD and under
-- every window, and while a window is open (AdminFlash.quietWhen, which the UI's owner sets) nothing takes the middle
-- of the screen at all: no dim, no 3, 2, 1, no splash, no end card, and the strip carries the start by itself. It
-- hides while a cutscene has the screen. The start banner card (EventBanner's "admin") is skipped while the splash can
-- show, since it says the same and would cover it; with a window open the card shows as before. Reduce Motion: the
-- cards show and hold still (no pop, no swell, no sparkles). Low performance: no sparkles. It counts down only the
-- event's own start and end, and sells nothing.
-- Toasts: AdminFlash.onPlaying(listener) tells the UI's owner when the middle of the screen is taken and given back.
-- Sound: AdminFlash.onBeat's "tick" (each of 3, 2, 1), "start", "last" (the last minute begins) and "over".
-- Client only; it sends nothing. What shows when is AdminFlashLogic.step; numbers in Presets.adminFlash.

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AdminEventLogic = require(script.Parent.AdminEventLogic)
local AdminFlashLogic = require(script.Parent.AdminFlashLogic)
local AdminHide = require(script.Parent.AdminHide)
local Context = require(script.Parent.Context)
local EventBanner = require(script.Parent.EventBanner)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)
local TradeUnlock = require(script.Parent.TradeUnlock)

local AdminFlash = {}

export type Beat = "tick" | "start" | "last" | "over"

local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)
local WHITE = Color3.new(1, 1, 1)

type Parts = {
	splash: ScreenGui,
	low: ScreenGui,
	dim: Frame,
	band: Frame,
	bandFill: UIGradient,
	top: TextLabel, -- "MONEY STORM STARTS IN", then the event's name
	count: TextLabel,
	head: TextLabel,
	line: TextLabel,
	popScale: UIScale,
	strip: Frame,
	stripFill: UIGradient,
	stripScale: UIScale,
	big: TextLabel,
	left: TextLabel,
	over: Frame,
	overTitle: TextLabel,
	overLine: TextLabel,
}

local started = false
local listeners: { (beat: Beat) -> () } = {}
local parts: Parts? = nil
local view: AdminEventLogic.View? = nil
local readAt = 0 -- os.clock of the last read of the attributes
local shownId: string? = nil -- the event this client has seen running
local seenAt: number? = nil -- server time it first saw it running
local shownTitle = ""
local lastCount = 0
local wasLast = false
local money: number? = nil -- the last ProfileSync's money
local earned = 0
local earnedShown = 0
local countsMoney = false -- the event this client is showing is a money event
local overUntil = 0 -- os.clock until which the end card shows
local look: string? = nil
local tint: ColorCorrectionEffect? = nil
local quietProbe: (() -> boolean)? = nil
local playingListeners: { (on: boolean) -> () } = {}
local wasPlaying = false

-- Calls `listener(beat)` on each of the 3, 2, 1 ("tick"), as the event starts ("start"), as its last minute begins
-- ("last") and as it ends ("over"). Listeners only listen.
function AdminFlash.onBeat(listener: (beat: Beat) -> ())
	table.insert(listeners, listener)
end

local function beat(name: Beat)
	for _, listener in listeners do
		task.spawn(listener, name)
	end
end

-- `probe()` says whether a window is open (the UI's `UI.isOpen() ~= nil`). While it is, nothing here takes the middle
-- of the screen. Effects never reads the UI's state itself, so its owner hands this in; with none set, the middle
-- still draws under every window.
function AdminFlash.quietWhen(probe: () -> boolean)
	quietProbe = probe
end

-- #4877 (Derek 2026-11-16: "no admin events ui or anything on screen for people in tutorial steps"): `probe()` says
-- whether this player is in the walk-through (the UI's UI.firstCat.tutorial). While it is, nothing of an admin event
-- shows: no splash, no strip, no tint, no drift (AdminHide, which AdminAir reads too). With none set, all shows.
function AdminFlash.hideWhen(probe: () -> boolean)
	AdminHide.set(probe)
end

function AdminFlash.hidden(): boolean
	return AdminHide.on()
end

local function quiet(): boolean
	local probe = quietProbe
	if probe == nil then
		return false
	end
	local ok, value = pcall(probe)
	return ok and value == true
end

-- Whether the countdown, the splash or the end card has the middle of the screen now.
function AdminFlash.playing(): boolean
	local made = parts
	return made ~= nil and (made.dim.Visible or made.over.Visible)
end

-- Calls `listener(on)` as the countdown, splash or end card takes the middle of the screen (true) and as it gives it
-- back (false), so the UI's owner can hold its toasts for that long (`UI.setQuiet`). Listeners only listen.
function AdminFlash.onPlaying(listener: (on: boolean) -> ())
	table.insert(playingListeners, listener)
end

local function tellPlaying()
	local on = AdminFlash.playing()
	if on == wasPlaying then
		return
	end
	wasPlaying = on
	for _, listener in playingListeners do
		task.spawn(listener, on)
	end
end

local function decode(json: string): any
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok then data else nil
end

local function label(name: string, parent: Instance, maxSize: number, colour: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.FontFace = FONT
	text.Text = ""
	text.TextColor3 = colour
	text.TextScaled = true
	text.Visible = false
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = math.max(8, math.floor(maxSize + 0.5))
	limit.MinTextSize = 8
	limit.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	local look = Presets.adminFlash
	stroke.Thickness = AdminFlashLogic.outlineOf(maxSize, look.thinUnder, look.thinOutline)
	stroke.Color = Presets.adminFlash.outline
	stroke.Parent = text
	text.Parent = parent
	return text
end

local function rounded(frame: Frame, radius: number, outline: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
	if outline > 0 then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = outline
		stroke.Color = Presets.adminFlash.outline
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
	end
end

local function gradient(parent: Instance): UIGradient
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Parent = parent
	return fill
end

-- The pixels everything is sized by: 1 on a 720 tall screen, smaller on a phone.
local function scaleOf(gui: ScreenGui): number
	local p = Presets.adminFlash
	local size = gui.AbsoluteSize
	return math.clamp(math.min(size.X, size.Y) / p.designHeight, p.scaleMin, p.scaleMax)
end

-- a phone or tablet with no keyboard or mouse (the HUD's own test, UI/Scale.isTouch)
local function touchOnly(): boolean
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

local function build(): Parts?
	local existing = parts
	if existing ~= nil and existing.splash.Parent ~= nil and existing.low.Parent ~= nil then
		return existing
	end
	local p = Presets.adminFlash
	local splash = ScreenFx.gui("EffectsAdminFlash", p.displayOrder)
	local low = ScreenFx.gui("EffectsAdminStrip", p.stripOrder)
	if splash == nil or low == nil then
		return nil
	end
	for _, gui in { splash, low } do
		for _, child in gui:GetChildren() do
			if child.Name ~= "Origin" then
				child:Destroy()
			end
		end
	end
	local s = scaleOf(splash)
	local r = AdminFlashLogic.readScale(s, p.readMin) -- #5040: the strip and end card stay readable on a small phone

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = p.dim
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Visible = false
	dim.Parent = splash
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.5)
	band.Size = UDim2.fromScale(1, p.band)
	band.BackgroundColor3 = WHITE
	band.BackgroundTransparency = p.bandClear
	band.BorderSizePixel = 0
	band.Visible = false
	band.Parent = dim
	local bandFill = gradient(band)
	local holder = Instance.new("Frame")
	holder.Name = "Words"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(p.wide, 1)
	holder.Parent = dim
	local popScale = Instance.new("UIScale")
	popScale.Parent = holder
	local top = label("Top", holder, p.titleSize * s, WHITE)
	top.Size = UDim2.new(1, 0, 0, p.titleSize * s * 1.15)
	local count = label("Count", holder, p.countSize * s, p.gold)
	count.Size = UDim2.new(1, 0, 0, p.countSize * s * 1.05)
	count.Position = UDim2.new(0.5, 0, 0.5, p.countSize * s * 0.12)
	local head = label("Head", holder, p.headSize * s, WHITE)
	head.Size = UDim2.new(1, 0, 0, p.headSize * s * 1.15)
	local line = label("Line", holder, p.lineSize * s, WHITE)
	line.Size = UDim2.new(1, 0, 0, p.lineSize * s * 1.3)

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	-- #4616: clear of the money and the X2 Cash button on a phone or tablet (AdminFlashLogic.stripSpot)
	local anchorY, atY, liftY = AdminFlashLogic.stripSpot(touchOnly(), s, p.stripY, p.stripLift)
	strip.AnchorPoint = Vector2.new(0.5, anchorY)
	strip.Position = UDim2.new(0.5, 0, atY, liftY)
	strip.Size = UDim2.fromOffset(p.stripWidth * r, p.stripHeight * r)
	strip.BackgroundColor3 = WHITE
	strip.BorderSizePixel = 0
	strip.Visible = false
	rounded(strip, 14 * r, math.max(2, 3 * r))
	strip.Parent = low
	local stripFill = gradient(strip)
	local stripScale = Instance.new("UIScale")
	stripScale.Parent = strip
	local big = label("Big", strip, p.stripBig * r, WHITE)
	big.Position = UDim2.fromScale(0.5, 0.36)
	big.Size = UDim2.fromScale(0.92, 0.56)
	big.Visible = true
	local left = label("Left", strip, p.stripSmall * r, WHITE)
	left.Position = UDim2.fromScale(0.5, 0.79)
	left.Size = UDim2.fromScale(0.92, 0.32)
	left.Visible = true
	left.RichText = true

	local over = Instance.new("Frame")
	over.Name = "Over"
	over.AnchorPoint = Vector2.new(0.5, 0.5)
	over.Position = UDim2.fromScale(0.5, 0.42)
	over.Size = UDim2.fromOffset(p.overWidth * r, p.overHeight * r)
	over.BackgroundColor3 = p.card
	over.BorderSizePixel = 0
	over.Visible = false
	rounded(over, 16 * r, math.max(2, 3 * r))
	over.Parent = splash
	local overTitle = label("Title", over, p.overTitle * r, p.gold)
	overTitle.Position = UDim2.fromScale(0.5, 0.32)
	overTitle.Size = UDim2.fromScale(0.9, 0.42)
	overTitle.Visible = true
	local overLine = label("Line", over, p.overLine * r, WHITE)
	overLine.Position = UDim2.fromScale(0.5, 0.72)
	overLine.Size = UDim2.fromScale(0.9, 0.3)
	overLine.RichText = true
	overLine.Visible = true

	local made: Parts = {
		splash = splash,
		low = low,
		dim = dim,
		band = band,
		bandFill = bandFill,
		top = top,
		count = count,
		head = head,
		line = line,
		popScale = popScale,
		strip = strip,
		stripFill = stripFill,
		stripScale = stripScale,
		big = big,
		left = left,
		over = over,
		overTitle = overTitle,
		overLine = overLine,
	}
	parts = made
	return made
end

-- Eases the world into the event's colour, or back out with nil.
local function setLook(name: string?)
	if name == look then
		return
	end
	look = name
	local p = Presets.adminFlash
	local spec = if name ~= nil then p.looks[name] else nil
	local effect: ColorCorrectionEffect
	local existing = tint
	if existing ~= nil and existing.Parent ~= nil then
		effect = existing
	else
		if spec == nil then
			return
		end
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "EffectsAdminTint"
		effect.TintColor = WHITE
		effect.Parent = Lighting
		tint = effect
	end
	TweenService:Create(
		effect,
		TweenInfo.new(p.tintSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{
			TintColor = if spec ~= nil then spec.tint else WHITE,
			Saturation = if spec ~= nil then spec.saturation else 0,
			Brightness = if spec ~= nil then spec.brightness else 0,
		}
	):Play()
end

local function moneyText(amount: number): string
	local p = Presets.adminFlash
	return string.format(
		'<font color="#%s">%s</font>',
		p.earnColour:ToHex(),
		AdminFlashLogic.money(amount, p.symbol)
	)
end

local function burst(made: Parts, colour: Color3)
	if Context.lowPerformance or Context.reducedMotion() then
		return
	end
	local p = Presets.adminFlash
	local size = made.splash.AbsoluteSize
	local middle = size / 2
	local spots: { Vector2 } = {}
	for i = 1, p.sparkles do
		local a = 2 * math.pi * i / p.sparkles
		table.insert(
			spots,
			middle + Vector2.new(math.cos(a) * size.X * 0.32, math.sin(a) * size.Y * 0.26)
		)
	end
	ScreenFx.sparkle(made.splash, spots, colour, p.sparkle)
	ScreenFx.ring(made.splash, middle, size.Y * 0.2, size.Y * 0.9, colour, p.ringSeconds)
end

-- Lays out the middle's words: `rows` top to bottom, each a label and its height.
local function stack(rows: { TextLabel })
	local total = 0
	for _, row in rows do
		total += row.Size.Y.Offset
	end
	local y = -total / 2
	for _, row in rows do
		local h = row.Size.Y.Offset
		row.Position = UDim2.new(0.5, 0, 0.5, y + h / 2)
		y += h
	end
end

local function endEvent(made: Parts)
	local p = Presets.adminFlash
	if shownId ~= nil then
		overUntil = os.clock() + p.overSeconds
		made.overTitle.Text = string.upper(shownTitle) .. " OVER"
		made.overLine.Text = if countsMoney and earned >= 1
			then "You earned " .. moneyText(earned)
			else "Thanks for playing!"
		beat("over")
	end
	shownId, seenAt = nil, nil
	lastCount, wasLast = 0, false
end

local function frame()
	local now = Workspace:GetServerTimeNow()
	local clock = os.clock()
	local p = Presets.adminFlash
	if clock - readAt >= p.readEvery then
		readAt = clock
		view = AdminEventLogic.read(function(name: string): any
			return ReplicatedStorage:GetAttribute(name)
		end, decode)
	end
	local current = view
	local running = AdminEventLogic.runs(current, now)
	if current == nil and shownId == nil and clock >= overUntil and look == nil then
		local idle = parts
		if idle ~= nil and (idle.dim.Visible or idle.strip.Visible or idle.over.Visible) then
			idle.dim.Visible, idle.strip.Visible, idle.over.Visible = false, false, false
		end
		return
	end
	local made = build()
	if made == nil then
		return
	end
	local still = Context.reducedMotion()
	-- the event this client was showing has gone, or another took its place
	if shownId ~= nil and (not running or (current ~= nil and current.id ~= shownId)) then
		endEvent(made)
	end
	-- #4830 (Sync's Studio read: a returning save never saw the running event, as its splash time passed under the
	-- UI's hold at load): the event counts as seen only once the middle is free, so the splash plays then
	if running and current ~= nil and shownId == nil and not quiet() then
		shownId, seenAt, shownTitle = current.id, now, current.title
		earned, earnedShown = 0, 0
		countsMoney = AdminFlashLogic.countsMoney(current)
		overUntil = 0
		beat("start")
		local spec = p.looks[AdminFlashLogic.lookOf(current) or ""]
		burst(made, if spec ~= nil then spec.top else p.gold)
	end
	local away = AdminFlash.hidden() -- #4877: the walk-through
	setLook(if running and not away then AdminFlashLogic.lookOf(current) else nil)

	local hidden = TradeUnlock.blocked() or TradeUnlock.playing() or away
	-- #4953 (Derek, #4877: no admin event UI in the walk-through or the first 5 minutes): while the UI holds the
	-- screen quiet, the low strip hides too, and comes back as the hold ends (the splash does not replay)
	local calm = quiet()
	made.splash.Enabled = not hidden
	made.low.Enabled = not hidden and not calm
	local step = AdminFlashLogic.step(current, now, seenAt, p, calm)
	local spec = p.looks[AdminFlashLogic.lookOf(current) or ""]
		or p.looks[AdminFlashLogic.DEFAULT_LOOK]

	-- the middle of the screen: 3, 2, 1, then the name
	local middle = step.phase == "count" or step.phase == "splash"
	made.dim.Visible = middle
	if middle and current ~= nil then
		local counting = step.phase == "count"
		made.band.Visible = not counting
		made.bandFill.Color = ColorSequence.new(spec.top, spec.bottom)
		made.count.Visible = counting
		made.head.Visible = not counting
		made.line.Visible = not counting
		made.top.Visible = true
		local pop = 1
		if counting then
			made.top.Text = string.upper(current.title) .. " STARTS IN"
			made.top.TextColor3 = WHITE
			made.count.Text = tostring(step.count)
			made.top.Position = UDim2.new(0.5, 0, 0.5, -made.count.Size.Y.Offset * 0.5)
			if step.count ~= lastCount then
				lastCount = step.count
				beat("tick")
			end
			local into = 1 - (step.left - math.floor(step.left)) -- 0 as a number shows, 1 as it goes
			pop = 1 + p.countPop * math.max(0, 1 - into / p.popSeconds)
		else
			local headline = AdminFlashLogic.headline(current)
			local title = string.upper(current.title) .. "!"
			made.top.Text = title
			made.top.TextColor3 = spec.text
			local same = headline == string.upper(current.title)
			made.head.Visible = not same
			made.head.Text = headline
			made.line.Text = AdminFlashLogic.lasting(current)
				.. ". "
				.. AdminFlashLogic.stay(current)
			stack(if same then { made.top, made.line } else { made.top, made.head, made.line })
			pop = 1 - p.splashPop * math.max(0, 1 - step.since / p.popSeconds)
		end
		made.popScale.Scale = if still then 1 else pop
	end

	-- the strip under the top bar
	made.strip.Visible = step.strip
	if step.strip and current ~= nil then
		local last = step.last
		if last and not wasLast then
			wasLast = true
			if not calm then
				beat("last") -- no last-minute sound for a strip the hold keeps hidden
			end
		end
		made.stripFill.Color = if last
			then ColorSequence.new(p.lastTop, p.lastBottom)
			else ColorSequence.new(spec.top, spec.bottom)
		made.big.Text = AdminFlashLogic.headline(current)
		earnedShown += (earned - earnedShown) * math.min(1, p.earnEase)
		if earned - earnedShown < 1 then
			earnedShown = earned
		end
		-- one small line: the time left, and what this player has earned once there is any
		made.left.Text = AdminEventLogic.clock(step.left)
			.. (if last then " LEFT!" else " left")
			.. (if countsMoney and earned >= 1 then "   " .. moneyText(earnedShown) else "")
		-- #4603 (Derek 2026-11-15: "no need to make this flash its annoying"): steady, the red colour is the cue
		made.stripScale.Scale = 1
	end

	made.over.Visible = clock < overUntil and not middle and not calm
end

function AdminFlash.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local value = (state :: { [string]: unknown }).money
		if type(value) ~= "number" then
			return
		end
		if shownId ~= nil then
			earned = AdminFlashLogic.earned(earned, money, value)
		end
		money = value
	end)
	-- the splash says what the start card says, and the card would cover it: no start card while the splash can show
	EventBanner.skipWhen("admin", function(): boolean
		return not quiet()
	end)
	RunService.RenderStepped:Connect(function()
		frame()
		tellPlaying()
	end)
end

return AdminFlash
