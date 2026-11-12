--!strict
-- The Cat Arcade's Mouse Dash (#3296, mouse-dash.md; a player's idea, credited on the card by IDEA_BY). Pure: times
-- are server time (Workspace:GetServerTimeNow()) and rolls come from a passed function, so the specs are
-- deterministic. The server holds a Run and is the only one that changes it; the client never reports a score, a
-- time or a kind.
--
-- A run: mice pop out of HOLES (9) holes, one wave at a time. A wave is one pop, or two at once from
-- MouseDashPairFrom points. Each pop has a kind:
--   mouse    +1 when tapped inside its window; getting away costs a heart
--   golden   +MouseDashGoldenPoints (3), a shorter window, and getting away costs nothing
--   kitten   a napping kitten: left alone it costs nothing, tapped it costs a heart
-- The run starts with MouseDashHearts (3) and ends at 0 ("hearts") or at ArcadeMaxPoints ("win"). Every
-- MouseDashHeartBackEvery (10) catches in a row give a heart back, never above the start. A tap on a hole with
-- nothing in it while a wave is up costs no heart but makes the paw dizzy for MouseDashDizzySeconds, and taps while
-- dizzy do nothing: mashing every hole is slower than playing.
--   - Harder every MouseDashStepEvery (5) points: the window x MouseDashWindowStep per step down to
--     MouseDashWindowFloor, the gap before the next wave x MouseDashGapStep down to MouseDashGapFloor.
--   - The next wave comes a gap after the wave is over (its mice caught or gone), so quick taps make a quicker run.
--     A hole is never used two waves running and a kitten never comes two waves running.
--   - The first MouseDashFirstRunMice waves of a player's first ever run are single mice with MouseDashFirstRunWindow
--     windows that cannot cost a heart.
--   - The server draws a wave only when it starts (wave) and sends it then, so a client never knows a hole ahead of
--     time. A tap names the wave's index and the hole; one for a wave that is over, or for a pop already caught, is
--     ignored, never punished.
--   - Records rank by points, then the fastest run: score(points, seconds) = points * 1000 + (999 - seconds).
-- The day's milestones and the Arcade Legend title are the arcade's, shared with Circle Streak (shared/Arcade's save:
-- day, paid, legend), so nothing pays twice whichever game or server reaches a milestone first. No Robux anywhere: no
-- extra heart, continue or skip.
--
-- Its own save (a new DataStore, not the profile, so no save version step or restart; older servers never read it):
--   Save = { best, bestSeconds, runs, freeDay, mouser, seenKitten, firstRunDone }

local Arcade = require(script.Parent.Arcade)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local MouseDash = {}

MouseDash.FLAG = "mouseDash" -- shows the game; off until QA passes
MouseDash.MAIN_FLAG = "mouseDashMain" -- makes it the game the cabinet opens on
MouseDash.HOLES = 9 -- a 3 x 3 grid, numbered row by row from the top left
MouseDash.MAX_STEP = 20 -- a step every MouseDashStepEvery points, to ArcadeMaxPoints
MouseDash.STORE = "CatCafe_MouseDash"
MouseDash.BOARD_STORE = "CatCafe_LB_MouseDash1"
MouseDash.MOUSER_TITLE = "Mouser"
MouseDash.NAME = "Mouse Dash"
MouseDash.IDEA_BY = Arcade.IDEA_BY
MouseDash.TOP = 10
MouseDash.KITTEN_HINT = "Let sleeping kittens nap!"
-- Two at once: each pop of a pair gets this much more time, so both can be reached with one thumb (as built; the
-- spec says only "each with its own window").
MouseDash.PAIR_WINDOW_SCALE = 1.35
MouseDash.LEAD_IN = 0.9 -- the breath between Play and the first mouse

export type Kind = "mouse" | "golden" | "kitten"
export type Reason = "hearts" | "win" | "quit"

export type Pop = {
	hole: number, -- 1 to HOLES
	kind: Kind,
	upAt: number,
	downAt: number,
	done: boolean, -- caught, tapped (a kitten) or gone
}

export type Wave = {
	index: number, -- 1, 2, 3 ... through the run
	pops: { Pop },
	safe: boolean, -- a first run's opening mice: getting away costs nothing
}

