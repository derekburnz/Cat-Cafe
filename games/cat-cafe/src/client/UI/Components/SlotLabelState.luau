--!strict
-- What the labels over your own cafe's role slots say (data-model section 5). At most one label per role, so the
-- three barista slots on the counter never stack labels:
--   labels(spots, tier, cats) -> { [spotId]: Label }
--   open    the first open slot of a role that no cat works: "Barista" over "Tap to add a cat" ("2 free · tap to
--           add cats" when more are free), or "Catch a cat for it" when every cat already has a role (a tap has
--           nothing to offer then). Only when the cats are known (state.cats), since without them a filled slot
--           looks empty.
--   locked  otherwise the next slot of the role this tier has not opened, the one the server labels
--           (CafeService.refreshSpots): "Barista" over "Opens at Tier 3".
-- A role with every slot open and working gets no label; its cats' rate tags are there already.

local Types = require(script.Parent.Parent.Types)

local SlotLabelState = {}

export type Kind = "locked" | "open"

export type Label = {
	kind: Kind,
	title: string,
	sub: string,
	tappable: boolean,
}

-- "barista" -> "Barista", as Format.roleName (Format needs Theme, which the cloud spec runner cannot load)
local function roleName(role: string): string
	return role:sub(1, 1):upper() .. role:sub(2)
end

function SlotLabelState.labels(
	spots: { Types.SpotDef },
	tier: number,
	cats: { [string]: Types.CatInstance }?
): { [string]: Label }
	local filled: { [string]: boolean } = {}
	local resting = 0
	if cats ~= nil then
		for _, cat in cats do
			if cat.spotId ~= nil then
				filled[cat.spotId :: string] = true
			else
				resting += 1
			end
		end
	end
	-- per role: the first free open slot and how many are free, and the lowest locked tier (the first in catalog
	-- order wins a tie, as on the server)
	local firstFree: { [string]: Types.SpotDef } = {}
	local free: { [string]: number } = {}
	local nextLocked: { [string]: Types.SpotDef } = {}
	local roles: { string } = {}
	for _, spot in spots do
		local role = spot.spotType
		if not table.find(roles, role) then
			table.insert(roles, role)
		end
		if tier >= spot.tier then
			if cats ~= nil and not filled[spot.id] then
				free[role] = (free[role] or 0) + 1
				firstFree[role] = firstFree[role] or spot
			end
		else
			local current = nextLocked[role]
			if current == nil or spot.tier < current.tier then
				nextLocked[role] = spot
			end
		end
	end

	local result: { [string]: Label } = {}
	for _, role in roles do
		local open = firstFree[role]
		local locked = nextLocked[role]
		if open ~= nil then
			local count = free[role] or 1
			result[open.id] = {
				kind = "open",
				title = roleName(role),
				sub = if resting == 0
					then "Catch a cat for it"
					elseif count > 1 then ("%d free · tap to add cats"):format(count)
					else "Tap to add a cat",
				tappable = resting > 0,
			}
		elseif locked ~= nil then
			result[locked.id] = {
				kind = "locked",
				title = roleName(role),
				sub = ("Opens at Tier %d"):format(locked.tier),
				tappable = false,
			}
		end
	end
	return result
end

return SlotLabelState
