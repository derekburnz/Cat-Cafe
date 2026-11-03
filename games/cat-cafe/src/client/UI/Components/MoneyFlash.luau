--!strict
-- When the HUD's money counter gives its little green flash (#1026, Derek live v181: "Money in bottom left is
-- flashing slightly"). While income flows, UIController ticks the counter up five times a second, and each tick
-- used to restart the flash, so the amount never settled. Now only a lump (a sale, a tip, a reward) flashes: a
-- gain bigger than one second of the steady income. The ticks and the server's sync corrections stay still.

local MoneyFlash = {}

function MoneyFlash.shouldFlash(
	previous: number?,
	current: number,
	incomePerSecond: number?
): boolean
	if previous == nil or current <= previous then
		return false
	end
	local trickle = math.max(incomePerSecond or 0, 0)
	return current - previous > trickle
end

return MoneyFlash
