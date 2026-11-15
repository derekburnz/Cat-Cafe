--!strict
-- #4668 (Derek 2026-11-15: "a setting to remove the circles infront of all stations/things in settings and have it
-- default turn to visibility off I think it adds too much visual clutter but have the menus still open in the area"):
-- the glowing walk-up rings (World/WalkUpCircles, parts named WalkUp.CIRCLE) are hidden on this client unless the
-- Settings switch "Station circles" (settings.stationCircles, off by default) is on. Only the look goes: the ring part
-- stays where the server put it and moves with its station, so WalkUpController still opens the window on stepping
-- in, and the server's pad checks are untouched.
--
-- Hidden means the ring's SurfaceGui pieces are not Visible (StationLockController switches the SurfaceGui's own
-- Enabled for a locked station, so the two never fight) and the art laid in its middle has LocalTransparencyModifier 1.
-- A sweep every SWEEP (1) seconds puts the look back after anything else touches it (a station unlocking). Listening only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WalkUp = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WalkUp"))

local StationCircles = {}

local SWEEP = 1 -- seconds between sweeps of the known rings (a station unlocking flashes its art at most this long)

local started = false
local shown = false
local rings: { [BasePart]: RBXScriptConnection } = {}
local faded: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- what this module faded

-- Pure: whether the rings show for a `stationCircles` setting value (only an explicit true shows them).
function StationCircles.visible(setting: unknown): boolean
	return setting == true
end

local function paint(ring: BasePart)
	for _, child in ring:GetChildren() do
		if child:IsA("SurfaceGui") then
			for _, piece in child:GetChildren() do
				if piece:IsA("GuiObject") then
					(piece :: GuiObject).Visible = shown
				end
			end
		end
	end
	for _, piece in ring:GetDescendants() do
		if piece:IsA("BasePart") or piece:IsA("Decal") then
			local thing = piece :: any
			if not shown then
				if thing.LocalTransparencyModifier < 1 then
					faded[piece] = true
					thing.LocalTransparencyModifier = 1
				end
			elseif faded[piece] then
				faded[piece] = nil
				thing.LocalTransparencyModifier = 0
			end
		end
	end
end

local function track(instance: Instance)
	if instance.Name ~= WalkUp.CIRCLE or not instance:IsA("BasePart") then
		return
	end
	local ring = instance :: BasePart
	if rings[ring] ~= nil then
		return
	end
	-- pieces that stream in after the part
	rings[ring] = ring.DescendantAdded:Connect(function()
		task.defer(paint, ring)
	end)
	paint(ring)
end

local function sweep()
	for ring, connection in rings do
		if ring.Parent == nil then
			connection:Disconnect()
			rings[ring] = nil
		else
			paint(ring)
		end
	end
end

-- Shows or hides every ring at once (Effects.applySettings, on a Settings tap and the saved value).
function StationCircles.set(setting: unknown)
	local want = StationCircles.visible(setting)
	if want == shown then
		return
	end
	shown = want
	sweep()
end

function StationCircles.start()
	if started then
		return
	end
	started = true
	for _, instance in Workspace:GetDescendants() do
		track(instance)
	end
	Workspace.DescendantAdded:Connect(track)
	task.spawn(function()
		while true do
			task.wait(SWEEP)
			sweep()
		end
	end)
end

return StationCircles
