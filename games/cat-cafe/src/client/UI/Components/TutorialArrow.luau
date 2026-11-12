--!strict
-- #2314 (Derek2: "not only flash the buttons you need to click next but also show big arrow on screen temporarily
-- pointing toward what to click next"): a big gold arrow with the dark outline, bobbing toward the thing a tutorial
-- step glows (Components/TutorialGlow adds and removes its targets here). One arrow at a time, at the newest target
-- that is on screen: hidden while the target is hidden, scrolled out of its list or under an open window, so the
-- HUD's Upgrades tile hands over to the row inside Upgrades once the window opens. #3153: it stays for as long as the
-- step waits (it used to hide and come back), never points at a target folded off the screen, and a tutorial target
-- gets the spotlight: the rest of the screen darkens round it (TutorialArrowLogic.dim and holes), and the world's edge
-- arrow (Components/StepTarget) steps aside so there is one arrow to follow. It goes with the glow.
-- With Roblox's Reduce Motion on it holds still. It sits in the target's own ScreenGui, over everything there.
--   add(target, low?)  the arrow may point at target (newest first); a `low` target (#2331, the goal card's ready
--                      rank up) only while no tutorial target is on screen, so it never takes the tutorial's arrow
--   remove(target)   not any more
--   leading()        true while the arrow points at a tutorial (not `low`) target

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local TutorialArrowLogic = require(script.Parent.TutorialArrowLogic)

local TutorialArrow = {}

TutorialArrow.NAME = "TutorialArrow"
TutorialArrow.SPOT_NAME = "TutorialSpotlight"
TutorialArrow.AVOID = "TutorialArrowAvoid" -- #3154: an attribute; a label with it set true is kept off like a button
local SIZE = 64 -- design px; Scale makes it a phone's or a big screen's
local BOB = 8 -- px it bobs toward the target
local BOB_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local Z = 60 -- over the target's ScreenGui's own pieces (they stay under 30)
local SPOT_Z = Z - 1 -- #3153: the spotlight's dim, under the arrow and over the rest of the ScreenGui

type Entry = { target: GuiObject, since: number, low: boolean }

local entries: { Entry } = {}
local arrow: Frame? = nil
local spot: Frame? = nil -- #3153: the spotlight's four dark boxes
-- #3638 (Derek 2026-11-12: "the sides are missing darken"): the dim lives in the target's ScreenGui, which stops at
-- the device's safe area, so on a phone the strips beside it (the notch and the rounded corners' side) stayed bright.
-- This second ScreenGui has no insets and darkens only what lies outside the target's ScreenGui.
local edges: ScreenGui? = nil
TutorialArrow.EDGES_NAME = "CatCafeTutorialSpotEdges"
local spotFor: GuiObject? = nil
local spotSince = 0
local lead = false
local loop: RBXScriptConnection? = nil
-- the other buttons the arrow should keep off, measured again every OTHERS_SECONDS (a walk of the whole ScreenGui)
local OTHERS_SECONDS = 0.5
local others: { TutorialArrowLogic.Rect } = {}
local othersFor: GuiObject? = nil
local othersAt = -math.huge

-- The big arrow, drawn pointing down: its Rotation turns it, and its Bob child bobs toward the tip. #2697: also
-- Components/StepTarget's arrow at the screen's edge.
function TutorialArrow.make(name: string?): Frame
	local holder: Frame = Create("Frame", {
		Name = name or TutorialArrow.NAME,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Visible = false,
		ZIndex = Z,
	})
	local bob: Frame = Create("Frame", {
		Name = "Bob",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = Z,
		Parent = holder,
	})
	local shaft: Frame = Create("Frame", {
		Name = "Shaft",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.34, 0.5),
		ZIndex = Z,
		Parent = bob,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
	})
	Outline.border(shaft, 3)
	local head: TextLabel = Create("TextLabel", {
		Name = "Head",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.62),
		FontFace = Theme.fonts.body,
		TextSize = SIZE,
		TextColor3 = Theme.colors.gold,
		Text = "▼",
		ZIndex = Z + 1,
		Parent = bob,
	})
	Outline.text(head, 3)
	if not GuiService.ReducedMotionEnabled then
		TweenService:Create(bob, BOB_INFO, { Position = UDim2.fromOffset(0, BOB) }):Play()
	end
	return holder
end

