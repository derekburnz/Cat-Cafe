--!strict
-- #3224 (Derek2 2026-11-11: the catch card "just shows cat on top instead of what it is"): what the catch card's
-- header needs about a stray when no prompt card is up for it (a catch that began with the net swing), read from
-- the attributes CatService puts on the stray's model: CatId, CatName, Rarity, Gold and Variant.
--   fromStray(strayId, stray, defOf) -> Named?   nil with no model or no cat on it; the name and rarity fall back
--                                                 to the catalog's (`defOf`) when the model has none

export type Named = {
	strayId: string,
	catId: string?,
	catName: string?,
	rarity: string?,
	shiny: boolean,
	rainbow: boolean,
}

type Def = { name: string, rarity: string }

local CatchHeader = {}

function CatchHeader.fromStray(
	strayId: string,
	stray: Instance?,
	defOf: (catId: string?) -> Def?
): Named?
	if stray == nil then
		return nil
	end
	local catId = stray:GetAttribute("CatId")
	local catName = stray:GetAttribute("CatName")
	local rarity = stray:GetAttribute("Rarity")
	local def = defOf(if type(catId) == "string" then catId else nil)
	local name: string? = if type(catName) == "string" and catName ~= ""
		then catName
		elseif def ~= nil then def.name
		else nil
	if name == nil then
		return nil
	end
	local variant = stray:GetAttribute("Variant")
	return {
		strayId = strayId,
		catId = if type(catId) == "string" then catId else nil,
		catName = name,
		rarity = if type(rarity) == "string" then rarity elseif def ~= nil then def.rarity else nil,
		shiny = variant == "gold" or (variant == nil and stray:GetAttribute("Gold") == true),
		rainbow = variant == "rainbow",
	}
end

return CatchHeader
