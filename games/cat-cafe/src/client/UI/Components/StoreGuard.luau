--!strict
-- #1936 (release.md section 3): when a Robux prompt may open, and when the first half hour keeps paid items quiet.
-- Pure (no services), so the specs load it; Components/PassShop holds the last tap and asks allow() before every
-- prompt.
--   allow(input) -> (boolean, reason?)   a tap in the last TAP_SECONDS and no catch, rescue or cutscene; the reason
--                                         is "no_tap" or "busy"
--   quiet(playSeconds) -> boolean         under QUIET_SECONDS of total play; nil (an older server) is not quiet
--   playSeconds(sent, sentAt, now) -> number?   the server's total at send time plus the time since

export type Input = {
	now: number, -- os.clock()
	lastTap: number?, -- os.clock() of the last tap, click or gamepad press
	busy: boolean, -- a catch, a rescue or a cutscene
}

local StoreGuard = {}

StoreGuard.TAP_SECONDS = 2
StoreGuard.QUIET_SECONDS = 1800 -- 30 minutes of total play
StoreGuard.EVENT = "store_guard_blocked"

function StoreGuard.allow(input: Input): (boolean, string?)
	local tap = input.lastTap
	if tap == nil or input.now - tap > StoreGuard.TAP_SECONDS or input.now < tap then
		return false, "no_tap"
	end
	if input.busy then
		return false, "busy"
	end
	return true, nil
end

function StoreGuard.playSeconds(sent: any, sentAt: number?, now: number): number?
	if type(sent) ~= "number" or sent ~= sent or sent < 0 then
		return nil
	end
	return sent + (if sentAt ~= nil then math.max(0, now - sentAt) else 0)
end

function StoreGuard.quiet(playSeconds: number?): boolean
	return playSeconds ~= nil and playSeconds < StoreGuard.QUIET_SECONDS
end

return StoreGuard
