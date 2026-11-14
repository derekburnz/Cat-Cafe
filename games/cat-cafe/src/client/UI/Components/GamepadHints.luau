--!strict
-- #4224 (console controls, from player feedback): a small strip along the bottom of the screen that says which
-- controller buttons do what right now (GamepadHintsLogic picks them): "View Menu" with nothing open, "A Select,
-- B Walk" on the HUD's menu grid, "A Select, B Back, LB RB Tabs" in a window. Only on a controller and while the
-- padControls switch is on. Each key shows the platform's own button picture (UserInputService:GetImageForKeyCode,
-- so a PlayStation pad sees its own shapes) and falls back to a round cap with the Xbox name.
-- Its own ScreenGui just over the windows (DisplayOrder 21), never selectable, so the DPad never lands on it.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local GamepadHintsLogic = require(script.Parent.GamepadHintsLogic)
local GamepadNav = require(script.Parent.GamepadNav)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local GamepadHints = {}
GamepadHints.__index = GamepadHints

local HEIGHT = 30 -- design px
local CAP = 22
local BOTTOM = 6

local KEYCODES: { [GamepadHintsLogic.Key]: Enum.KeyCode } = {
	A = Enum.KeyCode.ButtonA,
	B = Enum.KeyCode.ButtonB,
	L1 = Enum.KeyCode.ButtonL1,
	R1 = Enum.KeyCode.ButtonR1,
	Select = Enum.KeyCode.ButtonSelect,
}

-- the platform's picture for `key`, or nil (none given, or the call is missing)
local function picture(key: GamepadHintsLogic.Key): string?
	local ok, image = pcall(function()
		return (UserInputService :: any):GetImageForKeyCode(KEYCODES[key])
	end)
	if ok and type(image) == "string" and image ~= "" then
		return image
	end
	return nil
end

local function cap(key: GamepadHintsLogic.Key, order: number): GuiObject
	local image = picture(key)
	if image ~= nil then
		return Create("ImageLabel", {
			Name = "Key" .. key,
			BackgroundTransparency = 1,
			Image = image,
			Size = UDim2.fromOffset(CAP, CAP),
			LayoutOrder = order,
		})
	end
	local text = GamepadHintsLogic.CAP[key]
	local frame: TextLabel = Create("TextLabel", {
		Name = "Key" .. key,
		BackgroundColor3 = Theme.colors.white,
		Size = UDim2.fromOffset(math.max(CAP, 10 + #text * 8), CAP),
		FontFace = Theme.fonts.bodyBold,
		Text = text,
		TextColor3 = Theme.dark.panel,
		TextSize = 13,
		LayoutOrder = order,
	})
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	return frame
end

function GamepadHints.new(parent: Instance, modal: any)
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafePadHints",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 21,
		Enabled = false,
		Parent = parent,
	})
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	local uiScale = Scale.bind(root)
	local strip: Frame = Create("Frame", {
		Name = "Strip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM),
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.dark.panel,
		BackgroundTransparency = 0.08,
		Parent = root,
	})
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = strip })
	Create("UIStroke", { Color = Theme.dark.cardStroke, Thickness = 1.5, Parent = strip })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = strip,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 16),
		Parent = strip,
	})

	local self = setmetatable({}, GamepadHints) :: any
	self.screenGui = screenGui
	self._strip = strip
	self._modal = modal
	self._uiScale = uiScale
	self._shown = "" -- the hints drawn now, so an unchanged refresh leaves the strip alone
	self._connections = {} :: { RBXScriptConnection }

	local function later()
		task.defer(function()
			self:refresh()
		end)
	end
	table.insert(self._connections, UserInputService.LastInputTypeChanged:Connect(later))
	table.insert(
		self._connections,
		GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(later)
	)
	table.insert(
		self._connections,
		ReplicatedStorage:GetAttributeChangedSignal("LiveFlag_" .. GamepadNav.FLAG):Connect(later)
	)
	self._modalConnection = modal.changed:Connect(later)
	self:refresh()
	return self
end

function GamepadHints.refresh(self: any)
	local modal = self._modal
	local window = modal:current() ~= nil
	local tabs = false
	if window then
		local row = GamepadNav.tabs(modal.container)
		tabs = row ~= nil
	end
	-- a short screen's window reaches 8 px from the bottom (Modal), so there the strip stays away while one is open
	local list: { GamepadHintsLogic.Hint } = if window and Scale.isShort()
		then {}
		else GamepadHintsLogic.keys({
			gamepad = GamepadNav.isGamepad(),
			on = GamepadNav.on(),
			window = window,
			tabs = tabs,
			selecting = GuiService.SelectedObject ~= nil,
			card = GamepadNav.hasBack(),
		})
	local words = {}
	for _, hint in list do
		table.insert(words, table.concat(hint.keys, "+") .. ":" .. hint.label)
	end
	local key = table.concat(words, ",")
	if key == self._shown then
		return
	end
	self._shown = key
	for _, child in self._strip:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, hint in list do
		local item: Frame = Create("Frame", {
			Name = "Hint" .. hint.label,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			Parent = self._strip,
		})
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
			Parent = item,
		})
		for order, button in hint.keys do
			cap(button :: GamepadHintsLogic.Key, order).Parent = item
		end
		Create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Theme.fonts.bodyBold,
			Text = hint.label,
			TextColor3 = Theme.dark.text,
			TextSize = 15,
			LayoutOrder = #hint.keys + 1,
			Parent = item,
		})
	end
	-- over a window: along the bottom, under it; with none open: at the right edge below the goal card (Review-QA: at
	-- the top it covered the tip cards, at the bottom the travel row)
	if window then
		self._strip.AnchorPoint = Vector2.new(0.5, 1)
		self._strip.Position = UDim2.new(0.5, 0, 1, -BOTTOM)
	else
		self._strip.AnchorPoint = Vector2.new(1, 0.5)
		self._strip.Position = UDim2.new(1, -BOTTOM, 0.62, 0)
	end
	self.screenGui.Enabled = #list > 0
end

function GamepadHints.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	if self._modalConnection ~= nil then
		self._modalConnection:Disconnect()
		self._modalConnection = nil
	end
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return GamepadHints
