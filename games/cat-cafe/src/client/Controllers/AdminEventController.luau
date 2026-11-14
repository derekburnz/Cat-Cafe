--!strict
-- #4195 (Derek 2026-11-14, admin events on update days): the admin event on this client. Every half second it reads
-- the server's admin event attributes (shared/CafeEvents.ADMIN_ATTRIBUTES on ReplicatedStorage: the event running,
-- or the one starting within its 2 minute warning) and PlayerState.adminWheel, and hands them to UI.admin.set (the
-- banner, the HUD timer and the Admin Wheel's window). Spin on the window fires AdminWheelSpin; AdminWheelResult
-- turns the wheel. With the switch `adminEvents` off the server names no event, so nothing shows.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminBarLogic = require(script.Parent.Parent.UI.Components.AdminBarLogic)
local CafeEvents = require(Shared:WaitForChild("CafeEvents"))
local Net = require(script.Parent.Parent.Net)
local UI = require(script.Parent.Parent.UI)

local AdminEventController = {}

local TICK = 0.5

local function read(name: string): unknown
	return ReplicatedStorage:GetAttribute(name)
end

local function decode(raw: string): unknown
	return HttpService:JSONDecode(raw)
end

local function tick()
	local info = AdminBarLogic.info(read, CafeEvents.ADMIN_ATTRIBUTES :: any, decode)
	local state: any = UI.getState()
	local wheel: any = if type(state) == "table" then state.adminWheel else nil
	if
		type(wheel) ~= "table"
		or type(wheel.eventId) ~= "string"
		or type(wheel.endsAt) ~= "number"
	then
		wheel = nil
	end
	local admin = UI.admin :: any
	admin.set(info, wheel)
end

function AdminEventController.start()
	local admin = UI.admin :: any
	admin.spin:Connect(function()
		Net.fire("AdminWheelSpin")
	end)
	Net.on("AdminWheelResult", function(slice: unknown, prizeId: unknown, paid: unknown)
		local lines: { string } = {}
		if type(paid) == "table" then
			for _, line in paid :: { any } do
				if type(line) == "string" then
					table.insert(lines, line)
				end
			end
		end
		admin.result(
			if type(slice) == "number" then slice else 0,
			if type(prizeId) == "string" then prizeId else "",
			lines
		)
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(TICK)
		end
	end)
end

return AdminEventController
