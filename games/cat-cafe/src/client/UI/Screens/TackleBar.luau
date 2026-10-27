--!strict
-- The Tackle (F74, data-model section 10c v0.11; was the Shove, F41): a slim bar at the bottom centre, just above the
-- bottom row, and the Q key (gamepad Y), shown only while the controller says you stand in a catching area you have
-- unlocked (setEnabled). Derek 2026-10-27 23:25: "dont need a tackle button taking up a lot of the screen make a bar
-- that slowly recharges after tackle so people can tell when ready". The bar is full and bright orange when a tackle
-- is ready; a press empties it and it refills from the left over the TackleCooldownSeconds (8), then pops once when
-- it is full again. On touch the bar itself is the tap target, since phones have no Q.
-- There is no lock-on (Derek 2026-10-27: "so you can just spam it and chase people it needs to be like skill"): a
-- press fires tackle() and the character lunges straight ahead. While a tackle is ready, a faint orange arrow on the
-- ground in front of your character shows the TackleLungeStuds (12) reach. A miss never gives the cooldown back;
-- result(false) after a refusal does. The bar also greys while you cannot tackle: mid-lunge, down after a miss or a
-- hit, and while someone else's tackle has you down (Components/TackleLogic). Hidden while you carry a cat or play
-- the catch circles or the rescue bar (reviewer N85), so Q never fights the keys those sink (E, Space, gamepad A and
-- R2). The toasts live in UI.shove.result.
--
--   setEnabled(on)          inside a catching area this player has unlocked, and tackles are switched on
--   result(ok, outcome?)    the server refused (false) or took (true) the tackle; a hit outcome holds the bar
--
-- Roblox terms: HumanoidRootPart is the invisible box that carries a character's position. The arrow is a few flat
-- parts made by this client only, so nobody else sees it; they do not collide and are skipped by raycasts.

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
-- the ground arrow: three dashes, then a chevron whose tip sits at the reach
local ARROW_START = 1.5 -- studs ahead of the character's centre
local DASH, DASH_GAP = 2, 1
local DASHES = 3
local ARM = 2.4 -- each side of the chevron
local ARM_ANGLE = math.rad(40)
local ARROW_WIDTH = 0.5
local ARROW_THICK = 0.08
local ARROW_LIFT = 0.1 -- studs above the floor, so the parts do not flicker into it
local ARROW_TRANSPARENCY = 0.5

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

-- Each arrow part's place relative to the character's feet, facing where it faces (-Z is ahead).
local function arrowOffsets(): { CFrame }
	local offsets: { CFrame } = {}
	for index = 0, DASHES - 1 do
		local centre = ARROW_START + index * (DASH + DASH_GAP) + DASH / 2
		table.insert(offsets, CFrame.new(0, 0, -centre))
	end
	local tip = Vector3.new(0, 0, -TackleLogic.REACH)
	for _, side in { -1, 1 } do
		-- each arm runs back from the tip and out to one side; a part's length is along its Z
		local back = Vector3.new(side * math.sin(ARM_ANGLE), 0, math.cos(ARM_ANGLE))
		local centre = tip + back * (ARM / 2)
		table.insert(offsets, CFrame.new(centre) * CFrame.Angles(0, side * ARM_ANGLE, 0))
	end
	return offsets
end

function TackleBar.new(parent: Instance, callbacks: Callbacks): TackleBar
	local self = setmetatable({}, TackleBar) :: any
	self._callbacks = callbacks
	self._enabled = false
	self._coolUntil = 0 -- os.clock()
	self._holdUntil = 0 -- os.clock() a hit's hold ends
	self._state = nil :: TackleLogic.Look? -- the look last drawn, nil while hidden
	self._loop = nil :: RBXScriptConnection?
	self._arrowLoop = nil :: RBXScriptConnection?
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

	-- the reach arrow on the ground, parented to Workspace only while it shows
	local folder = Instance.new("Folder")
	folder.Name = "CatCafeTackleArrow"
	self._arrowFolder = folder
	self._arrowParts = {} :: { BasePart }
	self._arrowOffsets = arrowOffsets()
	for index, offset in self._arrowOffsets do
		local part = Instance.new("Part")
		part.Name = if index <= DASHES then "Dash" else "Tip"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Theme.colors.warn
		part.Transparency = ARROW_TRANSPARENCY
		part.Size = Vector3.new(ARROW_WIDTH, ARROW_THICK, if index <= DASHES then DASH else ARM)
		part.CFrame = offset
		part.Parent = folder
		table.insert(self._arrowParts, part)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	self._rayParams = rayParams
	self._rayFor = nil :: Model?

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

-- Every TICK while enabled: show or hide, sit above the HUD's bottom stack, colour the bar, and the arrow while
-- ready. The fill moves every frame while it recharges (_drawFill).
function TackleBar._tick(self: any)
	local show = self._enabled and not self._callbacks.blocked()
	self.screenGui.Enabled = show
	local look: TackleLogic.Look = if show then self:_look() else "down"
	self:_showArrow(show and look == "ready")
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

function TackleBar._showArrow(self: any, on: boolean)
	local loop: RBXScriptConnection? = self._arrowLoop
	if not on then
		if loop then
			loop:Disconnect()
			self._arrowLoop = nil
		end
		self._arrowFolder.Parent = nil
		return
	end
	if loop then
		return
	end
	self._arrowLoop = RunService.RenderStepped:Connect(function()
		self:_placeArrow()
	end)
	self:_placeArrow()
end

-- Lays the arrow flat on the floor under the character, pointing where it faces.
function TackleBar._placeArrow(self: any)
	local model, root, humanoid = character()
	if model == nil or root == nil or humanoid == nil then
		self._arrowFolder.Parent = nil
		return
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local feetDrop = root.Size.Y / 2 + humanoid.HipHeight
	local floorY = root.Position.Y - feetDrop
	local params: RaycastParams = self._rayParams
	if self._rayFor ~= model then
		-- the floor ray skips this character and the arrow; set once per character, not every frame
		self._rayFor = model
		params.FilterDescendantsInstances = { model, self._arrowFolder }
	end
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -(feetDrop + 4), 0), params)
	if hit then
		floorY = hit.Position.Y
	end
	local feet = Vector3.new(root.Position.X, floorY + ARROW_LIFT, root.Position.Z)
	local base = CFrame.lookAt(feet, feet + flat.Unit)
	local parts: { BasePart } = self._arrowParts
	for index, offset in self._arrowOffsets do
		parts[index].CFrame = base * offset
	end
	self._arrowFolder.Parent = Workspace
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
	self:_showArrow(false)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	Scale.unbind(self._uiScale)
	self._arrowFolder:Destroy()
	self.screenGui:Destroy()
end

return TackleBar
