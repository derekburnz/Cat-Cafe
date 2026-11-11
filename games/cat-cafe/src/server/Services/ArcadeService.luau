--!strict
-- The Cat Arcade on the server (#3062; the rules are shared/Arcade). ArcadeStart checks the `arcade` switch, that the
-- player's arcade save is read, that no game is running, that they are in no catch, rescue or flight
-- (CatService.busyReason) and have no trade fish freeze (TradeService.fishSpendBlocker), then spends ArcadeCostFish
-- golden fish and sends the first block of circles (ArcadeBlock). Every press (ArcadePress) is stamped on arrival,
-- half the ping taken off, and judged by Circles.press with the arcade's windows, exactly as a catch's; a circle left
-- alone is a Miss at its deadline. Each judged circle goes back as ArcadeJudged with the points and any milestone it
-- paid (Payout.pay, once per UTC day each; shown in the window only, no toast, #3080). A block played through brings
-- the next at the step its points reached; the first Miss, 100 points, Close (ArcadeQuit), leaving or dying ends the
-- game with ArcadeOver. There is no arcade-specific bot check (Derek2 2026-11-10: "not worried about bots yet").
-- Each player's best, today's milestones and the Arcade Legend title live in their own DataStore, STORE (key: the
-- user id), not in the save, so the arcade needed no save version step and no restart (Derek2 2026-11-11). They are
-- read when the player joins (no game starts until the read answers) and written after each milestone and game, at
-- most once every WRITE_GAP seconds. The server's best is kept in memory and shown on the cabinet's prompt.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arcade = require(ReplicatedStorage.Shared.Arcade)
local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Circles = require(ReplicatedStorage.Shared.Circles)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Guard = require(script.Parent.Parent.Util.Guard)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local TradeService = require(script.Parent.TradeService)
local Types = require(ReplicatedStorage.Shared.Types)

local ArcadeService = {}

local STORE = "CatCafe_Arcade" .. (if RunService:IsStudio() then "_dev" else "")
local READ_WAITS = { 2, 5, 15, 60 } -- seconds before each further try at a join's read
local WRITE_WAITS = { 2, 5, 15 } -- and at a write
local WRITE_GAP = 7 -- seconds between two writes of one key (a DataStore key takes one write per 6 s)
local READY_SECONDS = 1.6 -- from Play to the first circle starting to shrink: the window's "Ready?"
local MAX_RUN_ID = 2 ^ 30
local MAX_BLOCKS = 100 -- a game of 100 points can't need more blocks than this
local CLOSED_TEXT = "The Cat Arcade is closed for now"

type Run = {
	id: number,
	block: number,
	attempt: Circles.Attempt?,
	points: number,
	circles: number, -- circles hit
	paid: { number },
}

local runs: { [Player]: Run } = {}
local saves: { [Player]: Arcade.Save } = {}
local pending: { [number]: Arcade.Save } = {} -- by user id: the newest save waiting for its write
local writing: { [number]: boolean } = {}
local serverBest = { points = 0, circles = 0, name = nil :: string? }
local nextRunId = 0
local rng = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function store(): DataStore?
	if RunService:IsStudio() and not DataService.saves() then
		return nil -- Studio with no API access: the arcade forgets at the end of the test
	end
	return DataStoreService:GetDataStore(STORE)
end

local function copy(save: Arcade.Save): Arcade.Save
	return {
		best = save.best,
		bestCircles = save.bestCircles,
		day = save.day,
		paid = table.clone(save.paid),
		legend = save.legend,
		runs = save.runs,
	}
end

-- Writes the player's newest save, at most once every WRITE_GAP seconds, trying again a few times. A lost write only
-- forgets a record or lets a milestone pay again on the player's next server the same day.
local function queueSave(userId: number, save: Arcade.Save)
	local where = store()
	if where == nil then
		return
	end
	pending[userId] = copy(save)
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
					(where :: DataStore):SetAsync(key, value)
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
				warn("[ArcadeService] writing an arcade save failed") -- only this: DataStore errors can carry ids
			end
			task.wait(WRITE_GAP)
		end
		writing[userId] = nil
	end)
end

local function stateOf(player: Player): Arcade.State
	local save = saves[player]
	return {
		loaded = save ~= nil,
		best = if save ~= nil then save.best else 0,
		bestCircles = if save ~= nil then save.bestCircles else 0,
		today = if save ~= nil then table.clone(Arcade.today(save, os.time())) else {},
		legend = save ~= nil and save.legend,
		serverBest = serverBest.points,
		serverCircles = serverBest.circles,
		serverName = serverBest.name,
	}
end

local function sendState(player: Player)
	Net.fire(player, "ArcadeState", stateOf(player))
end

-- The cabinet's prompt carries the server's best: "Cat Arcade · Best 61 (Sam)".
local function showServerBest()
	local text = Arcade.NAME
	if serverBest.points > 0 then
		text ..= " · Best " .. Arcade.words(serverBest.points, serverBest.circles)
		if serverBest.name ~= nil then
			text ..= " (" .. serverBest.name .. ")"
		end
	end
	for _, model in CollectionService:GetTagged(Arcade.TAG) do
		local prompt = model:FindFirstChild(Arcade.PROMPT, true)
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			(prompt :: ProximityPrompt).ObjectText = text
		end
	end
end

-- Reads `player`'s arcade save when they join, trying again a few times; nothing read keeps the arcade shut for them.
local function load(player: Player)
	task.spawn(function()
		local where = store()
		if where == nil then
			saves[player] = Arcade.fresh()
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
				saves[player] = Arcade.sanitize(raw, os.time())
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
			"[ArcadeService] reading an arcade save failed; that player's arcade stays shut this visit"
		)
	end)
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0
end

