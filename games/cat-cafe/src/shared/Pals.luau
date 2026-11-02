--!strict
-- Pals (F92, playing-together.md sections 1 and 2), pure. A pal is someone on your server who is a Roblox friend,
-- joined through your invite (or you through theirs), followed you in (or you them), or shares your private server;
-- every link counts the same. PalService works the links out on the server; this module holds the bonus and the
-- invite's launch data.
--   bonus(count) -> number          the tip share pals add: 0, PalTipBonus with one, PalTipBonusMax with two or more
--   inviteData(userId) -> string    the LaunchData an invite carries ("pal:<userId>")
--   inviterOf(launchData) -> number?  the inviter's user id from a join's LaunchData, nil for anything else

local Config = require(script.Parent.Config)

local Pals = {}

-- How a pal is linked, for pal_time's field.
export type Link = "friend" | "invite" | "follow" | "private"

local INVITE_PREFIX = "pal:"

function Pals.bonus(count: number): number
	if count >= 2 then
		return Config.PalTipBonusMax
	elseif count >= 1 then
		return Config.PalTipBonus
	end
	return 0
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

return Pals
