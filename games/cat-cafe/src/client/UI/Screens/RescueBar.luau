--!strict
-- The rescue minigame's bar (F27, data-model section 10b), in the style of the timing bars in Fisch and other
-- fishing games: a marker slides back and forth along a bar and the player presses (tap anywhere, Space,
-- click or the gamepad's A) while it is inside the green zone. Each hit fills a pip and the zone jumps to its
-- next spot; each miss costs a paw. Enough hits free the cat; running out of paws or time ends the attempt and
-- the cat stays stuck. On a tree (kind "shake_catch") each hit shakes the branch, and the server follows the
-- last one with a single catch circle (init shows it on CatchCircles).
--
-- The server sends where the marker starts, how fast it moves and every zone, so the bar is drawn from server
-- time alone. Hits and misses drawn on a press are this device's guess; update() replaces them with the
-- server's count.
--
-- F93 (catch-rework.md section 4), when the challenge carries `zone`: every hit speeds the marker up by
-- speedUpPerHit and moves the zone on; RescueResult's last argument (Types.RescueBar) says how the marker runs and
-- which zone is live from then on. Derek 2026-11-03 01:04 ("bars going in circles and stuff is a little confusing"):
-- a zone now stays put until it is hit and its zoneEndsAt is the attempt's deadline, so the zone's draining bottom
-- edge is the one timer (red in its last quarter); the ring round the bar is gone. An older server's challenge
-- with zonePasses still moves an unhit zone on after that many sweeps ("Too slow!"), timed per zone. Polish: the
-- marker is a needle with a little paw on top and the hit pips sit above the bar. The trap's shake and the free
-- burst are the vfx-animator's.
--
-- F92 Team Rescue (playing-together.md section 3): a helper's copy of a running bar (challenge.helper) starts from
-- the hits so far, says "Helping! Your misses cost no paws", guesses no paw lost on a miss (the paws row is the
-- rescuer's, from RescueResult), and ends with "Thanks for helping!": the cat goes to the rescuer.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Motion = require(script.Parent.Parent.Components.Motion)
local Outline = require(script.Parent.Parent.Components.Outline)
local PawRow = require(script.Parent.Parent.Components.PawRow)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local TouchPrompt = require(script.Parent.Parent.Components.TouchPrompt)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
-- one formula for the bar and the server's judge (reviewer N74)
local RescueMarker = require(Shared:WaitForChild("RescueMarker"))

-- #3050: a bar that is not a stuck cat's (the Rummage Bin's) words its own ends. Any line left out reads as a rescue's.
export type Words = {
	slow: string?, -- the hint when the time runs out ("Too slow! It's still stuck.")
	gaveUp: string?, -- the hint after Give up ("You let it be for now.")
	won: string?, -- the hint on a win ("It's free!")
	win: string?, -- the banner's title and detail on a win, when update() brings no closing words
	winDetail: string?,
	lose: string?, -- the banner's title and detail on anything else
	loseDetail: string?,
}

export type Header = {
	catName: string?,
	rarity: string?, -- nil with `words`: no rarity chip
	words: Words?,
}

-- #3050: the win banner's words when the server names what was won (the Rummage Bin's prize).
export type Closing = { title: string, detail: string }

export type Callbacks = {
	press: () -> (), -- every press: forward as RescuePress
	cancel: () -> (), -- Give up: forward as RescueCancel
	ended: (success: boolean) -> (), -- the bar has hidden after the attempt ended
}

export type RescueBar = {
	screenGui: ScreenGui,
	show: (
		self: RescueBar,
		challenge: Types.RescueChallenge,
		header: Header?,
		callbacks: Callbacks
	) -> (),
	-- RescueResult: the server's hit count and paws left; done ends the attempt
	update: (
		self: RescueBar,
		hits: number,
		pawsLeft: number?,
		done: boolean,
		success: boolean,
		bar: Types.RescueBar?,
		closing: Closing?
	) -> (),
	isActive: (self: RescueBar) -> boolean,
	hide: (self: RescueBar) -> (),
	destroy: (self: RescueBar) -> (),
}

-- #3180 (Derek2 2026-11-10: "slightly smaller bars"): 560 by 44 before, the needle 56 tall, the paw 30 and the pips
-- 22; about an eighth smaller. The zone is a share of the bar and the marker's speed is in bar lengths, so the timing
-- is the same. Taps anywhere still count, so nothing here is a touch target but Give up, which keeps its size.
local BAR = Vector2.new(492, 40) -- design pixels at 1280 x 720
local WORD = Vector2.new(160, 34) -- NICE!, MISS or Too slow! over the marker
local WORD_SIZE = 28
-- #2219 (crispi_255): a rescuer's miss after hits sends the bar back to the start; the flash says so, wider and a
-- little smaller over the bar's middle
local RESET_WORDS = "MISS! Back to the start"
local RESET_WORD = Vector2.new(420, 34)
local RESET_SIZE = 26
local NEEDLE = Vector2.new(6, 50) -- the marker's line, a little taller than the bar
local PAW = 28 -- the paw on top of the needle
local PIP = 20
local BAR_TOP = PIP + 34 -- room for the paw between the pips and the bar
local LIFE = 6 -- the zone's draining bottom edge, the bar's one timer
local GIVE_UP_H = 36 -- Give up's face on a mouse screen (Theme.sizes.tapMouse)
local GIVE_UP_GAP = 20 -- between the bar and Give up
-- data-model RescueTolerance (0.03 of the bar) and RescueAttemptMaxSeconds (15)
local TOLERANCE: number = Config.RescueTolerance
local MAX_SECONDS: number = Config.RescueAttemptMaxSeconds
local PRESS_GAP = 0.12 -- a second press this soon is a bounce, not a try (the server allows 10 a second)
local RESULT_SECONDS = 1.6
local FAIL_SECONDS = 1.2
local GIVE_UP_SECONDS = 0.5
-- #3024 (Review-QA-Agent's read of the tablet numbers: half of tablet rescue attempts end "cancelled", which only
-- Give up sends, and the button sits just under the right end of the bar a finger is tapping): on a touch screen
-- Give up takes two taps. The first changes it to GIVE_UP_ASK for GIVE_UP_ASK_SECONDS and does nothing else; a
-- second tap in that time gives up. A mouse click and a gamepad's B stay one press.
local GIVE_UP_ASK = "Tap again to give up"
local GIVE_UP_ASK_SECONDS = 3
local GIVE_UP_W = 120
local GIVE_UP_ASK_W = 200 -- wide enough for GIVE_UP_ASK; the button grows to the left, off its right edge
local NO_RESULT_TIMEOUT = 3 -- hide if the server has not ended the attempt this long after its deadline
local ACTION_NAME = "CatCafeRescuePress"
local GIVE_UP_ACTION = "CatCafeRescueGiveUp" -- #2968: B gives up on a gamepad (Select does nothing while the HUD hides)
-- E starts a rescue (hold on the prompt), so presses on the bar are Space, a click or tap, or the gamepad's A
local PRESS_KEYS = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }
local WOBBLE = { 10, -9, 7, -5, 0 }
local WOBBLE_STEP = TweenInfo.new(0.045, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
-- #2318: short, so the drawn zone is where the press after a hit is judged (it was 0.18 s, and a fast tap on the new
-- zone met a zone still sliding there)
local ZONE_MOVE = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Run = { startsAt: number, phase: number, speed: number }

