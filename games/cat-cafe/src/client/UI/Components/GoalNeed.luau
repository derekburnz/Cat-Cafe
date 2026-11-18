--!strict
-- #5331 goalNeedLine (Design, first-15-minutes stall fixes item 2): the goal card's biggest missing Rank Up need in a
-- few words, for the folded touch chip ("Famous Cafe: Coins $194K / $250K") and for one small line under a takeover
-- goal. It reads RankUp.progress's requirements (from Components/RankUpNeeds), so it follows cheapTiers and
-- tier4Easy by itself. Pure, so the spec checks it.
--   biggest(requirements) -> Requirement?   the need furthest from done as a share; ties go coins, cats, rarity
--   words(requirement, anyCats) -> string   "Coins $194K / $250K", "Kinds 9 / 12", "Need an Epic" or "Need 2 Epic+"
--   line(progress) -> string?               the words for the next tier, "Ready to Rank Up!" once all are met, nil at
--                                           the top tier
--   chip(progress) -> string?               the folded chip: "Famous Cafe: Coins $194K / $250K", nil at the top
local GoalNeed = {}

GoalNeed.FLAG = "goalNeedLine"
GoalNeed.READY = "Ready to Rank Up!"

export type Requirement = {
	fraction: number,
	met: boolean,
	kind: string?,
	status: string,
	short: string,
}
export type Progress = {
	ready: boolean,
	nextTier: { name: string, anyCats: boolean?, needsRarity: string?, needsRarityCount: number? }?,
	requirements: { Requirement },
}

local ORDER: { [string]: number } = { coins = 1, cats = 2, rarity = 3 }

function GoalNeed.biggest(requirements: { Requirement }): Requirement?
	local best: Requirement? = nil
	for _, item in requirements do
		if not item.met then
			if best == nil then
				best = item
			else
				local a, b = item.fraction, best.fraction
				if
					a < b
					or (a == b and (ORDER[item.kind or ""] or 9) < (ORDER[best.kind or ""] or 9))
				then
					best = item
				end
			end
		end
	end
	return best
end

local function article(word: string): string
	return if word:match("^[AEIOUaeiou]") then "an" else "a"
end

function GoalNeed.words(
	item: Requirement,
	anyCats: boolean?,
	rarity: string?,
	rarityLeft: number?
): string
	if item.kind == "cats" then
		return ("%s %s"):format(if anyCats == true then "Cats" else "Kinds", item.status)
	end
	if item.kind == "rarity" and rarity ~= nil then
		local left = rarityLeft or 1
		if left <= 1 then
			return ("Need %s %s"):format(article(rarity), rarity)
		end
		return ("Need %d %s+"):format(left, rarity)
	end
	return ("%s %s"):format(item.short, item.status)
end

-- how many rarity cats are still short, from the row's "have / need" status
local function rarityLeft(item: Requirement): number
	local have, need = item.status:match("^(%d+) / (%d+)$")
	if have and need then
		return math.max(1, (tonumber(need) :: number) - (tonumber(have) :: number))
	end
	return 1
end

function GoalNeed.line(progress: Progress?): string?
	if progress == nil or progress.nextTier == nil then
		return nil
	end
	if progress.ready then
		return GoalNeed.READY
	end
	local item = GoalNeed.biggest(progress.requirements)
	if item == nil then
		return GoalNeed.READY
	end
	local nextTier = progress.nextTier :: any
	return GoalNeed.words(item, nextTier.anyCats, nextTier.needsRarity, rarityLeft(item))
end

function GoalNeed.chip(progress: Progress?): string?
	local words = GoalNeed.line(progress)
	if words == nil or words == GoalNeed.READY then
		return words
	end
	local nextTier = (progress :: Progress).nextTier :: any
	return ("%s: %s"):format(nextTier.name, words)
end

return GoalNeed
