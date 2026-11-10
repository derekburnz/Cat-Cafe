--!strict
-- The session recap (#1920, first-hour.md section 6): after Config.RecapAfterSeconds of play in one session
-- (RecapFirstSessionSeconds in the account's first, #2123), the
-- server sends this session's numbers once (SessionRecap) and the client shows the card when the player is idle. Pure:
-- SessionRecapService keeps the join's numbers and asks here.
--   start(profile, now) -> Start            the numbers at the join
--   due(start, now, enabled) -> boolean     whether the recap goes out now: not sent yet, long enough, setting on
--   view(start, profile, now) -> SessionRecapView   whole minutes, new Index cats and coins earned since the join,
--                                                     and the "Tomorrow" line (shared/ReturnHook, #2123); #2916 the
--                                                     next goals (shared/ReturnGoals)

local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local ReturnGoals = require(script.Parent.ReturnGoals)
local ReturnHook = require(script.Parent.ReturnHook)
local Types = require(script.Parent.Types)

local SessionRecap = {}

-- `after`: the seconds of play before the recap, sooner in the account's first session (stats.sessions counts this
-- join, so 1 is the first)
export type Start = {
	at: number,
	distinctCats: number,
	lifetimeCoins: number,
	sent: boolean,
	after: number,
}

function SessionRecap.start(profile: Types.PlayerProfile, now: number): Start
	return {
		at = now,
		distinctCats = Economy.distinctCats(profile),
		lifetimeCoins = profile.lifetimeCoins,
		sent = false,
		after = if profile.stats.sessions <= 1
			then Config.RecapFirstSessionSeconds
			else Config.RecapAfterSeconds,
	}
end

function SessionRecap.due(start: Start, now: number, enabled: boolean): boolean
	return enabled and not start.sent and now - start.at >= start.after
end

function SessionRecap.view(
	start: Start,
	profile: Types.PlayerProfile,
	now: number
): Types.SessionRecapView
	return {
		minutes = math.floor(math.max(0, now - start.at) / 60),
		newCats = math.max(0, Economy.distinctCats(profile) - start.distinctCats),
		earned = math.max(0, math.floor(profile.lifetimeCoins - start.lifetimeCoins)),
		tomorrow = ReturnHook.pick(profile, now, "recap"),
		goals = ReturnGoals.pick(profile, now),
	}
end

return SessionRecap