export type Run = {
	points: number,
	hearts: number,
	streak: number, -- catches in a row
	catches: number,
	lost: number, -- hearts lost through the run (telemetry)
	index: number, -- the last wave drawn
	wave: Wave?, -- the wave that is up, nil in a gap
	nextAt: number, -- when the next wave starts
	dizzyUntil: number,
	lastHoles: { number }, -- the last wave's, kept out of the next
	lastKitten: boolean, -- the last wave had a kitten
	safeLeft: number, -- a first run's opening mice still to come
	startedAt: number,
	sawKitten: boolean,
}

-- What a tap did. "catch": a mouse or golden mouse, `gain` points. "kitten": a napping kitten tapped, a heart lost.
-- "empty": nothing in that hole, the paw is dizzy. "dizzy": tapped while dizzy, nothing. "ignored": the wave is over,
-- the pop is already done, or the tap makes no sense.
export type Tap = {
	outcome: "catch" | "kitten" | "empty" | "dizzy" | "ignored",
	hole: number,
	kind: Kind?,
	gain: number,
	heart: number, -- -1 a heart lost, 1 one won back, 0
	waveOver: boolean,
}

-- A pop whose window ended untapped (settle). `heart` is -1 for a mouse that got away outside the safe opening.
export type Gone = { hole: number, kind: Kind, heart: number }

export type Save = {
	best: number,
	bestSeconds: number, -- the seconds that best took (fewest at that best), 0 with no run yet
	runs: number,
	freeDay: number, -- the UTC day the free run was last used, 0 never
	mouser: boolean, -- reached MouseDashMouserAt once
	seenKitten: boolean, -- the kitten's hint has been shown
	firstRunDone: boolean,
}

export type Result = {
	points: number,
	seconds: number,
	reason: Reason,
	win: boolean,
	best: number,
	bestSeconds: number,
	newBest: boolean,
	paid: { number }, -- the arcade's milestones paid in this run
	today: { number }, -- every milestone paid today
	legend: boolean,
	mouser: boolean,
}

export type Row = { rank: number, name: string, points: number, seconds: number, me: boolean? }

-- What the window shows before and after a game (MouseDashState).
export type State = {
	loaded: boolean,
	best: number,
	bestSeconds: number,
	today: { number },
	legend: boolean,
	mouser: boolean,
	free: boolean,
	firstRun: boolean,
	top: { Row }?,
}

-- The difficulty step at `points`: one per MouseDashStepEvery, 0 to MAX_STEP.
function MouseDash.step(points: number): number
	return math.clamp(math.floor(points / Config.MouseDashStepEvery), 0, MouseDash.MAX_STEP)
end

-- A mouse's window at `step`.
function MouseDash.window(step: number): number
	local s = math.clamp(step, 0, MouseDash.MAX_STEP)
	return math.max(
		Config.MouseDashWindowStart * Config.MouseDashWindowStep ^ s,
		Config.MouseDashWindowFloor
	)
end

-- The gap before the next wave at `step`.
function MouseDash.gap(step: number): number
	local s = math.clamp(step, 0, MouseDash.MAX_STEP)
	return math.max(
		Config.MouseDashGapStart * Config.MouseDashGapStep ^ s,
		Config.MouseDashGapFloor
	)
end

-- A new run starting at `now`. `firstRun`: the player's first ever, with its safe opening mice.
function MouseDash.begin(now: number, firstRun: boolean): Run
	return {
		points = 0,
		hearts = Config.MouseDashHearts,
		streak = 0,
		catches = 0,
		lost = 0,
		index = 0,
		wave = nil,
		nextAt = now + MouseDash.LEAD_IN,
		dizzyUntil = 0,
		lastHoles = {},
		lastKitten = false,
		safeLeft = if firstRun then Config.MouseDashFirstRunMice else 0,
		startedAt = now,
		sawKitten = false,
	}
end

-- Why the run is over, or nil while it goes on.
function MouseDash.over(run: Run): Reason?
	if run.points >= Config.ArcadeMaxPoints then
		return "win"
	end
	if run.hearts <= 0 then
		return "hearts"
	end
	return nil
end

