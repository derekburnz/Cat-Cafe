--!strict
-- Cafe Crate sums the screens share (golden-fish.md sections 4 to 6, F53 and F54): crates by id, which ones are
-- golden, and the "highest" crate that a Spin Wheel slice or an All Cats prize names, which the server pays as the
-- crate of the highest zone the player has opened. Pure: no Theme, so the cloud spec runner can load it.
-- Catalog.crates (SharedTypes.CrateDef) is read loosely, as a map or a list, until the UI's Types carry it.

export type Crate = {
	id: string,
	name: string?,
	area: string?, -- its pool: a zone id or "classic"
	golden: boolean?,
	price: number?,
	asset: string?, -- a model in ReplicatedStorage.Assets, once the asset thread makes one
}

export type Area = { id: string, tier: number }

local CrateLogic = {}

CrateLogic.HIGHEST = "highest"

-- Catalog.crates by id, from a map or a list; rows that are not tables or have no id are skipped.
function CrateLogic.byId(crates: any): { [string]: Crate }
	local out: { [string]: Crate } = {}
	if type(crates) ~= "table" then
		return out
	end
	for key, crate in crates :: { [any]: any } do
		if type(crate) == "table" then
			local id = if type(crate.id) == "string" then crate.id else key
			if type(id) == "string" then
				out[id] = crate :: Crate
			end
		end
	end
	return out
end

-- A golden crate (Epic or better, never sold): the catalog's flag, else its id says so.
function CrateLogic.isGolden(id: string, crate: Crate?): boolean
	if crate and crate.golden ~= nil then
		return crate.golden == true
	end
	return string.find(id, "golden", 1, true) ~= nil
end

-- "highest" becomes the plain crate of the highest-tier area the player's tier has opened; any other id stays.
-- With no such crate in the catalog (an older one) it stays "highest", and the screens show a plain crate.
function CrateLogic.resolve(
	crateId: string,
	crates: { [string]: Crate },
	areas: { Area }?,
	tier: number?
): string
	if crateId ~= CrateLogic.HIGHEST then
		return crateId
	end
	local best: string? = nil
	local bestTier = -math.huge
	local list: { Area } = areas or {}
	for _, area in list do
		if area.tier > (tier or 1) or area.tier <= bestTier then
			continue
		end
		for id, crate in crates do
			if crate.area == area.id and not CrateLogic.isGolden(id, crate) then
				best = id
				bestTier = area.tier
				break
			end
		end
	end
	return best or crateId
end

-- "Woods Crate", else the id made readable ("woods_crate" -> "Woods Crate"); "highest" unresolved is "Crate".
function CrateLogic.name(crateId: string, crate: Crate?): string
	if crate and type(crate.name) == "string" and crate.name ~= "" then
		return crate.name
	end
	if crateId == CrateLogic.HIGHEST then
		return "Crate"
	end
	local words = {}
	for word in string.gmatch(crateId, "[^_]+") do
		table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
	end
	return table.concat(words, " ")
end

return CrateLogic
