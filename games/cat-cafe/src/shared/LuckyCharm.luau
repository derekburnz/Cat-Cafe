--!strict
-- #3298 (new-activities.md section 5; a player idea): Lucky Charm, a permanent Golden Fish Market perk
-- (Catalog.fishShop row ID). Each level adds PER_LEVEL overall Luck (shared/Luck's "charm" source), the worth of one
-- Lucky Cat statue level, inside Config.LuckMax like every other source. Three levels, +0.3 in all, for 100, 250 and
-- 500 golden fish. Overall Luck is the number the bait and crate rolls and their odds cards already read, so the
-- printed odds always include it; the Spin Wheel never reads Luck. Golden fish only: never sold for Robux, never in a
-- Robux item, never traded (Monetization-Agent, 2026-11-11).
-- The live switch FLAG starts off (LiveFlags.OFF_BY_DEFAULT): off hides the Market row, refuses a buy and adds no
-- Luck; saved levels are kept. Switch it on only once no server older than the publish that added the row is
-- running, since an older server's save check drops a perk id it does not know. Pure.

local Types = require(script.Parent.Types)

local LuckyCharm = {}

LuckyCharm.ID = "lucky_charm"
LuckyCharm.NAME = "Lucky Charm"
LuckyCharm.FLAG = "luckyCharm" -- the LiveFlags key
LuckyCharm.PER_LEVEL = 0.1 -- Luck a level, as Config.LuckPerStatueLevel
LuckyCharm.MAX_LEVEL = 3

-- The Luck `level` levels add: 0.1, 0.2, 0.3.
function LuckyCharm.luckAt(level: number): number
	local n = math.clamp(math.floor(level), 0, LuckyCharm.MAX_LEVEL)
	return math.floor(n * LuckyCharm.PER_LEVEL * 100 + 0.5) / 100
end

-- The Luck the perk adds for `profile`, or 0 while the switch is off.
function LuckyCharm.bonus(profile: Types.PlayerProfile?, on: boolean?): number
	if profile == nil or on ~= true then
		return 0
	end
	local level = profile.fishPerks[LuckyCharm.ID]
	return LuckyCharm.luckAt(if type(level) == "number" then level else 0)
end

return LuckyCharm
