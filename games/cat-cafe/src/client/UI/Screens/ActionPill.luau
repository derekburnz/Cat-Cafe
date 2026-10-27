--!strict
-- Action pills: our look for every custom-style ProximityPrompt that is not a cat (the bait bowl, the night
-- dealer's cart, the Sewer manhole, Bump). A dark rounded pill over the thing with a key cap and the
-- prompt's ActionText, its ObjectText small above, like the custom prompts in Pet Simulator 99 and Adopt Me.
--   show(prompt, inputType)  pops a pill in over the prompt's part (PromptShown)
--   hide(prompt)             shrinks it away (PromptHidden)
--   holdBegan / holdEnded    a hold prompt fills its key cap with gold over HoldDuration; letting go drains it
--   triggered(prompt)        a quick squash so the press feels like it landed
-- On touch, and with a mouse when ClickablePrompt is on, the pill itself is the button: it drives the real prompt
-- with InputHoldBegin and InputHoldEnd, so the game sees the same Triggered as a key press.
--
-- Roblox terms: a ProximityPrompt with Style = Custom draws nothing itself. ProximityPromptService tells the
-- client when to show it (PromptShown, with the input type it was shown for) and when to hide it; the engine
-- still reads the key, the hold and the distance, so only the drawing is ours. The pill is a BillboardGui on the
-- prompt's part or attachment, sized in pixels like Roblox's own prompts so it stays readable from afar.

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PromptKey = require(script.Parent.Parent.Components.PromptKey)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type ActionPill = {
	show: (
		self: ActionPill,
		prompt: ProximityPrompt,
		inputType: Enum.ProximityPromptInputType
	) -> (),
	hide: (self: ActionPill, prompt: ProximityPrompt) -> (),
	holdBegan: (self: ActionPill, prompt: ProximityPrompt) -> (),
	holdEnded: (self: ActionPill, prompt: ProximityPrompt) -> (),
	triggered: (self: ActionPill, prompt: ProximityPrompt) -> (),
	isShown: (self: ActionPill, prompt: ProximityPrompt) -> boolean,
	destroy: (self: ActionPill) -> (),
}

type Pill = {
	billboard: BillboardGui,
	body: TextButton,
	scale: UIScale,
	cap: Frame,
	key: TextLabel,
	fill: Frame,
	object: TextLabel,
	action: TextLabel,
	connections: { RBXScriptConnection },
	pressed: boolean, -- the pill itself is held down (touch or mouse)
}

local WIDTH = 360 -- the billboard; the pill inside is as wide as its text
local HEIGHT = 72
local PILL_HEIGHT = 54
local KEY = 38
local TAP = "👆" -- the key cap on touch, where there is no key to name

local ActionPill = {}
ActionPill.__index = ActionPill

function ActionPill.new(parent: Instance): ActionPill
	local self = setmetatable({}, ActionPill) :: any
	self._parent = parent
	self._pills = {} :: { [ProximityPrompt]: Pill }
	return self :: ActionPill
end

-- The part or attachment the pill hangs from: the prompt's parent, or a model's PrimaryPart.
local function adorneeOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent == nil then
		return nil
	end
	if parent:IsA("BasePart") or parent:IsA("Attachment") then
		return parent
	end
	if parent:IsA("Model") then
		return (parent :: Model).PrimaryPart
	end
	return nil
end

local function setTexts(pill: Pill, prompt: ProximityPrompt)
	pill.object.Text = prompt.ObjectText
	pill.object.Visible = prompt.ObjectText ~= ""
	pill.action.Text = if prompt.ActionText ~= "" then prompt.ActionText else "Use"
end

local function build(
	self: any,
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType
): Pill?
	local adornee = adorneeOf(prompt)
	if adornee == nil then
		return nil
	end
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local clickable = touch or prompt.ClickablePrompt
	local keyName = if inputType == Enum.ProximityPromptInputType.Gamepad
		then prompt.GamepadKeyCode.Name
		else prompt.KeyboardKeyCode.Name
	local keyText = if touch then TAP else PromptKey.label(inputType.Name, keyName)

	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeActionPill",
		Adornee = adornee,
		AlwaysOnTop = true,
		Active = clickable, -- a BillboardGui only passes taps and clicks to its children when Active
		LightInfluence = 0,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		SizeOffset = Vector2.new(prompt.UIOffset.X / WIDTH, prompt.UIOffset.Y / HEIGHT),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	-- The pill is a button so it can be tapped; it grows with its text through AutomaticSize.
	local body: TextButton = Create("TextButton", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, PILL_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		Text = "",
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, (PILL_HEIGHT - KEY) / 2),
			PaddingRight = UDim.new(0, 20),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	Outline.border(body)
	Outline.shade(body)
	local scale: UIScale = Create("UIScale", { Scale = 1, Parent = body })

	-- Key cap: a light key with a gold fill that rises over a hold
	local cap: Frame = Create("Frame", {
		Name = "Key",
		LayoutOrder = 1,
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(PromptKey.width(keyText, KEY), KEY),
		Parent = body,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
	})
	Outline.border(cap, 2)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = cap,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
	})
	local key: TextLabel = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		FontFace = Theme.fonts.display,
		TextSize = if utf8.len(keyText) == 1 then Theme.sizes.textLarge else Theme.sizes.textSmall,
		TextColor3 = Theme.colors.ink,
		Text = keyText,
		Parent = cap,
	})

	-- Text: what it is (small) over what pressing does (big)
	local column: Frame = Create("Frame", {
		Name = "Text",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, PILL_HEIGHT - 8),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = body,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local object: TextLabel = Create("TextLabel", {
		Name = "Object",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = column,
	})
	local action: TextLabel = Create("TextLabel", {
		Name = "Action",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = column,
	})
	Outline.text(action)

	local pill: Pill = {
		billboard = billboard,
		body = body,
		scale = scale,
		cap = cap,
		key = key,
		fill = fill,
		object = object,
		action = action,
		connections = {},
		pressed = false,
	}
	setTexts(pill, prompt)

	local function textsChanged()
		setTexts(pill, prompt)
	end
	table.insert(
		pill.connections,
		prompt:GetPropertyChangedSignal("ActionText"):Connect(textsChanged)
	)
	table.insert(
		pill.connections,
		prompt:GetPropertyChangedSignal("ObjectText"):Connect(textsChanged)
	)
	-- PromptHidden covers a disabled or out-of-range prompt; this covers one that is removed outright
	table.insert(
		pill.connections,
		prompt.AncestryChanged:Connect(function()
			if not prompt:IsDescendantOf(game) then
				self:hide(prompt)
			end
		end)
	)

	if clickable then
		-- Roblox's custom prompt pattern: press on the pill begins the hold, lifting off it ends the hold
		table.insert(
			pill.connections,
			body.InputBegan:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if
					(kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1)
					and input.UserInputState ~= Enum.UserInputState.Change
				then
					pill.pressed = true
					prompt:InputHoldBegin()
				end
			end)
		)
		table.insert(
			pill.connections,
			body.InputEnded:Connect(function(input: InputObject)
				local kind = input.UserInputType
				if
					(kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1)
					and pill.pressed
				then
					pill.pressed = false
					prompt:InputHoldEnd()
				end
			end)
		)
	end

	billboard.Parent = self._parent
	return pill
