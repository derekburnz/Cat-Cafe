--!strict
-- The Tip Jar's rules (F47, data-model section 11b), shared so the UI's countdowns and coin estimates agree with
-- what the server pays. No Roblox services.

local Catalog = require(script.Parent.Catalog)
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

-- Coins a coins step pays at `dayRate` (the day income per second at claim time); 0 for a food step.
function TipJar.coins(def: Types.TipJarStep, dayRate: number): number
	if def.kind ~= "coins" then
		return 0
	end
	return math.max(def.minCoins or 0, math.floor(math.max(dayRate, 0) * (def.seconds or 0)))
end

-- A fresh session's claimed flags, one per step.
function TipJar.unclaimed(): { boolean }
	return table.create(#Catalog.tipJar, false)
end

return TipJar
