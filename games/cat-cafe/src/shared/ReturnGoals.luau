--!strict
-- The next goals (#2916): two or three things the player is close to, with progress, for the session recap
-- ("before you go") and the welcome back card ("pick up where you left off"). Pure, and nothing is saved: the join
-- works them out again from the save as it was left, which is what the exit recap showed.
--   pick(profile, now) -> { ReturnGoalView }   in this order, at most MAX:
--       "cats"     the next Tier wants more different cats: have, need, tier, area (the area that Tier opens)
--       "rarity"   it wants cats of a rarity or better: have, need, tier, rarity
--       "coins"    its rank up cost: have (coins now), need (the cost), tier
--       "away"     what the cafe earns while the player is away, at most the offline cap: amount (coins), hours
-- A goal that is met is left out; a player at the last Tier gets only "away". No timers, no "you'll lose" and
-- nothing paid: it only shows progress already made.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local ReturnGoals = {}

ReturnGoals.MAX = 3
ReturnGoals.KINDS = table.freeze({ "cats", "rarity", "coins", "away" }) :: { string }

export type Goal = Types.ReturnGoalView

-- Whether goal `goal` (one pick made earlier) is met by `profile` now: the Tier it was for is reached, or for a
-- "cats", "rarity" or "coins" goal its own need is. "away" is never done this way (it pays by itself).
function ReturnGoals.done(goal: Goal, profile: Types.PlayerProfile): boolean
	if goal.kind == "away" then
		return false
	end
	if goal.tier ~= nil and Economy.tier(profile) >= goal.tier then
		return true
	end
	local need = goal.need or 0
	if goal.kind == "cats" then
		return Economy.rankUpCatCount(profile.collection) >= need
	elseif goal.kind == "rarity" and goal.rarity ~= nil then
		return Economy.rankUpCatsAtLeast(profile.collection, goal.rarity :: Types.Rarity) >= need
	elseif goal.kind == "coins" then
		return profile.coins >= need
	end
	return false
end

function ReturnGoals.pick(profile: Types.PlayerProfile, now: number): { Goal }
	local goals: { Goal } = {}
	local nextTier = Catalog.getTier(Economy.tier(profile) + 1)
	if nextTier ~= nil then
		local cats = Economy.rankUpCatCount(profile.collection)
		if cats < nextTier.distinctCats then
			table.insert(goals, {
				kind = "cats",
				have = cats,
				need = nextTier.distinctCats,
				tier = nextTier.tier,
				area = nextTier.area,
			})
		end
		local rarity: Types.Rarity? = nextTier.needsRarity
		if rarity ~= nil then
			local need = nextTier.needsRarityCount or 1
			local have = Economy.rankUpCatsAtLeast(profile.collection, rarity)
			if have < need then
				table.insert(
					goals,
					{
						kind = "rarity",
						have = have,
						need = need,
						tier = nextTier.tier,
						rarity = rarity,
					}
				)
			end
		end
		if profile.coins < nextTier.cost then
			table.insert(goals, {
				kind = "coins",
				have = math.floor(math.max(0, profile.coins)),
				need = nextTier.cost,
				tier = nextTier.tier,
			})
		end
	end
	while #goals >= ReturnGoals.MAX do
		table.remove(goals)
	end
	-- the day rate as the save keeps it at logout (DataService), the Long Nap pass's longer cap when owned
	local longNap = Economy.passes(profile).longNap == true
	local amount = Economy.offlineGain(Economy.incomePerSecond(profile), now, now + 86400, longNap)
	if amount > 0 then
		local cap = if longNap then Config.OfflineCapPassSeconds else Config.OfflineCapSeconds
		table.insert(goals, { kind = "away", amount = amount, hours = math.floor(cap / 3600) })
	end
	return goals
end

return ReturnGoals
