--!strict
-- A Secret stray's tag (#3470 section 5): what Screens/SecretTags draws over a stray whose Rarity attribute is
-- "Secret". Pure, so the specs check it.
--   SecretTagLogic.tagged(rarity)      whether a stray of this Rarity attribute wears the tag (only "Secret")
--   SecretTagLogic.name(catName)       the name under the word: the stray's CatName attribute as the server set it
--                                      ("???" until it has been caught once), "???" for anything else
--   SecretTagLogic.shows(lockedBy)     whether the tag is up: not held in a net (the catch "!" takes over then)
--   SecretTagLogic.TEXT, UNKNOWN, RANGE   "SECRET", "???", shown within 150 studs

local SecretTagLogic = {}

SecretTagLogic.TEXT = "SECRET"
SecretTagLogic.UNKNOWN = "???"
SecretTagLogic.RANGE = 150 -- studs, on top of walls and bushes (as the pity cat's tag)

function SecretTagLogic.tagged(rarity: unknown): boolean
	return rarity == "Secret"
end

function SecretTagLogic.name(catName: unknown): string
	if type(catName) == "string" and catName ~= "" then
		return catName
	end
	return SecretTagLogic.UNKNOWN
end

function SecretTagLogic.shows(lockedBy: unknown): boolean
	return not (type(lockedBy) == "number" and lockedBy ~= 0)
end

return SecretTagLogic
