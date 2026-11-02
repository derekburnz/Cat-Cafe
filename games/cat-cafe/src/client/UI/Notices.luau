--!strict
-- What each menu screen has that the player has not seen yet, for the red dots on the menu tiles (F39 P1, the
-- Pet Simulator 99 and Grow a Garden side menu). A key per thing: an upgrade level or decor item the player can
-- buy right now, a crate piece the player owns. The HUD remembers which keys were on screen when the player last
-- opened that screen and shows a dot while any key is new. The Index has no keys: its "!" shows only while an
-- Index reward waits to be claimed (Derek 2026-10-28: "Index keeps throwing up random exclamation marks even with
-- nothing to claim"), so a newly met cat no longer lights it. Pure: no services, so it can be unit tested.

local DecorPieces = require(script.Parent.Components.DecorPieces)
local IndexRewards = require(script.Parent.Components.IndexRewards)
local Types = require(script.Parent.Types)

export type Candidates = {
	Upgrades: { string },
	Decor: { string },
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
	for _, def in DecorPieces.all(catalog) do
		if DecorPieces.isPiece(def) or (def :: any).source == "crate" then
			-- a crate piece (F53), or coin decor that F97 made a crate find (cost 0), is never bought: a new one
			-- lights the dot until the Decor screen is opened
			if state.decorOwned[def.id] then
				table.insert(keys, "piece:" .. def.id)
			end
			continue
		end
		if state.decorOwned[def.id] or IndexRewards.isIndexDecor(def) then
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

function Notices.candidates(catalog: Types.Catalog, state: Types.PlayerState): Candidates
	return {
		Upgrades = upgradeKeys(catalog, state),
		Decor = decorKeys(catalog, state),
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
