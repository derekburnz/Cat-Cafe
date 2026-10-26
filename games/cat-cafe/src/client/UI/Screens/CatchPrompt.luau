--!strict
-- Catch prompt card for strays and stuck cats.
--   show(info)          "[E] Catch" card at the bottom centre with the cat's name, stars and rarity.
--   waiting()           one press went to the server: "Get ready..." until the circles (CatchCircles) come.
--   startRescue(d)      rescue hold (stuck cat, F21): a bar fills over the hold.
--   stopRescue(done)    done = true after the full hold ("Rescued!"); false resets the bar, there is no fail.
--   fail(reason)        red flash ("It got away"), then hide; with retry the card stays.
--   hide()
-- The net has no hold any more (F26): a stray's prompt has HoldDuration 0 and one press asks for the
-- closing circles. The rescue hold stays until the rescue minigames replace it.
-- On touch devices a big round CATCH button appears; it drives the real prompt through holdBegan / holdEnded.
-- bindProximityPrompts() in init.luau wires all of this to any ProximityPrompt with Style = Custom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
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
	startRescue: (self: CatchPrompt, duration: number?) -> (),
	stopRescue: (self: CatchPrompt, completed: boolean) -> (),
	isRescuing: (self: CatchPrompt) -> boolean,
	fail: (self: CatchPrompt, reason: string?, retry: boolean?) -> (),
	waiting: (self: CatchPrompt) -> (),
	hide: (self: CatchPrompt) -> (),
	isVisible: (self: CatchPrompt) -> boolean,
	destroy: (self: CatchPrompt) -> (),
}

-- data-model RescueHoldSeconds (4); the rescue minigames (F27) replace the hold and this constant
local DEFAULT_RESCUE_HOLD: number = Config.RescueHoldSeconds

local CatchPrompt = {}
CatchPrompt.__index = CatchPrompt

