--!strict
-- Gamepad menu navigation (#2872, console support #2871).
-- Roblox terms: on a gamepad, GuiService.SelectedObject is the button the controller is "on". The DPad and the left
-- stick move it between buttons, and A presses it. While it is nil the sticks walk the character. Nothing set it
-- before this, so a console player had to find Roblox's own selection toggle to reach any menu.
--   * Select (the View button) starts selecting on the HUD's menu grid (init.luau), and pressed again lets go.
--   * Each window selects its first useful button when it opens on a gamepad (Modal), and closing it gives the old
--     selection back, so a player who opened Cats from the grid lands on the grid again.
--   * The highlight is a thick sky-blue ring with a white inner line (highlight), which reads on cream cards, cocoa
--     bars and the photo backgrounds alike; Roblox's default is a thin grey bracket that vanishes on Cozy Cream.
-- Only on gamepad input: a mouse, keyboard or touch player never sees a selection appear.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local GamepadNav = {}

-- names of buttons (or of the Button frame round their Face) a window's first selection skips: its X, and the arrow tabs that fold HUD rows
local SKIP: { [string]: boolean } = { Close = true, MenuFold = true, TravelFold = true }
local ROW = 12 -- pixels: buttons whose tops are this close count as one row, read left to right

local GAMEPADS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true,
}

-- True while the player is on a controller: the last input came from a gamepad.
function GamepadNav.isGamepad(): boolean
	return GAMEPADS[UserInputService:GetLastInputType()] == true
end

-- True when `object` and every GuiObject over it are Visible, and its ScreenGui is on.
function GamepadNav.shown(object: Instance?): boolean
	if object == nil or not object:IsA("GuiObject") then
		return false
	end
	local at: Instance? = object
	for _ = 1, 64 do
		local here = at
		if here == nil then
			return false
		elseif here:IsA("GuiObject") then
			if not (here :: GuiObject).Visible then
				return false
			end
		elseif here:IsA("LayerCollector") then
			if not (here :: LayerCollector).Enabled then
				return false
			end
			-- a ScreenGui that was destroyed or taken out keeps Enabled, and selecting a button in it is the
			-- engine's "Setting GuiService.SelectedObject to invalid GuiObject" (84 a day, #3839): it must still
			-- hang under a PlayerGui
			local up: Instance? = here.Parent
			for _ = 1, 16 do
				local step = up
				if step == nil then
					return false
				elseif step:IsA("PlayerGui") then
					return true
				end
				up = step.Parent
			end
			return false
		end
		at = here.Parent
	end
	return false
end

-- The buttons under `root` a gamepad can land on, in reading order (rows top to bottom, each left to right).
function GamepadNav.buttons(root: Instance): { GuiButton }
	local found: { GuiButton } = {}
	for _, descendant in root:GetDescendants() do
		if
			descendant:IsA("GuiButton")
			and (descendant :: GuiButton).Selectable
			and (descendant :: GuiButton).Active
			and not SKIP[descendant.Name]
			and not (descendant.Parent ~= nil and SKIP[(descendant.Parent :: Instance).Name]) -- a Button's Face
			and GamepadNav.shown(descendant)
		then
			table.insert(found, descendant :: GuiButton)
		end
	end
	table.sort(found, function(a: GuiButton, b: GuiButton): boolean
		local ay, by = a.AbsolutePosition.Y, b.AbsolutePosition.Y
		if math.abs(ay - by) > ROW then
			return ay < by
		end
		return a.AbsolutePosition.X < b.AbsolutePosition.X
	end)
	return found
end

-- The first useful button under `root`, or nil when it has none: the first row's item, buy or equip button rather than
-- a tab over it (a window's tab strip is a frame named Tabs), so A does the window's main thing at once and Up reaches
-- the tabs; a window of only tabs lands on its first tab.
function GamepadNav.first(root: Instance): GuiButton?
	local buttons = GamepadNav.buttons(root)
	for _, button in buttons do
		local tabs = button:FindFirstAncestor("Tabs")
		if tabs == nil or not tabs:IsDescendantOf(root) then
			return button
		end
	end
	return buttons[1]
end

-- Selects `target` when it still shows (GamepadNav.shown), else clears the selection, so the engine is never handed a
-- hidden, destroyed or taken out button (#3839). Returns whether `target` was selected.
function GamepadNav.select(target: GuiObject?): boolean
	if target ~= nil and GamepadNav.shown(target) then
		GuiService.SelectedObject = target
		return true
	end
	if GuiService.SelectedObject ~= nil then
		GuiService.SelectedObject = nil
	end
	return false
end

-- Puts the gamepad selection on the first useful button under `root` and returns what was selected before (to hand
-- back to restore). Does nothing off a gamepad, or when `root` has no button, and then returns nil.
function GamepadNav.focus(root: Instance): (GuiObject?, boolean)
	if not GamepadNav.isGamepad() then
		return nil, false
	end
	local first = GamepadNav.first(root)
	if first == nil then
		return nil, false
	end
	local before = GuiService.SelectedObject
	return before, GamepadNav.select(first)
end

-- Gives the selection back to `before` when it still shows, else clears it (the sticks walk again).
function GamepadNav.restore(before: GuiObject?)
	GamepadNav.select(before)
end

-- The selection ring: an outer sky-blue stroke and a white inner line, over the selected button's whole size.
function GamepadNav.ring(): Frame
	local inner: Frame = Create("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) :: Instance,
		Create("UIStroke", {
			Color = Theme.colors.white,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}) :: Instance,
	})
	return Create("Frame", {
		Name = "CatCafeSelection",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) :: Instance,
		Create("UIStroke", {
			Color = Theme.colors.sky,
			Thickness = 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}) :: Instance,
		inner :: Instance,
	})
end

-- Every button in `playerGui` draws the ring when selected (PlayerGui.SelectionImageObject).
function GamepadNav.highlight(playerGui: Instance)
	if playerGui:IsA("PlayerGui") then
		local ring = GamepadNav.ring()
		ring.Parent = playerGui;
		(playerGui :: PlayerGui).SelectionImageObject = ring
	end
end

return GamepadNav