-- Ends `run`. `tell` false for a player who left (nothing to send).
local function finish(player: Player, run: Run, tell: boolean)
	if runs[player] ~= run then
		return -- already over
	end
	runs[player] = nil
	run.attempt = nil
	local save = saves[player]
	local newBest = false
	if save ~= nil then
		newBest = Arcade.record(save, run.points, run.circles)
		queueSave(player.UserId, save)
	end
	if Arcade.beats(run.points, run.circles, serverBest.points, serverBest.circles) then
		serverBest.points = run.points
		serverBest.circles = run.circles
		serverBest.name = player.DisplayName
		showServerBest()
	end
	local win = run.points >= Config.ArcadeMaxPoints
	Telemetry.custom(player, "arcade_run", run.points, {
		tostring(run.circles),
		if #run.paid > 0 then table.concat(run.paid, ",") else "none",
		if win then "win" else "over",
	})
	if not tell then
		return
	end
	local result: Arcade.Result = {
		points = run.points,
		circles = run.circles,
		win = win,
		best = if save ~= nil then save.best else run.points,
		bestCircles = if save ~= nil then save.bestCircles else run.circles,
		newBest = newBest,
		serverBest = serverBest.points,
		serverCircles = serverBest.circles,
		serverName = serverBest.name,
		paid = table.clone(run.paid),
		today = if save ~= nil then table.clone(Arcade.today(save, os.time())) else {},
		legend = save ~= nil and save.legend,
	}
	Net.fire(player, "ArcadeOver", run.id, result)
	sendState(player)
end

-- Pays the milestones a move from `before` to the run's points crossed that today has not paid yet.
local function payMilestones(player: Player, run: Run, before: number): { number }
	local save = saves[player]
	local profile = DataService.get(player)
	if save == nil or profile == nil then
		return {}
	end
	local due = Arcade.claim(save, before, run.points, os.time())
	if #due == 0 then
		return due
	end
	for _, at in due do
		local milestone = Arcade.milestoneAt(at)
		if milestone ~= nil then
			Payout.pay(player, profile, milestone.prize, "arcade_" .. tostring(at))
			table.insert(run.paid, at)
		end
	end
	CafeService.sync(player)
	queueSave(player.UserId, save)
	return due
end

local startBlock: (player: Player, run: Run, startsAt: number) -> ()

-- Sends the grades judged since `before` with the points after each, paying milestones, then ends the game on a
-- Miss or 100 points, or starts the next block when this one is played through.
local function settle(player: Player, run: Run, attempt: Circles.Attempt, before: number)
	for index = before, attempt.nextIndex - 1 do
		local grade = attempt.grades[index]
		local was = run.points
		if grade == "perfect" or grade == "good" then
			run.points = Arcade.add(run.points, grade)
			run.circles += 1
		end
		local paid = payMilestones(player, run, was)
		Net.fire(player, "ArcadeJudged", run.id, run.block, index, grade, run.points, paid)
		if run.points >= Config.ArcadeMaxPoints then
			finish(player, run, true)
			return
		end
	end
	if attempt.missed then
		finish(player, run, true)
	elseif Circles.isDone(attempt) and run.attempt == attempt then
		startBlock(player, run, serverNow() + Config.ArcadeBlockLeadIn)
	end