-- The ScreenGui the target shows in, or nil while it is hidden, scrolled away or under an open window.
local function shownIn(target: GuiObject): ScreenGui?
	if target.Parent == nil or target.AbsoluteSize.X <= 0 or target.AbsoluteSize.Y <= 0 then
		return nil
	end
	local centre = target.AbsolutePosition + target.AbsoluteSize / 2
	local node: Instance? = target
	while node ~= nil do
		if node:IsA("ScreenGui") then
			break
		end
		if node:IsA("GuiObject") and not node.Visible then
			return nil
		end
		if node ~= target and node:IsA("ScrollingFrame") then
			local from = node.AbsolutePosition
			local to = from + node.AbsoluteSize
			if centre.X < from.X or centre.X > to.X or centre.Y < from.Y or centre.Y > to.Y then
				return nil
			end
		end
		node = node.Parent
	end
	if node == nil or not node:IsA("ScreenGui") then
		return nil
	end
	local gui = node :: ScreenGui
	if not gui.Enabled then
		return nil
	end
	-- #3153: a tile folded off the screen's edge (the menu's arrow tab) is still Visible, but not on screen
	local screen = gui.AbsoluteSize
	local top = if gui.IgnoreGuiInset then 0 else (GuiService:GetGuiInset()).Y
	if
		screen.X > 0
		and not TutorialArrowLogic.onScreen(
			target.AbsolutePosition,
			target.AbsoluteSize,
			screen,
			top
		)
	then
		return nil
	end
	-- a HUD piece while a window is open: the windows' dim is over it
	local dim = gui.Parent and gui.Parent:FindFirstChild("CatCafeModalDim")
	if dim and dim:IsA("ScreenGui") and dim.Enabled and gui.DisplayOrder < dim.DisplayOrder then
		return nil
	end
	return gui
end

local function visible(gui: GuiObject): boolean
	local node: Instance? = gui
	while node ~= nil and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

