--!strict
-- Action pills: our look for every custom-style ProximityPrompt that is not a cat (the bait bowl, the night
-- dealer's cart, the Sewer manhole, Bump). A dark rounded pill over the thing with a key cap and the
-- prompt's ActionText, its ObjectText small above, like the custom prompts in Pet Simulator 99 and Adopt Me.
--   show(prompt, inputType, note?)  pops a pill in over the prompt's part (PromptShown); a note is one small
--                    outlined line under it, no box (the Mystery gift's chances, F64)
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
		inputType: Enum.ProximityPromptInputType,
		note: string?
	) -> (),
	hide: (self: ActionPill, prompt: ProximityPrompt) -> (),
	holdBegan: (self: ActionPill, prompt: ProximityPrompt) -> (),
	holdEnded: (self: ActionPill, prompt: ProximityPrompt) -> (),
	triggered: (self: ActionPill, prompt: ProximityPrompt) -> (),
	isShown: (self: ActionPill, prompt: ProximityPrompt) -> boolean,
	setQuiet: (self: ActionPill, on: boolean) -> (), -- #3861: no pills while the catch circles or a rescue bar run
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
local NOTE_H = 22 -- the note line under the pill
local NOTE_W = 600
local TAP = "👆" -- the key cap on touch, where there is no key to name
-- Studs a prompt's pill floats over its point, by prompt name. The night dealer's prompt sits at the cart's head
-- height, right on the dealer's cat (Derek 2026-10-28: "make the night dealer text popup be out of the cats face so
-- they can see it"), so its pill goes above the 6.35 stud cart. A prompt's own PillLift attribute (studs) wins.
local LIFT: { [string]: number } = { DealerPrompt = 3 }
-- Derek 2026-11-13 ("the text for petting takes up too much of the screen and has that big obnoxious black border
-- make it smaller"): these prompts get a small pill, SMALL of the size, with a thin soft edge in place of the thick
-- outline. A prompt's own PillSmall attribute (true) does the same.
local SMALL_PROMPTS: { [string]: boolean } = { PetPrompt = true }
local SMALL = 0.62
local SMALL_TOUCH = 0.8

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
	inputType: Enum.ProximityPromptInputType,
	note: string?
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
	-- a note makes the billboard taller below the pill, so the pill itself stays where it was
	local height = if note then HEIGHT + NOTE_H * 2 else HEIGHT
	local small = SMALL_PROMPTS[prompt.Name] == true or prompt:GetAttribute("PillSmall") == true
	-- on touch the pill is the button, so it keeps a thumb's height (0.8 of 54 is 43)
	local k = if small then (if touch then SMALL_TOUCH else SMALL) else 1
	local pillH = math.floor(PILL_HEIGHT * k + 0.5)
	local keySize = math.floor(KEY * k + 0.5)
	if small then
		height = math.floor(height * k + 0.5)
	end

	local ownLift = prompt:GetAttribute("PillLift")
	local lift = if type(ownLift) == "number" and ownLift == ownLift
		then ownLift
		else LIFT[prompt.Name] or 0
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeActionPill",
		Adornee = adornee,
		StudsOffsetWorldSpace = Vector3.new(0, lift, 0),
		AlwaysOnTop = true,
		Active = clickable, -- a BillboardGui only passes taps and clicks to its children when Active
		LightInfluence = 0,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(WIDTH, height),
		SizeOffset = Vector2.new(prompt.UIOffset.X / WIDTH, prompt.UIOffset.Y / height),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	-- The pill is a button so it can be tapped; it grows with its text through AutomaticSize.
	local body: TextButton = Create("TextButton", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, pillH),
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
			PaddingLeft = UDim.new(0, (pillH - keySize) / 2),
			PaddingRight = UDim.new(0, math.floor(20 * k)),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, math.floor(10 * k)),
		}),
	})
	if small then
		-- a thin soft edge, so the pill reads over the cafe without a heavy black ring
		body.BackgroundTransparency = 0.15
		Create("UIStroke", {
			Color = Theme.colors.white,
			Transparency = 0.6,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = body,
		})
	else
		Outline.border(body)
		Outline.shade(body)
	end
	local scale: UIScale = Create("UIScale", { Scale = 1, Parent = body })

	-- Key cap: a light key with a gold fill that rises over a hold
	local cap: Frame = Create("Frame", {
		Name = "Key",
		LayoutOrder = 1,
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(PromptKey.width(keyText, keySize), keySize),
		Parent = body,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
	})
	Outline.border(cap, if small then 1 else 2)
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
		TextSize = math.floor(
			(if utf8.len(keyText) == 1 then Theme.sizes.textLarge else Theme.sizes.textSmall) * k
				+ 0.5
		),
		TextColor3 = Theme.colors.ink,
		Text = keyText,
		Parent = cap,
	})

	-- Text: what it is (small) over what pressing does (big)
	local column: Frame = Create("Frame", {
		Name = "Text",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, pillH - math.floor(8 * k)),
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
		Size = UDim2.fromOffset(0, math.floor(16 * k + 0.5)),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.bodyBold,
		TextSize = math.max(10, math.floor(Theme.sizes.textSmall * k + 0.5)),
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = column,
	})
	local action: TextLabel = Create("TextLabel", {
		Name = "Action",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, math.floor(26 * k + 0.5)),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.fonts.display,
		TextSize = math.floor(Theme.sizes.textLarge * k + 0.5),
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = column,
	})
	Outline.text(action, if small then 1 else nil)
	if note then
		local line: TextLabel = Create("TextLabel", {
			Name = "Note",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, pillH / 2 + 4),
			-- wider than the billboard, which does not clip, so a long line such as the gift's chances fits
			-- #3050: a note of two lines (the Rummage Bin's chances) fills the room the taller billboard leaves
			Size = UDim2.fromOffset(
				NOTE_W,
				(NOTE_H - 4) * (if string.find(note, "\n", 1, true) then 2 else 1)
			),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.white,
			Text = note,
			Parent = billboard,
		})
		Outline.text(line, 1.5)
	end

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
	inputType: Enum.ProximityPromptInputType,
	note: string?
)
	-- shown again for a new input type (a gamepad plugged in): rebuild with the right key
	local old: Pill? = self._pills[prompt]
	if old then
		drop(old, prompt)
		old.billboard:Destroy()
		self._pills[prompt] = nil
	end
	local pill = build(self, prompt, inputType, note)
	if pill == nil then
		return
	end
	self._pills[prompt] = pill
	pill.billboard.Enabled = not self._quiet
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

-- #3861 (Review-QA: the Rummage Bin's "Empty for now" pill sat over the bar's paw pips): while the catch circles or
-- a rescue bar run (HUD.catchingChanged) every pill steps away, and comes back when they end.
function ActionPill.setQuiet(self: any, on: boolean)
	self._quiet = on
	for _, pill: Pill in self._pills do
		pill.billboard.Enabled = not on
	end
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
