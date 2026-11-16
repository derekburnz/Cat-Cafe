--!strict
-- #4857: with the backdropsNear switch on, each area's backdrop ring (WorldBuilder's "Backdrop", a child of the area's
-- model) is in this client's Workspace only while the camera or the character is near it (shared/BackdropNear has
-- the rule and the numbers; a cannon flight's camera nears the area well before it lands). The rest wait outside Workspace on this device alone, so
-- a phone at the Town spawn does not draw the far areas' 19,000 ring parts. Switched off, every ring goes back.
--
-- Roblox terms: re-parenting an instance the server made, on a client, changes only that client's copy; nothing is
-- sent to the server. Not for StreamingEnabled (#4788): once the place streams, the engine does this itself, and this
-- switch stays off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BackdropNear = require(Shared:WaitForChild("BackdropNear"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local BackdropController = {}

type Entry = {
	area: string,
	home: Instance, -- the area's model, where the ring goes back to
	box: BackdropNear.Box,
	shown: boolean,
}

local entries: { [Instance]: Entry } = {}

local function on(): boolean
	return LiveFlags.shown(
		BackdropNear.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. BackdropNear.FLAG)
	)
end

local function place(ring: Instance, entry: Entry, show: boolean)
	if entry.shown == show then
		return
	end
	entry.shown = show
	ring.Parent = if show then entry.home else nil
end

local function add(ring: Instance, home: Instance)
	if entries[ring] ~= nil or not ring:IsA("Model") or ring.Name ~= BackdropNear.NAME then
		return
	end
	local area = home:GetAttribute("Area")
	if type(area) ~= "string" then
		return
	end
	local frame, size = ring:GetBoundingBox()
	local right = frame.RightVector
	local flat = Vector3.new(right.X, 0, right.Z)
	local axis = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
	entries[ring] = {
		area = area,
		home = home,
		box = {
			x = frame.Position.X,
			z = frame.Position.Z,
			ax = axis.X,
			az = axis.Z,
			halfX = size.X / 2,
			halfZ = size.Z / 2,
		},
		shown = true,
	}
end

local function watchArea(model: Instance)
	if not model:IsA("Model") or type(model:GetAttribute("Area")) ~= "string" then
		return
	end
	local ring = model:FindFirstChild(BackdropNear.NAME)
	if ring ~= nil then
		add(ring, model)
	end
	model.ChildAdded:Connect(function(child)
		if child.Name == BackdropNear.NAME then
			add(child, model)
		end
	end)
end

local function points(): { Vector3 }
	local list: { Vector3 } = {}
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		table.insert(list, camera.CFrame.Position)
	end
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character.PrimaryPart else nil
	if root ~= nil then
		table.insert(list, root.Position)
	end
	return list
end

local function check()
	local enabled = on()
	local where = points()
	for ring, entry in entries do
		-- with nothing to measure from (no camera or character yet), every ring stays
		local show = not enabled
			or #where == 0
			or BackdropNear.keep(entry.box, where, entry.shown, false)
		place(ring, entry, show)
	end
end

function BackdropController.start()
	task.spawn(function()
		local world = Workspace:WaitForChild("World", 60)
		if world == nil then
			return
		end
		for _, child in world:GetChildren() do
			watchArea(child)
		end
		world.ChildAdded:Connect(watchArea)
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. BackdropNear.FLAG)
			:Connect(check)
		while true do
			check()
			task.wait(BackdropNear.STEP)
		end
	end)
end

return BackdropController
