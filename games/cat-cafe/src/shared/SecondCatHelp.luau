--!strict
-- SecondCatHelp: two helps between the first cat and Tier 2 (Derek 2026-11-15 13:26 UTC: "Work on further improving
-- the drop off from first to secondcat in funnels and improving the tier 2 drop off"; Design-Agent's plan in the
-- project files, Design-Agent/dropoff-2026-11-15/second-cat-and-tier2.md). Pure; BaitService acts on it.
--   autoBaitDue(profile, on) -> boolean   #4452 (switch autoFirstBait): the starter Kibble goes in bowl 1 by itself
--   topUpFor(profile, on, anyCatch?) -> number  #4453 (switch tier2TopUp): coins the first tamed bait cat's welcome
--                                         pays; #4674: with anyCatch (bowl first) any catch that completes Tier 2's cats
-- Both switches are on unless switched off (not in LiveFlags.OFF_BY_DEFAULT); off brings back the flow before.

local Bait = require(script.Parent.Bait)
local Catalog = require(script.Parent.Catalog)
local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local SecondCatHelp = {}

SecondCatHelp.AUTO_BAIT_FLAG = "autoFirstBait"
SecondCatHelp.TOP_UP_FLAG = "tier2TopUp"
SecondCatHelp.FOOD = "kibble" -- the first bowl's Kibble (ProfileSchema, Config.StartBowls)
SecondCatHelp.BOWL = 1

-- #4452: whether the server puts the starter Kibble in bowl 1 for the player now. Only on the tutorial's bowl step
-- (4, after the first cat's job), only for an account that has never baited, with the bowl bought, bowl 1 empty and
-- a Kibble held. luresUsed counts the food once it goes in, so this is true at most once per account.
function SecondCatHelp.autoBaitDue(profile: Types.PlayerProfile, on: boolean): boolean
	return on
		and profile.tutorialStep == 4
		and profile.stats.luresUsed == 0
		and Economy.level(profile, "lure_bowl") >= 1
		and Bait.stateOf(profile, SecondCatHelp.BOWL) == nil
		and (profile.lures[SecondCatHelp.FOOD] or 0) >= 1
end

-- #4453: the coins to pay as the account's first bait cat is tamed (call it after the cat is added, with
-- stats.baitsTamed already counting it), else 0. Only once (stats.tier2TopUp holds what was paid), only at Tier 1
-- with Tier 2's cats need met, and only up to exactly Tier 2's cost: the price shown stays the real price and the
-- gift is shown as a gift.
function SecondCatHelp.topUpFor(
	profile: Types.PlayerProfile,
	on: boolean,
	anyCatch: boolean?
): number
	-- #4674 (Derek 2026-11-16: "give more starter money ... if you the 2nd cat safe it should be ready for rankup and
	-- park teleport"): bowl first's bait cat is the first cat, so there the catch that completes Tier 2's kinds (any
	-- route) pays the gap instead of the first tamed bait cat
	if
		not on
		or (anyCatch ~= true and profile.stats.baitsTamed ~= 1)
		or profile.stats.tier2TopUp > 0
	then
		return 0
	end
	if Economy.tier(profile) ~= 1 then
		return 0
	end
	local nextTier = Catalog.getTier(2)
	if nextTier == nil then
		return 0
	end
	if Economy.rankUpCatCount(profile.collection) < nextTier.distinctCats then
		return 0
	end
	local rarity: Types.Rarity? = nextTier.needsRarity
	if
		rarity ~= nil
		and Economy.rankUpCatsAtLeast(profile.collection, rarity)
			< (nextTier.needsRarityCount or 1)
	then
		return 0
	end
	return math.max(0, math.ceil(nextTier.cost - profile.coins))
end

return SecondCatHelp
