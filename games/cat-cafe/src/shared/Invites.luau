--!strict
-- #2797 (retention-ideas.md 5d, Derek2 2026-11-09: "reward for inviting and do after 5 min-15 min dont want to
-- overwhelm early"): the invite reward, pure. A brand-new player who joins through another player's invite (Roblox's
-- ReferredByPlayerId) is linked to that inviter once, on their fresh save. The joiner gets InviteRewardFish on their
-- first catch; the inviter gets InviteRewardFish once the joiner has played InviteQualifySeconds or caught a cat,
-- whichever is first, for at most InviteDailyMax joiners a UTC day and once per joiner ever. Sending an invite pays
-- nothing. The card ("Invite a friend") shows once per account between InviteCardFromSeconds and
-- InviteCardBySeconds of play (the client picks the calm moment); `cardShown` keeps it from coming back.
-- Fish are earned only, never sold, so this is outside monetization-policy.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Invites = {}

local DAY_SECONDS = 86400

function Invites.day(now: number): number
	return now // DAY_SECONDS
end

function Invites.fresh(): Types.InviteSave
	return { rewarded = {}, today = { day = 0, count = 0 }, cardShown = false }
end

local function whole(value: unknown, default: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return default
	end
	return math.max(0, math.floor(value))
end

-- A save's invites from anything: user ids kept in order (the last InviteRewardedMax), whole counts.
function Invites.sanitize(raw: unknown): Types.InviteSave
	local out = Invites.fresh()
	if type(raw) ~= "table" then
		return out
	end
	local t = raw :: any
	if type(t.rewarded) == "table" then
		for _, id in t.rewarded do
			local userId = whole(id, 0)
			if userId > 0 and table.find(out.rewarded, userId) == nil then
				table.insert(out.rewarded, userId)
			end
		end
	end
	while #out.rewarded > Config.InviteRewardedMax do
		table.remove(out.rewarded, 1)
	end
	if type(t.today) == "table" then
		out.today = { day = whole(t.today.day, 0), count = whole(t.today.count, 0) }
	end
	out.cardShown = t.cardShown == true
	return out
end

-- A joiner's link from anything; nil when there is none.
function Invites.sanitizeReferred(raw: unknown): Types.ReferredBy?
	if type(raw) ~= "table" then
		return nil
	end
	local t = raw :: any
	local userId = whole(t.userId, 0)
	if userId <= 0 then
		return nil
	end
	return { userId = userId, paid = t.paid == true, queued = t.queued == true }
end

-- Whether a player joining with `inviterId` (ReferredByPlayerId, nil or 0 for none) links to that inviter: their save is
-- brand new (no play and no catch before this session), not linked yet, and the inviter is someone else.
function Invites.links(
	profile: Types.PlayerProfile,
	userId: number,
	inviterId: number?,
	savedPlay: number
): boolean
	return inviterId ~= nil
		and inviterId > 0
		and inviterId ~= userId
		and profile.referredBy == nil
		and savedPlay <= 0
		and profile.stats.catsCaught <= 0
end

-- Whether the joiner's own reward is due: linked, unpaid, and a first catch made.
function Invites.joinerDue(profile: Types.PlayerProfile): boolean
	local link = profile.referredBy
	return link ~= nil and not link.paid and profile.stats.catsCaught >= 1
end

-- Whether the inviter's reward should be sent: linked, not sent yet, and InviteQualifySeconds of play or a catch.
function Invites.inviterDue(profile: Types.PlayerProfile, played: number): boolean
	local link = profile.referredBy
	return link ~= nil
		and not link.queued
		and (played >= Config.InviteQualifySeconds or profile.stats.catsCaught >= 1)
end

-- Why the inviter cannot be paid for `joinerId` today, or nil when they can.
function Invites.creditBlocker(save: Types.InviteSave, joinerId: number, now: number): string?
	if table.find(save.rewarded, joinerId) ~= nil then
		return "already"
	end
	if save.today.day == Invites.day(now) and save.today.count >= Config.InviteDailyMax then
		return "daily"
	end
	return nil
end

-- Marks `joinerId` rewarded on the inviter's save; the caller pays InviteRewardFish.
function Invites.credit(save: Types.InviteSave, joinerId: number, now: number)
	local day = Invites.day(now)
	if save.today.day ~= day then
		save.today = { day = day, count = 0 }
	end
	save.today.count += 1
	table.insert(save.rewarded, joinerId)
	while #save.rewarded > Config.InviteRewardedMax do
		table.remove(save.rewarded, 1)
	end
end

-- How many more joiners can pay the inviter today.
function Invites.leftToday(save: Types.InviteSave, now: number): number
	if save.today.day ~= Invites.day(now) then
		return Config.InviteDailyMax
	end
	return math.max(0, Config.InviteDailyMax - save.today.count)
end

-- The invite card's report: "shown", "invite" or "notnow"; nil for anything else.
function Invites.cardAction(raw: unknown): string?
	if raw == "shown" or raw == "invite" or raw == "notnow" then
		return raw :: string
	end
	return nil
end

-- What the client needs for the card and the menu's Friends button.
function Invites.view(profile: Types.PlayerProfile, now: number): Types.InviteView
	return {
		cardShown = profile.invites.cardShown,
		fish = Config.InviteRewardFish,
		leftToday = Invites.leftToday(profile.invites, now),
		cardFrom = Config.InviteCardFromSeconds,
		cardBy = Config.InviteCardBySeconds,
	}
end

return Invites
