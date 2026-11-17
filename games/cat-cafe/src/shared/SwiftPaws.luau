--!strict
-- #3063 (Derek2 2026-11-10, player its_cuzu098's idea): Swift Paws, a permanent Golden Fish Market perk
-- (Catalog.fishShop row ID) that adds PER_LEVEL walk speed a level, on the normal walk and while carrying a cat
-- (Derek2 17:42: "let the speed apply to holding a cat"). Two levels (Monetization-Agent: +1 for 60 fish, +2 for
-- 150), so normal walking goes 20 to 22 and carrying 16 to 18: a carrier stays slower than anyone on foot. It never
-- touches the catch rush or a Startled slow, and the Swift Potion (+4, sold for Robux) stacks on top, so the potion
-- stays the bigger bump. The live switch FLAG off hides the Market row, refuses a buy and drops the bonus at the
-- next speed set; saved levels are kept.
-- #3317 (Derek2 2026-11-11: "make swiftpaws have 5 upgrades and move to the top of perks"; Monetization-Agent's
-- numbers): five levels, +1 for levels 1 and 2 (so nobody who bought them loses anything) and +0.5 for 3 to 5, +3.5 in
-- all, under the Swift Potion's +4. A carrier at 16 + 3.5 still stays slower than anyone on foot (20). Levels 3 to 5
-- waited on the live switch `swiftPaws5` until no server older than this publish was left (retired in #4654 batch 7;
-- the callers pass fiveOn = true).
-- #4705 (Derek 2026-11-16: "add more speed upgrade stages past 5 in perks"): five more levels, +0.5 each, +6 in all at
-- level 10. Past level 5 the perk outgrows the Swift Potion's +4 and a full carry passes a plain walk; players
-- already stack past both with speed traits and the Dragon Keep's cards. Levels 6 to 10 wait on FLAG_TEN (off by
-- default) the same way: a server older than this publish keeps a saved level only up to 5. #4654: that switch ran on
-- live from 2026-11-16 03:32 UTC and is retired, so the callers pass tenOn = true. Pure.

local Types = require(script.Parent.Types)

local SwiftPaws = {}

SwiftPaws.ID = "swift_paws"
SwiftPaws.FLAG = "swiftPaws" -- the LiveFlags key
SwiftPaws.LEVELS = { 1, 1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 } :: { number } -- the walk speed each level adds
SwiftPaws.OLD_TOP = 2 -- the top level a server older than #3317 keeps
SwiftPaws.MID_TOP = 5 -- the top level a server older than #4705 keeps
SwiftPaws.CREDIT = "its_cuzu098" -- the player who suggested it, on the Market card (#3063)

-- The walk speed `level` levels add: LEVELS added up to it.
function SwiftPaws.speedAt(level: number): number
	local sum = 0
	for i = 1, math.min(math.floor(level), #SwiftPaws.LEVELS) do
		sum += SwiftPaws.LEVELS[i]
	end
	return sum
end

-- The walk speed the perk adds for `profile`, or 0 while the switch is off.
function SwiftPaws.bonus(profile: Types.PlayerProfile?, on: boolean): number
	if profile == nil or not on then
		return 0
	end
	return SwiftPaws.speedAt(profile.fishPerks[SwiftPaws.ID] or 0)
end

-- The top level a player can buy to now: OLD_TOP until fiveOn, then MID_TOP until FLAG_TEN is on too
-- (#4705), then the row's top. `tenOn` nil reads as off.
function SwiftPaws.topLevel(rowMax: number, fiveOn: boolean, tenOn: boolean?): number
	if not fiveOn then
		return math.min(rowMax, SwiftPaws.OLD_TOP)
	end
	return if tenOn == true then rowMax else math.min(rowMax, SwiftPaws.MID_TOP)
end

return SwiftPaws