-- A hole not in `taken`, picked evenly. `roll` returns a number in [0, 1).
local function pickHole(taken: { number }, roll: () -> number): number
	local free: { number } = {}
	for hole = 1, MouseDash.HOLES do
		if not table.find(taken, hole) then
			table.insert(free, hole)
		end
	end
	return free[math.clamp(math.floor(roll() * #free) + 1, 1, #free)]
end

-- Draws the wave that starts at `at` and puts it up (run.wave). Call only in a gap, at or after run.nextAt.
function MouseDash.wave(run: Run, at: number, roll: () -> number): Wave
	run.index += 1
	local points = run.points
	local window = MouseDash.window(MouseDash.step(points))
	local pops: { Pop } = {}
	local taken = table.clone(run.lastHoles)
	local safe = run.safeLeft > 0
	local function add(kind: Kind, seconds: number)
		local hole = pickHole(taken, roll)
		table.insert(taken, hole)
		table.insert(
			pops,
			{ hole = hole, kind = kind, upAt = at, downAt = at + seconds, done = false }
		)
	end
	-- a mouse, or (rolled once) a golden one
	local function mouseKind(): Kind
		if points >= Config.MouseDashGoldenFrom and roll() < Config.MouseDashGoldenChance then
			return "golden"
		end
		return "mouse"
	end
	local function seconds(kind: Kind, scale: number): number
		return window * scale * (if kind == "golden" then Config.MouseDashGoldenWindowScale else 1)
	end
	if safe then
		run.safeLeft -= 1
		add("mouse", Config.MouseDashFirstRunWindow)
	elseif points >= Config.MouseDashPairFrom and roll() < Config.MouseDashPairChance then
		local scale = MouseDash.PAIR_WINDOW_SCALE
		local first: Kind = mouseKind()
		add(first, seconds(first, scale))
		-- the second may be a kitten from MouseDashPairKittenFrom; a pair always has a mouse to catch
		local second: Kind = "mouse"
		if
			points >= Config.MouseDashPairKittenFrom
			and not run.lastKitten
			and roll() < Config.MouseDashKittenChance
		then
			second = "kitten"
		end
		add(second, seconds(second, scale))
	else
		local kind: Kind
		if
			points >= Config.MouseDashKittenFrom
			and not run.lastKitten
			and roll() < Config.MouseDashKittenChance
		then
			kind = "kitten"
		else
			kind = mouseKind()
		end
		add(kind, seconds(kind, 1))
	end
	local holes: { number } = {}
	local kitten = false
	for _, pop in pops do
		table.insert(holes, pop.hole)
		kitten = kitten or pop.kind == "kitten"
	end
	run.lastHoles = holes
	run.lastKitten = kitten
	run.sawKitten = run.sawKitten or kitten
	local wave: Wave = { index = run.index, pops = pops, safe = safe }
	run.wave = wave
	return wave
end

-- The wave is over once every mouse in it is caught or gone (a kitten beside a mouse ducks back with it); a kitten
-- alone stays its whole window unless it is tapped. Sets the next wave's time.
local function closeIfOver(run: Run, now: number): boolean
	local wave = run.wave
	if wave == nil then
		return false
	end
	local mice, openMice, allDone = 0, 0, true
	for _, pop in wave.pops do
		allDone = allDone and pop.done
		if pop.kind ~= "kitten" then
			mice += 1
			openMice += if pop.done then 0 else 1
		end
	end
	local over = if mice > 0 then openMice == 0 else allDone
	if over then
		run.wave = nil
		run.nextAt = now + MouseDash.gap(MouseDash.step(run.points))
	end
	return over
end

local function loseHeart(run: Run)
	run.hearts = math.max(run.hearts - 1, 0)
	run.lost += 1
	run.streak = 0
end

-- A tap on `hole` for wave `index`, judged at `now`. `slack` is the allowance for the player's ping: a pop can
-- still be caught that long after its window ended (it had not gone yet on their screen).
function MouseDash.tap(run: Run, index: number, hole: number, now: number, slack: number): Tap
	local tap: Tap =
		{ outcome = "ignored", hole = hole, kind = nil, gain = 0, heart = 0, waveOver = false }
	local wave = run.wave
	if
		MouseDash.over(run) ~= nil
		or wave == nil
		or wave.index ~= index
		or hole ~= math.floor(hole)
		or hole < 1
		or hole > MouseDash.HOLES
	then
		return tap
	end
	if now < run.dizzyUntil then
		tap.outcome = "dizzy"
		return tap
	end
	local found: Pop? = nil
	for _, pop in wave.pops do
		if pop.hole == hole then
			found = pop
		end
	end
	if found == nil then
		tap.outcome = "empty"
		run.dizzyUntil = now + Config.MouseDashDizzySeconds
		return tap
	end
	-- already caught, or gone on everyone's clock: nothing, and no second punishment
	if found.done or now < found.upAt or now > found.downAt + math.max(slack, 0) then
		return tap
	end
	found.done = true
	tap.kind = found.kind
	if found.kind == "kitten" then
		tap.outcome = "kitten"
		tap.heart = -1
		loseHeart(run)
	else
		tap.outcome = "catch"
		local gain = if found.kind == "golden" then Config.MouseDashGoldenPoints else 1
		local before = run.points
		run.points = math.min(run.points + gain, Config.ArcadeMaxPoints)
		tap.gain = run.points - before
		run.catches += 1
		run.streak += 1
		if
			run.streak % Config.MouseDashHeartBackEvery == 0
			and run.hearts < Config.MouseDashHearts
		then
			run.hearts += 1
			tap.heart = 1
		end
	end
	tap.waveOver = closeIfOver(run, now)
	return tap
end

-- Takes down every pop whose window (plus `slack`) has ended by `now`: a mouse that got away costs a heart outside
-- the safe opening, a golden mouse or a kitten costs nothing. Returns what went, and whether the wave is over.
function MouseDash.settle(run: Run, now: number, slack: number): ({ Gone }, boolean)
	local gone: { Gone } = {}
	local wave = run.wave
	if wave == nil then
		return gone, false
	end
	for _, pop in wave.pops do
		if not pop.done and now > pop.downAt + math.max(slack, 0) then
			pop.done = true
			local heart = 0
			if pop.kind == "mouse" and not wave.safe then
				heart = -1
				loseHeart(run)
			elseif pop.kind == "mouse" then
				run.streak = 0
			end
			table.insert(gone, { hole = pop.hole, kind = pop.kind, heart = heart })
		end
	end
	local over = closeIfOver(run, now)
	-- a kitten left beside a caught or gone mouse ducks back with the wave
	if over then
		for _, pop in wave.pops do
			if not pop.done then
				pop.done = true
				table.insert(gone, { hole = pop.hole, kind = pop.kind, heart = 0 })
			end
		end
	end
	return gone, over
end

-- When the server should look at the run next: the next wave's start in a gap, else the first window to end.
function MouseDash.wakeAt(run: Run, slack: number): number
	local wave = run.wave
	if wave == nil then
		return run.nextAt
	end
	local at = math.huge
	for _, pop in wave.pops do
		if not pop.done then
			at = math.min(at, pop.downAt + math.max(slack, 0))
		end
	end
	return if at == math.huge then run.nextAt else at
end

-- The whole seconds a run took, for its record (0 to 999).
function MouseDash.seconds(run: Run, now: number): number
	return math.clamp(math.ceil(now - run.startedAt), 0, 999)
end

-- The save ----------------------------------------------------------------------------------------------------------

function MouseDash.fresh(): Save
	return {
		best = 0,
		bestSeconds = 0,
		runs = 0,
		freeDay = 0,
		mouser = false,
		seenKitten = false,
		firstRunDone = false,
	}
end

local function whole(value: unknown, low: number, high: number): number
	if type(value) ~= "number" or value ~= value then
		return low
	end
	return math.clamp(math.floor(value), low, high)
end

-- A save read back from the DataStore, anything odd dropped.
function MouseDash.sanitize(raw: unknown): Save
	local save = MouseDash.fresh()
	if type(raw) ~= "table" then
		return save
	end
	local t = raw :: { [string]: unknown }
	save.best = whole(t.best, 0, Config.ArcadeMaxPoints)
	save.bestSeconds = if save.best > 0 then whole(t.bestSeconds, 0, 999) else 0
	save.runs = whole(t.runs, 0, 2 ^ 31)
	save.freeDay = whole(t.freeDay, 0, 2 ^ 31)
	save.mouser = t.mouser == true
	save.seenKitten = t.seenKitten == true
	save.firstRunDone = t.firstRunDone == true
	return save
end

-- The leaderboard score: points first, then fewer seconds.
function MouseDash.score(points: number, seconds: number): number
	return math.clamp(math.floor(points), 0, Config.ArcadeMaxPoints) * 1000
		+ (999 - math.clamp(math.floor(seconds), 0, 999))
end

-- The points and seconds a leaderboard score holds; 0, 0 for anything not a score.
function MouseDash.fromScore(value: unknown): (number, number)
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return 0, 0
	end
	local n = math.floor(value :: number)
	return math.clamp(n // 1000, 0, Config.ArcadeMaxPoints), math.clamp(999 - n % 1000, 0, 999)
end

-- Whether a run of `points` in `seconds` beats a record of `best` in `bestSeconds`.
function MouseDash.beats(
	points: number,
	seconds: number,
	best: number,
	bestSeconds: number
): boolean
	if points <= 0 then
		return false
	end
	if best <= 0 then
		return true
	end
	return MouseDash.score(points, seconds) > MouseDash.score(best, bestSeconds)
end

-- Two saves of one player joined, for a write that lands on top of another server's (UpdateAsync): the better
-- record, the most runs, a free run used on either, and every flag either has.
function MouseDash.merge(stored: Save, mine: Save): Save
	local out = MouseDash.fresh()
	out.runs = math.max(stored.runs, mine.runs)
	out.freeDay = math.max(stored.freeDay, mine.freeDay)
	out.mouser = stored.mouser or mine.mouser
	out.seenKitten = stored.seenKitten or mine.seenKitten
	out.firstRunDone = stored.firstRunDone or mine.firstRunDone
	if MouseDash.beats(mine.best, mine.bestSeconds, stored.best, stored.bestSeconds) then
		out.best, out.bestSeconds = mine.best, mine.bestSeconds
	else
		out.best, out.bestSeconds = stored.best, stored.bestSeconds
	end
	return out
end

-- Records a finished run in `save`; true when it is a new personal best. MouseDashMouserAt points earn Mouser for
-- good.
function MouseDash.record(save: Save, points: number, seconds: number, sawKitten: boolean): boolean
	save.runs += 1
	save.firstRunDone = true
	save.seenKitten = save.seenKitten or sawKitten
	if points >= Config.MouseDashMouserAt then
		save.mouser = true
	end
	if MouseDash.beats(points, seconds, save.best, save.bestSeconds) then
		save.best = points
		save.bestSeconds = seconds
		return true
	end
	return false
end

function MouseDash.freeToday(save: Save, now: number): boolean
	return save.freeDay ~= Arcade.day(now)
end

-- Uses today's free run; false when it was already used.
function MouseDash.useFree(save: Save, now: number): boolean
	if not MouseDash.freeToday(save, now) then
		return false
	end
	save.freeDay = Arcade.day(now)
	return true
end

-- "Play (free)" or "Play (1 golden fish)" (mouse-dash.md section 3).
function MouseDash.playText(free: boolean): string
	if free then
		return "Play (free)"
	end
	return string.format("Play (%d golden fish)", Config.ArcadeCostFish)
end

-- "37", or "100 in 84s" for a full run.
function MouseDash.words(points: number, seconds: number): string
	if points >= Config.ArcadeMaxPoints and seconds > 0 then
		return string.format("%d in %ds", points, seconds)
	end
	return tostring(points)
end

-- Leaderboard rows (values are scores) as the window's lines, at most TOP, `me` marking the viewer's.
function MouseDash.topRows(rows: { Types.LeaderboardRow }, viewer: number?): { Row }
	local out: { Row } = {}
	for _, row in rows do
		if #out >= MouseDash.TOP then
			break
		end
		local points, seconds = MouseDash.fromScore(row.value)
		if points <= 0 then
			continue
		end
		table.insert(out, {
			rank = #out + 1,
			name = row.name,
			points = points,
			seconds = seconds,
			me = if viewer ~= nil and row.userId == viewer then true else nil,
		})
	end
	return out
end

return MouseDash
