--!strict
-- Mouse Dash on the server (#3296, mouse-dash.md; the rules are shared/MouseDash). MouseDashStart checks the `arcade`
-- and `mouseDash` switches, that both arcade saves are read (this game's and ArcadeService's, which holds the day's
-- milestones), that no arcade game is running and that the player is in no catch, rescue or flight, then uses the
-- day's free run or spends ArcadeCostFish golden fish and answers MouseDashBegan.
--
-- The server owns the whole game. It draws one wave at a time, only as it starts (MouseDashWave), so a client never
-- knows a hole ahead of time. A tap (MouseDashTap) carries the run, the wave's index and the hole, nothing else: it
-- is stamped on arrival and judged by MouseDash.tap, with the player's ping (capped at CatchLatencyCapSeconds) as
-- the allowance past a window's end, since the pop also had to travel to them. A tap that did something goes back as
-- MouseDashJudged; a wrong run, an old wave, a hole that is not one or a tap while dizzy changes nothing. Windows
-- that end untapped are settled by a timer (MouseDashGone). No hearts, 100 points, Close (MouseDashQuit), leaving
-- or dying ends the game with MouseDashOver.
--
-- Prizes are the arcade's: each milestone crossed is paid through ArcadeService.claimMilestones, once per UTC day
-- whichever game reaches it, and 100 points gives Arcade Legend there. This game's own record (best, the free run,
-- Mouser, the first run and kitten hint flags) lives in its own DataStore, STORE (key: the user id), not in the
-- profile, so it needed no save version step and no restart; older servers never read it. It is read on join (no
-- game starts before the read answers) and written when a game starts free and when one ends, at most once every
-- WRITE_GAP seconds, joined with what is stored (MouseDash.merge).
-- The Mouser title is kept as a flag in this save and shown in the window; the chat title waits (spec section 7)
-- until it is checked that an older server would not wipe a chosen one.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arcade = require(ReplicatedStorage.Shared.Arcade)
local ArcadeService = require(script.Parent.ArcadeService)
local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local LiveFlagService = require(script.Parent.LiveFlagService)
local MouseDash = require(ReplicatedStorage.Shared.MouseDash)
local MouseDashBoard = require(script.Parent.MouseDashBoard)
local Net = require(script.Parent.Net)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)
local Types = require(ReplicatedStorage.Shared.Types)

local MouseDashService = {}

local STORE = MouseDash.STORE .. (if RunService:IsStudio() then "_dev" else "")
local READ_WAITS = { 2, 5, 15, 60 }
local WRITE_WAITS = { 2, 5, 15 }
local WRITE_GAP = 7 -- seconds between two writes of one key
local MAX_RUN_ID = 2 ^ 30
local MAX_WAVES = 600 -- a game of 100 points can't need more waves than this
local TIMER_SLOP = 0.03 -- the timer looks a moment after a window's end
local CLOSED_TEXT = "Mouse Dash is closed for now"

type Run = {
	id: number,
	state: MouseDash.Run,
	paid: { number },
	free: boolean,
	tick: number, -- the timer in force; a newer one retires the old
	hinted: boolean,
}

local runs: { [Player]: Run } = {}
local saves: { [Player]: MouseDash.Save } = {}
local pending: { [number]: MouseDash.Save } = {}
local writing: { [number]: boolean } = {}
local leaving: { [number]: boolean } = {}
local nextRunId = 0
local rng = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function roll(): number
	return rng:NextNumber()
end

-- The allowance past a window's end: the pop reaches the player half a round trip late and their tap comes back
-- half a round trip later, so the whole round trip (GetNetworkPing, as Circles.latency reads it), capped at
-- CatchLatencyCapSeconds. A catch press takes half, since its circles are sent ahead of time; a pop is not.
local function slackOf(player: Player): number
	local ping = player:GetNetworkPing()
	if ping ~= ping then
		return 0
	end
	return math.clamp(ping, 0, Config.CatchLatencyCapSeconds)
