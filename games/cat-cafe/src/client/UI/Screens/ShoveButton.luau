--!strict
-- Shove (F41, data-model section 10c): a round orange button with a hand at the bottom right, left of the CATCH
-- button, and the Q key (gamepad Y), shown only while the controller says you stand in a catching area you have
-- unlocked (setEnabled). It aims at the nearest other player within BumpRangeStuds (6): a small orange hand floats
-- over their head and the tag over the button names them, like the slap and push tools in Roblox brawl games. It
-- passes over players the server would refuse (reviewer S46, Components/ShoveTarget): one in the catch circles or the
-- rescue bar (the LockedBy of a stray or rescue spot), one this client shoved in the last BumpSameTargetSeconds (20)
-- and, for a few seconds, one the server just refused.
-- A press fires shove(targetUserId) and starts the BumpCooldownSeconds (8) cooldown: a dark wipe drains down the
-- button with the seconds left. The server validates everything and toasts the outcome; result(false) lifts the
-- cooldown after a refusal. Hidden while you carry a cat or play the catch circles or the rescue bar (reviewer N85),
-- so Q never fights the keys those sink (E, Space, gamepad A and R2).
--
--   setEnabled(on)   inside a catching area this player has unlocked, and shoves are switched on
--   result(ok)       optional: the server refused (false) or took (true) the shove
--
-- Roblox terms: HumanoidRootPart is the invisible box that carries a character's position; a BillboardGui over a
-- part always faces the camera.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local ShoveTarget = require(script.Parent.Parent.Components.ShoveTarget)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- data-model section 10c and the v0.5 constants table; the remote keeps its Bump names
local RANGE: number = Config.BumpRangeStuds
local COOLDOWN: number = Config.BumpCooldownSeconds
local SAME_TARGET: number = Config.BumpSameTargetSeconds
local PASS_OVER = 3 -- seconds a refused target is passed over, so the next nearest player gets the hand
local LOCK_TAGS = { "Stray", "RescueSpot" } -- their LockedBy is the player in the catch circles or the rescue bar
local KEYS = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }
local TICK = 0.15 -- seconds between target checks
local SIZE = 92
local HAND = "✋"

export type Callbacks = {
	shove: (targetUserId: number) -> (),
	-- true while the button must stay hidden: carrying, catch circles or the rescue bar up
	blocked: () -> boolean,
}

export type ShoveButton = {
	screenGui: ScreenGui,
	setEnabled: (self: ShoveButton, on: boolean) -> (),
	result: (self: ShoveButton, ok: boolean) -> (),
	destroy: (self: ShoveButton) -> (),
}

local ShoveButton = {}
ShoveButton.__index = ShoveButton

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

-- UserIds holding a catch or rescue lock: the server never lets them be shoved.
local function lockHolders(): { [number]: boolean }
	local locked: { [number]: boolean } = {}
	for _, tag in LOCK_TAGS do
		for _, instance in CollectionService:GetTagged(tag) do
			local holder = instance:GetAttribute("LockedBy")
			if type(holder) == "number" and holder ~= 0 then
				locked[holder] = true
			end
		end
	end
	return locked
end

-- The nearest other living player within RANGE studs that the server could take, and their root part.
local function nearestTarget(skipUntil: { [number]: number }): (Player?, BasePart?)
	local me = Players.LocalPlayer
	local mine = if me then rootOf(me) else nil
	if not mine then
		return nil, nil
	end
	local players: { Player } = {}
	local roots: { BasePart } = {}
	local candidates: { ShoveTarget.Candidate } = {}
	for _, player in Players:GetPlayers() do
		local root = if player ~= me then rootOf(player) else nil
		if root then
			table.insert(players, player)
			table.insert(roots, root)
			table.insert(candidates, {
				userId = player.UserId,
				distance = (root.Position - (mine :: BasePart).Position).Magnitude,
			})
		end
	end
	local index = ShoveTarget.pick(candidates, RANGE, lockHolders(), skipUntil, os.clock())
	if index == nil then
		return nil, nil
	end
	return players[index], roots[index]
end

