--!strict
-- #1572 (luck-and-rare-moments.md 1g): today's kinds as the Clock folder says (LuckyDay, GoldenDay, RainbowDay, each
-- true from sunrise to night). UI/init's clock read sets them; the bait bowl and the dealer read them for the odds
-- cards' gold and rainbow lines (FoodOdds.extras and FoodOdds.rainbow), as the server's Clock.goldChance and
-- Clock.rainbowChance do on a roll.

export type Kinds = { lucky: boolean, golden: boolean, rainbow: boolean }

local DayKinds = {}

DayKinds.current = { lucky = false, golden = false, rainbow = false } :: Kinds
DayKinds.bound = false -- UI/init: the clock has been read once, so a kind turning on after that is a sunrise

-- Sets today's kinds; true when any changed.
function DayKinds.set(kinds: Kinds): boolean
	local old = DayKinds.current
	local changed = old.lucky ~= kinds.lucky
		or old.golden ~= kinds.golden
		or old.rainbow ~= kinds.rainbow
	DayKinds.current = { lucky = kinds.lucky, golden = kinds.golden, rainbow = kinds.rainbow }
	return changed
end

return DayKinds
