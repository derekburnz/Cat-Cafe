--!strict
-- The Tackle (F74, data-model section 10c v0.11; was the Shove, F41): a slim bar at the bottom centre, just above the
-- bottom row, and the Q key (gamepad Y), shown only while the controller says you stand in a catching area you have
-- unlocked (setEnabled). Derek 2026-10-27 23:25: "dont need a tackle button taking up a lot of the screen make a bar
-- that slowly recharges after tackle so people can tell when ready". The bar is full and bright orange when a tackle
-- is ready; a press empties it and it refills from the left over the TackleCooldownSeconds (5), then pops once when
-- it is full again.
-- #2510 (Derek2 11-08: "add a tackle button instead of the bar in the middle of screen for mobile/ipad players"): on a
-- touch screen it is a round Tackle button instead (Components/NetButtonPlace.tackle), in screen pixels like the Net
-- and jump buttons; since #2721 it sits on the thumb's arc up and left of the jump button. Orange when ready, a grey that
-- drains down while it recharges with the seconds left, all grey while down.
-- There is no lock-on (Derek 2026-10-27: "so you can just spam it and chase people it needs to be like skill"): a
-- press fires tackle() and the character lunges straight ahead, TackleLungeStuds (12). There is no aim arrow on the
-- ground (Derek 2026-10-28: "take away the tackle arrow no need"). A miss never gives the cooldown back;
-- result(false) after a refusal does. The bar also greys while you cannot tackle: mid-lunge, down after a miss or a
-- hit, and while someone else's tackle has you down (Components/TackleLogic). Hidden while you carry a cat or play
-- the catch circles or the rescue bar (reviewer N85), so Q never fights the keys those sink (E, Space, gamepad A and
-- R2). The toasts live in UI.shove.result.
-- #2558 (Derek2 11-09: "makes pressing Q to tackle more obvious for pc players"): off touch, while the bar is ready
-- and someone carrying a cat is within a step and a lunge, a big pulsing key cap with "Tackle!" hangs over the
-- nearest of them (Components/TackleCue, TackleTry.cueTarget), until this player has landed TackleTry.CUE_HITS
-- tackles in the session. The bar's own key cap is bigger too.
-- #3342 (Derek2 11-11: "tackling immunity for the first 5 minutes"): while this player's join shield runs (the
-- Player's TackleShieldUntil attribute, set by ShoveService; 15 minutes since #3475), a small "🛡️ Safe 14:32" chip sits just over the bar or
-- the round button, counting down. Pressing Tackle ends the shield on the server, and the chip goes with it.
--
--   setEnabled(on)          inside a catching area this player has unlocked, and tackles are switched on
--   result(ok, outcome?)    the server refused (false) or took (true) the tackle; a hit outcome holds the bar

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Cooldown = require(script.Parent.Parent.Components.Cooldown)
local Create = require(script.Parent.Parent.Components.Create)
local JumpButton = require(script.Parent.Parent.Components.JumpButton)
local NetButtonPlace = require(script.Parent.Parent.Components.NetButtonPlace)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local TackleCue = require(script.Parent.Parent.Components.TackleCue)
local TackleLogic = require(script.Parent.Parent.Components.TackleLogic)
local TackleTry = require(script.Parent.Parent.Components.TackleTry)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local KEYS = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }
local TICK = 0.1 -- seconds between look checks; the fill itself moves every frame while it recharges
local WIDTH = 240 -- design pixels
local HEIGHT = 36 -- #2510: a click target the UI gate accepts (it was 30)
local INSET = 4 -- the fill sits this far inside the bar's dark edge
local ICON = "💨"

export type Callbacks = {
	tackle: () -> (),
	-- true while the bar must stay hidden: carrying, catch circles or the rescue bar up
	blocked: () -> boolean,
	-- the bar's bottom, in design pixels from the screen's bottom edge (negative): above the HUD's bottom row,
	-- carry banner and tutorial strip, whichever show
	lift: () -> number,
}

export type TackleBar = {
	screenGui: ScreenGui,
	setEnabled: (self: TackleBar, on: boolean) -> (),
	result: (self: TackleBar, ok: boolean, outcome: string?) -> (),
	ready: (self: TackleBar) -> boolean, -- #2302: shown and full, a press would lunge
	pulse: (self: TackleBar) -> (), -- #2302: one pop, while the "tackle them" tip points at it
	-- #3752: the bar's top edge in design pixels from the screen's bottom (negative) while the bar shows; nil while
	-- it is hidden and on touch, where the Tackle is the round button by the jump button
	top: (self: TackleBar) -> number?,
	destroy: (self: TackleBar) -> (),
}

local TackleBar = {}
TackleBar.__index = TackleBar

