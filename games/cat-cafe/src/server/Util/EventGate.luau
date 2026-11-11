--!strict
-- Analytics send budget (Laptop-Tester's Creator Hub read, 2026-11-11: 396 "AnalyticsService: You have sent too many
-- events" errors in 24 h since v498, so events such as upgrade_bought were lost). Roblox lets one server send about
-- 120 + 20 per player analytics events a minute, every kind counted together; past that each Log call fails and the
-- event is gone. Telemetry's send() asks this gate first: an event with budget left goes now, one without waits in a
-- queue and goes out oldest first as the budget refills, so a burst (a full server's joins, a run of catches) is
-- delayed by seconds instead of dropped. Only when the queue is full is an event dropped, and that is counted.
-- The budget refills continuously at SHARE of the limit, so a minute never holds more than the limit.
-- Pure apart from the clock and player count it is handed, so the cloud spec runner checks it.
--   new(now) -> Gate
--   gate:offer(item, now, players) -> boolean     true: send `item` now; false: queued (or dropped when full)
--   gate:due(now, players) -> { item }             the queued items whose turn has come, oldest first
--   gate.dropped                                    how many were dropped since the last takeDropped()

local EventGate = {}

EventGate.BASE_PER_MINUTE = 120
EventGate.PER_PLAYER_PER_MINUTE = 20
EventGate.SHARE = 0.8 -- headroom under Roblox's limit
EventGate.BURST_SECONDS = 10 -- the most budget that can pile up, as seconds of the rate
EventGate.QUEUE_MAX = 600
EventGate.FLUSH_SECONDS = 1 -- how often Telemetry sends what is due

export type Gate = {
	tokens: number,
	at: number,
	queue: { any },
	head: number,
	dropped: number,
	offer: (self: Gate, item: any, now: number, players: number) -> boolean,
	due: (self: Gate, now: number, players: number) -> { any },
	takeDropped: (self: Gate) -> number,
	size: (self: Gate) -> number,
}

-- Events a second the gate allows with `players` on the server.
function EventGate.rate(players: number): number
	local count = math.max(0, math.floor(players))
	return (EventGate.BASE_PER_MINUTE + EventGate.PER_PLAYER_PER_MINUTE * count)
		* EventGate.SHARE
		/ 60
end

local function refill(self: Gate, now: number, players: number)
	local rate = EventGate.rate(players)
	local elapsed = math.max(0, now - self.at)
	self.tokens = math.min(rate * EventGate.BURST_SECONDS, self.tokens + elapsed * rate)
	self.at = now
end

local function size(self: Gate): number
	return #self.queue - self.head + 1
end

local function offer(self: Gate, item: any, now: number, players: number): boolean
	refill(self, now, players)
	-- a queued event goes first, so order holds
	if size(self) <= 0 and self.tokens >= 1 then
		self.tokens -= 1
		return true
	end
	if size(self) >= EventGate.QUEUE_MAX then
		self.dropped += 1
		return false
	end
	table.insert(self.queue, item)
	return false
end

local function due(self: Gate, now: number, players: number): { any }
	refill(self, now, players)
	local out = {}
	while size(self) > 0 and self.tokens >= 1 do
		self.tokens -= 1
		table.insert(out, self.queue[self.head])
		self.queue[self.head] = nil
		self.head += 1
	end
	if size(self) <= 0 then
		-- empty: start the list again so it doesn't grow
		self.queue = {}
		self.head = 1
	end
	return out
end

local function takeDropped(self: Gate): number
	local n = self.dropped
	self.dropped = 0
	return n
end

function EventGate.new(now: number): Gate
	local gate = {
		tokens = 0,
		at = now,
		queue = {},
		head = 1,
		dropped = 0,
		offer = offer,
		due = due,
		takeDropped = takeDropped,
		size = size,
	}
	-- a new server starts with a full burst
	gate.tokens = EventGate.rate(0) * EventGate.BURST_SECONDS
	return gate :: any
end

return EventGate
