--!strict
-- #4061 (spec 1.3, shared/Toys): the use button of the Ticket Booth toy in hand. While the character's HeldToy is
-- "squirter" or "noodle" (the server sets it from the booth card's HOLD), one round button shows the toy's picture
-- and SPRAY or BONK, on the jump button's arc straight above it (NetButtonPlace.toy), on every screen, since a
-- mouse click and R2 still swing the net. A press, R on a keyboard or D-pad up on a controller (#4760, as D-pad down drops a cat) fires use() (UseToy) and greys the button
-- for Toys.COOLDOWN while it refills from the bottom; the server keeps its own cooldown. It hides while blocked()
-- (the catch circles or the rescue bar up). Fun only: nothing is earned or taken.
--
--   setHeld(toyId?)   the toy in hand, nil for none

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local JumpButton = require(script.Parent.Parent.Components.JumpButton)
local NetButtonPlace = require(script.Parent.Parent.Components.NetButtonPlace)
local Outline = require(script.Parent.Parent.Components.Outline)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local Toys = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Toys")) :: any

local COOLDOWN: number = Toys.COOLDOWN or 1.5
local TICK = 0.1 -- seconds between blocked() checks while a toy is in hand
local ACTION = "CatCafeUseToy"
local KEY = Enum.KeyCode.R
local PAD = Enum.KeyCode.DPadUp -- #4760

-- a toy id's look on the button
local LOOKS: { [string]: { glyph: string, word: string, picture: string, color: Color3 } } = {
	squirter = {
		glyph = "💦",
		word = "SPRAY",
		picture = "WaterSquirter",
		color = Theme.colors.sky,
	},
	noodle = { glyph = "🏊", word = "BONK", picture = "PoolNoodle", color = Theme.colors.berry },
}

export type Callbacks = {
	use: () -> (),
	-- true while the button must stay hidden: the catch circles or the rescue bar up
	blocked: () -> boolean,
}

export type ToyButton = {
	screenGui: ScreenGui,
	setHeld: (self: ToyButton, toyId: string?) -> (),
	destroy: (self: ToyButton) -> (),
}

local ToyButton = {}
ToyButton.__index = ToyButton

function ToyButton.new(parent: Instance, callbacks: Callbacks): ToyButton
	local self = setmetatable({}, ToyButton) :: any
	self._callbacks = callbacks
	self._held = nil :: string?
	self._coolUntil = 0 -- os.clock()
	self._loop = nil :: RBXScriptConnection?
	self._connections = {} :: { RBXScriptConnection }

	-- screen pixels, no UIScale: it lines up with Roblox's own jump button, as the Net button does
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeToyButton",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 14, -- with the Net button and the Tackle bar
		Enabled = false,
	})
	self.screenGui = screenGui
	local button: TextButton = Create("TextButton", {
		Name = "Toy",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.sky,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screenGui,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(button, Theme.sizes.outline, Theme.hud.stroke)
	self._button = button
	self._pressScale = Create("UIScale", { Parent = button })
	self._cool = Create("Frame", {
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
		Size = UDim2.fromScale(0.62, 0.52),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		Text = "",
		ZIndex = 3,
		Parent = button,
	}) :: TextLabel
	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromScale(0.84, 0.22),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 3,
		Parent = button,
	})
	Outline.text(word, 2)
	self._word = word
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
	return self :: ToyButton
end

function ToyButton._place(self: any)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(844, 390)
	local at, size = NetButtonPlace.toy(viewport, JumpButton.read(viewport))
	self._button.Position = UDim2.fromOffset(at.X, at.Y)
	self._button.Size = UDim2.fromOffset(size, size)
end

function ToyButton._press(self: any)
	if self._held == nil or not self.screenGui.Enabled or os.clock() < self._coolUntil then
		return
	end
	self._coolUntil = os.clock() + COOLDOWN
	self._callbacks.use()
	self:_drawCool()
end

function ToyButton._drawCool(self: any)
	local left = math.clamp((self._coolUntil - os.clock()) / COOLDOWN, 0, 1)
	self._cool.Size = UDim2.fromScale(1, left)
	self._cool.Visible = left > 0
end

function ToyButton._tick(self: any)
	local show = self._held ~= nil and not self._callbacks.blocked()
	if show and not self.screenGui.Enabled then
		Tween.popIn(self._button, 0.85)
	end
	self.screenGui.Enabled = show
	self:_drawCool()
end

function ToyButton.setHeld(self: any, toyId: string?)
	local look = if toyId ~= nil then LOOKS[toyId] else nil
	local held = if look ~= nil then toyId else nil
	if self._held == held then
		return
	end
	self._held = held
	local loop: RBXScriptConnection? = self._loop
	if held == nil or look == nil then
		if loop then
			loop:Disconnect()
			self._loop = nil
		end
		ContextActionService:UnbindAction(ACTION)
		self:_tick()
		return
	end
	self._button.BackgroundColor3 = look.color
	self._word.Text = look.word
	self._icon.Text = look.glyph
	IconArt.setImage(self._icon, ShopIcons.booth(look.picture))
	ContextActionService:BindAction(ACTION, function(_, inputState: Enum.UserInputState)
		-- D-pad up also moves a menu's selection: only with nothing selected
		if inputState == Enum.UserInputState.Begin and GuiService.SelectedObject == nil then
			self:_press()
		end
		return Enum.ContextActionResult.Pass
	end, false, KEY, PAD)
	if loop == nil then
		self:_place() -- the jump button is up by now, so follow where it really is
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

function ToyButton.destroy(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	ContextActionService:UnbindAction(ACTION)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.screenGui:Destroy()
end

return ToyButton
