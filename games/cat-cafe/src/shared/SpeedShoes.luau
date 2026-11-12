--!strict
-- #3535 (Derek 2026-11-12: "the new featured item speed shoes that give increased speed while carrying cat for 500
-- base price ... you decide how much to boost speed"): the Speed Shoes, a Mystery Market item (Catalog.mysteryItems
-- row ID) bought once with golden fish. They add Config.SpeedShoesCarryBonus walk speed while carrying a cat, and
-- only then: never on the normal walk, the catch rush or a Startled slow. One cat or two in the Backpack, the same
-- bonus. Derek ("dont put a flat cap let it stac", then "limit on carrying speeds"): no flat cap and everything
-- stacks, but the shoes never take a carry to the player's own walk speed with no cat: the carry is
-- max(base carry, min(base carry + bonus, own walk - 1)), counting the player's other boosts on both sides. The
-- limit only trims the shoes' own bonus and never slows anyone.
-- The live switch FLAG starts off (LiveFlags.OFF_BY_DEFAULT): off hides the shelf row, refuses a buy and drops the
-- bonus at the next speed set; an owned pair is kept. It goes on only once no server older than the publish that
-- added the row is running, since an older server's save check drops a Mystery Market id it does not know. Pure.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local SpeedShoes = {}

SpeedShoes.ID = "speed_shoes"
SpeedShoes.FLAG = "speedShoes" -- the LiveFlags key

function SpeedShoes.owns(profile: Types.PlayerProfile?): boolean
	return profile ~= nil and profile.mystery[SpeedShoes.ID] == true
end

-- The carry walk speed for `profile`: `baseCarry` is the carry speed without the shoes and `walk` the player's own
-- walk speed with no cat, both with the same boosts counted (Swift Paws; the Swift Potion is added on top of either
-- by the caller, so it cancels out). Without the shoes, or while the switch is off, `baseCarry` as it is.
function SpeedShoes.carry(
	baseCarry: number,
	walk: number,
	profile: Types.PlayerProfile?,
	on: boolean
): number
	if not on or not SpeedShoes.owns(profile) then
		return baseCarry
	end
	return math.max(baseCarry, math.min(baseCarry + Config.SpeedShoesCarryBonus, walk - 1))
end

return SpeedShoes