end

local function store(): DataStore?
	if RunService:IsStudio() and not DataService.saves() then
		return nil -- Studio with no API access: the game forgets at the end of the test
	end
	return DataStoreService:GetDataStore(STORE)
end

-- Writes the player's newest save, at most once every WRITE_GAP seconds, trying again a few times. A lost write only
-- forgets a record or gives the day's free run again; milestones are not kept here.
local function queueSave(userId: number, save: MouseDash.Save)
	local where = store()
	if where == nil then
		return
	end
	pending[userId] = table.clone(save)
	if writing[userId] then
		return
	end
	writing[userId] = true
	task.spawn(function()
		local key = tostring(userId)
		while pending[userId] ~= nil do
			local value = pending[userId]
			pending[userId] = nil
			local ok = false
			for attempt = 1, #WRITE_WAITS + 1 do
				ok = pcall(function()
					(where :: DataStore):UpdateAsync(key, function(old: unknown)
						return MouseDash.merge(MouseDash.sanitize(old), MouseDash.sanitize(value))
					end)
				end)
				if ok then
					break
				end
				local wait = WRITE_WAITS[attempt]
				if wait == nil then
					break
				end
				task.wait(wait)
			end
			if not ok then
				warn("[MouseDashService] writing a save failed") -- only this: DataStore errors can carry ids
			end
			local waited = 0
			while waited < WRITE_GAP and not leaving[userId] do
				waited += task.wait(0.5)
			end
		end
		writing[userId] = nil
		leaving[userId] = nil
	end)
end

local function present(): { Leaderboards.Present }
	local out: { Leaderboards.Present } = {}
	for player, save in saves do
		if save.best > 0 and player.Parent == Players then
			table.insert(out, {
				userId = player.UserId,
				name = player.DisplayName,
				value = MouseDash.score(save.best, save.bestSeconds),
			})
		end
	end
	return out
end

local function stateOf(player: Player): MouseDash.State
	local save = saves[player]
	local today, legend = ArcadeService.today(player)
	return {
		loaded = save ~= nil and ArcadeService.loaded(player),
		best = if save ~= nil then save.best else 0,
		bestSeconds = if save ~= nil then save.bestSeconds else 0,
		today = today,
		legend = legend,
		mouser = save ~= nil and save.mouser,
		free = save ~= nil and MouseDash.freeToday(save, os.time()),
		firstRun = save ~= nil and not save.firstRunDone,
		top = MouseDashBoard.top(present(), player.UserId),
	}
end

local function sendState(player: Player)
	Net.fire(player, "MouseDashState", stateOf(player))
end

-- Reads `player`'s save when they join, trying again a few times; nothing read keeps the game shut for them.
local function load(player: Player)
	task.spawn(function()
		local where = store()
		if where == nil then
			saves[player] = MouseDash.fresh()
			sendState(player)
			return
		end
		local key = tostring(player.UserId)
		for attempt = 1, #READ_WAITS + 1 do
			local ok, raw = pcall(function()
				return (where :: DataStore):GetAsync(key)
			end)
			if player.Parent ~= Players then
				return
			end
			if ok then
				local save = MouseDash.sanitize(raw)
				saves[player] = save
				MouseDashBoard.note(player, save.best, save.bestSeconds)
				sendState(player)
				return
			end
			local wait = READ_WAITS[attempt]
			if wait == nil then
				break
			end
			task.wait(wait)
		end
		warn(
			"[MouseDashService] reading a save failed; that player's Mouse Dash stays shut this visit"
		)
	end)
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0
end

