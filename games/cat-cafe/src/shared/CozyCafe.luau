--!strict
-- #2798 (retention-ideas.md section 2 idea 10, Derek2 2026-11-09: "yes"): Cozy Cafe, pure. While a player stays in their
-- own cafe, after CozyStartSeconds a cat curls up on the counter, and every CozyBagSeconds more it leaves a small gift
-- bag on the counter: CozyCoinSeconds of income, CozyLureChance of a Tuna, CozyFishChance of CozyFishMin to
-- CozyFishMax golden fish. One bag waits at a time (the timer stops until it is collected), at most CozyBagsPerDay a
-- UTC day, never a cat, and only after the account's first catch, so new players learn to catch first.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local CozyCafe = {}

local DAY = 86400

function CozyCafe.day(now: number): number
	return now // DAY
end

function CozyCafe.fresh(): Types.CozySave
	return { day = 0, bags = 0 }
end

function CozyCafe.sanitize(raw: unknown): Types.CozySave
	local out = CozyCafe.fresh()
	if type(raw) == "table" then
		local t = raw :: any
		if type(t.day) == "number" and t.day == t.day and t.day >= 0 and t.day < math.huge then
			out.day = math.floor(t.day)
		end
		if type(t.bags) == "number" and t.bags == t.bags and t.bags >= 0 then
			out.bags = math.min(Config.CozyBagsPerDay, math.floor(t.bags))
		end
	end
	return out
end

-- Bags already given today.
function CozyCafe.bagsToday(save: Types.CozySave, now: number): number
	return if save.day == CozyCafe.day(now) then save.bags else 0
end

-- Whether the cafe can give `profile` a bag now (not counting time): past the first catch, and under today's cap.
function CozyCafe.eligible(profile: Types.PlayerProfile, now: number): boolean
	return profile.stats.catsCaught >= 1
		and CozyCafe.bagsToday(profile.cozy, now) < Config.CozyBagsPerDay
end

-- Counts one bag given today.
function CozyCafe.note(save: Types.CozySave, now: number)
	local day = CozyCafe.day(now)
	if save.day ~= day then
		save.day = day
		save.bags = 0
	end
	save.bags = math.min(Config.CozyBagsPerDay, save.bags + 1)
end

-- Seconds in the cafe (with no bag waiting) before the next bag, from `seconds` already counted toward it. The first
-- bag of a stay needs CozyStartSeconds for the cat to curl up, then CozyBagSeconds.
function CozyCafe.secondsToBag(curled: boolean, seconds: number): number
	local need = Config.CozyBagSeconds + (if curled then 0 else Config.CozyStartSeconds)
	return math.max(0, need - seconds)
end

-- What a bag holds, from two rolls in [0, 1): income always, sometimes a Tuna, rarely a few golden fish.
function CozyCafe.prize(lureRoll: number, fishRoll: number): Types.IndexPrize
	local prize: Types.IndexPrize = { coinSeconds = Config.CozyCoinSeconds }
	if lureRoll < Config.CozyLureChance then
		prize.lures = { [Config.CozyLure] = 1 }
	end
	if fishRoll < Config.CozyFishChance then
		local span = Config.CozyFishMax - Config.CozyFishMin + 1
		-- the fish roll's own place inside its chance picks the count, so one roll does both
		local share = fishRoll / Config.CozyFishChance
		prize.fish = Config.CozyFishMin + math.min(span - 1, math.floor(share * span))
	end
	return prize
end

return CozyCafe
