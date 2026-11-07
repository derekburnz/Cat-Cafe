--!strict
-- #2314 (Derek2: "not only flash the buttons you need to click next but also show big arrow on screen temporarily
-- pointing toward what to click next"): a big gold arrow with the dark outline, bobbing toward the thing a tutorial
-- step glows (Components/TutorialGlow adds and removes its targets here). One arrow at a time, at the newest target
-- that is on screen: hidden while the target is hidden, scrolled out of its list or under an open window, so the
-- HUD's Upgrades tile hands over to the row inside Upgrades once the window opens. It shows for SHOW_SECONDS when a
-- target starts to glow, then comes back every AGAIN_SECONDS while the step still waits, and goes with the glow.
-- With Roblox's Reduce Motion on it holds still. It sits in the target's own ScreenGui, over everything there.
--   add(target, low?)  the arrow may point at target (newest first); a `low` target (#2331, the goal card's ready
--                      rank up) only while no tutorial target is on screen, so it never takes the tutorial's arrow
--   remove(target)   not any more

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
local SIZE = 64 -- design px; Scale makes it a phone's or a big screen's
local BOB = 8 -- px it bobs toward the target
local BOB_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local Z = 60 -- over the target's ScreenGui's own pieces (they stay under 30)

type Entry = { target: GuiObject, since: number, low: boolean }

local entries: { Entry } = {}
local arrow: Frame? = nil
local loop: RBXScriptConnection? = nil
-- the other buttons the arrow should keep off, measured again every OTHERS_SECONDS (a walk of the whole ScreenGui)
local OTHERS_SECONDS = 0.5
local others: { TutorialArrowLogic.Rect } = {}
local othersFor: GuiObject? = nil
local othersAt = -math.huge

local function build(): Frame
	local holder: Frame = Create("Frame", {
		Name = TutorialArrow.NAME,
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
			piece:IsA("GuiButton")
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

local function hide()
	local current = arrow
	if current then
		current.Visible = false
	end
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
	local current = arrow or build()
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
	local place =
		TutorialArrowLogic.place(target.AbsolutePosition, target.AbsoluteSize, screen, px, others)
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

-- The arrow frame while it shows, or nil (the UI gate's scenes read it).
function TutorialArrow.current(): Frame?
	local current = arrow
	return if current and current.Visible then current else nil
end

return TutorialArrow
