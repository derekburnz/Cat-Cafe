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
--   on() -> boolean
--   follow()          sets the needs now and each time the switch flips

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

local following = false

function CheapTiers.on(): boolean
	return LiveFlags.shown(
		CheapTiers.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.FLAG)
	)
end

local function apply()
	Catalog.setTierNeeds(if CheapTiers.on() then CheapTiers.NEEDS else nil)
end

function CheapTiers.follow()
	apply()
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CheapTiers.FLAG)
		:Connect(apply)
end

return CheapTiers
