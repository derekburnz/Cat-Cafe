--!strict
-- RankUpNeeds (#1141): what the next tier needs and what the player has, for RankUp.progress (the rank up card, the
-- upgrade shop's button, the goal card and the gate signs). Pure, so a spec can check it against the server: the
-- cat and rarity counts are the shared Economy.rankUpCatCount and rankUpCatsAtLeast the server's rankUpBlocker reads,
-- so the free Bellhop Cat counts on both sides (Derek 2026-11-04).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local Types = require(script.Parent.Parent.Types)

export type Needs = {
	coinsHave: number,
	coinsNeed: number,
	catsHave: number,
	catsNeed: number,
	rarity: Types.Rarity?, -- nil when the tier needs no rarity
	rarityHave: number,
	rarityNeed: number,
	ready: boolean, -- every need met
}

local RankUpNeeds = {}

-- Distinct cats ever caught, catId -> anything. collection (catId -> firstCaughtAt) is the source; a state without
-- it falls back to the cats owned now.
local function caughtMap(state: Types.PlayerState): { [string]: any }
	return state.collection or state.catsOwned or {}
end

function RankUpNeeds.of(nextTier: Types.TierDef, state: Types.PlayerState): Needs
	local caught = caughtMap(state)
	local rarity: Types.Rarity? = nextTier.needsRarity :: any
	local needs: Needs = {
		coinsHave = state.money,
		coinsNeed = nextTier.cost,
		catsHave = Economy.rankUpCatCount(caught),
		catsNeed = nextTier.distinctCats,
		rarity = rarity,
		-- "or better": a rarer cat also counts (designer, data-model 5b)
		rarityHave = if rarity ~= nil then Economy.rankUpCatsAtLeast(caught, rarity) else 0,
		rarityNeed = if rarity ~= nil then nextTier.needsRarityCount or 1 else 0,
		ready = false,
	}
	needs.ready = needs.coinsHave >= needs.coinsNeed
		and needs.catsHave >= needs.catsNeed
		and needs.rarityHave >= needs.rarityNeed
	return needs
end

return RankUpNeeds
