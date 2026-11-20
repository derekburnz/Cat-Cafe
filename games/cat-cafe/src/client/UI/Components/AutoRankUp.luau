--!strict
-- #4924 (Derek 2026-11-16 18:39 UTC: "make it so when its ready pull the rankup screen into their screen to click";
-- Growth's first 3 minutes read: 34% of players with a rank up ready never press it): the moment a rank up is ready,
-- the Rank Up window opens by itself, so the player only taps RANK UP. Once a tier a session: closed, it waits for the
-- HUD button. Never over a catch, rescue, carry, cutscene, roll, window or card: it waits until the screen has been
-- calm for CALM_SECONDS, then opens. Switch `autoRankUp` (LiveFlags), on unless switched off. Pure.
-- #5516 (Growth's Nov 19 read: with autoRankUp off since Nov 18 14:27 UTC, a new player who sees the rank up cue
-- opens the window less often, 12.1% lost against 3.3%): switch `autoRankFirst` (LiveFlags.OFF_BY_DEFAULT) opens it
-- by itself for the first rank up only (FIRST_TIER), where the tutorial is waiting on it; every later tier stays a tap.
--   on(all, first, tier) -> boolean   whether the window may open by itself at this tier
--   due(o) -> boolean   whether to open the window now

local AutoRankUp = {}

AutoRankUp.FLAG = "autoRankUp"
AutoRankUp.FIRST_FLAG = "autoRankFirst"
AutoRankUp.FIRST_TIER = 1
AutoRankUp.CALM_SECONDS = 1.5 -- the screen calm this long first, so the window never lands as a card closes
AutoRankUp.CHECK_SECONDS = 0.5 -- how often a ready rank up waiting for calm looks again
-- the local player's attribute (client side only): the tier whose rank up is ready, nil while none is (client/Effects)
AutoRankUp.ATTRIBUTE = "RankUpReady"

export type Due = {
	on: boolean, -- the switch
	tier: number, -- the cafe's tier now
	ready: boolean, -- every need of the next tier met (RankUpNeeds)
	opened: boolean, -- it already opened for this tier this session
	calmFor: number, -- seconds the screen has been calm
}

function AutoRankUp.on(all: boolean, first: boolean, tier: number): boolean
	return all or (first and tier == AutoRankUp.FIRST_TIER)
end

function AutoRankUp.due(o: Due): boolean
	return o.on and o.ready and not o.opened and o.calmFor >= AutoRankUp.CALM_SECONDS
end

return AutoRankUp
