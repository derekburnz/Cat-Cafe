--!strict
-- #5249 (Derek 2026-11-18 14:28 UTC: "lower the money amount for tier 2 to tier 3 to 25k it should also be super easy
-- to get people going", then 14:36 UTC: "lower the money amount jump from tier 3 to tier 4 and tier 4 to tier 5 by a lot
-- at least half", then 15:06 UTC: "make tiers 5-8 much easier so more people can get to the more fun late game content
-- especially getting to ruins"): behind the switch `cheapTiers` (LiveFlags.OFF_BY_DEFAULT), the rank ups to Tiers 3
-- to 8 ask NEEDS in place of Catalog.PLAIN_TIER_NEEDS. Catalog.setTierNeeds writes each tier's fields, so every reader
-- (Economy.rankUpBlocker and the server's rank up, the Rank Up card, the goal card, the return goals, Tier3Path,
-- SecondCatHelp) agrees. Both sides follow the switch's ReplicatedStorage attribute, like shared/NetTiers.
--   plain                                  cheapTiers on
--   Tier 3   50,000                        25,000
--   Tier 4   1,000,000                     400,000
--   Tier 5   12,000,000                    5,000,000
--   Tier 6   150,000,000, 21 kinds         50,000,000, 17 kinds
--   Tier 7   3,125,000,000, 27 kinds, 3 M  1,000,000,000, 22 kinds, 2 Mythicals (the Ruins)
--   Tier 8   21,000,000,000, 43 kinds      7,000,000,000, 35 kinds (5 Mythicals kept: Derek's #4513)
-- #5285 E (Design-Agent's Pace read of the first 30 minutes, 2026-11-18: with cheapTiers on, Tier 4 is the wall, a median
-- of 22.5 min for the model player and 15 for an active one, coins first, and a quarter of model runs got no Legendary in
-- 30 min): behind its own switch `tier4Easy`, Tier 4 asks 250,000 and an Epic or better (Tier 5 keeps the Legendary).
-- It sits on top of whichever Tier 4 row is in use, so it works with cheapTiers on or off. Pace: 18 and 11.4 min.
-- #5467 (Derek 2026-11-19: "lower the tier 2->tier3 requirements for money and different cats by a lot so people
-- progress to tier 3 more often"; Growth's funnel: tier_3_ready loses 68% after park_catch): behind its own switch
-- `tier3Easy`, Tier 3 asks 10,000 coins and 4 kinds (25,000 and 6 with cheapTiers, 50,000 and 6 without). The 2 Rares
-- stay (the free Bellhop Cat is one). Like tier4Easy it sits on top of either Tier 3 row.
-- Derek 2026-11-19 21:11 UTC (the audit's Tier 4 wall): "it's fine to lower the costs of tiers we want to get people to
-- later game most of the fun content doesn't even come till later make 3-7 super easy": behind its own switch
-- `tiersEasy`, Tiers 4 to 7 ask EASY, laid on top of whichever rows are in use (Tier 3 keeps tier3Easy's 10,000):
--   Tier 4   60,000, 7 kinds, 1 Epic           (250,000, 10 kinds with tier4Easy)
--   Tier 5   400,000, 10 kinds, 1 Legendary    (5,000,000, 13 kinds, 2 Legendaries)
--   Tier 6   3,000,000, 13 kinds, 2 Legendaries (50,000,000, 17 kinds, 2 Mythicals)
--   Tier 7   30,000,000, 17 kinds, 1 Mythical  (1,000,000,000, 22 kinds, 2 Mythicals)
-- Each step is 6 to 10 times the one before, and no tier before 7 waits on a Mythical. Tier 8 is untouched.
-- #5533 (Derek 2026-11-20 11:40 UTC: "lets not gatekeep behind cats lets make it just coin amount"): behind its own
-- switch `coinsOnly`, laid last over whatever the other switches give, every tier from 2 up asks coins only (no kinds,
-- no rarity) and Tiers 2 to 7 ask COINS: 1,500, 10,000, 60,000, 400,000, 3,000,000, 30,000,000. Tier 8 and up keep
-- their coin cost. Cats still matter as the way to earn the coins.
--   on() -> boolean           cheapTiers
--   easyFour() -> boolean     tier4Easy
--   easyThree() -> boolean    tier3Easy
--   easyAll() -> boolean      tiersEasy
--   coinsOnly() -> boolean    coinsOnly
--   needs() -> needs?         what setTierNeeds gets for the two switches now
--   follow()                  sets the needs now and each time either switch flips

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(script.Parent.Catalog)
local LiveFlags = require(script.Parent.LiveFlags)

local CheapTiers = {}

CheapTiers.FLAG = "cheapTiers"
CheapTiers.NEEDS = {
	[3] = { cost = 25000 }, -- half of 50,000
	[4] = { cost = 400000 }, -- 60% off 1,000,000
	[5] = { cost = 5000000 }, -- about 58% off 12,000,000
	[6] = { cost = 50000000, distinctCats = 17 }, -- a third of 150,000,000; 21 kinds before
	[7] = { cost = 1000000000, distinctCats = 22, needsRarityCount = 2 }, -- a third of 3,125,000,000; 27 kinds, 3
	[8] = { cost = 7000000000, distinctCats = 35 }, -- a third of 21,000,000,000; 43 kinds before
} :: { [number]: Catalog.TierNeeds }

CheapTiers.TIER4_FLAG = "tier4Easy"
CheapTiers.TIER4 = { cost = 250000, needsRarity = "Epic" } :: Catalog.TierNeeds

CheapTiers.TIER3_FLAG = "tier3Easy"
CheapTiers.TIER3 = { cost = 10000, distinctCats = 4 } :: Catalog.TierNeeds -- #5467: 25,000 and 6 kinds before

CheapTiers.EASY_FLAG = "tiersEasy"
CheapTiers.EASY = {
	[4] = { cost = 60000, distinctCats = 7, needsRarity = "Epic", needsRarityCount = 1 },
	[5] = { cost = 400000, distinctCats = 10, needsRarity = "Legendary", needsRarityCount = 1 },
	[6] = { cost = 3000000, distinctCats = 13, needsRarity = "Legendary", needsRarityCount = 2 },
	[7] = { cost = 30000000, distinctCats = 17, needsRarity = "Mythical", needsRarityCount = 1 },
} :: { [number]: Catalog.TierNeeds }

CheapTiers.COINS_FLAG = "coinsOnly"
CheapTiers.COINS = {
	[2] = 1500, -- Design's 1,000 is Config.StartCoins, so it would be ready at 0 s; Pace: 1,500 at 55 s
	[3] = 10000,
	[4] = 60000,
	[5] = 400000,
	[6] = 3000000,
	[7] = 30000000,
} :: { [number]: number }

local following = false

function CheapTiers.on(): boolean
	return LiveFlags.shown(
		CheapTiers.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.FLAG)
	)
end

function CheapTiers.easyThree(): boolean
	return LiveFlags.shown(
		CheapTiers.TIER3_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.TIER3_FLAG)
	)
