--!strict
-- The Cat Arcade's shared save, milestones, Arcade Legend title, board and cabinet rules (#3062; a player's idea,
-- credited on the card by IDEA_BY, Derek2 2026-11-10). Pure: times are server time (Workspace:GetServerTimeNow()).
-- #4656 step 4 (claim #4722): Circle Streak, the first game, is gone; its circle builder,
-- scoring and result went with it. Mouse Dash (#3296) is the arcade's game and uses this save, these milestones
-- (once per UTC day each, Config.ArcadeMilestones) and the title.
--   - Records rank by points, then fewest circles: score(points, circles) = points * 1000 + (999 - circles).
-- No Robux anywhere: no extra try, continue or skip (Monetization-Agent's conditions, #3062).
-- #3296 (Derek2 2026-11-11: "arcade game 1 free attempt daily"): the first run of each UTC day is free; later runs
-- cost ArcadeCostFish. `freeDay` is the UTC day the free run was last used.
--
-- The save (its own DataStore, not the profile, so it needed no save version step or restart):
--   Save = { best, bestCircles, day, paid, legend, runs, freeDay }  `paid` the milestone points paid on UTC `day`
-- An older server reading a save drops `freeDay` (sanitize keeps only what it knows), so for the few minutes old and
-- new servers overlap a player could get one more free run; nothing else is lost.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Arcade = {}

Arcade.FLAG = "arcade"
Arcade.LEGEND_TITLE = "Arcade Legend"
Arcade.IDEA_BY = "Idea by its_cuzu098"
Arcade.TAG = "ArcadeCabinet"
Arcade.PROMPT = "ArcadePrompt"
Arcade.ASSET = "CatCafe_Town_ArcadeCabinet"
Arcade.NAME = "Cat Arcade"
Arcade.ACTION = "Play"
Arcade.PROMPT_RANGE = 10
-- #3359: the reach the cabinet's floor ring is laid with (WalkUp.frontOffset). Nothing on the server measures a range
-- for the arcade, and with PROMPT_RANGE the ring was pulled back to 2 studs from the pivot, on top of the cabinet;
-- 16 let a radius 6 ring touch the cabinet's front; #3448: 20 for the radius 8 ring.
Arcade.RING_RANGE = 20
Arcade.DAY_SECONDS = 86400

export type Milestone = { at: number, prize: Types.IndexPrize, name: string }

export type Save = {
	best: number, -- the most points in one run
	bestCircles: number, -- the circles that best took (fewest at that best), 0 with no run yet
	day: number, -- the UTC day number `paid` is for
	paid: { number }, -- milestone points paid on `day`
	legend: boolean, -- reached 100 once: the Arcade Legend title, kept for good
	runs: number,
	freeDay: number, -- #3296: the UTC day the free run was last used, 0 never
	epoch: number, -- #3378: the board `best` is for (Arcade.BOARD_EPOCH)
}

-- What the window shows before and after a game (ArcadeState): `loaded` false while the save is still being read.
export type State = {
	loaded: boolean,
	best: number,
	bestCircles: number,
	today: { number },
	legend: boolean,
	serverBest: number,
	serverCircles: number,
	serverName: string?,
	free: boolean?, -- #3296: today's free run is still there (nil from an older server: none)
	-- #3338 (Derek2: the leaderboard button): the arcade's top players across every server, best first, at most TOP
	top: { Row }?,
}

-- #3338: one line of the arcade's leaderboard (ArcadeState.top).
export type Row = { rank: number, name: string, points: number, circles: number, me: boolean? }

Arcade.TOP = 10 -- lines on the window's leaderboard
-- #3378 (Derek 2026-11-11, "reset for now"): the board started again once the 2x faster start (#3366) was live, so
-- every score on it is made under the new rules. The board is a new store name; a save's record is reset by its
-- `epoch` (sanitize drops a best from another epoch). The save store keeps its name, so the day's paid milestones
-- and the free game stay in one place for old and new servers alike and nothing pays twice. An older server keeps
-- the old board and writes saves without an epoch, so a best made there is dropped on the next new server.
Arcade.BOARD_STORE = "CatCafe_LB_Arcade2" -- the OrderedDataStore of each player's best score, keyed by user id
Arcade.BOARD_EPOCH = 2 -- which board a save's best belongs to (none or 1: before the reset)

function Arcade.milestones(): { Milestone }
	return Config.ArcadeMilestones :: any
end

function Arcade.milestoneAt(at: number): Milestone?
	for _, m in Arcade.milestones() do
		if m.at == at then
			return m
		end
	end
	return nil
end

-- The milestones whose points lie in (before, after], lowest first.
function Arcade.crossed(before: number, after: number): { number }
	local out: { number } = {}
	for _, m in Arcade.milestones() do
		if m.at > before and m.at <= after then
			table.insert(out, m.at)
		end
	end
	table.sort(out)
	return out
end

function Arcade.day(now: number): number
	return math.floor(now / Arcade.DAY_SECONDS)
end

function Arcade.fresh(): Save
	return {
		best = 0,
		bestCircles = 0,
		day = 0,
		paid = {},
		legend = false,
		runs = 0,
		freeDay = 0,
		epoch = Arcade.BOARD_EPOCH,
	}
end

local function whole(value: unknown, low: number, high: number): number
	if type(value) ~= "number" or value ~= value then
		return low
	end
	return math.clamp(math.floor(value), low, high)
end

-- A save read back from the DataStore, anything odd dropped. A day other than today's starts with nothing paid.
-- #3378: a record from another board epoch (a save from before the reset, or one an older server rewrote) is dropped;
-- the title, the games played, the free game and today's paid milestones stay.
function Arcade.sanitize(raw: unknown, now: number): Save
	local save = Arcade.fresh()
	if type(raw) ~= "table" then
		return save
	end
	local t = raw :: { [string]: unknown }
	if t.epoch == Arcade.BOARD_EPOCH then
		save.best = whole(t.best, 0, Config.ArcadeMaxPoints)
		save.bestCircles = whole(t.bestCircles, 0, 999)
	end
	save.runs = whole(t.runs, 0, 2 ^ 31)
	save.legend = t.legend == true
	save.freeDay = whole(t.freeDay, 0, 2 ^ 31)
	local today = Arcade.day(now)
	if whole(t.day, 0, 2 ^ 31) == today and type(t.paid) == "table" then
		save.day = today
		for _, at in t.paid :: { unknown } do
			if
				type(at) == "number"
				and Arcade.milestoneAt(at) ~= nil
				and not table.find(save.paid, at)
			then
				table.insert(save.paid, at)
			end
		end
		table.sort(save.paid)
	end
	return save
end

-- Two saves of one player joined, for a write that lands on top of another server's (UpdateAsync): today's paid
-- milestones from both, the better record (more points, then fewer circles), the most runs, and the title if either has
-- it. Both should come through `sanitize` first, so a `paid` is only ever today's.
function Arcade.merge(stored: Save, mine: Save): Save
	local out = Arcade.fresh()
	out.legend = stored.legend or mine.legend
	out.runs = math.max(stored.runs, mine.runs)
	out.freeDay = math.max(stored.freeDay, mine.freeDay) -- a free run used on either server stays used
	if
		mine.best > stored.best
		or (
			mine.best == stored.best
			and mine.bestCircles > 0
			and (stored.bestCircles == 0 or mine.bestCircles < stored.bestCircles)
		)
	then
		out.best, out.bestCircles = mine.best, mine.bestCircles
	else
		out.best, out.bestCircles = stored.best, stored.bestCircles
	end
	out.day = math.max(stored.day, mine.day)
	for _, save in { stored, mine } do
		if save.day == out.day then
			for _, at in save.paid do
				if not table.find(out.paid, at) then
					table.insert(out.paid, at)
				end
			end
		end
	end
	table.sort(out.paid)
	return out
end

-- The milestones paid today, after moving `save` to today (a new UTC day clears them).
function Arcade.today(save: Save, now: number): { number }
	local day = Arcade.day(now)
	if save.day ~= day then
		save.day = day
		save.paid = {}
	end
	return save.paid
end

-- Marks and returns the milestones a run moving from `before` to `after` points pays now: those crossed that are
-- not paid today yet.
function Arcade.claim(save: Save, before: number, after: number, now: number): { number }
	local paid = Arcade.today(save, now)
	local out: { number } = {}
	for _, at in Arcade.crossed(before, after) do
		if not table.find(paid, at) then
			table.insert(paid, at)
			table.insert(out, at)
		end
	end
	table.sort(paid)
	return out
end

-- #3296: whether today's free run is still there.
function Arcade.freeToday(save: Save, now: number): boolean
	return save.freeDay ~= Arcade.day(now)
end

-- The leaderboard score: points first, then fewer circles.
function Arcade.score(points: number, circles: number): number
	return math.clamp(math.floor(points), 0, Config.ArcadeMaxPoints) * 1000
		+ (999 - math.clamp(circles, 0, 999))
end

-- The points and circles a leaderboard score holds (score's other way round); 0, 0 for anything not a score.
function Arcade.fromScore(value: unknown): (number, number)
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return 0, 0
	end
	local whole = math.floor(value :: number)
	local points = math.clamp(whole // 1000, 0, Config.ArcadeMaxPoints)
	local circles = math.clamp(999 - whole % 1000, 0, 999)
	return points, circles
end

-- #3338: leaderboard rows (Leaderboards.rows or withPresent, values are scores) as the window's lines, at most TOP,
-- `me` marking the viewer's.
function Arcade.topRows(rows: { Types.LeaderboardRow }, viewer: number?): { Row }
	local out: { Row } = {}
	for _, row in rows do
		if #out >= Arcade.TOP then
			break
		end
		local points, circles = Arcade.fromScore(row.value)
		if points <= 0 then
			continue
		end
		table.insert(out, {
			rank = #out + 1,
			name = row.name,
			points = points,
			circles = circles,
			me = if viewer ~= nil and row.userId == viewer then true else nil,
		})
	end
	return out
end

-- Why `profile` can't start a run now, in words, or nil. `busy` names a catch, rescue or flight in progress. `free`
-- (#3296): today's free run is still there, so no fish are needed.
function Arcade.startBlocker(
	fish: number,
	busy: string?,
	running: boolean,
	loaded: boolean,
	free: boolean?
): string?
	if not loaded then
		return "The arcade is still waking up, try again in a moment"
	end
	if running then
		return "Finish this game first"
	end
	if busy ~= nil then
		return busy
	end
	if free ~= true and fish < Config.ArcadeCostFish then
		return string.format("You need %d golden fish 🐟 to play", Config.ArcadeCostFish)
	end
	return nil
end

-- #3443: whether the cabinet and its floor ring are in the world: only while the arcade has a game to play, the
-- `arcade` switch on and `mouseDash` on (ArcadeCabinetService puts them away otherwise; #4656: Circle Streak is gone).
-- #3627: and never before the server has read the switches (`ready` false), when all it has is their defaults.
function Arcade.cabinetStands(arcade: boolean, mouseDash: boolean, ready: boolean?): boolean
	return ready ~= false and arcade and mouseDash
end

return Arcade
