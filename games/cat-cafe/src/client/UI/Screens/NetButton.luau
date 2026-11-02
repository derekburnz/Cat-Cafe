--!strict
-- The Net button on touch screens (F93, catch-rework.md section 1): a round button just above and left of Roblox's
-- jump button (Components/NetButtonPlace) that swings the net, since a phone has no mouse click or R2. It fires
-- swing() (UI.events.netSwing, NetSwingController sends SwingNet) and greys while the net comes back
-- (Config.NetSwingCooldown, 0.8 s), refilling from the bottom. It shows only on a touch screen, inside a catching
-- area or with a stray in reach (a dropped cat on the street, reviewer N298), while the controller says a swing
-- could go (UI.net.setEnabled: not carrying, not in a minigame, the intro, a flight or a camp) and while blocked()
-- is false (the catch circles or the rescue bar up). With a mouse a click in the world swings and with a gamepad
-- R2, so no button shows there.
--
--   setEnabled(on)   a swing could go now (the controller's canSwing)
--   setInArea(on)    the player stands in a catching area (UI.setZone)
--   setInReach(on)   a stray is in reach of a swing (UI.net.setInReach)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local NetButtonPlace = require(script.Parent.Parent.Components.NetButtonPlace)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local TICK = 0.1 -- seconds between blocked() checks; the refill itself moves every frame
local COOLDOWN: number = Config.NetSwingCooldown or 0.8
local ICON = "🥅"

export type Callbacks = {
	swing: () -> (),
	-- true while the button must stay hidden: the catch circles or the rescue bar up
	blocked: () -> boolean,
}

export type NetButton = {
	screenGui: ScreenGui,
	setEnabled: (self: NetButton, on: boolean) -> (),
	setInArea: (self: NetButton, on: boolean) -> (),
	setInReach: (self: NetButton, on: boolean) -> (),
	destroy: (self: NetButton) -> (),
}

local NetButton = {}
NetButton.__index = NetButton

function NetButton.new(parent: Instance, callbacks: Callbacks): NetButton
	local self = setmetatable({}, NetButton) :: any
	self._callbacks = callbacks
	self._touch = Scale.isTouch()
	self._enabled = false
	self._inArea = false
	self._inReach = false
	self._coolUntil = 0 -- os.clock()
	self._loop = nil :: RBXScriptConnection?
	self._connections = {} :: { RBXScriptConnection }

	-- screen pixels, no UIScale: it lines up with Roblox's own jump button, which is drawn in screen pixels
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeNetButton",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 14, -- with the Tackle bar
		Enabled = false,
	})
	self.screenGui = screenGui
	local button: TextButton = Create("TextButton", {
		Name = "Net",
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
	self._button = button
	self._pressScale = Create("UIScale", { Parent = button })
	-- the grey that drains down while the net comes back
	self._cool = Create("Frame", {
		Name = "Cool",
		BackgroundColor3 = Theme.colors.disabledDark,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		ZIndex = 2,
		Parent = button,
	})
	local icon: TextLabel = Create("TextLabel", {
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
	self._icon = icon
	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromScale(0.8, 0.24),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "NET",
		ZIndex = 3,
		Parent = button,
	})
	Outline.text(word, 2)
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

	screenGui.Parent = parent
	return self :: NetButton
end

-- Up and left of the jump button, in screen pixels.
function NetButton._place(self: any)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(844, 390)
	local at, size = NetButtonPlace.place(viewport)
	self._button.Position = UDim2.fromOffset(at.X, at.Y)
	self._button.Size = UDim2.fromOffset(size, size)
end

function NetButton._press(self: any)
	if not self.screenGui.Enabled or os.clock() < self._coolUntil then
		return
	end
	self._coolUntil = os.clock() + COOLDOWN
	self._callbacks.swing()
	self:_drawCool()
end

-- The grey's share: full at the press, gone when the net is back.
function NetButton._drawCool(self: any)
	local left = math.clamp((self._coolUntil - os.clock()) / COOLDOWN, 0, 1)
	self._cool.Size = UDim2.fromScale(1, left)
	self._cool.Visible = left > 0
end

function NetButton._tick(self: any)
	local show = self._touch
		and self._enabled
		and (self._inArea or self._inReach)
		and not self._callbacks.blocked()
	if show and not self.screenGui.Enabled then
		Tween.popIn(self._button, 0.85)
	end
	self.screenGui.Enabled = show
	self:_drawCool()
end

function NetButton._watch(self: any)
	local on = self._touch and self._enabled and (self._inArea or self._inReach)
	local loop: RBXScriptConnection? = self._loop
	if not on then
		if loop then
			loop:Disconnect()
			self._loop = nil
		end
		self:_tick()
		return
	end
	if loop == nil then
		local accumulator = TICK
		self._loop = RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= TICK then
				accumulator = 0
				self:_tick()
			elseif os.clock() < self._coolUntil + 0.1 then
				self:_drawCool()
			end
		end)
	end
	self:_tick()
end

function NetButton.setEnabled(self: any, on: boolean)
	if self._enabled ~= on then
		self._enabled = on
		self:_watch()
	end
end

function NetButton.setInArea(self: any, on: boolean)
	if self._inArea ~= on then
		self._inArea = on
		self:_watch()
	end
end

function NetButton.setInReach(self: any, on: boolean)
	if self._inReach ~= on then
		self._inReach = on
		self:_watch()
	end
end

function NetButton.destroy(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.screenGui:Destroy()
end

return NetButton
