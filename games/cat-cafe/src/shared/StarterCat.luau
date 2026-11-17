--!strict
-- The free Bellhop Cat (F96, starter-cat.md sections 2 and 4), pure: its id, its stand's tag and why a claim is
-- refused, in the stand card's words. Shared so the card can say what the server will answer. The server's
-- StarterCatService measures the range and asks the group; this module only judges the answers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local LiveFlags = require(script.Parent.LiveFlags)
local StationTiers = require(script.Parent.StationTiers)
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
StarterCat.NEEDS_TIER = "Rank up to Tier 2 to take me home"
-- When Roblox's join prompt fails (#999, growth's note): most often the account is at its group limit. Copy only,
-- never a paid step (Premium raises the limit, and we never say so), never pushy.
StarterCat.GROUP_FULL = "Your group list may be full. Leave a group to join ours."

-- #4679: whether a "not a member" answer may be set aside because the player pressed "Join the group" this session:
-- `promptedAgo` is how long ago (seconds), nil when they never did. Roblox keeps a player's membership answer for
-- the session, so a fresh join can read as "no" until they rejoin.
function StarterCat.trustsJoin(promptedAgo: number?): boolean
	return promptedAgo ~= nil and promptedAgo >= 0 and promptedAgo <= Config.GroupJoinTrustSeconds
end

-- Derek 2026-11-17 15:14 UTC ("free starting cat, into food bowl into alleyway cannon, 1 catch into rankup"; Sync's
-- fresh-save run: the Bellhop Cat taken at 69 s was Tier 2's third cat, so the Rank Up came before the Alleyway):
-- the stand opens at Tier 2 (StationTiers.BY_TAG), hidden below it like the Mystery Market. Read from the switch's
-- ReplicatedStorage copy, so the server and the client answer the same.
function StarterCat.locked(tier: unknown): boolean
	local on = LiveFlags.shown(
		StationTiers.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. StationTiers.FLAG)
	)
	return StationTiers.locked(StarterCat.TAG, tier, on)
end

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
	if StarterCat.locked(profile.tier) then
		return StarterCat.NEEDS_TIER
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
