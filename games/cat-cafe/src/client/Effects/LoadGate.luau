--!strict
-- #5068 (phones lose players before the loading screen ends): client start-up work that nobody sees under the loading
-- screen waits until it has gone. Behind the `fxAfterLoad` live switch (off by default): with it off, whenLoaded runs
-- its function at once, so a join plays exactly as before.
--
--   LoadGate.whenLoaded(fn)   run fn once the loading screen is done (or CAP seconds after the client started)
--   LoadGate.done()           the loading screen is done (IntroController, where it slides away); a second call does nothing
--   LoadGate.isDone()         whether done() has run or the cap has passed
--
-- The switch is read once, at the first whenLoaded: a switch that is not in yet counts as off.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)

local LoadGate = {}

LoadGate.FLAG = "fxAfterLoad"
-- the same as IntroController's LOAD_LIMIT: the loading screen never stays up longer, so nothing waits longer either
LoadGate.CAP = 15

local startedAt = os.clock()
local finished = false
local waiting: { () -> () } = {}
local capping = false
local holds: boolean? = nil -- the switch, read once

local function release()
	if finished then
		return
	end
	finished = true
	local list = waiting
	waiting = {}
	for _, fn in list do
		task.spawn(fn)
	end
end

function LoadGate.done()
	release()
end

function LoadGate.isDone(): boolean
	return finished
end

-- Whether whenLoaded holds functions back on this client (the switch at the first call).
function LoadGate.holds(): boolean
	if holds == nil then
		holds = ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. LoadGate.FLAG) == true
	end
	return holds == true
end

function LoadGate.whenLoaded(fn: () -> ())
	if finished or not LoadGate.holds() then
		fn()
		return
	end
	table.insert(waiting, fn)
	if not capping then
		capping = true
		task.delay(math.max(0, LoadGate.CAP - (os.clock() - startedAt)), function()
			if os.clock() - startedAt >= LoadGate.CAP - 0.1 then -- a timer that came early (tests) waits for done()
				release()
			end
		end)
	end
end

-- Tests only: forget the done state and set the switch as read (nil reads it again at the next call).
function LoadGate._reset(switch: boolean?)
	finished = false
	waiting = {}
	capping = false
	holds = switch
end

return LoadGate
