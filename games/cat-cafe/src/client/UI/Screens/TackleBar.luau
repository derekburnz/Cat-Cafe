--!strict
-- The Tackle (F74, data-model section 10c v0.11; was the Shove, F41): a slim bar at the bottom centre, just above the
-- bottom row, and the Q key (gamepad Y), shown only while the controller says you stand in a catching area you have
-- unlocked (setEnabled). Derek 2026-10-27 23:25: "dont need a tackle button taking up a lot of the screen make a bar
-- that slowly recharges after tackle so people can tell when ready". The bar is full and bright orange when a tackle
-- is ready; a press empties it and it refills from the left over the TackleCooldownSeconds (8), then pops once when
-- it is full again. On touch the bar itself is the tap target, since phones have no Q.
-- There is no lock-on (Derek 2026-10-27: "so you can just spam it and chase people it needs to be like skill"): a
-- press fires tackle() and the character lunges straight ahead, TackleLungeStuds (12). There is no aim arrow on the
-- ground (Derek 2026-10-28: "take away the tackle arrow no need"). A miss never gives the cooldown back;
-- result(false) after a refusal does. The bar also greys while you cannot tackle: mid-lunge, down after a miss or a
-- hit, and while someone else's tackle has you down (Components/TackleLogic). Hidden while you carry a cat or play
-- the catch circles or the rescue bar (reviewer N85), so Q never fights the keys those sink (E, Space, gamepad A and
-- R2). The toasts live in UI.shove.result.
--
--   setEnabled(on)          inside a catching area this player has unlocked, and tackles are switched on
--   result(ok, outcome?)    the server refused (false) or took (true) the tackle; a hit outcome holds the bar

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local TackleLogic = require(script.Parent.Parent.Components.TackleLogic)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local KEYS = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }
local TICK = 0.1 -- seconds between look checks; the fill itself moves every frame while it recharges
local WIDTH = 240 -- design pixels
local HEIGHT = 30
local TOUCH_HEIGHT = 44 -- Theme.sizes.touchMin, so a thumb can hit it
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
	destroy: (self: TackleBar) -> (),
}

local TackleBar = {}
TackleBar.__index = TackleBar

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

function TackleBar.new(parent: Instance, callbacks: Callbacks): TackleBar
	local self = setmetatable({}, TackleBar) :: any
	self._callbacks = callbacks
	self._enabled = false
	self._coolUntil = 0 -- os.clock()
	self._holdUntil = 0 -- os.clock() a hit's hold ends
	self._state = nil :: TackleLogic.Look? -- the look last drawn, nil while hidden
	self._loop = nil :: RBXScriptConnection?
	self._connections = {} :: { RBXScriptConnection }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeTackle",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 14,
		Enabled = false,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	local height = if Scale.isTouch() then TOUCH_HEIGHT else HEIGHT
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

	if UserInputService.KeyboardEnabled and not Scale.isTouch() then
		local key: TextLabel = Create("TextLabel", {
			Name = "Key",
			BackgroundColor3 = Theme.colors.paper,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, INSET + 2, 0.5, 0),
			Size = UDim2.fromOffset(height - 2 * INSET - 2, height - 2 * INSET - 2),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.ink,
			Text = "Q",
			ZIndex = 4,
			Parent = bar,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
		Outline.border(key, 2)
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
		return
	end
	self._bar.Position = UDim2.new(0.5, 0, 1, self._callbacks.lift())
	local was: TackleLogic.Look? = self._state
	self._state = look
	if look == "ready" and was ~= nil and was ~= "ready" then
		Tween.popIn(self._bar, 0.88) -- full again: one pop so the eye catches it
	end
	self._fill.BackgroundColor3 = if look == "ready"
		then Theme.colors.warn
		elseif look == "cooling" then Theme.colors.warnDark
		else Theme.colors.disabledDark
	self._word.Text = if look == "cooling" then "Recharging" else ICON .. " TACKLE"
	self:_drawFill()
end

-- The fill's share of the bar: empty at the press, full when the cooldown is over (and while down, in grey).
function TackleBar._drawFill(self: any)
	local share = if self._state == "cooling"
		then 1 - TackleLogic.share(self._coolUntil - os.clock())
		else 1
	self._fill.Size = UDim2.new(share, -2 * INSET * share, 1, -2 * INSET)
	self._fill.Visible = share > 0.02
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
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return TackleBar