-- Ends `run`. `tell` false for a player who left (nothing to send).
local function finish(player: Player, run: Run, reason: MouseDash.Reason, tell: boolean)
	if runs[player] ~= run then
		return -- already over
	end
	runs[player] = nil
	run.tick += 1
	local state = run.state
	local seconds = MouseDash.seconds(state, serverNow())
	local save = saves[player]
	local newBest = false
	if save ~= nil then
		newBest = MouseDash.record(save, state.points, seconds, state.sawKitten)
		queueSave(player.UserId, save)
		if newBest then
			MouseDashBoard.note(player, save.best, save.bestSeconds)
		end
	end
	local win = state.points >= Config.ArcadeMaxPoints
	if win then
		ArcadeService.grantLegend(player)
	end
	if not OwnerTest.isOwner(player.UserId) then
		Telemetry.custom(player, "mouse_dash_run", state.points, {
			tostring(state.lost),
			tostring(seconds),
			if run.free then "free" else "paid",
			reason,
		})
	end
	if not tell then
		return
	end
	local today, legend = ArcadeService.today(player)
	local result: MouseDash.Result = {
		points = state.points,
		seconds = seconds,
		reason = reason,
		win = win,
		best = if save ~= nil then save.best else state.points,
		bestSeconds = if save ~= nil then save.bestSeconds else seconds,
		newBest = newBest,
		paid = table.clone(run.paid),
		today = today,
		legend = legend,
		mouser = save ~= nil and save.mouser,
	}
	Net.fire(player, "MouseDashOver", run.id, result)
	sendState(player)
end

local schedule: (player: Player, run: Run) -> ()

