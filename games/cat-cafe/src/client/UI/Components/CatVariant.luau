--!strict
-- Gold cats (Derek, 2026-10-27: "shiny" is now "gold"). The server moves from variant "shiny" and the Shiny
-- attribute to variant "gold" and the Gold attribute (engineer #181); the UI accepts both, so the two can land in
-- either order.
--   isGold(variant)              true for "gold" or the old "shiny"
--   goldFlag(gold, shiny)        a Gold attribute when set, else the old Shiny one
--   collection(state)            state.goldCollection, else the old shinyCollection, else empty
-- Pure, no Theme, so the cloud spec runner can load it.

local CatVariant = {}

function CatVariant.isGold(variant: string?): boolean
	return variant == "gold" or variant == "shiny"
end

function CatVariant.goldFlag(gold: unknown, shiny: unknown): boolean
	if gold ~= nil then
		return gold == true
	end
	return shiny == true
end

function CatVariant.collection(state: {
	goldCollection: { [string]: number }?,
	shinyCollection: { [string]: number }?,
}): { [string]: number }
	return state.goldCollection or state.shinyCollection or {}
end

return CatVariant
