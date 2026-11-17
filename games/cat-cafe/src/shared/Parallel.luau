--!strict
-- #4307: runs yielding calls side by side instead of one after another, for the join path (each pass lookup is its
-- own web call, and 20+ of them in a row were most of the save wait). Server or client; nothing here is saved.
--
--   Parallel.map(items, limit, fn) calls fn(item) for every item, at most `limit` at once, and returns once all
--   have answered; out[i] is fn(items[i]). A call that errors gives nil in its place (the error is warned), so one
--   bad call never hangs the caller.
--   Parallel.start(fn) starts fn now and returns a wait() that yields until fn has answered and then gives its
--   result (nil when it errored); wait() can be called any number of times, before or after fn is done.

local Parallel = {}

-- Resumes `thread` if it is parked in coroutine.yield (task.spawn on a running thread would error).
local function wake(thread: thread)
	if coroutine.status(thread) == "suspended" then
		task.spawn(thread)
	end
end

function Parallel.map<T, R>(items: { T }, limit: number, fn: (T) -> R): { R? }
	local out: { R? } = {}
	local count = #items
	if count == 0 then
		return out
	end
	local nextIndex = 0
	local running = math.clamp(math.floor(limit), 1, count)
	local waiter: thread? = nil
	local function worker()
		while true do
			nextIndex += 1
			local index = nextIndex
			if index > count then
				break
			end
			local ok, result = pcall(fn, items[index])
			if ok then
				out[index] = result
			else
				warn("[Parallel] a call failed:", result)
			end
		end
		running -= 1
		if running == 0 and waiter ~= nil then
			wake(waiter)
		end
	end
	for _ = 1, running do
		task.spawn(worker)
	end
	-- every call may already have answered without yielding (cached answers); only park when some are still out
	if running > 0 then
		waiter = coroutine.running()
		coroutine.yield()
	end
	return out
end

function Parallel.start<R>(fn: () -> R): () -> R?
	local done = false
	local result: R? = nil
	local waiters: { thread } = {}
	task.spawn(function()
		local ok, value = pcall(fn)
		if ok then
			result = value
		else
			warn("[Parallel] a call failed:", value)
		end
		done = true
		for _, thread in waiters do
			wake(thread)
		end
	end)
	return function(): R?
		if not done then
			table.insert(waiters, coroutine.running())
			coroutine.yield()
		end
		return result
	end
end

return Parallel
