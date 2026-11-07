--!strict
-- #2302 (Derek2: "add tackling somewhere in tutorial or something if it's not already"): the `tackle_try` tip, a
-- card pointing at the Tackle bar the first time it could be used: the tackling lesson seen, this player's tackle
-- ready and someone else carrying a cat within a lunge (Config.TackleLungeStuds, with REACH_SLACK for the walk in).
--   due(input)                     the pure rule, for the spec
--   carriers(players, me)          the others on the server and whether each carries a cat, read off their characters

local TackleTry = {}

TackleTry.TIP = "tackle_try"
TackleTry.REACH_SLACK = 4 -- studs past the lunge: close enough that a step and a press lands it

export type Carrier = { position: Vector3?, carrying: boolean }

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

-- Every other player with a character: its root's position and whether it carries a cat (CarryingCatId).
function TackleTry.carriers(players: { Player }, me: Player?): { Carrier }
	local found: { Carrier } = {}
	for _, player in players do
		local character = player.Character
		if player ~= me and character ~= nil then
			local root = character:FindFirstChild("HumanoidRootPart")
			table.insert(found, {
				position = if root ~= nil and root:IsA("BasePart") then root.Position else nil,
				carrying = character:GetAttribute("CarryingCatId") ~= nil,
			})
		end
	end
	return found
end

return TackleTry
