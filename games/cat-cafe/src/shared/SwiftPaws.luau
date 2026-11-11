--!strict
-- #3063 (Derek2 2026-11-10, player its_cuzu098's idea): Swift Paws, a permanent Golden Fish Market perk
-- (Catalog.fishShop row ID) that adds PER_LEVEL walk speed a level, on the normal walk and while carrying a cat
-- (Derek2 17:42: "let the speed apply to holding a cat"). Two levels (Monetization-Agent: +1 for 60 fish, +2 for
-- 150), so normal walking goes 20 to 22 and carrying 16 to 18: a carrier stays slower than anyone on foot. It never
-- touches the catch rush or a Startled slow, and the Swift Potion (+4, sold for Robux) stacks on top, so the potion
-- stays the bigger bump. The live switch FLAG off hides the Market row, refuses a buy and drops the bonus at the
-- next speed set; saved levels are kept. Pure.

local Types = require(script.Parent.Types)

local SwiftPaws = {}

SwiftPaws.ID = "swift_paws"
SwiftPaws.FLAG = "swiftPaws" -- the LiveFlags key
SwiftPaws.PER_LEVEL = 1
SwiftPaws.CREDIT = "its_cuzu098" -- the player who suggested it, on the Market card (#3063)

-- The walk speed the perk adds for `profile`: its level times PER_LEVEL, or 0 while the switch is off.
function SwiftPaws.bonus(profile: Types.PlayerProfile?, on: boolean): number
	if profile == nil or not on then
		return 0
	end
	local level = profile.fishPerks[SwiftPaws.ID] or 0
	return math.max(0, level) * SwiftPaws.PER_LEVEL
end

return SwiftPaws
