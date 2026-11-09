--!strict
-- #2302 (Derek2: "add tackling somewhere in tutorial or something if it's not already"): the `tackle_try` tip, a
-- card pointing at the Tackle bar the first time it could be used: the tackling lesson seen, this player's tackle
-- ready and someone else carrying a cat within a lunge (Config.TackleLungeStuds, with REACH_SLACK for the walk in).
--   due(input)                     the pure rule, for the spec
--   carriers(players, me)          the others on the server and whether each carries a cat, read off their characters
--   cueTarget(input)               #2558: which carrier the big "Q Tackle!" cue hangs over (Components/TackleCue), the
--                                  nearest within the same reach while the tackle is ready, for this player's first
--                                  CUE_HITS landed tackles of the session; nil for none

local TackleTry = {}

TackleTry.TIP = "tackle_try"
TackleTry.REACH_SLACK = 4 -- studs past the lunge: close enough that a step and a press lands it
TackleTry.CUE_HITS = 3 -- #2558: the big cue stops after this many landed tackles in a session

export type Carrier = { position: Vector3?, carrying: boolean, root: BasePart? }

export type Input = {
	lessonSeen: boolean, -- the `tackle` tip (the lesson) is in tipsSeen
	tried: boolean, -- `tackle_try` is in tipsSeen
	ready: boolean, -- the Tackle bar shows and is full
	from: Vector3?, -- this player's root
	reach: number, -- Config.TackleLungeStuds
	others: { Carrier },
}

function TackleTry.due(input: Input): boolean
	if not input.lessonSeen or input.tried or not input.ready then
		return false
	end
	local from = input.from
	if from == nil then
		return false
	end
	local range = input.reach + TackleTry.REACH_SLACK
	for _, other in input.others do
		local at = other.position
		if other.carrying and at ~= nil and (at - from).Magnitude <= range then
			return true
		end
	end
	return false
end

export type CueInput = {
	ready: boolean, -- the Tackle bar shows and is full
	hits: number, -- tackles this player landed this session
	from: Vector3?, -- this player's root
	reach: number, -- Config.TackleLungeStuds
	others: { Carrier },
}

-- #2558: the index in `others` of the nearest carrier a step and a press would reach, or nil.
function TackleTry.cueTarget(input: CueInput): number?
	local from = input.from
	if not input.ready or input.hits >= TackleTry.CUE_HITS or from == nil then
		return nil
	end
	local range = input.reach + TackleTry.REACH_SLACK
	local best: number?, bestDistance = nil, math.huge
	for index, other in input.others do
		local at = other.position
		if other.carrying and at ~= nil then
			local distance = (at - from).Magnitude
			if distance <= range and distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

-- Every other player with a character: its root (and that root's position) and whether it carries a cat
-- (CarryingCatId).
function TackleTry.carriers(players: { Player }, me: Player?): { Carrier }
	local found: { Carrier } = {}
	for _, player in players do
		local character = player.Character
		if player ~= me and character ~= nil then
			local root = character:FindFirstChild("HumanoidRootPart")
			local part: BasePart? = if root ~= nil and root:IsA("BasePart")
				then root :: BasePart
				else nil
			table.insert(found, {
				position = if part ~= nil then part.Position else nil,
				carrying = character:GetAttribute("CarryingCatId") ~= nil,
				root = part,
			})
		end
	end
	return found
end

return TackleTry
