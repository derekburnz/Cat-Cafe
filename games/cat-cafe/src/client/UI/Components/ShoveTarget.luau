--!strict
-- Which player the Shove button aims at (F41, data-model section 10c, reviewer S46): the nearest other player in
-- range, passing over the ones the server would refuse anyway, so the hand never sticks on a player you cannot
-- shove while someone else stands right there:
--   pick(candidates, range, locked, skipUntil, now) -> index of the candidate to aim at, or nil
--   locked[userId]     holds a catch or rescue lock (the LockedBy of a stray or rescue spot)
--   skipUntil[userId]  a clock time: this client shoved them (BumpSameTargetSeconds) or the server just refused them
-- The server stays the judge; this only moves the hand.

local ShoveTarget = {}

export type Candidate = {
	userId: number,
	distance: number,
}

function ShoveTarget.pick(
	candidates: { Candidate },
	range: number,
	locked: { [number]: boolean },
	skipUntil: { [number]: number },
	now: number
): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index, candidate in candidates do
		local skipEnd = skipUntil[candidate.userId]
		local skipped = locked[candidate.userId] == true or (skipEnd ~= nil and now < skipEnd)
		if not skipped and candidate.distance <= range and candidate.distance < bestDistance then
			best, bestDistance = index, candidate.distance
		end
	end
	return best
end

return ShoveTarget
