--!strict
-- Token bucket per key. Pure apart from the default clock, which tests can replace.

export type RateLimiter = {
	allow: (self: RateLimiter, key: any) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

local RateLimiter = {}

type Bucket = { tokens: number, last: number }

-- `maxCalls` calls per `windowSeconds`, refilled continuously.
function RateLimiter.new(
	maxCalls: number,
	windowSeconds: number,
	clock: (() -> number)?
): RateLimiter
	local now = clock or os.clock
	local buckets: { [any]: Bucket } = {}
	local refillPerSecond = maxCalls / windowSeconds

	local self = {} :: any

	function self.allow(_, key: any): boolean
		local t = now()
		local bucket = buckets[key]
		if bucket == nil then
			bucket = { tokens = maxCalls, last = t }
			buckets[key] = bucket
		end
		local b = bucket :: Bucket
		b.tokens = math.min(maxCalls, b.tokens + (t - b.last) * refillPerSecond)
		b.last = t
		if b.tokens >= 1 then
			b.tokens -= 1
			return true
		end
		return false
	end

	function self.forget(_, key: any)
		buckets[key] = nil
	end

	return self :: RateLimiter
end

return RateLimiter
