--!strict
-- #2714 (Derek2 11-09: "let you shrink down your goal so they have more screen space"): the folded goal card's one
-- line. Pure, so the spec checks it.
--   chip(progress, nudge) -> (string, boolean)   the words and whether they are the gold "ready" ones:
--                                                "🏆 Grand Cafe 2/3" (its requirements met of all), "🏆 Rank up!" once
--                                                ready, "📖 Find 3 more cats" for #1919's nudge, "🏆 Top tier" at the top

local GoalFold = {}

GoalFold.SETTING = "goalFolded" -- shared/Settings: the card folded, kept on the account (touch only reads it)

export type Requirement = { met: boolean }
export type Progress = { ready: boolean, nextTier: { name: string }?, requirements: { Requirement } }

function GoalFold.chip(progress: Progress?, nudge: string?): (string, boolean)
	if progress ~= nil and progress.ready then
		return "🏆 Rank up!", true
	end
	if nudge ~= nil then
		return nudge, false
	end
	local nextTier = if progress then progress.nextTier else nil
	if progress == nil or nextTier == nil then
		return "🏆 Top tier", false
	end
	local met, total = 0, 0
	for _, item in progress.requirements do
		total += 1
		if item.met then
			met += 1
		end
	end
	return ("🏆 %s %d/%d"):format(nextTier.name, met, total), false
end

return GoalFold
