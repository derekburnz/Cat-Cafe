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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Button)
local Create = require(script.Parent.Create)
local GamepadTabs = require(script.Parent.GamepadTabs)
local Theme = require(script.Parent.Parent.Theme)

local GamepadNav = {}

-- #4224: the console controls (B back one step, L1/R1 tabs, pop-ups taking focus) wait for their own update day
-- (Wed 2026-11-25) behind this switch; off, B and the cards work as before
GamepadNav.FLAG = "padControls"
function GamepadNav.on(): boolean
	local LiveFlags =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any
	return LiveFlags.shown(
		GamepadNav.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. GamepadNav.FLAG)
	)
end

-- names of buttons (or of the Button frame round their Face) a window's first selection skips: its X, and the arrow tabs that fold HUD rows
local SKIP: { [string]: boolean } = { Close = true, MenuFold = true, TravelFold = true }
-- #4224: the frames that hold a window's tab row (a tabbed window's Tabs, the Store's Rail, the Bait Bowl's Bowls,
-- the Decor shop's Chips): L1/R1 step through them, and a window's first selection lands below them
local TAB_ROWS: { [string]: boolean } = { Tabs = true, Rail = true, Bowls = true, Chips = true }
-- #4224 (Review-QA's controller pass): buttons a window's first selection passes over when it has another, so a
-- habit A never spends every potion ("Use all potions", Use all) or collects a station strip in place of Launch
local SKIP_FIRST: { [string]: boolean } =
	{ UseAllPotions = true, DrinkAll = true, UseAll = true, Collect = true }
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
	local fallback: GuiButton? = nil
	for _, button in buttons do
		local onTabs = false
		local at: Instance? = button.Parent
		while at ~= nil and at ~= root do
			if TAB_ROWS[at.Name] then
				onTabs = true
				break
			end
			at = at.Parent
		end
		if not onTabs then
			local face = if button.Parent ~= nil then (button.Parent :: Instance).Name else ""
			if not (SKIP_FIRST[button.Name] or SKIP_FIRST[face]) then
				return button
			end
			fallback = fallback or button
		end
	end
	return fallback or buttons[1]
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