-- #3119: the bar's height and width in design pixels, for the HUD, which keeps the bar's place under the Drop off touch
TackleBar.HEIGHT = HEIGHT
TackleBar.WIDTH = WIDTH

local function character(): (Model?, BasePart?, Humanoid?)
	local me = Players.LocalPlayer
	local model = if me then me.Character else nil
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if model and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return model, root :: BasePart, humanoid :: Humanoid
	end
	return nil, nil, nil
end

local function mark(model: Model?, name: string): number?
	local value = if model then model:GetAttribute(name) else nil
	return if type(value) == "number" then value else nil
end

-- #2966: the bar's key cap for the input the player last used (its UserInputType name): Y on a gamepad, Q on a
-- keyboard or mouse with a keyboard, nil (no cap) on touch or with no keyboard.
function TackleBar.keyCap(lastInput: string, keyboard: boolean): string?
	if lastInput:sub(1, 7) == "Gamepad" then
		return "Y"
	elseif keyboard and lastInput ~= "Touch" then
		return "Q"
	end
	return nil
end

function TackleBar.new(parent: Instance, callbacks: Callbacks): TackleBar
	local self = setmetatable({}, TackleBar) :: any
	self._callbacks = callbacks
	self._enabled = false
	self._coolUntil = 0 -- os.clock()
	self._holdUntil = 0 -- os.clock() a hit's hold ends
	self._state = nil :: TackleLogic.Look? -- the look last drawn, nil while hidden
	self._loop = nil :: RBXScriptConnection?
	self._connections = {} :: { RBXScriptConnection }
	self._touch = Scale.isTouch()
	self._hits = 0 -- #2558: tackles landed this session; the big cue stops at TackleTry.CUE_HITS
	self._cue = nil :: TackleCue.TackleCue?
	self._shield = nil :: TextLabel? -- #3342

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeTackle",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 14,
		Enabled = false,
	})
	self.screenGui = screenGui
	if self._touch then
		self:_buildButton(screenGui)
		screenGui.Parent = parent
		return self :: TackleBar
	end
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)
	self._cue = TackleCue.new(parent)

	local height = HEIGHT
	self._height = height
	-- the bar: a dark pill (a TextButton, so a tap or click tackles too) with the orange fill inside
	local bar: TextButton = Create("TextButton", {
		Name = "Tackle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, callbacks.lift()),
		Size = UDim2.fromOffset(WIDTH, height),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(bar, Theme.sizes.outline, Theme.hud.stroke)
	self._bar = bar
	self._pressScale = Create("UIScale", { Parent = bar })
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.warn,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(INSET, INSET),
		Size = UDim2.new(1, -2 * INSET, 1, -2 * INSET),
		Parent = bar,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.shade(fill, 0.22)
	self._fill = fill
	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
		Text = ICON .. " TACKLE",
		ZIndex = 3,
		Parent = bar,
	})
	Outline.text(word, 2)
	self._word = word
	-- #3342: the join shield's chip, just over the bar
	self._shield = self:_buildShield(bar, UDim2.new(0.5, 0, 0, -6))

	do
		local key: TextLabel = Create("TextLabel", {
			Name = "Key",
			BackgroundColor3 = Theme.colors.paper,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, INSET + 2, 0.5, 0),
			Size = UDim2.fromOffset(height - 2 * INSET - 2, height - 2 * INSET - 2),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 4, -- #2558: big enough to read as a key to press
			TextColor3 = Theme.colors.ink,
			Text = "Q",
			ZIndex = 4,
			Parent = bar,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
		Outline.border(key, 2)
		-- #2966 (console pass 2): the cap names the input the player last used, Y on a gamepad and Q on a keyboard,
		-- and hides on touch with no keyboard
		local function capFor()
			local cap = TackleBar.keyCap(
				UserInputService:GetLastInputType().Name,
				UserInputService.KeyboardEnabled
			)
			key.Visible = cap ~= nil
			key.Text = cap or ""
		end
		capFor()
		table.insert(self._connections, UserInputService.LastInputTypeChanged:Connect(capFor))
	end

	table.insert(
		self._connections,
		bar.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				Tween.press(self._pressScale, true)
			end
		end)
	)
	table.insert(
		self._connections,
		bar.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				Tween.press(self._pressScale, false)
			end
		end)
	)
	table.insert(
		self._connections,
		bar.Activated:Connect(function()
			self:_press()
		end)
	)
	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if not gameProcessed and table.find(KEYS, input.KeyCode) and self.screenGui.Enabled then
				Tween.popIn(bar, 0.9)
				self:_press()
			end
		end)
	)

	screenGui.Parent = parent
	return self :: TackleBar
