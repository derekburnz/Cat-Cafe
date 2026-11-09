--!strict
-- Viewport-driven scaling. Every ScreenGui root gets one UIScale from Scale.bind, so screens are laid out
-- in design pixels (1280x720) and shrink or grow together. Touch devices get a floor so buttons stay tappable.
-- MIN is the same 0.75 as that floor (device pass 2026-11-07): at 0.6 a small laptop window drew textTiny at 7 px and
-- the Store's card words at about 8, so a small window now draws the UI at a phone's size.

local UserInputService = game:GetService("UserInputService")

local Signal = require(script.Parent.Components.Signal)

local Scale = {}

Scale.DESIGN = Vector2.new(1280, 720)
Scale.MIN = 0.75
Scale.MAX = 1.3
Scale.TOUCH_FLOOR = 0.75

Scale.changed = Signal.new() -- fires (scale: number)

local current = 1
-- Each bound root is a full-screen Frame. UIScale shrinks it about its top-left corner, so the root's
-- Size is set to 1/scale to keep it covering the screen; right- and bottom-anchored children stay on the edges.
local bound: { { uiScale: UIScale, root: GuiObject } } = {}
local cameraConnection: RBXScriptConnection? = nil
local workspaceConnection: RBXScriptConnection? = nil

-- Phones and tablets without a keyboard or mouse plugged in.
function Scale.isTouch(): boolean
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

Scale.TAP = 44 -- px a finger needs on screen (ui-review; the UI gate's tap check)

-- A button's height in design pixels that still gives a 44 px face on the smallest phone scale (TOUCH_FLOOR), less
-- `depth` px of lip under the face; `height` unchanged with a mouse or when it is already enough.
function Scale.tapHeight(height: number, depth: number?): number
	if not Scale.isTouch() then
		return height
	end
	return math.max(height, math.ceil(Scale.TAP / Scale.TOUCH_FLOOR) + (depth or 0))
end

function Scale.compute(viewport: Vector2): number
	local s = math.min(viewport.X / Scale.DESIGN.X, viewport.Y / Scale.DESIGN.Y)
	s = math.clamp(s, Scale.MIN, Scale.MAX)
	if Scale.isTouch() then
		s = math.max(s, Scale.TOUCH_FLOOR)
	end
	return s
end

local function viewportSize(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Scale.DESIGN
end

function Scale.get(): number
	return current
end

-- #2339 (Laptop-Tester, iPhone SE: "windows show only about 1.5 rows"): a screen under SHORT design pixels tall is
-- short, a phone held sideways (an iPhone SE is 500, an 844 x 390 phone 520; a PC's window never is, as MIN keeps
-- its design height at 720 down to a 540 px tall window). Windows then take more of the height and a slimmer header.
Scale.SHORT = 560
function Scale.isShort(): boolean
	return viewportSize().Y / current < Scale.SHORT
end

-- #2762 (Derek2: tips, the "How is it so far?" ask and the bubbles are "for phone too big"): a touch screen that is
-- short, a phone held sideways. The touch floor draws the UI there at about 1.6 times its share of a PC's screen, so
-- the pop-ups that need no finger-sized parts (tip cards, the hint strip, the ask's title) take a smaller layout.
function Scale.isPhone(): boolean
	return Scale.isTouch() and Scale.isShort()
end

-- #2762: a world BillboardGui's pixel part for this screen. Billboards sit outside every UIScale, so a 120 px bubble
-- took a sixth of a phone's width; this scales `px` with the screen's height, full size from 720 px tall and down to
-- BILLBOARD_MIN on a phone held sideways. A screen not measured yet (under 100 px) counts as full size.
Scale.BILLBOARD_MIN = 0.55
function Scale.billboard(px: number): number
	local height = viewportSize().Y
	local share = if height < 100
		then 1
		else math.clamp(height / Scale.DESIGN.Y, Scale.BILLBOARD_MIN, 1)
	return math.floor(px * share + 0.5)
end

-- #2762: a world bubble's studs on this screen: 0.8 of them on a phone, so one close by covers less of it.
Scale.PHONE_STUDS = 0.8
function Scale.phoneStuds(): number
	return if Scale.isPhone() then Scale.PHONE_STUDS else 1
end

function Scale.refresh()
	current = Scale.compute(viewportSize())
	for _, entry in bound do
		entry.uiScale.Scale = current
		entry.root.Size = UDim2.fromScale(1 / current, 1 / current)
	end
	Scale.changed:Fire(current)
end

-- Creates a UIScale under `parent` (a full-screen root Frame) that tracks the viewport. Call unbind on destroy.
function Scale.bind(parent: GuiObject): UIScale
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ViewportScale"
	uiScale.Scale = current
	uiScale.Parent = parent
	parent.Size = UDim2.fromScale(1 / current, 1 / current)
	table.insert(bound, { uiScale = uiScale, root = parent })
	return uiScale
end

function Scale.unbind(uiScale: UIScale)
	for index, entry in bound do
		if entry.uiScale == uiScale then
			table.remove(bound, index)
			return
		end
	end
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(Scale.refresh)
	end
	Scale.refresh()
end

function Scale.start()
	if workspaceConnection then
		return
	end
	workspaceConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

function Scale.stop()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	if workspaceConnection then
		workspaceConnection:Disconnect()
		workspaceConnection = nil
	end
	table.clear(bound)
end

return Scale
