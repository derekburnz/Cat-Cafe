--!strict
-- #3555 (Derek 2026-11-12: "do the darken screen and point through rank up also when it is confirmed possible as
-- some people are missing it", "make sure only when in safezone"): the first rank up's walk-through. Pure rules.
-- The server decides when it may show (server/Services/RankSpotService sets the Player attribute ATTRIBUTE from
-- `due`): the switch on, a Tier 1 cafe whose rank up the server would take right now, not put away before, and the
-- player outside every catching area. The client only picks the moment (`phase`): free for FREE_SECONDS, no window
-- but the rank up's own. A press on the dim puts it away for good (TipSeen with SEEN, saved in tipsSeen); stepping
-- out of the safe area or spending the coins only hides it. Behind the live switch `rankUpSpotlight` (off).
--   FLAG, SEEN, ATTRIBUTE, FREE_SECONDS, TELEMETRY, WINDOW, WORDS
--   due(on, tier, seen, blocker, area) -> boolean                 the server's word
--   phase(due, was, freeSeconds, window) -> "none" | "button" | "confirm"

local RankSpot = {}

export type Phase = "none" | "button" | "confirm"

RankSpot.FLAG = "rankUpSpotlight"
RankSpot.SEEN = "rank_spotlight" -- the tipsSeen id
RankSpot.ATTRIBUTE = "RankSpotlight" -- on the Player, true while the walk-through may show
RankSpot.FREE_SECONDS = 2
RankSpot.TELEMETRY = "rank_spot" -- TelemetryReport name; values "shown" and "closed"
RankSpot.WINDOW = "RankUp" -- the rank up window's name in the UI's modal
RankSpot.WORDS = table.freeze({
	button = "You can rank up!",
	confirm = "Press to rank up",
})

-- `blocker` is Economy.rankUpBlocker's answer (nil: the server would take the rank up) and `area` the catching area
-- the player stands in (nil: the cafes and the Town Square, the safe side of every gate).
function RankSpot.due(
	on: boolean,
	tier: number,
	seen: boolean,
	blocker: string?,
	area: string?
): boolean
	return on and tier == 1 and not seen and blocker == nil and area == nil
end

-- What the client shows. `was` is what it shows now, `freeSeconds` how long nothing else has been going on (0 while
-- a catch, a rescue, a carry, a cutscene or a flight runs) and `window` the open window's name, or nil.
function RankSpot.phase(due: boolean, was: Phase, freeSeconds: number, window: string?): Phase
	if not due or freeSeconds <= 0 then
		return "none"
	end
	if window == RankSpot.WINDOW then
		-- the rank up window: its button is lit once the walk-through has begun, or after the wait
		return if was ~= "none" or freeSeconds >= RankSpot.FREE_SECONDS then "confirm" else "none"
	end
	if window ~= nil then
		return "none"
	end
	if was == "button" or freeSeconds >= RankSpot.FREE_SECONDS then
		return "button"
	end
	return "none"
end

return RankSpot
