--!strict
-- The one short wait line (#2324, Derek2: "make it a brief text message and not long ex: 'cooling down 1 second'"):
-- "Cooling down 3s", the whole seconds left rounded up, so it counts 3s, 2s, 1s and is gone at 0. The catch card after
-- a miss and the Tackle bar while it recharges both read it.

local Cooldown = {}

-- "Cooling down Ns" for `left` seconds still to wait, or nil once the wait is over.
function Cooldown.text(left: number): string?
	if left ~= left or left <= 0 then
		return nil
	end
	return string.format("Cooling down %ds", math.ceil(left))
end

-- Seconds until the text next changes (the next whole second down), so a caller can repaint just then.
function Cooldown.nextTick(left: number): number
	if left ~= left or left <= 0 then
		return 0
	end
	local step = left - (math.ceil(left) - 1)
	return math.max(step, 0.01)
end

return Cooldown