-- #4224 (console controls, from player feedback): B goes back one step. A card or a window's sub page that shows
-- over everything (an ask card, a confirm, the Index detail card) pushes how to close it here while it shows, and B
-- closes the top one that still shows before it closes the window (init.luau). `id` names it, so pushing again
-- moves it to the top and pop takes it out wherever it is.
-- A close that returns false keeps the card (it cannot close now, like the first bowl's card), and B stops there.
type Back = { id: string, frame: GuiObject, close: () -> boolean? }
local backs: { Back } = {}

function GamepadNav.pushBack(id: string, frame: GuiObject, close: () -> boolean?)
	GamepadNav.popBack(id)
	table.insert(backs, { id = id, frame = frame, close = close })
end

function GamepadNav.popBack(id: string)
	for index = #backs, 1, -1 do
		if backs[index].id == id then
			table.remove(backs, index)
		end
	end
end

-- #4224 (the hint strip): whether a pushed card or list still shows, so B goes back out of it
function GamepadNav.hasBack(): boolean
	for index = #backs, 1, -1 do
		if GamepadNav.shown(backs[index].frame) then
			return true
		end
	end
	return false
end

-- Closes the top pushed card that still shows and returns true; a card that has gone without popping is dropped.
-- False when none shows (B then closes the window, or lets go of the selection).
function GamepadNav.back(): boolean
	if not GamepadNav.on() then
		return false
	end
	while #backs > 0 do
		local top = table.remove(backs) :: Back
		if GamepadNav.shown(top.frame) then
			if top.close() == false then
				table.insert(backs, top)
			end
			return true
		end
	end
	return false
end

-- #4224: a pop-up card as it shows: on a gamepad it takes the selection on its main button (`main`, else its first
-- useful button; never its X) and B closes it through `close`. Returns the function to call as it hides, which
-- pops it and gives the selection back when the card had taken it.
function GamepadNav.card(
	id: string,
	frame: GuiObject,
	close: () -> boolean?,
	main: GuiObject?
): () -> ()
	if not GamepadNav.on() then
		return function() end
	end
	GamepadNav.pushBack(id, frame, close)
	local before: GuiObject? = nil
	local took = false
	local done = false
	if GamepadNav.isGamepad() then
		-- a frame later, once the card has laid out and shows, and a few times more while it slides in (Review-QA:
		-- the invite card's first try could miss)
		task.defer(function()
			for _ = 1, 6 do
				if done then
					return
				end
				local target = if main ~= nil and GamepadNav.shown(main)
					then main
					else GamepadNav.first(frame)
				if target ~= nil and GamepadNav.shown(target) then
					before = GuiService.SelectedObject
					took = GamepadNav.select(target)
					if took then
						return
					end
				end
				task.wait(0.1)
			end
		end)
	end
	return function()
		if done then
			return
		end
		done = true
		GamepadNav.popBack(id)
		local selected = GuiService.SelectedObject
		if
			took
			and (
				selected == nil
				or selected:IsDescendantOf(frame)
				or not GamepadNav.shown(selected)
			)
		then
			GamepadNav.restore(before)
		end
	end
end

-- #4224: L1 / R1 step through a window's tabs. The tab row is the first frame named Tabs under `root` that shows
-- (every tabbed window builds one), its tabs are its Buttons in reading order, and the open tab is the one not in
-- the "ghost" style (each window draws the open tab gold or primary and the rest ghost).
GamepadNav.tabIndex = GamepadTabs.index

-- The tab row under `root` and its tabs in reading order, or nil when it shows no row of two or more.
function GamepadNav.tabs(root: Instance): (Instance?, { GuiButton })
	local rows: { GuiObject } = {}
	for _, descendant in root:GetDescendants() do
		if
			TAB_ROWS[descendant.Name]
			and descendant:IsA("GuiObject")
			and GamepadNav.shown(descendant)
		then
			table.insert(rows, descendant :: GuiObject)
		end
	end
	table.sort(rows, function(a: GuiObject, b: GuiObject): boolean
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)
	for _, row in rows do
		local tabs: { GuiButton } = {}
		for _, descendant in row:GetDescendants() do
			if
				descendant:IsA("GuiButton")
				and Button.styleOf(descendant) ~= nil
				and GamepadNav.shown(descendant)
			then
				table.insert(tabs, descendant :: GuiButton)
			end
		end
		if #tabs >= 2 then
			table.sort(tabs, function(a: GuiButton, b: GuiButton): boolean
				local ay, by = a.AbsolutePosition.Y, b.AbsolutePosition.Y
				if math.abs(ay - by) > ROW then
					return ay < by
				end
				return a.AbsolutePosition.X < b.AbsolutePosition.X
			end)
			return row, tabs
		end
	end
	return nil, {}
end

-- Presses the tab `step` away in the window under `root`. A selection on the tab row follows to the new tab; one
-- that the switch hid lands on the window's first button. Returns whether a tab was pressed.
function GamepadNav.stepTab(root: Instance, step: number): boolean
	if not GamepadNav.on() then
		return false
	end
	local row, tabs = GamepadNav.tabs(root)
	if row == nil then
		return false
	end
	local styles: { string? } = {}
	for index, tab in tabs do
		styles[index] = Button.styleOf(tab)
	end
	local index = GamepadNav.tabIndex(styles, step)
	if index == nil then
		return false
	end
	local target = tabs[index]
	local selected = GuiService.SelectedObject
	local onRow = selected ~= nil and selected:IsDescendantOf(row)
	if not Button.press(target) then
		return false
	end
	if onRow then
		GamepadNav.select(target)
		-- a window that rebuilds or re-picks its tab row on a switch: land on the new tab once it has
		task.defer(function()
			local _, now = GamepadNav.tabs(root)
			local tab = now[index]
			if tab ~= nil and GuiService.SelectedObject ~= tab then
				GamepadNav.select(tab)
			end
		end)
	else
		task.defer(function()
			local now = GuiService.SelectedObject
			if now ~= nil and not GamepadNav.shown(now) then
				GamepadNav.select(GamepadNav.first(root))
			end
		end)
	end
	return true
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