end

-- #2510: the touch Tackle button, round like the Net button and in screen pixels like it (no UIScale), so it lines up
-- with Roblox's jump button.
function TackleBar._buildButton(self: any, screenGui: ScreenGui)
	screenGui.IgnoreGuiInset = true
	local button: TextButton = Create("TextButton", {
		Name = "Tackle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.warn,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screenGui,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(button, Theme.sizes.outline, Theme.hud.stroke)
	self._bar = button
	self._pressScale = Create("UIScale", { Parent = button })
	-- the grey over the orange: all of it while down, draining down from the top while it recharges
	self._fill = Create("Frame", {
		Name = "Cool",
		BackgroundColor3 = Theme.colors.disabledDark,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		Visible = false,
		ZIndex = 2,
		Parent = button,
	})
	self._icon = Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.6, 0.5),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		Text = ICON,
		ZIndex = 3,
		Parent = button,
	})
	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromScale(0.86, 0.24),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "TACKLE",
		ZIndex = 3,
		Parent = button,
	})
	Outline.text(word, 2)
	self._word = word
	-- #3342: the join shield's chip, a sibling over the round button (the button clips its children)
	self._shield = self:_buildShield(screenGui, UDim2.new())
	self:_place()
	table.insert(
		self._connections,
		button.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				Tween.press(self._pressScale, true)
			end
		end)
	)
	table.insert(
		self._connections,
		button.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				Tween.press(self._pressScale, false)
			end
		end)
	)
	table.insert(
		self._connections,
		button.Activated:Connect(function()
			self:_press()
		end)
	)
	local camera = Workspace.CurrentCamera
	if camera then
		table.insert(
			self._connections,
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:_place()
			end)
		)
	end
end

-- #2721: on the thumb's arc up and left of the live jump button, between it and the Net button, in screen pixels.
function TackleBar._place(self: any)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(844, 390)
	local at, size = NetButtonPlace.tackle(viewport, JumpButton.read(viewport))
	self._bar.Position = UDim2.fromOffset(at.X, at.Y)
	self._bar.Size = UDim2.fromOffset(size, size)
	local shield: TextLabel? = self._shield
	if shield ~= nil then
		shield.Position = UDim2.fromOffset(at.X + size / 2, at.Y - 4)
	end
end

