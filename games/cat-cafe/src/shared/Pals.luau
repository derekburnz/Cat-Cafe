--!strict
-- Pals (F92, playing-together.md sections 1 and 2), pure. A pal is someone on your server who is a Roblox friend,
-- joined through your invite (or you through theirs), followed you in (or you them), or shares your private server;
-- every link counts the same. PalService works the links out on the server; this module holds the bonus and the
-- invite's launch data.
--   bonus(count) -> number          the tip share pals add: 0, PalTipBonus with one, PalTipBonusStep more for each
--                                   more, at most PalTipBonusMax (#1165)
--   inviteData(userId) -> string    the LaunchData an invite carries ("pal:<userId>")
--   inviterOf(launchData) -> number?  the inviter's user id from a join's LaunchData, nil for anything else
--   palDayDue(save, now, playSeconds, tutorialStep) -> boolean
--                                   #4913: whether today's Pal Day gift (GIFT) is still to come: once a UTC day, never
--                                   in the tutorial or the account's first PAL_DAY_AFTER_PLAY seconds; no streak
--   palDayToday(save, now) -> boolean  whether the gift was paid today (the recap's "tomorrow" line)

local Config = require(script.Parent.Config)
local Spin = require(script.Parent.Spin)
local Types = require(script.Parent.Types)

local Pals = {}

-- How a pal is linked, for pal_time's field.
export type Link = "friend" | "invite" | "follow" | "private"

local INVITE_PREFIX = "pal:"

function Pals.bonus(count: number): number
	local n = math.floor(count)
	if n < 1 then
		return 0
	end
	return math.min(Config.PalTipBonusMax, Config.PalTipBonus + Config.PalTipBonusStep * (n - 1))
end

function Pals.inviteData(userId: number): string
	return INVITE_PREFIX .. tostring(math.floor(userId))
end

-- Launch data comes from the join link, so anyone could write any id there: only "pal:" and 1 to 19 digits, and it
-- only ever links two players who are both on the server.
function Pals.inviterOf(launchData: unknown): number?
	if type(launchData) ~= "string" or #launchData > 32 then
		return nil
	end
	local digits = string.match(launchData, "^pal:(%d+)$")
	if digits == nil or #digits > 19 then
		return nil
	end
	local id = tonumber(digits)
	return if id ~= nil and id > 0 then id else nil
end

-- #4913 (Pal Day, behind the palDay switch): once a UTC day, the first PAL_DAY_SECONDS of play beside at least one
-- pal pay GIFT. Nothing is lost by missing a day and nothing counts up: it is a gift, not a streak.
Pals.PAL_DAY_FLAG = "palDay"
Pals.PAL_DAY_SECONDS = 300 -- 5 minutes beside a pal today
Pals.PAL_DAY_AFTER_PLAY = 300 -- never in an account's first 5 minutes
Pals.PAL_DAY_TUTORIAL_DONE = 5 -- Onboarding.NEW_PLAYER_STEP: the walk-through is behind the player
Pals.GIFT = table.freeze({ fish = 30, spins = 1 })

function Pals.palDayDue(
	save: Types.PalDaySave,
	now: number,
	playSeconds: number,
	tutorialStep: number
): boolean
	if tutorialStep < Pals.PAL_DAY_TUTORIAL_DONE or playSeconds < Pals.PAL_DAY_AFTER_PLAY then
		return false
	end
	return Spin.day(now) > save.day
end

function Pals.palDayToday(save: Types.PalDaySave, now: number): boolean
	return save.day > 0 and save.day == Spin.day(now)
end

return Pals
