--!strict
-- Catch prompt card for strays and stuck cats.
--   show(info)          "[E] Catch" card at the bottom centre with the cat's name, stars, rarity and (v0.4) the
--                       paws this player has left on it.
--   waiting()           one press went to the server: "Get ready..." until the circles (CatchCircles) or the
--                       rescue bar (RescueBar) come.
--   fail(reason)        red flash ("It got away"), then hide; with retry the card stays.
--   hide()
-- Nothing holds any more: a stray's prompt (F26) and a stuck cat's (F27) have HoldDuration 0, and one press asks
-- the server for the closing circles or the rescue minigame.
-- On touch devices a big round CATCH button appears; it drives the real prompt through holdBegan / holdEnded.
-- bindProximityPrompts() in init.luau wires all of this to any ProximityPrompt with Style = Custom.

local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local PawRow = require(script.Parent.Parent.Components.PawRow)
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
	fail: (self: CatchPrompt, reason: string?, retry: boolean?) -> (),
	waiting: (self: CatchPrompt) -> (),
	hide: (self: CatchPrompt) -> (),
	isVisible: (self: CatchPrompt) -> boolean,
	destroy: (self: CatchPrompt) -> (),
}

local CatchPrompt = {}
CatchPrompt.__index = CatchPrompt

function CatchPrompt.new(parent: Instance): CatchPrompt
	local self = setmetatable({}, CatchPrompt) :: any
	self.holdBegan = Signal.new()
	self.holdEnded = Signal.new()
	self._connections = {} :: { RBXScriptConnection }
	self._failToken = 0
	self._kind = "swing" :: Types.PromptKind

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
	self._paws = PawRow.new({
		parent = card,
		paw = 16,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 0, 62),
	})

	-- Mobile CATCH button (bottom right, above the lure slot); reads RESCUE on a stuck cat
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

function CatchPrompt._actionText(self: any): string
	return if self._kind == "rescue" then "Rescue" else "Catch"
end

function CatchPrompt.show(self: any, info: Types.CatchInfo)
	self._failToken += 1
	local kind: Types.PromptKind = info.kind or "swing"
	local rescue = kind == "rescue" -- a plain boolean: chained singleton tests confuse the type checker
	self._kind = kind
	self._action.Text = info.actionText or self:_actionText()
	self._action.TextColor3 = Theme.hud.text
	self._grab.Text = if rescue then "RESCUE" else "CATCH"
	local nameText = info.catName or ""
	if info.stars then
		nameText = nameText .. "  " .. Format.stars(info.stars :: number)
	end
	self._catName.Text = nameText
	local rarity: string = info.rarity or "Common"
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	-- v0.4 strays carry Patience: any miss costs a paw. Without it the v0.3 rule holds (only Commons stay).
	local v04 = info.patience ~= nil and not rescue
	self._hint.Text = if rescue
		then "Stop the marker in the zone. The cat never leaves if you miss."
		elseif v04 then "Hit each ring. A miss costs a paw!"
		elseif rarity == "Common" then "Hit each circle on its ring. Commons stay if you miss."
		else "Hit each circle on its ring. It runs if you miss!"
	self._paws:set(if v04 then info.paws else nil, info.patience)
	self._hint.Size = UDim2.new(1, if v04 then -140 else -80, 0, 18)
	local key: Enum.KeyCode = info.keyCode or Enum.KeyCode.E
	self._keycap.Text = key.Name
	self._keycap.Visible = not Scale.isTouch()
	self._grab.Visible = Scale.isTouch()
	if not self.screenGui.Enabled then
		self.screenGui.Enabled = true
		Tween.popIn(self._card, 0.9)
	end
end

-- retry = true keeps the prompt open: Commons and lured strays, or a rescue the server turned down for
-- now ("Someone else is rescuing it"). Otherwise the card flashes the reason and hides, which is what a
-- fleeing cat looks like.
function CatchPrompt.fail(self: any, reason: string?, retry: boolean?)
	self._failToken += 1
	local token = self._failToken
	local fallback = if retry then "Missed, try again" else "It got away"
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

-- The press went to the server; dim the card until the circles or the minigame come.
function CatchPrompt.waiting(self: any)
	self._failToken += 1
	self._action.Text = "Get ready..."
	self._action.TextColor3 = Theme.hud.subtext
end

function CatchPrompt.hide(self: any)
	self._failToken += 1
	self.screenGui.Enabled = false
end

function CatchPrompt.isVisible(self: any): boolean
	return self.screenGui.Enabled
end

function CatchPrompt.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.holdBegan:DisconnectAll()
	self.holdEnded:DisconnectAll()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return CatchPrompt