end

-- Lets go of a hold the pill itself began, so walking out of range mid-hold never leaves it held (N76)
local function drop(pill: Pill, prompt: ProximityPrompt)
	for _, connection in pill.connections do
		connection:Disconnect()
	end
	table.clear(pill.connections)
	if pill.pressed then
		pill.pressed = false
		prompt:InputHoldEnd()
	end
end

function ActionPill.show(
	self: any,
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType
)
	-- shown again for a new input type (a gamepad plugged in): rebuild with the right key
	local old: Pill? = self._pills[prompt]
	if old then
		drop(old, prompt)
		old.billboard:Destroy()
		self._pills[prompt] = nil
	end
	local pill = build(self, prompt, inputType)
	if pill == nil then
		return
	end
	self._pills[prompt] = pill
	Tween.popIn(pill.body, 0.6)
end

function ActionPill.hide(self: any, prompt: ProximityPrompt)
	local pill: Pill? = self._pills[prompt]
	if pill == nil then
		return
	end
	self._pills[prompt] = nil
	drop(pill, prompt)
	local billboard = pill.billboard
	Tween.popOut(pill.body, function()
		billboard:Destroy()
	end)
end

function ActionPill.holdBegan(self: any, prompt: ProximityPrompt)
	local pill: Pill? = self._pills[prompt]
	if pill == nil or prompt.HoldDuration <= 0 then
		return
	end
	pill.fill.Size = UDim2.fromScale(1, 0)
	Tween.to(
		pill.fill,
		TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	)
	Tween.press(pill.scale, true)
end

function ActionPill.holdEnded(self: any, prompt: ProximityPrompt)
	local pill: Pill? = self._pills[prompt]
	if pill == nil or prompt.HoldDuration <= 0 then
		return
	end
	Tween.to(pill.fill, Tween.FAST, { Size = UDim2.fromScale(1, 0) })
	Tween.press(pill.scale, false)
end

function ActionPill.triggered(self: any, prompt: ProximityPrompt)
	local pill: Pill? = self._pills[prompt]
	if pill == nil then
		return
	end
	-- a flash of gold through the key and a squash that springs back
	pill.fill.Size = UDim2.fromScale(1, 1)
	Tween.to(
		pill.fill,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad),
		{ Size = UDim2.fromScale(1, 0) }
	)
	pill.scale.Scale = 0.88
	Tween.to(pill.scale, Tween.POP, { Scale = 1 })
end

function ActionPill.isShown(self: any, prompt: ProximityPrompt): boolean
	return self._pills[prompt] ~= nil
end

function ActionPill.destroy(self: any)
	for prompt: ProximityPrompt, pill: Pill in self._pills do
		drop(pill, prompt)
		pill.billboard:Destroy()
	end
	table.clear(self._pills)
end

return ActionPill
