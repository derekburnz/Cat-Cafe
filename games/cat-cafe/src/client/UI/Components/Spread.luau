--!strict
-- Sync's Park landing timing (Nov 17): 4,000 to 5,000 instances stream in within one frame, and the strays among them
-- each built a label at once (NewKindTags 12.1 ms over 3 landings, about 0.5 ms a stray; MoodIcons 10.5 ms), all in
-- the landing's worst frame. Spread.later queues that work and runs it a frame at a time, at most BUDGET seconds of it
-- a frame (always at least one job, so the queue keeps moving), in the order it came.
--   Spread.later(job)                    queue a job for the next frames
--   Spread.drain(queue, clock, budget)   run jobs from the front of `queue` until `budget` seconds have gone by
--                                        on `clock`; returns how many ran (pure, for the specs)

local Spread = {}

Spread.BUDGET = 0.001 -- seconds of queued jobs a frame

type Job = () -> ()

local queue: { Job } = {}
local driving: RBXScriptConnection? = nil

function Spread.drain(jobs: { Job }, clock: () -> number, budget: number): number
	local started = clock()
	local ran = 0
	while #jobs > 0 do
		local job = table.remove(jobs, 1) :: Job
		local ok, err = pcall(job :: () -> any) -- a Job returns nothing; pcall then gives the error as its second value
		if not ok then
			warn("[Spread] a queued job failed: " .. tostring(err))
		end
		ran += 1
		if clock() - started >= budget then
			break
		end
	end
	return ran
end

function Spread.later(job: Job)
	table.insert(queue, job)
	if driving ~= nil then
		return
	end
	driving = game:GetService("RunService").Heartbeat:Connect(function()
		Spread.drain(queue, os.clock, Spread.BUDGET)
		if #queue == 0 and driving ~= nil then
			driving:Disconnect()
			driving = nil
		end
	end)
end

return Spread