-- The timer's look at the run: the next wave when its time has come, else the windows that have ended.
local function step(player: Player, run: Run)
	if runs[player] ~= run then
		return
	end
	if player.Parent ~= Players or not alive(player) then
		finish(player, run, "quit", player.Parent == Players)
		return
	end
	local state = run.state
	local now = serverNow()
	if state.wave == nil then
		if now >= state.nextAt then
			if state.index >= MAX_WAVES then
				finish(player, run, "quit", true)
				return
			end
			local wave = MouseDash.wave(state, now, roll)
			local pops = table.create(#wave.pops)
			local kitten = false
			for index, pop in wave.pops do
				kitten = kitten or pop.kind == "kitten"
				pops[index] =
					{ hole = pop.hole, kind = pop.kind, upAt = pop.upAt, downAt = pop.downAt }
			end
			-- a player's first kitten ever comes with its one line hint
			local hint: string? = nil
			local save = saves[player]
			if kitten and not run.hinted and save ~= nil and not save.seenKitten then
				run.hinted = true
				hint = MouseDash.KITTEN_HINT
			end
			Net.fire(player, "MouseDashWave", run.id, wave.index, pops, hint)
		end
	else
		local index = state.wave.index
		local gone = MouseDash.settle(state, now, slackOf(player))
		if #gone > 0 then
			Net.fire(player, "MouseDashGone", run.id, index, gone, state.hearts)
		end
		local over = MouseDash.over(state)
		if over ~= nil then
			finish(player, run, over, true)
			return
		end
	end
	schedule(player, run)
end

-- Sets the one timer for the run's next moment (a wave's start or a window's end); a catch that ends a wave early
-- calls this again, which retires the timer before it.
schedule = function(player: Player, run: Run)
	run.tick += 1
	local tick = run.tick
	local wake = MouseDash.wakeAt(run.state, slackOf(player))
	task.delay(math.max(0, wake - serverNow()) + TIMER_SLOP, function()
		if runs[player] == run and run.tick == tick then
			step(player, run)
		end
	end)
end

local function onStart(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if not (LiveFlagService.on(Arcade.FLAG) and LiveFlagService.on(MouseDash.FLAG)) then
		Net.toast(player, CLOSED_TEXT, "warn")
		return
	end
	local save = saves[player]
	local loaded = save ~= nil and ArcadeService.loaded(player)
	local free = save ~= nil and MouseDash.freeToday(save, os.time())
	-- a free run spends no fish, so the trade fish freeze doesn't hold it up
	local busy = CatService.busyReason(player)
		or (if free then nil else TradeService.fishSpendBlocker(player))
	local running = runs[player] ~= nil or ArcadeService.running(player)
	local blocker = Arcade.startBlocker(profile.goldenFish, busy, running, loaded, free)
	if blocker ~= nil or save == nil then
		Net.toast(player, blocker or CLOSED_TEXT, "warn")
		return
	end
	if free then
		-- the free day is written at once so another server can't give it again
		MouseDash.useFree(save, os.time())
		queueSave(player.UserId, save)
	else
		if not GoldenFish.trySpend(profile, Config.ArcadeCostFish) then
			Net.toast(player, Arcade.startBlocker(0, nil, false, true) or CLOSED_TEXT, "warn")
			return
		end
		Telemetry.fishSink(player, profile, Config.ArcadeCostFish, "Gameplay", "mouse_dash")
		CafeService.sync(player)
	end
	nextRunId = nextRunId % MAX_RUN_ID + 1
	local now = serverNow()
	local run: Run = {
		id = nextRunId,
		state = MouseDash.begin(now, not save.firstRunDone),
		paid = {},
		free = free,
		tick = 0,
		hinted = false,
	}
	runs[player] = run
	Net.fire(player, "MouseDashBegan", run.id, run.state.hearts, run.state.nextAt)
	sendState(player)
	schedule(player, run)
end

-- One tap on `hole` while wave `index` is up. The client sends no time, score or kind.
local function onTap(player: Player, rawRun: unknown, rawIndex: unknown, rawHole: unknown)
	local runId = Guard.int(rawRun, 1, MAX_RUN_ID)
	local index = Guard.int(rawIndex, 1, MAX_WAVES)
	local hole = Guard.int(rawHole, 1, MouseDash.HOLES)
	if runId == nil or index == nil or hole == nil then
		return
	end
	local run = runs[player]
	if run == nil or run.id ~= runId then
		return
	end
	local state = run.state
	local before = state.points
	local tap = MouseDash.tap(state, index, hole, serverNow(), slackOf(player))
	if tap.outcome == "ignored" or tap.outcome == "dizzy" then
		return
	end
	local paid: { number } = {}
	if state.points > before then
		paid = ArcadeService.claimMilestones(player, before, state.points, "mousedash")
		for _, at in paid do
			table.insert(run.paid, at)
		end
	end
	Net.fire(
		player,
		"MouseDashJudged",
		run.id,
		index,
		tap,
		state.points,
		state.hearts,
		state.streak,
		paid,
		state.dizzyUntil
	)
	local over = MouseDash.over(state)
	if over ~= nil then
		finish(player, run, over, true)
	elseif tap.waveOver then
		schedule(player, run) -- the gap starts now, not at the window's end
	end
end

local function onQuit(player: Player, rawRun: unknown)
	local runId = Guard.int(rawRun, 1, MAX_RUN_ID)
	local run = runs[player]
	if runId == nil or run == nil or run.id ~= runId then
		return
	end
	finish(player, run, "quit", true)
end

-- Debug hook for the specs and Studio checks; ArcadeService asks through its otherGame.
function MouseDashService.running(player: Player): boolean
	return runs[player] ~= nil
end

function MouseDashService.start()
	ArcadeService.otherGame = MouseDashService.running
	Net.on("MouseDashStart", onStart)
	Net.on("MouseDashTap", onTap)
	Net.on("MouseDashQuit", onQuit)
	DataService.onLoaded:Connect(function(player: Player, _profile: Types.PlayerProfile)
		load(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		if writing[player.UserId] then
			leaving[player.UserId] = true
		end
		local run = runs[player]
		if run ~= nil then
			finish(player, run, "quit", false)
		end
		saves[player] = nil
	end)
	MouseDashBoard.start(function()
		for player in saves do
			if player.Parent == Players then
				sendState(player)
			end
		end
	end)
end

return MouseDashService
