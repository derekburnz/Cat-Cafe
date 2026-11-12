--!strict
-- #3470: where each live Secret stray is, for every client. A stray's model streams in only near a player, but its
-- sky beam is meant to be seen from the camp, so the server keeps one Vector3Value per Secret stray in
-- ReplicatedStorage's Catching.SECRET_BEACONS folder: named by the stray's id, its Value the cat's position (followed
-- every FOLLOW_SECONDS while it lives) and its Area attribute the area id. Effects draws the beam from these. The
-- server-wide line names the area only; the beam is what shows the spot, as the design asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catching = require(ReplicatedStorage.Shared.Catching)

local SecretBeacons = {}

local FOLLOW_SECONDS = 2

local folder: Folder? = nil
local beacons: { [string]: Vector3Value } = {}

local function home(): Folder
	local found = folder
	if found == nil then
		local made = Instance.new("Folder")
		made.Name = Catching.SECRET_BEACONS
		made.Parent = ReplicatedStorage
		folder = made
		return made
	end
	return found
end

-- Puts the beacon of stray `id` in `areaId` at `position` (again for a stray that already has one).
function SecretBeacons.set(id: string, areaId: string, position: Vector3)
	local beacon = beacons[id]
	if beacon == nil then
		local made = Instance.new("Vector3Value")
		made.Name = id
		beacons[id] = made
		beacon = made
	end
	local value = beacon :: Vector3Value
	value.Value = position
	value:SetAttribute("Area", areaId)
	value.Parent = home()
end

-- Keeps the beacon of stray `id` on `model` until the beacon is cleared or the model is gone.
function SecretBeacons.follow(id: string, model: Model)
	task.spawn(function()
		while beacons[id] ~= nil and model.Parent ~= nil do
			beacons[id].Value = model:GetPivot().Position
			task.wait(FOLLOW_SECONDS)
		end
	end)
end

function SecretBeacons.clear(id: string)
	local beacon = beacons[id]
	if beacon ~= nil then
		beacons[id] = nil
		beacon:Destroy()
	end
end

return SecretBeacons
