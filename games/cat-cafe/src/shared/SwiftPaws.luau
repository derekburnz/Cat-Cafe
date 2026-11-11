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
-- wait on the live switch FLAG_FIVE (off by default): a server older than this publish keeps a saved level only up to
-- its own top of 2, so they open only once no such server is left. Pure.

local Types = require(script.Parent.Types)

local SwiftPaws = {}

SwiftPaws.ID = "swift_paws"
SwiftPaws.FLAG = "swiftPaws" -- the LiveFlags key
SwiftPaws.FLAG_FIVE = "swiftPaws5" -- the LiveFlags key that opens levels 3 to 5 (#3317)
SwiftPaws.LEVELS = { 1, 1, 0.5, 0.5, 0.5 } :: { number } -- the walk speed each level adds
SwiftPaws.OLD_TOP = 2 -- the top level a server older than #3317 keeps
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

-- The top level a player can buy to now: the row's top with FLAG_FIVE on, else OLD_TOP.
function SwiftPaws.topLevel(rowMax: number, fiveOn: boolean): number
	return if fiveOn then rowMax else math.min(rowMax, SwiftPaws.OLD_TOP)
end

return SwiftPaws