function ShoveButton.new(parent: Instance, callbacks: Callbacks): ShoveButton
	local self = setmetatable({}, ShoveButton) :: any
	self._callbacks = callbacks
	self._enabled = false
	self._target = nil :: Player?
	self._coolUntil = 0
	self._skipUntil = {} :: { [number]: number } -- userId -> os.clock() until the hand passes them over
	self._lastTarget = nil :: number?
	self._loop = nil :: RBXScriptConnection?
	self._connections = {} :: { RBXScriptConnection }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeShove",
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

	local button: TextButton = Create("TextButton", {
		Name = "Shove",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.warn,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -150, 1, -100),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	self._border = Outline.border(button, 4, Theme.colors.warnDark)
	Outline.shade(button)
	self._button = button
	self._pressScale = Create("UIScale", { Parent = button })
	Create("TextLabel", {
		Name = "Hand",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 44),
		FontFace = Theme.fonts.display,
		TextSize = 38,
		Text = HAND,
		Parent = button,
	})
	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall + 2,
		TextColor3 = Theme.colors.white,
		Text = "SHOVE",
		Parent = button,
	})
	Outline.text(word, 2)

	-- cooldown: a dark layer whose lower part shows (UIGradient transparency), with the seconds left
	local cool: Frame = Create("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Theme.colors.black,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._cool = cool
	self._coolGradient = Create("UIGradient", { Rotation = 90, Parent = cool })
	local seconds: TextLabel = Create("TextLabel", {
		Name = "Seconds",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 36,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 4,
		Parent = cool,
	})
	Outline.text(seconds, 2)
	self._seconds = seconds

	if UserInputService.KeyboardEnabled and not Scale.isTouch() then
		local key: TextLabel = Create("TextLabel", {
			Name = "Key",
			BackgroundColor3 = Theme.colors.paper,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-4, -4),
			Size = UDim2.fromOffset(26, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.ink,
			Text = "Q",
			ZIndex = 5,
			Parent = button,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
		Outline.border(key, 2)
	end

	-- who the press will shove, above the button
	local tag: TextLabel = Create("TextLabel", {
		Name = "Target",
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(1, -150 - SIZE / 2, 1, -100 - SIZE - 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.text,
		Text = "",
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.border(tag, 2, Theme.hud.stroke)
	self._tag = tag

	-- the hand over the target's head
	local marker: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeShoveTarget",
		AlwaysOnTop = true,
		Enabled = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Size = UDim2.fromScale(1.4, 1.4),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		Parent = parent,
	})
	local bubble: TextLabel = Create("TextLabel", {
		Name = "Hand",
		BackgroundColor3 = Theme.colors.warn,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		Text = HAND,
		Parent = marker,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0.15, 0),
			PaddingBottom = UDim.new(0.15, 0),
			PaddingLeft = UDim.new(0.15, 0),
			PaddingRight = UDim.new(0.15, 0),
		}),
	})
	Outline.border(bubble, 2, Theme.colors.warnDark)
	self._marker = marker

	table.insert(
		self._connections,
		button.InputBegan:Connect(function(input: InputObject)
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
		button.InputEnded:Connect(function(input: InputObject)
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
		button.Activated:Connect(function()
			self:_press()
		end)
	)
	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if not gameProcessed and table.find(KEYS, input.KeyCode) and self.screenGui.Enabled then
				Tween.popIn(button, 0.9)
				self:_press()
			end
		end)
	)

	screenGui.Parent = parent
	return self :: ShoveButton
end

function ShoveButton._press(self: any)
	local target: Player? = self._target
	if target == nil or os.clock() < self._coolUntil or not self.screenGui.Enabled then
		return
	end
	local now = os.clock()
	local skipUntil: { [number]: number } = self._skipUntil
	for userId, skipEnd in skipUntil do
		if skipEnd <= now then
			skipUntil[userId] = nil
		end
	end
	local userId = (target :: Player).UserId
	self._coolUntil = now + COOLDOWN
	-- the server refuses the same target for BumpSameTargetSeconds, so the hand moves on to someone else
	skipUntil[userId] = now + SAME_TARGET
	self._lastTarget = userId
	self._callbacks.shove(userId)
	self:_tick()
end

-- Every TICK while enabled: show or hide, pick the target, draw the cooldown.
function ShoveButton._tick(self: any)
	local show = self._enabled and not self._callbacks.blocked()
	self.screenGui.Enabled = show
	if not show then
		self._target = nil
		self._marker.Enabled = false
		return
	end
	local target, targetRoot = nearestTarget(self._skipUntil)
	self._target = target
	local left = self._coolUntil - os.clock()
	local cooling = left > 0
	local ready = target ~= nil and not cooling
	self._button.BackgroundColor3 = if ready then Theme.colors.warn else Theme.colors.disabled
	self._border.Color = if ready then Theme.colors.warnDark else Theme.colors.disabledDark
	self._cool.Visible = cooling
	if cooling then
		-- the dark part covers the lower share of the button that is still cooling
		local share = math.clamp(left / COOLDOWN, 0, 1)
		local edge = math.clamp(1 - share, 0.001, 0.998)
		self._coolGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(edge, 1),
			NumberSequenceKeypoint.new(edge + 0.001, 0),
			NumberSequenceKeypoint.new(1, 0),
		})
		self._seconds.Text = tostring(math.ceil(left))
	end
	if target then
		self._tag.Text = "Shove " .. (target :: Player).DisplayName
		self._tag.TextColor3 = Theme.hud.text
	else
		self._tag.Text = "No one near"
		self._tag.TextColor3 = Theme.hud.subtext
	end
	self._marker.Adornee = targetRoot
	self._marker.Enabled = targetRoot ~= nil and not cooling
end

function ShoveButton.setEnabled(self: any, on: boolean)
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
		if accumulator < TICK then
			return
		end
		accumulator = 0
		self:_tick()
	end)
end

function ShoveButton.result(self: any, ok: boolean)
	if not ok then
		self._coolUntil = 0
		-- a refused shove does not count for the same-target wait; pass over that player briefly so a press goes
		-- to the next nearest one (they may be inside ShoveTargetImmuneSeconds after someone else's shove)
		local last: number? = self._lastTarget
		if last ~= nil then
			self._skipUntil[last] = os.clock() + PASS_OVER
		end
		self:_tick()
	end
end

function ShoveButton.destroy(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	Scale.unbind(self._uiScale)
	self._marker:Destroy()
	self.screenGui:Destroy()
end

return ShoveButton
