--!strict
-- Gold cats (Derek, 2026-10-27: "shiny" is now "gold"). The server sends variant "gold", the Gold attribute and
-- goldCollection, and migrates older saves, so one place says what counts as gold.
--   isGold(variant)              true for "gold"
--   collection(state)            state.goldCollection, else empty
-- Pure, no Theme, so the cloud spec runner can load it.

local CatVariant = {}

function CatVariant.isGold(variant: string?): boolean
	return variant == "gold"
end

function CatVariant.collection(
	state: { goldCollection: { [string]: number }? }
): { [string]: number }
	return state.goldCollection or {}
end

return CatVariant
