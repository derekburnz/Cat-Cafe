--!strict
-- The rescue minigame's bar (F27, data-model section 10b), in the style of the timing bars in Fisch and other
-- fishing games: a marker slides back and forth along a bar and the player presses (tap anywhere, E, Space,
-- click or the gamepad's A) while it is inside the green zone. Each hit fills a pip and the zone jumps to its
-- next spot; each miss costs a paw. Enough hits free the cat; running out of paws or time ends the attempt and
-- the cat stays stuck. On a tree (kind "shake_catch") each hit shakes the branch, and the server follows the
-- last one with a single catch circle (init shows it on CatchCircles).
--
-- The server sends where the marker starts, how fast it moves and every zone, so the bar is drawn from server
-- time alone. Hits and misses drawn on a press are this device's guess; update() replaces them with the
-- server's count.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PawRow = require(script.Parent.Parent.Components.PawRow)
local RescueMarker = require(script.Parent.Parent.Components.RescueMarker)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Header = {
	catName: string?,
	rarity: string?,
}

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
		success: boolean
	) -> (),
	isActive: (self: RescueBar) -> boolean,
	hide: (self: RescueBar) -> (),
	destroy: (self: RescueBar) -> (),
}

local BAR = Vector2.new(560, 44) -- design pixels at 1280 x 720
local MARKER = Vector2.new(14, 64)
local PIP = 22
-- data-model RescueTolerance (0.03 of the bar) and RescueAttemptMaxSeconds (15), read once the engineer adds them
local TOLERANCE: number = (Config :: any).RescueTolerance or 0.03
local MAX_SECONDS: number = (Config :: any).RescueAttemptMaxSeconds or 15
local PRESS_GAP = 0.12 -- a second press this soon is a bounce, not a try (the server allows 10 a second)
local RESULT_SECONDS = 1.6
local FAIL_SECONDS = 1.2
local GIVE_UP_SECONDS = 0.5
local NO_RESULT_TIMEOUT = 3 -- hide if the server has not ended the attempt this long after its deadline
local ACTION_NAME = "CatCafeRescuePress"
local PRESS_KEYS =
	{ Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }
local WOBBLE = { 10, -9, 7, -5, 0 }
local WOBBLE_STEP = TweenInfo.new(0.045, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ZONE_MOVE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local RescueBar = {}
RescueBar.__index = RescueBar

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- A quick sideways shake, skipped when the player asked for reduced motion.
local function wobble(gui: GuiObject, base: UDim2)
	if GuiService.ReducedMotionEnabled then
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

	-- The bar group, a little below the middle of the screen so the stuck cat stays in view above it
	local group: Frame = Create("Frame", {
		Name = "BarGroup",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(BAR.X, 150),
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
	local barBase = UDim2.new(0, 0, 0, PIP + 22)
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
	self._marker = Create("Frame", {
		Name = "Marker",
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(MARKER.X, MARKER.Y),
		ZIndex = 2,
		Parent = bar,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(self._marker, 3)
	-- NICE! or MISS over the marker
	self._word = label({
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0, 0, 0, -6),
		Size = UDim2.fromOffset(160, 34),
		TextSize = 28,
		Visible = false,
		ZIndex = 3,
		Parent = bar,
	})
	Outline.text(self._word, 3)
	-- time left, draining under the bar
	local timeTrack: Frame = Create("Frame", {
		Name = "Time",
		BackgroundColor3 = Theme.colors.cocoa,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, PIP + 22 + BAR.Y + 10),
		Size = UDim2.new(1, -16, 0, 6),
		Parent = group,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._timeFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.sky,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = timeTrack,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._cancel = Button.new({
		name = "GiveUp",
		text = "Give up",
		style = "ghost",
		size = UDim2.fromOffset(120, 36),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, PIP + 22 + BAR.Y + 26),
		textSize = Theme.sizes.textSmall,
		parent = group,
		onClick = function()
			self:_giveUp()
		end,
	})

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

-- The zone for the next hit, sliding to its new spot after a hit.
function RescueBar._placeZone(self: any, animate: boolean)
	local challenge: Types.RescueChallenge? = self._challenge
	if not challenge then
		return
	end
	local zones: { number } = challenge.zones or {}
	local centre = zones[self._hits + 1] or zones[#zones] or 0.5
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
	self._hits = 0
	self._lastPress = 0
	self._paws = challenge.paws

	local info: Header = header or {}
	local rarity = info.rarity or "Common"
	self._name.Text = info.catName or "Stuck cat"
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	local shake = challenge.kind == "shake_catch"
	self._hint.Text = if shake
		then "Hit the green to shake the branch!"
		elseif Scale.isTouch() then "Tap when the bar is in the green!"
		else "Press E or click when the bar is in the green!"
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
	local challenge: Types.RescueChallenge = self._challenge
	return RescueMarker.position(challenge.startsAt, challenge.phase or 0, challenge.speed or 1, t)
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
		local zones: { number } = current.zones or {}
		local centre = zones[self._hits + 1] or 0.5
		local inside = RescueMarker.inZone(position, centre, current.zoneWidth or 0.3, 0)
		-- the marker lights up gold inside the zone, so the timing reads at a glance
		self._marker.BackgroundColor3 = if inside then Theme.colors.gold else Theme.colors.white
	end
	local ends = deadline(current)
	local total = math.max(ends - current.startsAt, 0.001)
	self._timeFill.Size = UDim2.fromScale(math.clamp((ends - t) / total, 0, 1), 1)
	if not self._done and t >= ends then
		self._done = true
		self._hint.Text = "Too slow! It's still stuck."
	end
	if t >= ends + NO_RESULT_TIMEOUT and self._active then
		self:_finish(false) -- the server's answer never came
	end
end

function RescueBar._flash(self: any, text: string, color: Color3, position: number)
	local word: TextLabel = self._word
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
	local zones: { number } = current.zones or {}
	local centre = zones[self._hits + 1] or 0.5
	-- this device's guess; the server judges the press with the same numbers and RescueTolerance
	if RescueMarker.inZone(position, centre, current.zoneWidth or 0.3, TOLERANCE) then
		self._hits += 1
		self:_flash("NICE!", Theme.colors.good, position)
		self:_paintPips()
		self:_placeZone(true)
	else
		self:_flash("MISS", Theme.colors.red, position)
		wobble(self._bar, self._barBase)
		local paws: number? = self._paws
		if paws ~= nil then
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

function RescueBar._giveUp(self: any)
	if not self._active or self._done then
		return
	end
	self._done = true
	self._cancel:setEnabled(false)
	self._hint.Text = "You let it be for now."
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
	success: boolean
)
	if not self._active then
		return
	end
	-- the server's count replaces this device's guesses
	local zoneMoved = hits ~= self._hits
	self._hits = hits
	self:_paintPips()
	if zoneMoved then
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
	self._cancel:setEnabled(false)
	if success then
		self._outcome.Text = "Rescued!"
		self._outcome.TextColor3 = Theme.colors.good
		self._detail.Text = "Carry it home to check in"
		self._banner.UIStroke.Color = Theme.colors.good
		self._hint.Text = "It's free!"
	else
		self._outcome.Text = "Still stuck"
		self._outcome.TextColor3 = Theme.colors.red
		self._detail.Text = if pawsLeft == 0
			then "Out of paws. Try again soon"
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
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	ContextActionService:UnbindAction(ACTION_NAME)
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