-- The boxes of the buttons on screen in `gui` other than the target, its own parts and anything screen sized (a
-- window's backdrop).
local function measureOthers(
	gui: ScreenGui,
	target: GuiObject,
	screen: Vector2
): { TutorialArrowLogic.Rect }
	local found: { TutorialArrowLogic.Rect } = {}
	local tile = target.Parent
	for _, piece in gui:GetDescendants() do
		if
			(
				piece:IsA("GuiButton")
				or (piece:IsA("GuiObject") and piece:GetAttribute(TutorialArrow.AVOID) == true)
			)
			and piece ~= (target :: Instance)
			and piece ~= tile
			and not piece:IsDescendantOf(target)
			and not target:IsDescendantOf(piece)
			and piece.Name ~= TutorialArrow.NAME
		then
			local size = piece.AbsoluteSize
			if
				size.X > 0
				and size.Y > 0
				and size.X * size.Y < screen.X * screen.Y / 6
				and visible(piece :: GuiObject)
			then
				local from = piece.AbsolutePosition
				table.insert(found, { min = from, max = from + size })
			end
		end
	end
	return found
end

-- #3153: the spotlight's holder, four black boxes round a hole; never Active, so taps go through to what is under it.
local function makeSpot(): Frame
	local holder: Frame = Create("Frame", {
		Name = TutorialArrow.SPOT_NAME,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		Visible = false,
		ZIndex = SPOT_Z,
	})
	for index = 1, 4 do
		Create("Frame", {
			Name = "Dim" .. index,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
			ZIndex = SPOT_Z,
			Parent = holder,
		})
	end
	return holder
end

local function makeEdges(): ScreenGui
	local gui: ScreenGui = Create("ScreenGui", {
		Name = TutorialArrow.EDGES_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	for _, name in { "Left", "Right", "Top", "Bottom" } do
		Create("Frame", {
			Name = name,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
			Visible = false,
			Parent = gui,
		})
	end
	return gui
end

-- #3638: the same shade over the screen outside `into` (nothing where `into` already reaches the screen's edge).
local function showEdges(into: ScreenGui, shade: number)
	local gui = edges or makeEdges()
	edges = gui
	if gui.Parent ~= into.Parent then
		gui.Parent = into.Parent
	end
	gui.DisplayOrder = into.DisplayOrder
	gui.Enabled = true
	local full = gui.AbsoluteSize
	local margins = TutorialArrowLogic.margins(
		gui.AbsolutePosition,
		full,
		into.AbsolutePosition,
		into.AbsoluteSize
	)
	local boxes: { [string]: { position: UDim2, size: UDim2, thick: number } } = {
		Left = {
			position = UDim2.fromOffset(0, 0),
			size = UDim2.new(0, margins.left, 1, 0),
			thick = margins.left,
		},
		Right = {
			position = UDim2.new(1, -margins.right, 0, 0),
			size = UDim2.new(0, margins.right, 1, 0),
			thick = margins.right,
		},
		Top = {
			position = UDim2.fromOffset(margins.left, 0),
			size = UDim2.new(1, -(margins.left + margins.right), 0, margins.top),
			thick = margins.top,
		},
		Bottom = {
			position = UDim2.new(0, margins.left, 1, -margins.bottom),
			size = UDim2.new(1, -(margins.left + margins.right), 0, margins.bottom),
			thick = margins.bottom,
		},
	}
	for name, box in boxes do
		local found = gui:FindFirstChild(name)
		if found and found:IsA("Frame") then
			local frame = found :: Frame
			frame.Position = box.position
			frame.Size = box.size
			frame.BackgroundTransparency = shade
			frame.Visible = box.thick > 0
		end
	end
end

local function hideSpot()
	local current = spot
	if current then
		current.Visible = false
	end
	local outer = edges
	if outer then
		outer.Enabled = false
	end
	spotFor = nil
end

local function hide()
	local current = arrow
	if current then
		current.Visible = false
	end
	hideSpot()
	lead = false
end

-- #3153: the dim round `target` in `into`, `now` seconds on the clock.
local function showSpot(into: ScreenGui, target: GuiObject, screen: Vector2, now: number)
	local holder = spot or makeSpot()
	spot = holder
	if spotFor ~= target then
		spotFor = target
		spotSince = now
	end
	if holder.Parent ~= into then
		holder.Parent = into
	end
	-- the holder sits at the ScreenGui's origin, in the same pixels as the arrow and AbsolutePosition
	local rects = TutorialArrowLogic.holes(target.AbsolutePosition, target.AbsoluteSize, screen)
	local shade = if GuiService.ReducedMotionEnabled
		then TutorialArrowLogic.SPOT_SOFT
		else TutorialArrowLogic.dim(now - spotSince)
	for index, rect in rects do
		local box = holder:FindFirstChild("Dim" .. index)
		if box and box:IsA("Frame") then
			local frame = box :: Frame
			frame.Position = UDim2.fromOffset(rect.min.X, rect.min.Y)
			frame.Size = UDim2.fromOffset(rect.max.X - rect.min.X, rect.max.Y - rect.min.Y)
			frame.BackgroundTransparency = shade
		end
	end
	holder.Visible = true
	showEdges(into, shade)
end

local function update()
	local now = os.clock()
	local chosen: Entry? = nil
	local gui: ScreenGui? = nil
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.target.Parent == nil then
			table.remove(entries, index)
		elseif chosen == nil or (chosen.low and not entry.low) then
			local shown = shownIn(entry.target)
			if shown then
				chosen = entry
				gui = shown
			end
		end
	end
	if chosen == nil or gui == nil or not TutorialArrowLogic.showing(now - chosen.since) then
		hide()
		return
	end
	local current = arrow or TutorialArrow.make()
	arrow = current
	local px = SIZE * Scale.get()
	local into = gui :: ScreenGui
	local screen = into.AbsoluteSize
	if screen.X <= 0 then
		local camera = Workspace.CurrentCamera
		screen = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end
	local target = chosen.target
	if othersFor ~= target or now - othersAt >= OTHERS_SECONDS then
		others = measureOthers(into, target, screen)
		othersFor = target
		othersAt = now
	end
	local top = if into.IgnoreGuiInset then 0 else (GuiService:GetGuiInset()).Y
	local place = TutorialArrowLogic.place(
		target.AbsolutePosition,
		target.AbsoluteSize,
		screen,
		px,
		others,
		top
	)
	current.Size = UDim2.fromOffset(px, px)
	current.Position = UDim2.fromOffset(place.x, place.y)
	current.Rotation = place.rotation
	local head = current:FindFirstChild("Head", true)
	if head and head:IsA("TextLabel") then
		(head :: TextLabel).TextSize = px
	end
	if current.Parent ~= into then
		current.Parent = into
	end
	current.Visible = true
	lead = not chosen.low
	if lead then
		showSpot(into, target, screen, now)
	else
		hideSpot() -- the goal card's rank up nudge is no tutorial step: no dim for it
	end
end

local function watch()
	if #entries == 0 then
		local running = loop
		if running then
			running:Disconnect()
			loop = nil
		end
		hide()
		return
	end
	if loop == nil then
		loop = RunService.Heartbeat:Connect(update)
	end
	update()
end

function TutorialArrow.add(target: GuiObject, low: boolean?)
	for _, entry in entries do
		if entry.target == target then
			return
		end
	end
	table.insert(entries, { target = target, since = os.clock(), low = low == true })
	watch()
end

function TutorialArrow.remove(target: GuiObject)
	for index = #entries, 1, -1 do
		if entries[index].target == target then
			table.remove(entries, index)
		end
	end
	watch()
end

-- #3153: true while the arrow points at a tutorial target (Components/StepTarget's edge arrow keeps away then).
function TutorialArrow.leading(): boolean
	local current = arrow
	return lead and current ~= nil and current.Visible
end

-- The spotlight's holder while it shows, or nil (the UI gate's scenes read it).
function TutorialArrow.spotlight(): Frame?
	local current = spot
	return if current and current.Visible then current else nil
end

-- #3638: the ScreenGui that darkens the screen outside the target's ScreenGui, while it shows (the gate reads it).
function TutorialArrow.spotEdges(): ScreenGui?
	local current = edges
	return if current and current.Enabled then current else nil
end

-- The arrow frame while it shows, or nil (the UI gate's scenes read it).
function TutorialArrow.current(): Frame?
	local current = arrow
	return if current and current.Visible then current else nil
end

return TutorialArrow
