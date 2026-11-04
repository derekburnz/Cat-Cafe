--!strict
-- The free Bellhop Cat (F96, starter-cat.md sections 2 and 4), pure: its id, its stand's tag and why a claim is
-- refused, in the stand card's words. Shared so the card can say what the server will answer. The server's
-- StarterCatService measures the range and asks the group; this module only judges the answers.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local StarterCat = {}

StarterCat.CAT_ID = "bellhop_cat"
StarterCat.TAG = "BellhopStand" -- the stand, CatCafe_Street_BellhopStand; only stands under Workspace count

-- The stand card's lines (section 2) and the server's refusals.
StarterCat.CLAIMED = "Already home with you"
StarterCat.TOO_FAR = "Walk up to my stand to take me home"
StarterCat.NEEDS_GOALS = "Finish your first goals to take me home"
StarterCat.NEEDS_GROUP = "Join our group to take me home"
StarterCat.TRY_AGAIN = "Try again in a moment"
-- When Roblox's join prompt fails (#999, growth's note): most often the account is at its group limit. Copy only,
-- never a paid step (Premium raises the limit, and we never say so), never pushy.
StarterCat.GROUP_FULL = "Your group list may be full. Leave a group to join ours."

-- What a claim is checked against: the first goals ("task") while the game has no group, the group after.
export type Gate = "task" | "group"

function StarterCat.gate(groupId: number): Gate
	if groupId == 0 then
		return "task"
	end
	return "group"
end

-- Why `profile` cannot take the cat home now, or nil when it can. `near` is the range check; `inGroup` the
-- membership answer, nil when the call failed (read only for the group gate). `groupId` is Config.GroupId.
function StarterCat.blocker(
	profile: Types.PlayerProfile,
	near: boolean,
	inGroup: boolean?,
	groupId: number
): string?
	if profile.starterCatClaimed then
		return StarterCat.CLAIMED
	end
	if not near then
		return StarterCat.TOO_FAR
	end
	if StarterCat.gate(groupId) == "task" then
		return if profile.tutorialStep < Config.StarterCatTutorialStep
			then StarterCat.NEEDS_GOALS
			else nil
	end
	if inGroup == nil then
		return StarterCat.TRY_AGAIN
	end
	return if inGroup then nil else StarterCat.NEEDS_GROUP
end

return StarterCat