end

function CheapTiers.easyFour(): boolean
	return LiveFlags.shown(
		CheapTiers.TIER4_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.TIER4_FLAG)
	)
end

function CheapTiers.easyAll(): boolean
	return LiveFlags.shown(
		CheapTiers.EASY_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.EASY_FLAG)
	)
end

function CheapTiers.coinsOnly(): boolean
	return LiveFlags.shown(
		CheapTiers.COINS_FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.COINS_FLAG)
	)
end

-- The rows for the switches: NEEDS with cheapTiers, Tier 4's row replaced by TIER4 with tier4Easy and Tier 3's by
-- TIER3 with tier3Easy (#5467), each keeping the other fields of the row it replaces. Pure on its answers, so the
-- spec can check every case.
function CheapTiers.needsFor(
	cheap: boolean,
	easy: boolean,
	easyThree: boolean?,
	easyAll: boolean?,
	coins: boolean?
): { [number]: Catalog.TierNeeds }?
	if not easy and not easyThree and not easyAll and not coins then
		return if cheap then CheapTiers.NEEDS else nil
	end
	local out: { [number]: Catalog.TierNeeds } = {}
	if cheap then
		for tier, row in CheapTiers.NEEDS do
			out[tier] = row
		end
	end
	local function lay(tier: number, over: Catalog.TierNeeds)
		local row: any = table.clone((out[tier] or {}) :: any)
		for field, value in over :: any do
			row[field] = value
		end
		out[tier] = row
	end
	if easy then
		lay(4, CheapTiers.TIER4)
	end
	if easyThree then
		lay(3, CheapTiers.TIER3)
	end
	if easyAll then
		for tier, row in CheapTiers.EASY do
			lay(tier, row)
		end
	end
	if coins then
		-- #5533: last, so it wins over every row above; Tier 8 and up keep the cost those rows give
		for tier in Catalog.PLAIN_TIER_NEEDS do
			lay(tier, { cost = CheapTiers.COINS[tier], distinctCats = 0, noRarity = true })
		end
	end
	return out
end

function CheapTiers.needs(): { [number]: Catalog.TierNeeds }?
	return CheapTiers.needsFor(
		CheapTiers.on(),
		CheapTiers.easyFour(),
		CheapTiers.easyThree(),
		CheapTiers.easyAll(),
		CheapTiers.coinsOnly()
	)
end

local function apply()
	Catalog.setTierNeeds(CheapTiers.needs())
end

function CheapTiers.follow()
	apply()
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.FLAG)
		:Connect(apply)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.TIER4_FLAG)
		:Connect(apply)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.TIER3_FLAG)
		:Connect(apply)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.EASY_FLAG)
		:Connect(apply)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.COINS_FLAG)
		:Connect(apply)
end

return CheapTiers
