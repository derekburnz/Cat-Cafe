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

-- What a step pays, for analytics: "coins" or "lure" for a step of only that, "mixed" for one that pays several
-- kinds of thing (v0.10 steps 9 and 12).
function TipJar.kind(def: Types.TipJarStep): string
	local prize = def.prize
	local coins = prize.coins ~= nil or prize.coinSeconds ~= nil
	local others = prize.fish ~= nil or prize.spins ~= nil or prize.crates ~= nil
	if coins and prize.lures == nil and not others then
		return "coins"
	elseif prize.lures ~= nil and not coins and not others then
		return "lure"
	end
	return "mixed"
end

-- A fresh session's claimed flags, one per step.
function TipJar.unclaimed(): { boolean }
	return table.create(#Catalog.tipJar, false)
end

return TipJar
