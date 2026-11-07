--!strict
-- The pity cat's tag (#2099, luck-and-rare-moments.md 1j): what Screens/PityTags draws over a stray with the
-- `PityCat` attribute ("Legendary" or "Mythical", set by the server's PityService). Pure, so the specs check it.
--   PityTagLogic.kind(value)              "Legendary" or "Mythical" for the attribute's value, else nil (no tag)
--   PityTagLogic.shows(kind, lockedBy)    whether the tag is up: a pity cat not held in a net (a net's LockedBy is
--                                         a user id; the catch "!" takes over then, and a bolt clears it)
--   PityTagLogic.compact(studs)           past ICON_STUDS the tag is only its paw-star icon
--   PityTagLogic.TEXT, RANGE, ICON_STUDS  "Pity cat" (no timer, no hurry), shown within 150 studs, icon past 60

local PityTagLogic = {}

PityTagLogic.TEXT = "Pity cat"
PityTagLogic.RANGE = 150 -- studs: the tag shows within this, on top of walls and bushes
PityTagLogic.ICON_STUDS = 60 -- studs: past this only the paw-star icon shows

function PityTagLogic.kind(value: unknown): ("Legendary" | "Mythical")?
	if value == "Mythical" then
		return "Mythical"
	elseif type(value) == "string" and value ~= "" then
		return "Legendary" -- the server's only other kind; an unknown one still reads as a pity cat
	end
	return nil
end

function PityTagLogic.shows(kind: string?, lockedBy: unknown): boolean
	if kind == nil then
		return false
	end
	return not (type(lockedBy) == "number" and lockedBy ~= 0)
end

function PityTagLogic.compact(studs: number): boolean
	return studs > PityTagLogic.ICON_STUDS
end

return PityTagLogic
