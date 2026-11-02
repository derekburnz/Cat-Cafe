--!strict
-- The Rescue Rally weekend on this server (F101, rescue-rally.md; the rules are shared/Rally). One bar per server,
-- in memory: a server restart starts it again at lap 1.
-- Points come only from the server's own events, never a remote: CatService scores a check-in (1, a rescued cat's
-- 3), BaitService a tame (1) and RescueService each Team Rescue helper (3), through `score`. Each point goes to every
-- client as RallyPoint(userId, amount) for the pops. A lap's goal is fixed at its first point (review N326); passing a
-- step pays every player in the server who scored RallyMinPoints this lap (Rally.pays, at most RallyMaxLaps laps a
-- weekend, kept in the save) with one toast, and the full bar starts the next lap. RallyState goes to a player on
-- join, to everyone at each step, lap, start and end, and at most every RallyStateSeconds while points come in.
-- While the Rally runs the Town Square shows its bunting and board (WorldBuilder.setRally). Analytics: rally_step
-- (value the players in the server; the step's share, the lap, the players paid) and rally_points (value the
-- player's points this Rally on this server; their laps paid), when the Rally ends or they leave.
-- Nothing here is sold for Robux, and nothing skips or speeds the bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Rally = require(ReplicatedStorage.Shared.Rally)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RallyService = {}

local CHECK_SECONDS = 1

type Bar = {
	active: boolean,
	weekend: number,
	lap: number,
	goal: number,
	points: number,
	endsAt: number,
	startsAt: number,
}

local bar: Bar =
	{ active = false, weekend = -1, lap = 0, goal = 0, points = 0, endsAt = 0, startsAt = 0 }
local myPoints: { [Player]: number } = {} -- this lap
local rallyPoints: { [Player]: number } = {} -- this Rally on this server, for rally_points
local countedLap: { [Player]: number } = {} -- the lap of this Rally whose prizes counted toward the save's laps
local changed = false -- points came in since RallyState last went out
local forced: boolean? = nil -- Debug's override of Config.RallyForce

local function force(): boolean
	if forced ~= nil then
		return forced
	end
	return Config.RallyForce == true
end

local function stateFor(player: Player, now: number): Types.RallyState
	local profile = DataService.get(player)
	local counted = countedLap[player] == bar.lap
	local lapsPaid, lapsDone = 0, false
	if profile ~= nil then
		lapsDone = Rally.lapsDone(profile.rally, now, counted)
		lapsPaid = profile.rally.laps
	end
	return {
		active = bar.active,
		endsAt = bar.endsAt,
		startsAt = bar.startsAt,
		lap = if bar.active then bar.lap else 0,
		goal = if bar.active then bar.goal else 0,
		points = if bar.active then bar.points else 0,
		myPoints = if bar.active then myPoints[player] or 0 else 0,
		lapsPaid = lapsPaid,
		lapsDone = bar.active and lapsDone,
	}
end

local function send(player: Player)
	if DataService.get(player) == nil then
		return
	end
	Net.fire(player, "RallyState", stateFor(player, os.time()))
end

local function sendAll()
	changed = false
	for _, player in DataService.loadedPlayers() do
		send(player)
	end
end

-- A lap's goal is set as it starts and set again at its first point (review N326): a server that starts its Rally
-- before anyone has joined, or a lap that starts in an empty moment, still gets 30 a player for who is playing. From
-- the first point on it is fixed, so a player leaving does not move it.
local function startLap(lap: number)
	bar.lap = lap
	bar.goal = Rally.goal(#Players:GetPlayers())
	bar.points = 0
	table.clear(myPoints)
end

-- Logs a player's rally_points once, when the Rally ends or they leave, if they scored.
local function logPoints(player: Player)
	local points = rallyPoints[player]
	rallyPoints[player] = nil
	if points == nil or points <= 0 then
		return
	end
	local profile = DataService.get(player)
	local laps = if profile ~= nil then profile.rally.laps else 0
	Telemetry.custom(player, "rally_points", points, { tostring(laps) })
end

local function begin(now: number)
	bar.active = true
	bar.weekend = Rally.weekend(now)
	table.clear(countedLap)
	table.clear(rallyPoints)
	startLap(1)
	WorldBuilder.setRally(true)
end

local function finish()
	for _, player in Players:GetPlayers() do
		logPoints(player)
	end
	bar.active = false
	bar.lap, bar.goal, bar.points = 0, 0, 0
	table.clear(myPoints)
	table.clear(countedLap)
	WorldBuilder.setRally(false)
end

-- Starts or ends the Rally as the clock (or RallyForce) says, and keeps its times; true when anything changed.
local function update(now: number): boolean
	local active = Rally.isActive(now, force())
	local endsAt, startsAt = Rally.endsAt(now, force()), Rally.startsAt(now)
	local moved = endsAt ~= bar.endsAt or startsAt ~= bar.startsAt
	bar.endsAt, bar.startsAt = endsAt, startsAt
	if active and bar.active and Rally.weekend(now) ~= bar.weekend then
		finish() -- a forced Rally ran into the next weekend's: that one starts fresh
	end
	if active and not bar.active then
		begin(now)
		return true
	elseif not active and bar.active then
		finish()
		return true
	end
	return moved
end

-- Pays step `index` to every player in the server who earned it; returns how many were paid.
local function payStep(index: number, now: number): number
	local step = Catalog.rallySteps[index]
	local paidCount = 0
	for _, player in DataService.loadedPlayers() do
		local profile = DataService.get(player)
		if profile ~= nil then
			local counted = countedLap[player] == bar.lap
			if Rally.pays(profile.rally, now, myPoints[player] or 0, counted) then
				countedLap[player] = bar.lap
				local paid = Payout.pay(player, profile, step.prize, "rally")
				if #paid > 0 then
					Net.toast(player, "Rescue Rally: " .. table.concat(paid, ", "), "good")
				end
				CafeService.sync(player)
				paidCount += 1
			end
		end
	end
	return paidCount
end

-- Scores `kind` of play (Config.RallyPoints: "checkIn", "tame", "rescue", "teamRescue") for `player` while a Rally
-- runs. Called by the services that saw it happen; never from a remote.
function RallyService.score(player: Player, kind: string)
	local amount = Rally.pointsFor(kind)
	if
		not bar.active
		or amount <= 0
		or player.Parent ~= Players
		or DataService.get(player) == nil
	then
		return
	end
	local now = os.time()
	myPoints[player] = (myPoints[player] or 0) + amount
	rallyPoints[player] = (rallyPoints[player] or 0) + amount
	local before = bar.points
	if before == 0 then
		bar.goal = Rally.goal(#Players:GetPlayers())
	end
	bar.points += amount
	Net.fireAll("RallyPoint", player.UserId, amount)
	local crossed = Rally.stepsCrossed(before, bar.points, bar.goal)
	if #crossed == 0 then
		changed = true
		return
	end
	for _, index in crossed do
		local paidCount = payStep(index, now)
		local share = math.floor(Catalog.rallySteps[index].share * 100 + 0.5)
		Telemetry.custom(
			player,
			"rally_step",
			#Players:GetPlayers(),
			{ tostring(share), tostring(bar.lap), tostring(paidCount) }
		)
	end
	if bar.points >= bar.goal then
		sendAll() -- the full bar first, so each client sees the last step
		startLap(bar.lap + 1)
	end
	sendAll()
end

function RallyService.start()
	update(os.time())
	DataService.onLoaded:Connect(function(player: Player)
		send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		logPoints(player)
		myPoints[player] = nil
		countedLap[player] = nil
	end)
	task.spawn(function()
		local sinceCheck = 0
		while true do
			task.wait(Config.RallyStateSeconds)
			sinceCheck += Config.RallyStateSeconds
			if sinceCheck >= CHECK_SECONDS then
				sinceCheck = 0
				if update(os.time()) then
					sendAll()
				end
			end
			if changed then
				sendAll()
			end
		end
	end)
end

-- Studio-only test hooks (Debug.rally).
-- Turns the forced Rally on or off (nil goes back to Config.RallyForce) and sends the state.
function RallyService.debugForce(on: boolean?)
	forced = on
	update(os.time())
	sendAll()
end

-- Scores `count` check-ins for the player as if they played, through the same steps and prizes.
function RallyService.debugPoints(player: Player, count: number)
	for _ = 1, math.clamp(math.floor(count), 0, 1000) do
		RallyService.score(player, "checkIn")
	end
end

-- Sets the player's laps paid this weekend and sends the state.
function RallyService.debugLaps(player: Player, profile: Types.PlayerProfile, laps: number)
	Rally.settle(profile.rally, os.time())
	profile.rally.laps = math.clamp(math.floor(laps), 0, Config.RallyMaxLaps)
	send(player)
end

-- A line for the Studio command bar.
function RallyService.debugSummary(player: Player): string
	local state = stateFor(player, os.time())
	return string.format(
		"active=%s lap=%d points=%d/%d mine=%d lapsPaid=%d lapsDone=%s",
		tostring(state.active),
		state.lap,
		state.points,
		state.goal,
		state.myPoints,
		state.lapsPaid,
		tostring(state.lapsDone)
	)
end

return RallyService
