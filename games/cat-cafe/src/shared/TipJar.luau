--!strict
-- The Tip Jar's rules (F47, data-model section 11b), shared so the UI's countdowns and coin estimates agree with
-- what the server pays. No Roblox services.

local Catalog = require(script.Parent.Catalog)
local Prizes = require(script.Parent.Prizes)
local Types = require(script.Parent.Types)

local TipJar = {}

function TipJar.step(step: number): Types.TipJarStep?
	return Catalog.tipJar[step]
end

-- Session seconds before the step can be claimed.
function TipJar.unlocksAfter(def: Types.TipJarStep): number
	return def.minutes * 60
end

-- `sessionStartedAt` and `now` are both workspace:GetServerTimeNow() readings.
function TipJar.isReady(def: Types.TipJarStep, sessionStartedAt: number, now: number): boolean
	return now - sessionStartedAt >= TipJar.unlocksAfter(def)
end

-- Coins a step pays at `dayRate` (the day income per second at claim time): its coinSeconds of day rate, never
-- under its coins; 0 for a step without coins.
function TipJar.coins(def: Types.TipJarStep, dayRate: number): number
	local prize = def.prize
	if prize.coins == nil and prize.coinSeconds == nil then
		return 0
	end
	return Prizes.coins(prize.coins, prize.coinSeconds, dayRate)
end

-- What a step pays, for analytics: "coins", "lure", "fish" or "spin" for a step of only that, "mixed" for one that
-- pays several kinds of thing (v0.10 steps 9 and 12; F94 gives the food steps golden fish and step 6 a spin).
function TipJar.kind(def: Types.TipJarStep): string
	local prize = def.prize
	local found: { string } = {}
	if prize.coins ~= nil or prize.coinSeconds ~= nil then
		table.insert(found, "coins")
	end
	if prize.lures ~= nil then
		table.insert(found, "lure")
	end
	if prize.fish ~= nil then
		table.insert(found, "fish")
	end
	if prize.spins ~= nil then
		table.insert(found, "spin")
	end
	if prize.crates ~= nil or prize.potions ~= nil then
		table.insert(found, "other")
	end
	return if #found == 1 and found[1] ~= "other" then found[1] else "mixed"
end

-- A fresh session's claimed flags, one per step.
function TipJar.unclaimed(): { boolean }
	return table.create(#Catalog.tipJar, false)
end

return TipJar
