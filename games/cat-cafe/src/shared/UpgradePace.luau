--!strict
-- #2996 (retention-ideas.md section 5e, "Early upgrades about a minute apart"): the numbers behind the
-- `upgrade_bought` custom event, which measures how far apart a player's upgrade buys land.
--   bought(levels)        upgrade levels bought on the account so far (each upgrade's level over the level a new
--                         save is given: its start level, and for the tables Config.StartTables since #3660)
--   nth(count)            the event's first field: "1", "2", "3", "4" or "5+", so the first four buys read on their own
--   gap(at, lastAt, joinedAt)   the event's value: whole seconds since the previous buy this session, else since
--                         the session began
-- Pure, so UpgradePace.spec can check it; Telemetry.upgradeBought sends the event.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)

local UpgradePace = {}

UpgradePace.FIRST = 4 -- buys counted one by one, so the 3rd to 4th gap reads on its own; later ones share "5+"

function UpgradePace.bought(levels: { [string]: number }): number
	local total = 0
	for _, def in Catalog.upgrades do
		local level = levels[def.id]
		if level ~= nil then
			-- #3660 opens the first table on every save (ProfileSchema), so it is no buy: without this a new
			-- account's first buy read as "2" from 2026-11-13 on
			local given = if def.id == "tables"
				then math.max(def.startLevel, Config.StartTables)
				else def.startLevel
			total += math.max(0, level - given)
		end
	end
	return total
end

function UpgradePace.nth(count: number): string
	if count <= UpgradePace.FIRST then
		return tostring(math.max(1, count))
	end
	return string.format("%d+", UpgradePace.FIRST + 1)
end

function UpgradePace.gap(at: number, lastAt: number?, joinedAt: number): number
	return math.max(0, math.floor(at - (lastAt or joinedAt)))
end

return UpgradePace
