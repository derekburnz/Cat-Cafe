--!strict
-- Viewport-driven scaling. Every ScreenGui root gets one UIScale from Scale.bind, so screens are laid out
-- in design pixels (1280x720) and shrink or grow together. Touch devices get a floor so buttons stay tappable.

local UserInputService = game:GetService("UserInputService")

local Signal = require(script.Parent.Components.Signal)

local Scale = {}

Scale.DESIGN = Vector2.new(1280, 720)
Scale.MIN = 0.6
Scale.MAX = 1.3
Scale.TOUCH_FLOOR = 0.75

Scale.changed = Signal.new() -- fires (scale: number)

local current = 1
local bound: { UIScale } = {}
local cameraConnection: RBXScriptConnection? = nil
local workspaceConnection: RBXScriptConnection? = nil

-- Phones and tablets without a keyboard or mouse plugged in.
function Scale.isTouch(): boolean
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
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

function Scale.refresh()
	current = Scale.compute(viewportSize())
	for _, uiScale in bound do
		uiScale.Scale = current
	end
	Scale.changed:Fire(current)
end

-- Creates a UIScale under `parent` that tracks the viewport. Call unbind on destroy.
function Scale.bind(parent: GuiObject): UIScale
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ViewportScale"
	uiScale.Scale = current
	uiScale.Parent = parent
	table.insert(bound, uiScale)
	return uiScale
end

function Scale.unbind(uiScale: UIScale)
	local index = table.find(bound, uiScale)
	if index then
		table.remove(bound, index)
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
