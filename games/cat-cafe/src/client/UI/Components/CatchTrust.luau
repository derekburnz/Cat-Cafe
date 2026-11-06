--!strict
-- Catch v3's trust (#1884, catch-rework.md 7b and 7d), the numbers the catch screen draws. The server keeps the real
-- trust and sends it with CatchResult; between presses the bar shows this device's sum of the grades so far, from
-- the schedule's trustStart, and each CatchJudged grade moves it on. Pure, so the cloud specs check it.
--   after(start, grades) -> number      trust after `grades` from `start`: Perfect +2, Good +1, Miss -2 (Config's
--                                      TrustPerfect, TrustGood, TrustMiss), a paw ring left alone +1 ("left")
--   fill(trust, need) -> number         how full the bar is, 0 to 1
--   streakText(streak) -> string?       "Purrfect x3" from the second Purrfect in a row (7d), else nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CatchTrust = {}

CatchTrust.STREAK_FROM = 2 -- the counter shows from the second Purrfect in a row

local function step(key: string, fallback: number): number
	local value = (Config :: any)[key]
	return if type(value) == "number" then value else fallback
end

-- One grade's change: "perfect", "good", "miss", or "left" for a paw ring nobody tapped (7c).
function CatchTrust.delta(grade: string): number
	if grade == "perfect" then
		return step("TrustPerfect", 2)
	elseif grade == "good" then
		return step("TrustGood", 1)
	elseif grade == "miss" then
		return step("TrustMiss", -2)
	elseif grade == "left" then
		return step("TrustPawLeft", 1)
	end
	return 0
end

function CatchTrust.after(start: number, grades: { string }): number
	local trust = start
	for _, grade in grades do
		trust += CatchTrust.delta(grade)
	end
	return trust
end

function CatchTrust.fill(trust: number, need: number): number
	if need <= 0 then
		return 0
	end
	return math.clamp(trust / need, 0, 1)
end

function CatchTrust.streakText(streak: number?): string?
	if type(streak) ~= "number" or streak < CatchTrust.STREAK_FROM then
		return nil
	end
	return ("Purrfect x%d"):format(math.floor(streak))
end

return CatchTrust
