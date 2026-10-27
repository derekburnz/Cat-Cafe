--!strict
-- What each menu screen has that the player has not seen yet, for the red dots on the menu tiles (F39 P1, the
-- Pet Simulator 99 and Grow a Garden side menu). A key per thing: an upgrade level or decor item the player can
-- buy right now, a cat (or shiny) in the collection. The HUD remembers which keys were on screen when the player
-- last opened that screen and shows a dot while any key is new. Pure: no services, so it can be unit tested.

local Types = require(script.Parent.Types)

export type Candidates = {
	Upgrades: { string },
	Decor: { string },
	Collection: { string },
}

local Notices = {}

-- The same rules as the shop rows: not maxed, the tier gate met, and enough coins for the next level.
local function upgradeKeys(catalog: Types.Catalog, state: Types.PlayerState): { string }
	local keys = {}
	for _, def in catalog.upgrades do
		local level = state.upgradeLevels[def.id] or 0
		if level >= def.maxLevel then
			continue
		end
		local needsTier: number? = def.requiresTier
		local perLevel = def.requiresTierAtLevel
		if perLevel and perLevel[level + 1] then
			needsTier = math.max(needsTier or 0, perLevel[level + 1])
		end
		if needsTier ~= nil and state.tier < (needsTier :: number) then
			continue
		end
		local cost = def.costs[level + 1]
		if cost ~= nil and state.money >= cost then
			table.insert(keys, ("%s:%d"):format(def.id, level + 1))
		end
	end
	return keys
end

local function decorKeys(catalog: Types.Catalog, state: Types.PlayerState): { string }
	local keys = {}
	for _, def in catalog.decor do
		if state.decorOwned[def.id] then
			continue
		end
		if def.requiresTier ~= nil and state.tier < (def.requiresTier :: number) then
			continue
		end
		if state.money >= def.cost then
			table.insert(keys, def.id)
		end
	end
	return keys
end

local function collectionKeys(state: Types.PlayerState): { string }
	local keys = {}
	local collection: { [string]: number } = state.collection or {}
	for catId in collection do
		table.insert(keys, catId)
	end
	local shiny: { [string]: number } = state.shinyCollection or {}
	for catId in shiny do
		table.insert(keys, "shiny:" .. catId)
	end
	return keys
end

function Notices.candidates(catalog: Types.Catalog, state: Types.PlayerState): Candidates
	return {
		Upgrades = upgradeKeys(catalog, state),
		Decor = decorKeys(catalog, state),
		Collection = collectionKeys(state),
	}
end

-- True when any key is missing from `seen`.
function Notices.hasNew(keys: { string }, seen: { [string]: boolean }): boolean
	for _, key in keys do
		if not seen[key] then
			return true
		end
	end
	return false
end

function Notices.markSeen(keys: { string }, seen: { [string]: boolean })
	for _, key in keys do
		seen[key] = true
	end
end

return Notices