function CatchPrompt.new(parent: Instance): CatchPrompt
	local self = setmetatable({}, CatchPrompt) :: any
	self.holdBegan = Signal.new()
	self.holdEnded = Signal.new()
	self._connections = {} :: { RBXScriptConnection }
	self._failToken = 0
	self._rescueConnection = nil :: RBXScriptConnection?
	self._rescuing = false
	self._kind = "swing" :: Types.PromptKind
	self._press = true

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

	-- Rescue bar: fills over the rescue hold (4 s, no band, no fail), above the card
	local rescueHolder: Frame = Create("Frame", {
		Name = "Rescue",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -236),
		Size = UDim2.fromOffset(260, 56),
		Visible = false,
		Parent = root,
	})
	self._rescueHolder = rescueHolder
	self._rescueText = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.paper,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Theme.colors.ink,
		Text = "Rescuing...",
		Parent = rescueHolder,
	})
	local rescueTrack: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = rescueHolder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.paper, Thickness = 2, Transparency = 0.3 }),
	})
	self._rescueFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = rescueTrack,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

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
		Text = "Catch",
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
		Text = "Hit each circle on its ring",
		Parent = card,
	})

	-- Mobile CATCH button (bottom right, above the lure slot); reads RESCUE or HOLD on a rescue prompt
	local grab: TextButton = Create("TextButton", {
		Name = "Grab",
		Text = "CATCH",
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

-- "Catch", "Rescue" (a press rescue) or "Hold to rescue" (the v0.2 rescue hold)
function CatchPrompt._actionText(self: any): string
	if self._kind ~= "rescue" then
		return "Catch"
	end
	return if self._press then "Rescue" else "Hold to rescue"
end

function CatchPrompt.show(self: any, info: Types.CatchInfo)
	self._failToken += 1
	local kind: Types.PromptKind = info.kind or "swing"
	local rescue = kind == "rescue" -- a plain boolean: chained singleton tests confuse the type checker
	-- one press starts the circles or the rescue minigame; only the v0.2 rescue still holds
	local press = info.press == true or not rescue
	self._kind = kind
	self._press = press
	self._action.Text = info.actionText or self:_actionText()
	self._action.TextColor3 = Theme.hud.text
	self._grab.Text = if not rescue then "CATCH" elseif press then "RESCUE" else "HOLD"
	self:_stopRescueLoop()
	self._rescuing = false
	self._rescueHolder.Visible = false
	local nameText = info.catName or ""
	if info.stars then
		nameText = nameText .. "  " .. Format.stars(info.stars :: number)
	end
	self._catName.Text = nameText
	local rarity: string = info.rarity or "Common"
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	self._hint.Text = if press and rescue
		then "Stop the marker in the zone. The cat never leaves if you miss."
		elseif
			press and rarity == "Common"
		then "Hit each circle on its ring. Commons stay if you miss."
		elseif press then "Hit each circle on its ring. It runs if you miss!"
		else "Hold still for 4 seconds. No swing, no miss."
	local key: Enum.KeyCode = info.keyCode or Enum.KeyCode.E
	self._keycap.Text = key.Name
	self._keycap.Visible = not Scale.isTouch()
	self._grab.Visible = Scale.isTouch()
	if not self.screenGui.Enabled then
		self.screenGui.Enabled = true
		Tween.popIn(self._card, 0.9)
	end
end

-- Rescue hold (F21, data-model section 10): the bar fills over the hold; releasing early only resets it.
function CatchPrompt.startRescue(self: any, duration: number?)
	local total: number = duration or DEFAULT_RESCUE_HOLD
	self._failToken += 1 -- a new hold cancels the reset a pending retry fail would apply
	self:_stopRescueLoop()
	self._rescuing = true
	self._rescueHolder.Visible = true
	self._rescueText.Text = "Rescuing..."
	self._rescueText.TextColor3 = Theme.colors.paper
	self._rescueFill.Size = UDim2.fromScale(0, 1)
	self._action.Text = "Keep holding"
	self._action.TextColor3 = Theme.hud.text
	local elapsed = 0
	self._rescueConnection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local alpha = math.clamp(elapsed / total, 0, 1)
		self._rescueFill.Size = UDim2.fromScale(alpha, 1)
		if alpha >= 1 then
			self:_stopRescueLoop()
		end
	end)
end

-- completed = true when the hold ran its full length (the controller then sends RescueEnd and the
-- server moves the player to carry). false is an early release: the bar resets, nothing else happens.
function CatchPrompt.stopRescue(self: any, completed: boolean)
	self:_stopRescueLoop()
	self._rescuing = false
	if completed then
		self._rescueFill.Size = UDim2.fromScale(1, 1)
		self._rescueText.Text = "Rescued!"
		self._rescueText.TextColor3 = Theme.colors.mint
		self._action.Text = "Rescued!"
		self._action.TextColor3 = Theme.colors.good
	else
		self._rescueFill.Size = UDim2.fromScale(0, 1)
		self._rescueHolder.Visible = false
		self._action.Text = self:_actionText()
		self._action.TextColor3 = Theme.hud.text
	end
end

function CatchPrompt._stopRescueLoop(self: any)
	local connection: RBXScriptConnection? = self._rescueConnection
	if connection then
		connection:Disconnect()
		self._rescueConnection = nil
	end
end

function CatchPrompt.isRescuing(self: any): boolean
	return self._rescuing
end

-- retry = true keeps the prompt open: Commons and lured strays, or a rescue the server turned down for
-- now ("Someone else is rescuing it"). Otherwise the card flashes the reason and hides, which is what a
-- fleeing cat looks like. A fail during a rescue hold also stops and hides the rescue bar.
function CatchPrompt.fail(self: any, reason: string?, retry: boolean?)
	self._failToken += 1
	local token = self._failToken
	self:_stopRescueLoop()
	self._rescuing = false
	local rescue = self._kind == "rescue"
	if rescue then
		self._rescueFill.Size = UDim2.fromScale(0, 1)
		self._rescueHolder.Visible = false
	end
	local fallback = if not retry
		then "It got away"
		elseif rescue and not self._press then "Hold again to rescue it"
		else "Missed, try again"
	self._action.Text = reason or fallback
	self._action.TextColor3 = Theme.colors.warn
	task.delay(if retry then 1.4 else 0.9, function()
		if self._failToken ~= token then
			return
		end
		if retry then
			self._action.Text = self:_actionText()
			self._action.TextColor3 = Theme.hud.text
		else
			self:hide()
		end
	end)
end

-- v0.3 press prompt: the press went to the server; dim the card until the circles or the minigame come.
function CatchPrompt.waiting(self: any)
	self._failToken += 1
	self._action.Text = "Get ready..."
	self._action.TextColor3 = Theme.hud.subtext
end

function CatchPrompt.hide(self: any)
	self._failToken += 1
	self:_stopRescueLoop()
	self._rescuing = false
	self._rescueHolder.Visible = false
	self.screenGui.Enabled = false
end

function CatchPrompt.isVisible(self: any): boolean
	return self.screenGui.Enabled
end

function CatchPrompt.destroy(self: any)
	self:_stopRescueLoop()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.holdBegan:DisconnectAll()
	self.holdEnded:DisconnectAll()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return CatchPrompt
