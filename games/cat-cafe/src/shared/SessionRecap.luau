--!strict
-- The session recap (#1920, first-hour.md section 6): after Config.RecapAfterSeconds of play in one session, the
-- server sends this session's numbers once (SessionRecap) and the client shows the card when the player is idle. Pure:
-- SessionRecapService keeps the join's numbers and asks here.
--   start(profile, now) -> Start            the numbers at the join
--   due(start, now, enabled) -> boolean     whether the recap goes out now: not sent yet, long enough, setting on
--   view(start, profile, now) -> SessionRecapView   whole minutes, new Index cats and coins earned since the join

local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local SessionRecap = {}

export type Start = { at: number, distinctCats: number, lifetimeCoins: number, sent: boolean }

function SessionRecap.start(profile: Types.PlayerProfile, now: number): Start
	return {
		at = now,
		distinctCats = Economy.distinctCats(profile),
		lifetimeCoins = profile.lifetimeCoins,
		sent = false,
	}
end

function SessionRecap.due(start: Start, now: number, enabled: boolean): boolean
	return enabled and not start.sent and now - start.at >= Config.RecapAfterSeconds
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
	}
end

return SessionRecap