local RescueBar = {}
RescueBar.__index = RescueBar

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Where on the back-and-forth (0 to 2) the marker is at server time t, as shared/RescueMarker.phaseAt (F93): a
-- faster marker after a hit starts again from the same spot, going the same way.
local function phaseAt(run: Run, t: number): number
	return (run.phase + run.speed * math.max(0, t - run.startsAt)) % 2
end

-- F93's fields on the challenge, when the server sends them (an older one does not)
local function rules(challenge: Types.RescueChallenge): Types.RescueRules
	return challenge :: any
end

-- A quick sideways shake, skipped when the player turned Screen shake off or asked for reduced motion.
local function wobble(gui: GuiObject, base: UDim2)
	if not Motion.canShake() then
		return
	end
	local step = 0
	local function nextStep()
		step += 1
		local offset = WOBBLE[step]
		if offset == nil then
			return
		end
		local tween = Tween.to(gui, WOBBLE_STEP, { Position = base + UDim2.fromOffset(offset, 0) })
		tween.Completed:Once(function()
			nextStep()
		end)
	end
	nextStep()
end

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.hud.text,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function RescueBar.new(parent: Instance): RescueBar
	local self = setmetatable({}, RescueBar) :: any
	self._active = false
	self._done = false
	self._token = 0
	self._challenge = nil :: Types.RescueChallenge?
	self._hits = 0
	self._paws = nil :: number?
	self._lastPress = 0
	self._callbacks = nil :: Callbacks?
	self._loop = nil :: RBXScriptConnection?
	self._pips = {} :: { Frame }
	self._run = { startsAt = 0, phase = 0, speed = 1 } :: Run
	self._zoneIndex = 1 -- zones[zoneIndex] is the one to hit
	self._zoneSince = 0 -- server time the live zone came up (F93)
	self._zoneEndsAt = nil :: number? -- server time it moves on unhit (F93); nil on an older server
	self._words = {} :: Words -- #3050: the running bar's own closing words, if any

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeRescueBar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, -- with the catch circles: above modals (20), under toasts (30) and popups (40)
		Enabled = false,
	})
	self.screenGui = screenGui

	-- Taps anywhere count as presses; InputBegan fires on touch down, so a tap is not delayed to its release.
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
			if not self:_onGiveUp(input.Position) then
				self:_press()
			end
		end
	end)

	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	-- Header: the cat, its rarity, the instruction and the paws, as on the catch circles
	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
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
	self._name = label({
		Name = "CatName",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -120, 0, 28),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	self._rarity = label({
		Name = "Rarity",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		TextSize = Theme.sizes.textTiny + 1,
		Parent = header,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._rarity })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = self._rarity,
	})
	self._hint = label({
		Name = "Hint",
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -110, 0, 22),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	self._pawRow = PawRow.new({
		parent = header,
		paw = 20,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 0, 38),
	})

	-- The bar group, a little below the middle of the screen so the stuck cat stays in view above it. Give up is a
	-- finger tall on touch (its face, without the button's depth).
	local depth: number = Theme.sizes.buttonDepth
	local giveUpH = Scale.tapHeight(GIVE_UP_H + depth, depth)
	local group: Frame = Create("Frame", {
		Name = "BarGroup",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(BAR.X, BAR_TOP + BAR.Y + GIVE_UP_GAP + giveUpH),
		Parent = root,
	})
	self._group = group
	-- one pip per hit needed, gold once hit
	self._pipRow = Create("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, PIP),
		Parent = group,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local barBase = UDim2.new(0, 0, 0, BAR_TOP)
	local bar: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Position = barBase,
		Size = UDim2.fromOffset(BAR.X, BAR.Y),
		Parent = group,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(bar, Theme.sizes.outline)
	self._bar = bar
	self._barBase = barBase
	self._zone = Create("Frame", {
		Name = "Zone",
		BackgroundColor3 = Theme.colors.good,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.3, 0, 1, -8),
		Parent = bar,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		-- lighter at the top, like the green 3D buttons
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		}),
	})
	Outline.border(self._zone, 2, Theme.colors.goodDark)
	-- the zone's bottom edge drains as the time to hit it runs out (the attempt's deadline, F93 2026-11-03)
	self._life = Create("Frame", {
		Name = "Life",
		BackgroundColor3 = Theme.colors.white,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, LIFE),
		ZIndex = 2,
		Parent = self._zone,
	})
	-- the marker: a needle for the exact spot and a little paw on top of it (F93 polish)
	self._marker = Create("Frame", {
		Name = "Marker",
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(NEEDLE.X, NEEDLE.Y),
		ZIndex = 3,
		Parent = bar,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(self._marker, 2)
	local paw: Frame = Create("Frame", {
		Name = "Paw",
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(PAW, PAW),
		ZIndex = 4,
		Parent = self._marker,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(paw, 2)
	self._paw = paw
	label({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		Text = "🐾",
		ZIndex = 5,
		Parent = paw,
	})
	-- NICE!, MISS or Too slow! over the marker
	self._word = label({
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0, 0, 0, -(PAW + 2)),
		Size = UDim2.fromOffset(WORD.X, WORD.Y),
		TextSize = WORD_SIZE,
		Visible = false,
		ZIndex = 6,
		Parent = bar,
	})
	Outline.text(self._word, 3)
	self._cancel = Button.new({
		name = "GiveUp",
		text = "Give up",
		style = "ghost",
		size = UDim2.fromOffset(GIVE_UP_W, giveUpH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, BAR_TOP + BAR.Y + GIVE_UP_GAP),
		textSize = Theme.sizes.textSmall,
		parent = group,
		onClick = function()
			self:_giveUpTap()
		end,
	})
	self._giveUpH = giveUpH
	self._touch = false -- whether Give up asks twice (set by show)
	self._askToken = 0
	self._asking = false

	-- Result banner: Rescued! or Still stuck
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
	self._outcome = label({
		Name = "Outcome",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 30,
		Parent = banner,
	})
	Outline.text(self._outcome, 3)
	self._detail = label({
		Name = "Detail",
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Theme.hud.subtext,
		Parent = banner,
	})

	if parent then
		screenGui.Parent = parent
	end
	return self :: RescueBar
end

function RescueBar._buildPips(self: any, count: number)
	for _, pip in self._pips do
		pip:Destroy()
	end
	table.clear(self._pips)
	for index = 1, count do
		local pip: Frame = Create("Frame", {
			Name = "Pip" .. index,
			BackgroundColor3 = Theme.colors.cocoa,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(PIP, PIP),
			LayoutOrder = index,
			Parent = self._pipRow,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(pip, 2)
		table.insert(self._pips, pip)
	end
end

function RescueBar._paintPips(self: any)
	for index, pip in self._pips :: { Frame } do
		local filled = index <= self._hits
		if filled and pip.BackgroundColor3 ~= Theme.colors.gold then
			Tween.popIn(pip, 0.5)
		end
		pip.BackgroundColor3 = if filled then Theme.colors.gold else Theme.colors.cocoa
	end
end

-- The live zone's centre: zones[zoneIndex] (the next hit's on an older server, F93's `zone` on a newer one).
function RescueBar._zoneCentre(self: any): number
	local challenge: Types.RescueChallenge? = self._challenge
	local zones: { number } = if challenge then challenge.zones or {} else {}
	return zones[self._zoneIndex] or zones[#zones] or 0.5
end

-- The live zone, sliding to its new spot after a hit or when it runs out.
function RescueBar._placeZone(self: any, animate: boolean)
	local challenge: Types.RescueChallenge? = self._challenge
	if not challenge then
		return
	end
	local centre = self:_zoneCentre()
	local width = challenge.zoneWidth or 0.3
	local position = UDim2.fromScale(math.clamp(centre, 0, 1), 0.5)
	local size = UDim2.new(math.clamp(width, 0.02, 1), 0, 1, -8)
	if animate then
		Tween.to(self._zone, ZONE_MOVE, { Position = position, Size = size })
	else
		self._zone.Position = position
		self._zone.Size = size
	end
end

function RescueBar.show(
	self: any,
	challenge: Types.RescueChallenge,
	header: Header?,
	callbacks: Callbacks
)
	self:hide()
	self._token += 1
	self._challenge = challenge
	self._callbacks = callbacks
	self._active = true
	self._done = false
	self._helper = challenge.helper == true -- F92: on someone else's bar
	self._hits = if self._helper then math.max(0, math.floor(challenge.hits or 0)) else 0
	self._lastPress = 0
	self._lastPressAt = nil :: number? -- #2318: the server time of the last press, the judge's `since`
	self._paws = challenge.paws
	self._run = {
		startsAt = challenge.startsAt,
		phase = challenge.phase or 0,
		speed = challenge.speed or 1,
	}
	self._zoneIndex = rules(challenge).zone or (self._hits + 1)
	self._zoneSince = challenge.startsAt
	self._zoneEndsAt = rules(challenge).zoneEndsAt

	local info: Header = header or {}
	local rarity = info.rarity or "Common"
	self._words = info.words or {} :: Words
	self._name.Text = info.catName or "Stuck cat"
	self._rarity.Visible = info.words == nil or info.rarity ~= nil -- #3050: the bin has no rarity
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	local shake = challenge.kind == "shake_catch"
	-- #2775 (Research-Agent: 0 of 10 tablet players got past the first rescue): "Hit the green!" never said how on a
	-- touch screen, so a touch player is told to tap, as the zone-less bar already did (#2315)
	local touch = TouchPrompt.wants(nil, UserInputService:GetLastInputType().Name, Scale.isTouch())
	self._hint.Text = if self._helper
		then "Helping! Your misses cost no paws"
		elseif shake and touch then "Tap on the green to shake it!"
		elseif shake then "Hit the green to shake the branch!"
		elseif rules(challenge).zone ~= nil and touch then "Tap when the paw hits the green!"
		elseif rules(challenge).zone ~= nil then "Hit the green!"
		elseif touch then "Tap when the bar is in the green!" -- #2315: on any sign of touch
		elseif
			UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
		then "Press A when the bar is in the green!" -- #2871
		else "Press Space or click when the bar is in the green!"
	self._pawRow:set(challenge.paws, challenge.paws)
	self._hint.Size = UDim2.new(1, if challenge.paws ~= nil then -110 else -28, 0, 22)
	-- a tree's last hit drops the cat into a catch circle instead, so its pips stop one short
	local hitsNeeded = challenge.hitsNeeded or #(challenge.zones or {})
	self:_buildPips(math.max(1, hitsNeeded))
	self:_paintPips()
	self:_placeZone(false)
	self._banner.Visible = false
	self._word.Visible = false
	self._bar.Position = self._barBase
	self._cancel:setEnabled(true)
	self._touch = touch
	self:_giveUpRest()

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
	ContextActionService:BindActionAtPriority(
		GIVE_UP_ACTION,
		function(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then
				self:_giveUp()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonB
	)
	-- #2968: the button says so on a gamepad
	self._giveUpText = if UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
		then "Give up (B)"
		else "Give up"
	self._cancel:setText(self._giveUpText)

	self._tap.Visible = true
	self.screenGui.Enabled = true
	Tween.popIn(self._header, 0.9)
	Tween.popIn(self._group, 0.9)
	-- RenderStepped (not Heartbeat) so the drawn marker matches the frame the player sees when they press
	self._loop = RunService.RenderStepped:Connect(function()
		self:_step(now())
	end)
	self:_step(now())
end

local function deadline(challenge: Types.RescueChallenge): number
	return challenge.endsAt or (challenge.startsAt + MAX_SECONDS)
end

function RescueBar._markerAt(self: any, t: number): number
	local run: Run = self._run
	return RescueMarker.position(run.startsAt, run.phase, run.speed, t)
end

function RescueBar._step(self: any, t: number)
	local challenge: Types.RescueChallenge? = self._challenge
	if not challenge then
		return
	end
	local current = challenge :: Types.RescueChallenge
	if not self._done then
		local position = self:_markerAt(t)
		self._marker.Position = UDim2.fromScale(position, 0.5)
		local inside =
			RescueMarker.inZone(position, self:_zoneCentre(), current.zoneWidth or 0.3, 0)
		-- the marker lights up gold inside the zone, so the timing reads at a glance
		local color = if inside then Theme.colors.gold else Theme.colors.white
		self._marker.BackgroundColor3 = color
		self._paw.BackgroundColor3 = color
		-- the time left to hit the zone, as its bottom edge (the attempt's deadline when the server sends none)
		local zoneEndsAt: number = self._zoneEndsAt or deadline(current)
		local span = math.max(zoneEndsAt - self._zoneSince, 0.001)
		local share = math.clamp((zoneEndsAt - t) / span, 0, 1)
		self._life.Size = UDim2.new(share, 0, 0, LIFE)
		self._life.BackgroundColor3 = if share <= 0.25 then Theme.colors.red else Theme.colors.white
	end
	local ends = deadline(current)
	if not self._done and t >= ends then
		self._done = true
		self._hint.Text = (self._words :: Words).slow or "Too slow! It's still stuck."
	end
	if t >= ends + NO_RESULT_TIMEOUT and self._active then
		self:_finish(false) -- the server's answer never came
	end
end

function RescueBar._flash(self: any, text: string, color: Color3, position: number, wide: boolean?)
	local word: TextLabel = self._word
	local box = if wide then RESET_WORD else WORD
	word.Size = UDim2.fromOffset(box.X, box.Y)
	word.TextSize = if wide then RESET_SIZE else WORD_SIZE
	word.Text = text
	word.TextColor3 = color
	word.Position = UDim2.new(position, 0, 0, -6)
	word.Visible = true
	Tween.popIn(word, 0.5)
	local token = self._token
	task.delay(0.6, function()
		if self._token == token then
			word.Visible = false
		end
	end)
end

function RescueBar._press(self: any)
	local challenge: Types.RescueChallenge? = self._challenge
	if not self._active or self._done or not challenge then
		return
	end
	local current = challenge :: Types.RescueChallenge
	local t = now()
	if t < current.startsAt then
		return -- before the marker moves: the server ignores it too
	end
	local clock = os.clock()
	if clock - self._lastPress < PRESS_GAP then
		return
	end
	self._lastPress = clock
	local position = self:_markerAt(t)
	-- this device's guess, judged as the server does (shared/Rescue.pressBar): the marker in the zone at the press or
	-- up to RescueMarker.SEEN_LAG before it, never before the last press (#2318: a fast marker just past the zone's
	-- edge flashed MISS while the server called it a hit)
	local since: number? = self._lastPressAt
	local at = math.max(t, since or t) -- as the server, a press never lands before the one before it
	self._lastPressAt = at
	local run: Run = self._run
	if
		RescueMarker.hitAt(
			run.startsAt,
			run.phase,
			run.speed,
			at,
			self:_zoneCentre(),
			current.zoneWidth or 0.3,
			TOLERANCE,
			since
		)
	then
		self._hits += 1
		self:_flash("NICE!", Theme.colors.good, position)
		self:_paintPips()
		local f93 = rules(current)
		if f93.zone ~= nil then
			-- F93: the next zone, and a faster marker from the same spot; RescueResult's bar corrects both
			local speed = run.speed * (1 + (f93.speedUpPerHit or 0))
			self._run = { startsAt = at, phase = phaseAt(run, at), speed = speed }
			self._zoneIndex += 1
			-- an older server's zone lives zonePasses sweeps; now the time to hit it is the attempt's, kept as it was
			local passes = f93.zonePasses
			if passes ~= nil then
				self._zoneSince = t
				self._zoneEndsAt = t + passes / math.max(speed, 0.01)
			end
		else
			self._zoneIndex = self._hits + 1
		end
		self:_placeZone(true)
	else
		self:_flash("MISS", Theme.colors.red, position)
		wobble(self._bar, self._barBase)
		local paws: number? = self._paws
		if paws ~= nil and not self._helper then -- F92: a helper's miss costs no paw
			self._paws = math.max(0, paws - 1)
			self._pawRow:lose(self._paws)
		end
	end
	local callbacks: Callbacks? = self._callbacks
	if callbacks then
		callbacks.press()
	end
end

-- True when a tap lands on Give up, so reaching for it does not also press the bar and spend a paw.
function RescueBar._onGiveUp(self: any, position: Vector3): boolean
	local playerGui = self.screenGui.Parent
	if playerGui == nil or not playerGui:IsA("BasePlayerGui") then
		return false
	end
	local button: Instance = self._cancel.instance
	for _, gui in (playerGui :: BasePlayerGui):GetGuiObjectsAtPosition(position.X, position.Y) do
		if (gui :: Instance) == button or gui:IsDescendantOf(button) then
			return true
		end
	end
	return false
end

-- Give up back to its resting words and width, with no second tap pending.
function RescueBar._giveUpRest(self: any)
	self._askToken += 1
	self._asking = false
	self._cancel:setText(self._giveUpText or "Give up")
	self._cancel.instance.Size = UDim2.fromOffset(GIVE_UP_W, self._giveUpH)
end

-- A tap or click on Give up. On a touch screen the first only asks (#3024); anything else gives up at once.
function RescueBar._giveUpTap(self: any)
	if not self._active or self._done then
		return
	end
	if not self._touch or self._asking then
		self:_giveUp()
		return
	end
	self._asking = true
	self._askToken += 1
	local token = self._askToken
	self._cancel:setText(GIVE_UP_ASK)
	self._cancel.instance.Size = UDim2.fromOffset(GIVE_UP_ASK_W, self._giveUpH)
	task.delay(GIVE_UP_ASK_SECONDS, function()
		if self._askToken == token and self._asking and not self._done then
			self:_giveUpRest()
		end
	end)
end

function RescueBar._giveUp(self: any)
	if not self._active or self._done then
		return
	end
	self._done = true
	self._askToken += 1
	self._asking = false
	self._cancel:setEnabled(false)
	self._hint.Text = (self._words :: Words).gaveUp or "You let it be for now."
	local callbacks: Callbacks? = self._callbacks
	if callbacks then
		callbacks.cancel()
	end
	-- the server ends the attempt on RescueCancel; the bar does not wait for its answer
	self._token += 1
	local token = self._token
	task.delay(GIVE_UP_SECONDS, function()
		if self._token == token then
			self:_finish(false)
		end
	end)
end

-- Hides the bar and tells init the attempt is over, once.
function RescueBar._finish(self: any, success: boolean)
	local callbacks: Callbacks? = self._callbacks
	self:hide()
	if callbacks then
		callbacks.ended(success)
	end
end

function RescueBar.update(
	self: any,
	hits: number,
	pawsLeft: number?,
	done: boolean,
	success: boolean,
	bar: Types.RescueBar?,
	closing: Closing?
)
	if not self._active then
		return
	end
	-- the server's count replaces this device's guesses
	local before = self._zoneIndex
	local nextZone = if bar ~= nil then bar.zone else hits + 1
	-- F93: a zone that ran out unhit costs a paw and moves on with no press behind it
	local tooSlow = bar ~= nil
		and hits == self._hits
		and nextZone ~= before
		and pawsLeft ~= nil
		and self._paws ~= nil
		and pawsLeft < self._paws
	if tooSlow and not done then
		self:_flash("Too slow!", Theme.colors.warn, self:_zoneCentre())
	end
	-- #2219: the server took this rescuer's filled pips away for a miss; a helper's miss resets nothing
	if not done and not self._helper and hits == 0 and self._hits > 0 then
		self:_flash(RESET_WORDS, Theme.colors.red, 0.5, true)
	end
	self._hits = hits
	self:_paintPips()
	if bar ~= nil then
		-- F92 Team Rescue: a helper joining moves the attempt's deadline later (bar.endsAt); the timer and "Too slow!"
		-- read the kept challenge's endsAt, so it takes the new one. Read loosely until the shared type has it.
		local endsAt: unknown = (bar :: any).endsAt
		local challenge: Types.RescueChallenge? = self._challenge
		if type(endsAt) == "number" and challenge ~= nil and challenge.endsAt ~= endsAt then
			local moved = table.clone(challenge)
			moved.endsAt = endsAt
			self._challenge = moved
		end
		self._run = { startsAt = bar.startsAt, phase = bar.phase, speed = bar.speed }
		-- an older server times each zone (zonePasses), so its timer restarts with the zone; now it runs from the
		-- attempt's start and only grows when a helper's extra time moves the deadline
		local perZone = challenge ~= nil and rules(challenge).zonePasses ~= nil
		if perZone and (bar.zoneEndsAt ~= self._zoneEndsAt or nextZone ~= before) then
			self._zoneSince = math.min(now(), bar.zoneEndsAt)
		end
		self._zoneEndsAt = bar.zoneEndsAt
	end
	self._zoneIndex = nextZone
	if nextZone ~= before then
		self:_placeZone(true)
	end
	if pawsLeft ~= nil and pawsLeft ~= self._paws then
		local before: number? = self._paws
		self._paws = pawsLeft
		if before ~= nil and pawsLeft < before then
			self._pawRow:lose(pawsLeft)
		else
			local challenge: Types.RescueChallenge? = self._challenge
			self._pawRow:set(pawsLeft, if challenge then challenge.paws else pawsLeft)
		end
	end
	if not done then
		return
	end
	self._done = true
	self._token += 1
	local token = self._token
	ContextActionService:UnbindAction(ACTION_NAME)
	ContextActionService:UnbindAction(GIVE_UP_ACTION)
	self._cancel:setEnabled(false)
	-- #2460 (Derek2 11-08: "the "rescued" on mobile has the same issue that catching used to ... it doesn't let you
	-- move for a little while after a rescue"): as on the catch circles (#2405), the full-screen tap catcher goes the
	-- moment the attempt is over, so the result banner shows over a screen that moves again (a thumbstick or a tap
	-- to move) instead of eating every touch until it closes
	self._tap.Visible = false
	local words: Words = self._words
	if success then
		self._outcome.Text = if closing ~= nil then closing.title else words.win or "Rescued!"
		self._outcome.TextColor3 = Theme.colors.good
		-- F92: the helper's cat goes to the rescuer
		self._detail.Text = if closing ~= nil
			then closing.detail
			elseif words.win ~= nil then words.winDetail or ""
			elseif self._helper then "Thanks for helping!"
			else "Carry it home to check in"
		self._banner.UIStroke.Color = Theme.colors.good
		self._hint.Text = words.won or "It's free!"
	else
		self._outcome.Text = words.lose or "Still stuck"
		self._outcome.TextColor3 = Theme.colors.red
		self._detail.Text = if words.lose ~= nil
			then words.loseDetail or ""
			elseif self._helper then "Thanks for helping"
			elseif pawsLeft == 0 then "Out of paws. Try again soon"
			else "Try again in a moment"
		self._banner.UIStroke.Color = Theme.colors.red
		wobble(self._bar, self._barBase)
	end
	self._banner.Visible = true
	Tween.popIn(self._banner, 0.8)
	task.delay(if success then RESULT_SECONDS else FAIL_SECONDS, function()
		if self._token == token then
			self:_finish(success)
		end
	end)
end

function RescueBar.isActive(self: any): boolean
	return self._active
end

function RescueBar.hide(self: any)
	self._token += 1
	self._active = false
	self._done = false
	self._challenge = nil
	self._callbacks = nil
	self._askToken += 1
	self._asking = false
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	ContextActionService:UnbindAction(ACTION_NAME)
	ContextActionService:UnbindAction(GIVE_UP_ACTION)
	self._banner.Visible = false
	self._word.Visible = false
	self.screenGui.Enabled = false
end

function RescueBar.destroy(self: any)
	self:hide()
	self._tapConnection:Disconnect()
	self._cancel:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return RescueBar
