--!strict
-- Grab prompt with the timing ring.
--   show(info)          "Hold [E] to grab" card at the bottom centre with the cat's name and rarity.
--   startRing(config)   the outer ring shrinks onto the target band; call on hold begin.
--   stopRing()          returns "perfect" | "good" | "miss" from where the ring was; call on hold end.
--   fail(reason)        red flash ("It got away"), then hide.
--   hide()
-- On touch devices a big round GRAB button appears; holding it fires holdBegan / holdEnded.
-- bindProximityPrompts() in init.luau wires all of this to any ProximityPrompt with Style = Custom.

local RunService = game:GetService("RunService")

local Create = require(script.Parent.Parent.Components.Create)
local Scale = require(script.Parent.Parent.Scale)
local Signal = require(script.Parent.Parent.Components.Signal)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type CatchPrompt = {
	screenGui: ScreenGui,
	holdBegan: Signal.Signal,
	holdEnded: Signal.Signal,
	show: (self: CatchPrompt, info: Types.CatchInfo) -> (),
	startRing: (self: CatchPrompt, config: Types.RingConfig?) -> (),
	stopRing: (self: CatchPrompt) -> Types.RingResult,
	isRinging: (self: CatchPrompt) -> boolean,
	setProgress: (self: CatchPrompt, alpha: number) -> (),
	fail: (self: CatchPrompt, reason: string?, retry: boolean?) -> (),
	hide: (self: CatchPrompt) -> (),
	isVisible: (self: CatchPrompt) -> boolean,
	destroy: (self: CatchPrompt) -> (),
}

local RING_SIZE = 150 -- outer ring diameter at scale 1 (design px)
local DEFAULT_DURATION = 1.5
local DEFAULT_GOOD = { 0.26, 0.48 }
local DEFAULT_PERFECT = { 0.33, 0.41 }

local CatchPrompt = {}
CatchPrompt.__index = CatchPrompt

local function ring(
	parent: Instance,
	name: string,
	diameter: number,
	color: Color3,
	thickness: number,
	transparency: number?
): Frame
	return Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(diameter, diameter),
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create(
			"UIStroke",
			{ Color = color, Thickness = thickness, Transparency = transparency or 0 }
		),
	})
end

function CatchPrompt.new(parent: Instance): CatchPrompt
	local self = setmetatable({}, CatchPrompt) :: any
	self.holdBegan = Signal.new()
	self.holdEnded = Signal.new()
	self._connections = {} :: { RBXScriptConnection }
	self._ringConnection = nil :: RBXScriptConnection?
	self._ringScale = 1
	self._ringing = false
	self._good = DEFAULT_GOOD
	self._perfect = DEFAULT_PERFECT
	self._failToken = 0

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeCatch",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 15,
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

	-- Ring sits above the card, centred horizontally.
	local ringHolder: Frame = Create("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -236),
		Size = UDim2.fromOffset(RING_SIZE + 8, RING_SIZE + 8),
		Visible = false,
		Parent = root,
	})
	self._ringHolder = ringHolder
	-- target band: a translucent disc between good min and good max, plus a crisp perfect ring
	self._goodDisc = Create("Frame", {
		Name = "GoodBand",
		BackgroundColor3 = Theme.colors.good,
		BackgroundTransparency = 0.6,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING_SIZE * DEFAULT_GOOD[2], RING_SIZE * DEFAULT_GOOD[2]),
		Parent = ringHolder,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._goodHole = Create("Frame", {
		Name = "GoodHole",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING_SIZE * DEFAULT_GOOD[1], RING_SIZE * DEFAULT_GOOD[1]),
		Parent = ringHolder,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._perfectRing = ring(ringHolder, "PerfectRing", RING_SIZE * 0.37, Theme.colors.gold, 3)
	self._outerRing = ring(ringHolder, "OuterRing", RING_SIZE, Theme.colors.paper, 5)
	self._outerRing.ZIndex = 3
	self._centreText = Create("TextLabel", {
		Name = "Result",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING_SIZE, 40),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.paper,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Theme.colors.ink,
		Text = "",
		ZIndex = 4,
		Parent = ringHolder,
	})

	-- Card
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(340, 84),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 2) }),
		Create(
			"UIStroke",
			{ Color = Theme.hud.stroke, Transparency = Theme.hud.strokeTransparency, Thickness = 2 }
		),
	})
	self._card = card
	self._keycap = Create("TextLabel", {
		Name = "Key",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(40, 40),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.ink,
		Text = "E",
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	self._action = Create("TextLabel", {
		Name = "Action",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 10),
		Size = UDim2.new(1, -80, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Hold to grab",
		Parent = card,
	})
	self._catName = Create("TextLabel", {
		Name = "Cat",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 38),
		Size = UDim2.new(1, -170, 0, 20),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = card,
	})
	self._rarity = Create("TextLabel", {
		Name = "Rarity",
		BackgroundColor3 = Theme.rarity.Common.color,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 40),
		Size = UDim2.fromOffset(0, 18),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.rarity.Common.text,
		Text = "Common",
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	self._hint = Create("TextLabel", {
		Name = "Hint",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 60),
		Size = UDim2.new(1, -80, 0, 18),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Let go when the ring hits the green band",
		Parent = card,
	})

	-- Mobile GRAB button (bottom right, above the lure slot)
	local grab: TextButton = Create("TextButton", {
		Name = "Grab",
		Text = "GRAB",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.good,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -100),
		Size = UDim2.fromOffset(108, 108),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.goodText,
		Visible = Scale.isTouch(),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.goodDark, Thickness = 4 }),
	})
	self._grab = grab
	local holding = false
	table.insert(
		self._connections,
		grab.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				if not holding then
					holding = true
					grab.BackgroundColor3 = Theme.colors.goodDark
					self.holdBegan:Fire()
				end
			end
		end)
	)
	table.insert(
		self._connections,
		grab.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				if holding then
					holding = false
					grab.BackgroundColor3 = Theme.colors.good
					self.holdEnded:Fire()
				end
			end
		end)
	)

	if parent then
		screenGui.Parent = parent
	end
	return self :: CatchPrompt
