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
		catsHave = Economy.rankUpCats(caught, state.cats, nextTier), -- #4809: any 3 cats for Tier 2
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

-- The rarity need's caption on the HUD's goal card. #2999 (Derek2 11-10: "shorten text for 'your goal' where
-- possible especially the catch mythical… just put Mythical+ cat or legendary+ cat or add a 2 if its more then
-- one"): on a touch screen "Mythical+ cat" for one and "2 Mythical+ cats" for more; elsewhere "Mythical or better",
-- with the count in the row's status.
function RankUpNeeds.rarityCaption(rarity: string, count: number, touch: boolean): string
	if not touch then
		return ("%s or better"):format(rarity)
	end
	if count <= 1 then
		return ("%s+ cat"):format(rarity)
	end
	return ("%d %s+ cats"):format(count, rarity)
end

-- #4920 item 7 (Design-Agent: "the grey state says what is missing (\"2 more kinds\"), not just grey"): the first
-- need not met yet, as the Rank Up window's grey button reads it. Cats first (the need players miss most), then the
-- rarity, then the coins, which only take waiting. `money` writes the coins still short ("$1.2K"). Nil when ready.
-- Short on purpose: the button is 260 px wide.
function RankUpNeeds.missing(
	nextTier: Types.TierDef,
	needs: Needs,
	money: (amount: number) -> string
): string?
	local cats = needs.catsNeed - needs.catsHave
	if cats > 0 then
		local word = if nextTier.anyCats == true then "cat" else "kind"
		return ("Need %d more %s%s"):format(cats, word, if cats == 1 then "" else "s")
	end
	local rarity = needs.rarity
	local rare = needs.rarityNeed - needs.rarityHave
	if rarity ~= nil and rare > 0 then
		if rare == 1 then
			return ("Need a %s+ cat"):format(rarity)
		end
		return ("Need %d more %s+"):format(rare, rarity)
	end
	local coins = needs.coinsNeed - needs.coinsHave
	if coins > 0 then
		return ("Need %s more"):format(money(coins))
	end
	return nil
end

-- #5218 (switch rankUpSteps, Screens/RankUp): the Rank Up window's needs as steps, in rankUpBlocker's order (cats,
-- rarity, coins; a need with no kind last), and how many are left. A copy; the list passed in keeps its order.
local STEP_ORDER: { [string]: number } = { cats = 1, rarity = 2, coins = 3 }
function RankUpNeeds.steps<T>(requirements: { T }): ({ T }, number)
	local list = table.clone(requirements)
	table.sort(list, function(a: T, b: T): boolean
		return (STEP_ORDER[(a :: any).kind or ""] or 9) < (STEP_ORDER[(b :: any).kind or ""] or 9)
	end)
	local left = 0
	for _, item in list do
		if not (item :: any).met then
			left += 1
		end
	end
	return list, left
end

return RankUpNeeds
