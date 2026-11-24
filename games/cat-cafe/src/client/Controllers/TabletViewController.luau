--!strict
-- #5696 (switch tabletView, shared/TabletView): on a touch screen held sideways and narrower than 16:9 the player
-- camera's vertical view widens so a tablet sees as much sideways as a 16:9 screen (80 on a 4:3 iPad). Worked out
-- again when the screen turns and when the camera is replaced. A view an effect set (DragonRise, RiftRun) is left
-- alone: only BASE or the value this set last is changed, and those effects put their saved view back after.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(script.Parent.Parent.Net)
local Scale = require(script.Parent.Parent.UI.Scale)
local TabletView = require(Shared:WaitForChild("TabletView"))

local TabletViewController = {}

local FLAG_ATTR = "LiveFlag_" .. TabletView.FLAG
local lastSet: number? = nil -- the view this controller last put on the camera
local reported = false
local viewportConn: RBXScriptConnection? = nil

local function wanted(camera: Camera): number
	if ReplicatedStorage:GetAttribute(FLAG_ATTR) ~= true then
		return TabletView.BASE
	end
	local size = camera.ViewportSize
	if size.Y <= 0 then
		return TabletView.BASE
	end
	return TabletView.fov(size.X / size.Y, Scale.isTouch())
end

local function apply()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = camera.FieldOfView
	if now ~= TabletView.BASE and now ~= lastSet then
		return -- an effect's own view; it restores the one it saved
	end
	local fov = wanted(camera)
	if now ~= fov then
		camera.FieldOfView = fov
	end
	lastSet = fov
	if not reported and fov ~= TabletView.BASE then
		reported = true
		Net.fire("TelemetryReport", TabletView.REPORT, fov)
	end
end

local function watchCamera()
	if viewportConn ~= nil then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
	apply()
end

function TabletViewController.start()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	ReplicatedStorage:GetAttributeChangedSignal(FLAG_ATTR):Connect(apply)
	watchCamera()
end

return TabletViewController