end

function CatchPrompt.show(self: any, info: Types.CatchInfo)
	self._failToken += 1
	self._action.Text = info.actionText or "Hold to grab"
	self._action.TextColor3 = Theme.hud.text
	self._catName.Text = info.catName or ""
	local rarity: string = info.rarity or "Common"
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	self._hint.Text = if rarity == "Common"
		then "Let go in the green band. Commons stay if you miss."
		else "Let go in the green band. It runs if you miss!"
	local key: Enum.KeyCode = info.keyCode or Enum.KeyCode.E
	self._keycap.Text = key.Name
	self._keycap.Visible = not Scale.isTouch()
	self._grab.Visible = Scale.isTouch()
	self._outerRing.UIStroke.Color = Theme.rarityColor(rarity)
	self._centreText.Text = ""
	self._ringHolder.Visible = false
	if not self.screenGui.Enabled then
		self.screenGui.Enabled = true
		Tween.popIn(self._card, 0.9)
	end
end

function CatchPrompt._setRingScale(self: any, alpha: number)
	self._ringScale = alpha
	local size = RING_SIZE * alpha
	self._outerRing.Size = UDim2.fromOffset(size, size)
end

function CatchPrompt.startRing(self: any, config: Types.RingConfig?)
	local duration = (config and config.duration) or DEFAULT_DURATION
	self._good = (config and config.goodBand) or DEFAULT_GOOD
	self._perfect = (config and config.perfectBand) or DEFAULT_PERFECT
	local goodMax = RING_SIZE * self._good[2]
	local goodMin = RING_SIZE * self._good[1]
	local perfectMid = RING_SIZE * (self._perfect[1] + self._perfect[2]) / 2
	self._goodDisc.Size = UDim2.fromOffset(goodMax, goodMax)
	self._goodHole.Size = UDim2.fromOffset(goodMin, goodMin)
	self._perfectRing.Size = UDim2.fromOffset(perfectMid, perfectMid)

	self:_stopRingLoop()
	self._ringing = true
	self._centreText.Text = ""
	self._ringHolder.Visible = true
	self:_setRingScale(1)
	local elapsed = 0
	self._ringConnection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		local alpha = math.max(0, 1 - elapsed / duration)
		self:_setRingScale(alpha)
		if alpha <= 0 then
			-- held too long: the ring collapsed past the band
			self:_stopRingLoop()
			self._ringing = false
			self._centreText.Text = "Too late"
			self._centreText.TextColor3 = Theme.colors.warn
		end
	end)
end

function CatchPrompt._stopRingLoop(self: any)
	local connection: RBXScriptConnection? = self._ringConnection
	if connection then
		connection:Disconnect()
		self._ringConnection = nil
	end
end

function CatchPrompt.isRinging(self: any): boolean
	return self._ringing
end

-- Called on hold release. Judges the ring and shows the word; the server still decides the catch.
function CatchPrompt.stopRing(self: any): Types.RingResult
	local wasRinging = self._ringing
	self:_stopRingLoop()
	self._ringing = false
	if not wasRinging then
		return "miss"
	end
	local alpha = self._ringScale
	local result: Types.RingResult = "miss"
	if alpha >= self._perfect[1] and alpha <= self._perfect[2] then
		result = "perfect"
	elseif alpha >= self._good[1] and alpha <= self._good[2] then
		result = "good"
	end
	if result == "perfect" then
		self._centreText.Text = "Perfect!"
		self._centreText.TextColor3 = Theme.colors.gold
	elseif result == "good" then
		self._centreText.Text = "Good"
		self._centreText.TextColor3 = Theme.colors.good
	else
		self._centreText.Text = if alpha > self._good[2] then "Too early" else "Too late"
		self._centreText.TextColor3 = Theme.colors.warn
	end
	return result
end

-- Plain progress fill for engineers who skip the ring (0..1 shrinks the outer ring).
function CatchPrompt.setProgress(self: any, alpha: number)
	self._ringHolder.Visible = true
	self:_setRingScale(1 - math.clamp(alpha, 0, 1))
end

-- retry = true keeps the prompt open ("Missed, try again"): Commons and lured strays. Otherwise the
-- card flashes the reason and hides, which is what a fleeing cat looks like.
function CatchPrompt.fail(self: any, reason: string?, retry: boolean?)
	self._failToken += 1
	local token = self._failToken
	self:_stopRingLoop()
	self._ringing = false
	self._action.Text = reason or (if retry then "Missed, try again" else "It got away")
	self._action.TextColor3 = Theme.colors.warn
	task.delay(if retry then 1.4 else 0.9, function()
		if self._failToken ~= token then
			return
		end
		if retry then
			self._action.Text = "Hold to grab"
			self._action.TextColor3 = Theme.hud.text
			self._centreText.Text = ""
			self._ringHolder.Visible = false
		else
			self:hide()
		end
	end)
end

function CatchPrompt.hide(self: any)
	self._failToken += 1
	self:_stopRingLoop()
	self._ringing = false
	self._ringHolder.Visible = false
	self.screenGui.Enabled = false
end

function CatchPrompt.isVisible(self: any): boolean
	return self.screenGui.Enabled
end

function CatchPrompt.destroy(self: any)
	self:_stopRingLoop()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.holdBegan:DisconnectAll()
	self.holdEnded:DisconnectAll()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return CatchPrompt
