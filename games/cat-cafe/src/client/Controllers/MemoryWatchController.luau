--!strict
-- #3743: reports this client's memory at shared/MemoryWatch.MARKS minutes into the session (the total, and at two
-- of the marks each of MemoryWatch.TAGS), through TelemetryReport. Analytics only; nothing is shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MemoryWatch = require(Shared:WaitForChild("MemoryWatch"))
local Net = require(script.Parent.Parent.Net)

local MemoryWatchController = {}

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
	if MemoryWatch.TAG_MARKS[markIndex] ~= true then
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