end

startBlock = function(player: Player, run: Run, startsAt: number)
	if runs[player] ~= run then
		return
	end
	if run.block >= MAX_BLOCKS then
		finish(player, run, true)
		return
	end
	run.block += 1
	local step = Arcade.step(run.points)
	local windows = Arcade.windows(step)
	local circles = Arcade.block(step, startsAt, function(): number
		return rng:NextNumber()
	end)
	local attempt = Circles.newAttempt(circles, windows)
	run.attempt = attempt
	Net.fire(
		player,
		"ArcadeBlock",
		run.id,
		run.block,
		circles,
		Circles.publicWindows(windows),
		run.points
	)
	-- a circle nobody presses is a Miss at its deadline, which ends the game
	task.spawn(function()
		while run.attempt == attempt do
			local deadline = Circles.nextDeadline(attempt)
			if deadline == nil then
				return
			end
			task.wait(math.max(0, deadline - serverNow()) + 0.05)
			if run.attempt ~= attempt then
				return
			end
			if player.Parent ~= Players or not alive(player) then
				finish(player, run, player.Parent == Players)
				return
			end
			local before = attempt.nextIndex
			Circles.expire(attempt, serverNow())
			if attempt.nextIndex > before then
				settle(player, run, attempt, before)
			end
		end
	end)
end

local function onStart(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if not LiveFlagService.on(Arcade.FLAG) then
		Net.toast(player, CLOSED_TEXT, "warn")
		return
	end
	local busy = CatService.busyReason(player) or TradeService.fishSpendBlocker(player)
	local blocker =
		Arcade.startBlocker(profile.goldenFish, busy, runs[player] ~= nil, saves[player] ~= nil)
	if blocker ~= nil then
		Net.toast(player, blocker, "warn")
		return
	end
	if not GoldenFish.trySpend(profile, Config.ArcadeCostFish) then
		Net.toast(player, Arcade.startBlocker(0, nil, false, true) or CLOSED_TEXT, "warn")
		return
	end
	Telemetry.fishSink(player, profile, Config.ArcadeCostFish, "Gameplay", "arcade")
	CafeService.sync(player)
	nextRunId = nextRunId % MAX_RUN_ID + 1
	local run: Run =
		{ id = nextRunId, block = 0, attempt = nil, points = 0, circles = 0, paid = {} }
	runs[player] = run
	startBlock(player, run, serverNow() + READY_SECONDS)
end

-- One press for circle `index` of block `block`. The client sends no time: the press is stamped on arrival and half
-- the player's ping (capped) is taken off. Out-of-order, repeated, early and old-block presses are ignored.
local function onPress(player: Player, rawRun: unknown, rawBlock: unknown, rawIndex: unknown)
	local runId = Guard.int(rawRun, 1, MAX_RUN_ID)
	local block = Guard.int(rawBlock, 1, MAX_BLOCKS)
	local index = Guard.int(rawIndex, 1, Arcade.BLOCK)
	if runId == nil or block == nil or index == nil then
		return
	end
	local run = runs[player]
	if run == nil or run.id ~= runId or run.block ~= block then
		return
	end
	local attempt = run.attempt
	if attempt == nil then
		return
	end
	local arrival = serverNow()
	local pressTime = arrival - Circles.latency(player:GetNetworkPing())
	local before = attempt.nextIndex
	Circles.press(attempt, index, pressTime, arrival)
	if attempt.nextIndex > before then
		settle(player, run, attempt, before)
	end
end

local function onQuit(player: Player, rawRun: unknown)
	local runId = Guard.int(rawRun, 1, MAX_RUN_ID)
	local run = runs[player]
	if runId == nil or run == nil or run.id ~= runId then
		return
	end
	finish(player, run, true)
end

-- Debug hooks for the specs and Studio checks.
function ArcadeService.running(player: Player): boolean
	return runs[player] ~= nil
end

function ArcadeService.start()
	Net.on("ArcadeStart", onStart)
	Net.on("ArcadePress", onPress)
	Net.on("ArcadeQuit", onQuit)
	DataService.onLoaded:Connect(function(player: Player, _profile: Types.PlayerProfile)
		load(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local run = runs[player]
		if run ~= nil then
			finish(player, run, false)
		end
		saves[player] = nil
	end)
	CollectionService:GetInstanceAddedSignal(Arcade.TAG):Connect(function()
		task.defer(showServerBest)
	end)
	showServerBest()
end

return ArcadeService