-- #3342: the join shield's chip, hidden until _drawShield has a time to show. Its bottom centre sits at `position`.
function TackleBar._buildShield(_self: any, parent: Instance, position: UDim2): TextLabel
	local chip: TextLabel = Create("TextLabel", {
		Name = "Shield",
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.border(chip, 2, Theme.hud.stroke)
	Outline.text(chip, 1)
	return chip
end

-- #3342: shows the chip with the time left while the join shield runs, hides it after.
function TackleBar._drawShield(self: any)
	local shield: TextLabel? = self._shield
	if shield == nil then
		return
	end
	local me = Players.LocalPlayer
	local text = TackleLogic.shieldText(
		if me then me:GetAttribute("TackleShieldUntil") else nil,
		Workspace:GetServerTimeNow()
	)
	shield.Visible = text ~= nil
	if text ~= nil then
		shield.Text = text
	end
end

-- Whether a lunge, a miss slide, a hit's hold or someone else's tackle has this player down right now.
function TackleBar._down(self: any): boolean
	if os.clock() < self._holdUntil then
		return true
	end
	local model = character()
	if model == nil then
		return false
	end
	local untilAt = TackleLogic.downUntil({
		tackleAt = mark(model, "TackleAt"),
		missAt = mark(model, "TackleMissAt"),
		shovedAt = mark(model, "ShovedAt"),
	})
	return Workspace:GetServerTimeNow() < untilAt
end

function TackleBar._look(self: any): TackleLogic.Look
	return TackleLogic.look(self._coolUntil - os.clock(), self:_down())
end

function TackleBar._press(self: any)
	if not self.screenGui.Enabled or self:_look() ~= "ready" then
		return
	end
	self._coolUntil = os.clock() + TackleLogic.COOLDOWN
	self._callbacks.tackle()
	self:_tick()
end

-- Every TICK while enabled: show or hide, sit above the HUD's bottom stack and colour the bar. The fill moves every
-- frame while it recharges (_drawFill).
function TackleBar._tick(self: any)
	local show = self._enabled and not self._callbacks.blocked()
	self.screenGui.Enabled = show
	local look: TackleLogic.Look = if show then self:_look() else "down"
	if not show then
		self._state = nil
		self:_placeCue(false)
		return
	end
	self:_placeCue(look == "ready")
	self:_drawShield() -- #3342
	if not self._touch then
		self._bar.Position = UDim2.new(0.5, 0, 1, self._callbacks.lift())
	end
	local was: TackleLogic.Look? = self._state
	self._state = look
	if look == "ready" and was ~= nil and was ~= "ready" then
		Tween.popIn(self._bar, 0.88) -- full again: one pop so the eye catches it
	end
	if self._touch then
		-- #2510: the button keeps its orange; the grey over it shows what is left, and the seconds take the word
		local left = math.ceil(math.max(self._coolUntil - os.clock(), 0))
		self._word.Text = if look == "cooling" and left > 0 then left .. "s" else "TACKLE"
		self._bar.BackgroundColor3 = if look == "down"
			then Theme.colors.disabledDark
			else Theme.colors.warn
		self:_drawFill()
		return
	end
	self._fill.BackgroundColor3 = if look == "ready"
		then Theme.colors.warn
		elseif look == "cooling" then Theme.colors.warnDark
		else Theme.colors.disabledDark
	-- #2324: the seconds left while it recharges, "Cooling down 3s" (each TICK, so it counts down)
	self._word.Text = if look == "cooling"
		then Cooldown.text(self._coolUntil - os.clock()) or "Recharging"
		else ICON .. " TACKLE"
	self:_drawFill()
end

-- #2558: the big "Q Tackle!" over the nearest carrier in reach while `ready`, else hidden.
function TackleBar._placeCue(self: any, ready: boolean)
	local cue: TackleCue.TackleCue? = self._cue
	if cue == nil then
		return
	end
	local _, root = character()
	local others = if ready and self._hits < TackleTry.CUE_HITS
		then TackleTry.carriers(
			Players:GetPlayers(),
			Players.LocalPlayer,
			Workspace:GetServerTimeNow()
		)
		else {}
	local index = TackleTry.cueTarget({
		ready = ready,
		hits = self._hits,
		from = if root ~= nil then root.Position else nil,
		reach = (Config :: any).TackleLungeStuds or 12,
		others = others,
	})
	local target = if index ~= nil then others[index].root else nil
	if target == nil then
		cue:hide()
		return
	end
	local gamepad = string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
	cue:show(target, if gamepad then "Y" else "Q")
end

-- The fill's share of the bar: empty at the press, full when the cooldown is over (and while down, in grey).
function TackleBar._drawFill(self: any)
	local share = if self._state == "cooling"
		then 1 - TackleLogic.share(self._coolUntil - os.clock())
		else 1
	if self._touch then
		-- #2510: the grey drains down from the top as the button recharges
		local grey = if self._state == "cooling" then 1 - share else 0
		self._fill.Size = UDim2.fromScale(1, grey)
		self._fill.Visible = grey > 0.02
		return
	end
	self._fill.Size = UDim2.new(share, -2 * INSET * share, 1, -2 * INSET)
	self._fill.Visible = share > 0.02
end

-- #2302: true while the bar shows and is full, so a press would lunge now.
function TackleBar.ready(self: any): boolean
	return self.screenGui.Enabled and self:_look() == "ready"
end

-- #2302: one pop so the eye finds the bar the "tackle them" tip talks about.
function TackleBar.top(self: any): number?
	if self._touch or not self.screenGui.Enabled then
		return nil
	end
	return self._callbacks.lift() - self._height
end

function TackleBar.pulse(self: any)
	if self.screenGui.Enabled then
		Tween.popIn(self._bar, 0.85)
	end
end

function TackleBar.setEnabled(self: any, on: boolean)
	if self._enabled == on then
		return
	end
	self._enabled = on
	local loop: RBXScriptConnection? = self._loop
	if not on then
		if loop then
			loop:Disconnect()
			self._loop = nil
		end
		self:_tick()
		return
	end
	if self._touch then
		self:_place() -- #2721: follow where the jump button really is
	end
	local accumulator = TICK
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= TICK then
			accumulator = 0
			self:_tick()
		elseif self._state == "cooling" then
			self:_drawFill()
		end
	end)
end

function TackleBar.result(self: any, ok: boolean, outcome: string?)
	if not ok then
		-- a refusal spends nothing (carrying, in a minigame, outside an area)
		self._coolUntil = 0
	elseif TackleLogic.isHit(outcome) then
		self._holdUntil = os.clock() + TackleLogic.HIT_RECOVER
		self._hits += 1 -- #2558
	end
	self:_tick()
end

function TackleBar.destroy(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	if self._uiScale then
		Scale.unbind(self._uiScale)
	end
	local cue: TackleCue.TackleCue? = self._cue
	if cue ~= nil then
		cue:destroy()
		self._cue = nil
	end
	self.screenGui:Destroy()
end

return TackleBar
