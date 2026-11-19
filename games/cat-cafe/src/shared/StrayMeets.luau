--!strict
-- onboarding_v9 drop (Design-Agent's spec, /mnt/project-files/Design-Agent/v9-drops-2026-11-18/spec.md, switch
-- `strayMeets`, off by default): for an account's first catch by hand, once the player stands in the Alleyway the
-- stray that waits for them (shared/SecondCat) walks over to a spot MEET_STUDS from the camp landing on its side, and
-- its wander stays round that spot, so it stands right where they land. It walks there at its own speed (its home
-- moves; CatService's wander takes it), never chases the player, and the player still starts the catch. Later
-- strays act as before. Pure.

local StrayMeets = {}

StrayMeets.FLAG = "strayMeets"
StrayMeets.MEET_STUDS = 8 -- the spot's distance from the landing pad's centre

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The spot the waiting stray stands round: MEET_STUDS from `pad` towards `home` (the stray's side), at home's
-- height; home itself when it is already that near.
function StrayMeets.point(pad: Vector3, home: Vector3): Vector3
	local offset = flat(home - pad)
	if offset.Magnitude <= StrayMeets.MEET_STUDS then
		return home
	end
	local kept = offset.Unit * StrayMeets.MEET_STUDS
	return Vector3.new(pad.X + kept.X, home.Y, pad.Z + kept.Z)
end

-- Whether the save is still before its first catch by hand (`caught` from SecondCat.caught).
function StrayMeets.due(caught: number): boolean
	return caught < 1
end

return StrayMeets
