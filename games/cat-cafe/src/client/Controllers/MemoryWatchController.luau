--!strict
-- #3743: reports this client's memory at shared/MemoryWatch.MARKS minutes into the session (the total, and at two
-- of the marks each of MemoryWatch.TAGS), through TelemetryReport. Analytics only; nothing is shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MemoryWatch = require(Shared:WaitForChild("MemoryWatch"))
local Net = require(script.Parent.Parent.Net)

local MemoryWatchController = {}

-- The per-tag numbers need Roblox's memory tracking, which is off on most players' devices: asking anyway does not
-- fail but logs "Memory tracking is currently disabled" every time (2,360 of the day's 3,159 client errors after the
-- 2026-11-13 02:42 UTC build). So the tags are read only where tracking is on; the total always works.
local function tracking(): boolean
	local ok, on = pcall(function(): unknown
		return (Stats :: any).MemoryTrackingEnabled
	end)
	return ok and on == true
end

local function tagMb(name: string): number?
	local ok, mb = pcall(function(): number
		local tag = (Enum :: any).DeveloperMemoryTag[name]
		return Stats:GetMemoryUsageMbForTag(tag)
	end)
	if ok and type(mb) == "number" and mb == mb then
		return mb
	end
	return nil
end

local function send(markIndex: number)
	Net.fire(
		"TelemetryReport",
		MemoryWatch.TOTAL,
		MemoryWatch.encode(markIndex, Stats:GetTotalMemoryUsageMb())
	)
	if MemoryWatch.TAG_MARKS[markIndex] ~= true or not tracking() then
		return
	end
	for tagIndex, name in MemoryWatch.TAGS do
		local mb = tagMb(name)
		if mb ~= nil then
			Net.fire(
				"TelemetryReport",
				MemoryWatch.TAG,
				MemoryWatch.encode(MemoryWatch.tagIndex(markIndex, tagIndex), mb)
			)
		end
	end
end

function MemoryWatchController.start()
	local started = os.clock()
	task.spawn(function()
		for markIndex, minutes in MemoryWatch.MARKS do
			task.wait(math.max(0, minutes * 60 - (os.clock() - started)))
			send(markIndex)
		end
	end)
end

return MemoryWatchController
