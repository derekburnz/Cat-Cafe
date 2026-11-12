--!strict
-- #3378 (Derek 2026-11-11: "setup a funnel for it"): the Cat Arcade's funnel, arcade_v1. One run per player per UTC
-- day (its funnel session is `key`): 1 arcade_seen (came near the cabinet), 2 arcade_opened (the window opened, ring
-- or prompt), 3 arcade_started (the server accepted ArcadeStart), 4 arcade_first_circle (the first circle hit in a
-- game), 5 arcade_finished (a game ended, not a quit), 6 arcade_played_again (a second game started that day).
-- Fields on every step: "free" or "paid" (the day's free game or golden fish), the device, the minutes played band.
-- Counts only, never who. Pure: Telemetry keeps each player's `State` for the session and logs what `due` returns.

local ArcadeFunnel = {}

ArcadeFunnel.NAME = "arcade_v1"
ArcadeFunnel.STEPS = table.freeze({
	"arcade_seen",
	"arcade_opened",
	"arcade_started",
	"arcade_first_circle",
	"arcade_finished",
	"arcade_played_again",
})
ArcadeFunnel.SEEN = 1
ArcadeFunnel.OPENED = 2
ArcadeFunnel.STARTED = 3
ArcadeFunnel.FIRST_CIRCLE = 4
ArcadeFunnel.FINISHED = 5
ArcadeFunnel.PLAYED_AGAIN = 6

-- #3296: the arcade has two games (Circle Streak, vaulted by the `circleStreak` switch, and Mouse Dash). arcade_v1
-- keeps its six steps across the swap; step 4 is "first hit in a game" (a circle hit, or a mouse caught), and
-- arcade_quit, arcade_blocked and arcade_board_top carry the game as their second field. An event takes three
-- fields at most, so arcade_run's third is "win" or "over" for Circle Streak (as before the swap) and "mouse_win"
-- or "mouse_over" for Mouse Dash; its first is the circles hit, or Mouse Dash's seconds.
ArcadeFunnel.GAME_CIRCLE = "circle"
ArcadeFunnel.GAME_MOUSE = "mouse"
ArcadeFunnel.FIRST_HIT = 4 -- the same step as FIRST_CIRCLE, under the name both games use

ArcadeFunnel.SEEN_STUDS = 40 -- "near the cabinet": about the Town Square corner it stands in
ArcadeFunnel.SEEN_EVERY = 2 -- seconds between two looks at who is near

-- `day` is the UTC day the steps so far were logged for (0 none yet), `step` the furthest step logged that day,
-- `starts` the games started that day on this server, `again` a second game started before any game was finished
-- (arcade_played_again waits for arcade_finished, so the steps always come in order).
export type State = { day: number, step: number, starts: number, again: boolean }

function ArcadeFunnel.fresh(): State
	return { day = 0, step = 0, starts = 0, again = false }
end

local function newDay(state: State, day: number)
	if state.day ~= day then
		state.day, state.step, state.starts, state.again = day, 0, 0, false
	end
end

-- The funnel session of one player's day.
function ArcadeFunnel.key(day: number, userId: number): string
	return string.format("%d:%d", day, userId)
end

-- The steps to log, in order, now that the player reached `step` on `day`; `state` moves on. A new day starts the
-- run again. Seen, opened and started fill in the steps before them (a player who starts a game has seen and opened
-- the cabinet, whatever the range check caught). The later steps are logged alone and only once a day, so a quit
-- game never counts as finished. Played again before any game was finished (game 1 was quit) is kept back and
-- logged right after the day's first finished game, so step 6 never comes before step 5 or shuts it out.
function ArcadeFunnel.due(state: State, day: number, step: number): { number }
	if step < 1 or step > #ArcadeFunnel.STEPS or step ~= math.floor(step) then
		return {}
	end
	newDay(state, day)
	local out: { number } = {}
	for s = state.step + 1, math.min(step, ArcadeFunnel.STARTED) do
		table.insert(out, s)
	end
	state.step = math.max(state.step, math.min(step, ArcadeFunnel.STARTED))
	if step == ArcadeFunnel.PLAYED_AGAIN and state.step < ArcadeFunnel.FINISHED then
		state.again = true
		return out
	end
	if step > state.step then
		table.insert(out, step)
		state.step = step
		if step == ArcadeFunnel.FINISHED and state.again then
			table.insert(out, ArcadeFunnel.PLAYED_AGAIN)
			state.step = ArcadeFunnel.PLAYED_AGAIN
		end
	end
	return out
end

-- Counts a game started on `day` and says whether it is a second one that day: one was started here already, or
-- the day's free game was used before this paid one (`freeUsed`, from the arcade save, so another server's counts).
function ArcadeFunnel.started(state: State, day: number, freeUsed: boolean): boolean
	newDay(state, day)
	state.starts += 1
	return state.starts >= 2 or freeUsed
end

-- arcade_blocked's reason field, from what refused the start.
function ArcadeFunnel.blockedReason(
	closed: boolean,
	loaded: boolean,
	running: boolean,
	busy: boolean
): string
	if closed then
		return "closed"
	elseif not loaded then
		return "loading"
	elseif running then
		return "running"
	elseif busy then
		return "busy"
	end
	return "no_fish"
end

return ArcadeFunnel
