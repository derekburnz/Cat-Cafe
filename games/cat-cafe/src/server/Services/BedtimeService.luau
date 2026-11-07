--!strict
-- Bedtime (F79, data-model section 12c): at night start each cafe's working cats get up from their stations, best
-- rating first and BedtimeStaggerSeconds apart, and walk to the cat trees, the decor cat trees and the beds
-- (World/SleepSpots, in Bedtime's fill order), hop up and sleep there; at sunrise they get up, walk back and sit at
-- their stations in their outfits again. Cats past the last spot doze at their stations as before. An entertainer
-- whose station is its cat tree's top keeps that spot and only lies down. Cats built after dark are built asleep by
-- CafeService and walk back at sunrise like the rest. The walk is cosmetic: income never depends on it.
-- Roblox terms: PathfindingService works out a walkable route round the tables and furniture as waypoints on the
-- floor. #2050 (Derek2 on live: cats "teleport part by part really quick away"): the server no longer steps the
-- anchored cat along its trip every frame, whose many parts reached clients one by one. It works the trip out once
-- (Bedtime.TripPoint, the hops and the path's waypoints), sets it on the cat (BedTripRoute, BedTripAt, BedTripSpeed,
-- BedTripHop, BedTripTo), leaves the model where it is and pivots it once onto BedTripTo when the trip's time is up;
-- each client walks it meanwhile (Animation's Effects). Without that, the cat appears at the end of its trip.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Bedtime = require(ReplicatedStorage.Shared.Bedtime)
local CafeService = require(script.Parent.CafeService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SleepSpots = require(script.Parent.Parent.World.SleepSpots)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local BedtimeService = {}

-- A cat's size on the way; it walks round anything it cannot step over rather than jumping (the hops are ours).
local AGENT = { AgentRadius = 0.8, AgentHeight = 2, AgentCanJump = false }

local trips: { [string]: number } = {} -- cat uid -> its latest trip, so a newer trip stops an older one
local tripCount = 0

local function newTrip(uid: string): number
	tripCount += 1
	trips[uid] = tripCount
	return tripCount
end

local function endTrip(uid: string, trip: number)
	if trips[uid] == trip then
		trips[uid] = nil
	end
end

-- The trip from `start` (where the cat is, on the top of `from`) down `from`'s hops to its foot, across the floor
-- to `to`'s foot along a PathfindingService path when there is one (its waypoints held to the floor's height, else
-- straight there) and up `to`'s hops.
local function plan(
	start: Vector3,
	from: SleepSpots.Route,
	to: SleepSpots.Route
): { Bedtime.TripPoint }
	local points: { Bedtime.TripPoint } = { { at = start, hop = false } }
	for i = #from.hops - 1, 1, -1 do
		table.insert(points, { at = from.hops[i].Position, hop = true })
	end
	if #from.hops > 0 then
		table.insert(points, { at = from.foot.Position, hop = true })
	end
	local goal = to.foot.Position
	local path = PathfindingService:CreatePath(AGENT)
	local computed = pcall(function()
		path:ComputeAsync(points[#points].at, goal)
	end)
	if computed and path.Status == Enum.PathStatus.Success then
		for i, waypoint in path:GetWaypoints() do
			if i > 1 then
				local p = waypoint.Position
				table.insert(points, { at = Vector3.new(p.X, goal.Y, p.Z), hop = false })
			end
		end
	end
	table.insert(points, { at = goal, hop = false })
	for _, point in to.hops do
		table.insert(points, { at = point.Position, hop = true })
	end
	return points
end

-- Sets the trip on `model` for the clients to walk, from `startsAt` (server time), ending on `ends`. Returns its
-- seconds, at most BedtimeTimeoutSeconds.
local function setTrip(
	model: Model,
	points: { Bedtime.TripPoint },
	startsAt: number,
	ends: CFrame
): number
	model:SetAttribute("BedTripRoute", Bedtime.encodeTrip(points))
	model:SetAttribute("BedTripSpeed", Config.CafeCatWalkSpeed)
	model:SetAttribute("BedTripHop", Config.HopSeconds)
	model:SetAttribute("BedTripTo", ends)
	model:SetAttribute("BedTripAt", startsAt)
	return math.min(
		Bedtime.tripSeconds(points, Config.CafeCatWalkSpeed, Config.HopSeconds),
		Config.BedtimeTimeoutSeconds
	)
end

local function clearTrip(model: Model)
	model:SetAttribute("BedTripAt", nil)
	model:SetAttribute("BedTripRoute", nil)
	model:SetAttribute("BedTripTo", nil)
end

-- The working cat `uid` gets up from its station `station` and goes to sleep on `spot`, or just lies down there when
-- it is already on it; a sunrise before its turn keeps it at its station. The trip takes its walking time (at most
-- BedtimeTimeoutSeconds), then the cat is on the spot; a newer trip, or the model going (the cat moved or sold, the
-- owner gone), ends it where the model is.
local function toBed(
	player: Player,
	uid: string,
	station: CFrame,
	spot: SleepSpots.Spot,
	trip: number
)
	if trips[uid] ~= trip then
		return
	end
	local plot = PlotService.get(player)
	if not ClockService.isNight() then
		-- the sun came up before this cat's turn: it stays at its station and gives up its spot
		local seated = if plot ~= nil then plot.cats:FindFirstChild(uid) else nil
		if seated ~= nil then
			seated:SetAttribute("SleepSpot", nil)
		end
		endTrip(uid, trip)
		return
	end
	local existing = if plot ~= nil then plot.cats:FindFirstChild(uid) else nil
	if existing ~= nil and existing:GetAttribute("Bedtime") == true then
		-- rebuilt asleep on a spot of its own during the stagger (its slot changed after dark): it stays there
		endTrip(uid, trip)
		return
	end
	local here = (spot.at.Position - station.Position).Magnitude <= SleepSpots.SAME
	local model = CafeService.bedtimeBody(player, uid, spot.id, not here)
	if plot == nil or model == nil then
		endTrip(uid, trip)
		return
	end
	local current = function(): boolean
		return trips[uid] == trip and (model.Parent :: Instance?) ~= nil
	end
	if not here then
		local points = plan(
			station.Position,
			SleepSpots.stationRoute(plot, station, SleepSpots.trees(plot)),
			spot
		)
		if not current() then
			endTrip(uid, trip)
			return
		end
		local startsAt = Workspace:GetServerTimeNow() + Config.BedtimeStretchSeconds
		local seconds = setTrip(model, points, startsAt, spot.at)
		task.wait(math.max(0, startsAt - Workspace:GetServerTimeNow()) + seconds)
	end
	if current() then
		model:PivotTo(spot.at)
		clearTrip(model)
		model:SetAttribute("Asleep", true)
	end
	endTrip(uid, trip)
end

-- The working cat `uid` on `model` wakes on its sleep spot (or wherever its trip left it), stretches and goes back to
-- its station, where CafeService sits it down in its outfit again, after the trip's walking time (at most
-- BedtimeTimeoutSeconds).
local function toStation(player: Player, uid: string, model: Model, trip: number)
	if trips[uid] ~= trip or model.Parent == nil then
		return
	end
	local plot = PlotService.get(player)
	local spotId = model:GetAttribute("SpotId")
	local anchor = if plot ~= nil and type(spotId) == "string" then plot.spots[spotId] else nil
	if plot == nil or anchor == nil then
		CafeService.endBedtime(player, uid)
		endTrip(uid, trip)
		return
	end
	local current = function(): boolean
		return trips[uid] == trip and (model.Parent :: Instance?) ~= nil
	end
	clearTrip(model) -- a bedtime trip still showing ends where the model is
	model:SetAttribute("Asleep", false)
	local now = Workspace:GetServerTimeNow()
	model:SetAttribute("StretchAt", now)
	local sleepSpot = model:GetAttribute("SleepSpot")
	local spot = if type(sleepSpot) == "string"
		then SleepSpots.find(SleepSpots.list(plot), sleepSpot)
		else nil
	local station = anchor.CFrame
	local at = model:GetPivot()
	local onSpot = spot ~= nil and (at.Position - spot.at.Position).Magnitude <= SleepSpots.SAME
	local from: SleepSpots.Route = if spot ~= nil and onSpot
		then spot
		else { foot = at - Vector3.new(0, at.Y - plot.cframe.Y, 0), hops = {} }
	if (at.Position - station.Position).Magnitude > SleepSpots.SAME then
		local points =
			plan(at.Position, from, SleepSpots.stationRoute(plot, station, SleepSpots.trees(plot)))
		if not current() then
			endTrip(uid, trip)
			return
		end
		local startsAt = now + Config.BedtimeStretchSeconds
		local seconds = setTrip(model, points, startsAt, station)
		task.wait(math.max(0, startsAt - Workspace:GetServerTimeNow()) + seconds)
	else
		task.wait(Config.BedtimeStretchSeconds)
	end
	if current() then
		CafeService.endBedtime(player, uid)
	end
	endTrip(uid, trip)
end

-- The working cats in `plot` that are in `profile`, best rating first, with their models.
local function workers(
	plot: WorldBuilder.Plot,
	profile: Types.PlayerProfile
): ({ Types.CatInstance }, { [string]: Model })
	local list: { Types.CatInstance } = {}
	local models: { [string]: Model } = {}
	for _, child in plot.cats:GetChildren() do
		local uid = child:GetAttribute("Uid")
		local instance = if type(uid) == "string" then profile.cats[uid] else nil
		if instance ~= nil and instance.spotId ~= nil and child:IsA("Model") then
			table.insert(list, instance)
			models[instance.uid] = child :: Model
		end
	end
	table.sort(list, CatStats.betterFor(profile.tier))
	return list, models
end

-- Night start: every working cat with a spot goes to bed, BedtimeStaggerSeconds after the one before. Spots are
-- claimed (SleepSpot) at once, so a cat built in the meantime (CafeService) takes another.
local function goToBed(player: Player)
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return
	end
	local spots = SleepSpots.list(plot)
	local ids: { string } = {}
	for _, spot in spots do
		table.insert(ids, spot.id)
	end
	local list, models = workers(plot, profile)
	local uids: { string } = {}
	local held: { [string]: string } = {}
	for _, instance in list do
		table.insert(uids, instance.uid)
		local model = models[instance.uid]
		local claimed = model:GetAttribute("SleepSpot")
		local tree = SleepSpots.at(spots, model:GetPivot())
		if type(claimed) == "string" then
			held[instance.uid] = claimed
		elseif tree ~= nil then
			held[instance.uid] = tree.id -- an entertainer on its cat tree's top sleeps where it is
		end
	end
	local plan = Bedtime.assign(uids, ids, held)
	local n = 0
	for _, uid in uids do
		local spotId = plan[uid]
		local model = models[uid]
		local spot = if spotId ~= nil then SleepSpots.find(spots, spotId) else nil
		if spot == nil or model:GetAttribute("Bedtime") == true then
			continue -- no spot left, or already asleep (built after dark)
		end
		model:SetAttribute("SleepSpot", spot.id)
		task.delay(
			Config.BedtimeStaggerSeconds * n,
			toBed,
			player,
			uid,
			model:GetPivot(),
			spot,
			newTrip(uid)
		)
		n += 1
	end
end

-- Sunrise: every cat on a bedtime trip or asleep goes back to its station, best rating first, staggered the same.
local function getUp(player: Player)
	local plot = PlotService.get(player)
	local profile = DataService.get(player)
	if plot == nil or profile == nil then
		return
	end
	local list, models = workers(plot, profile)
	local n = 0
	for _, instance in list do
		local model = models[instance.uid]
		if model:GetAttribute("Bedtime") ~= true then
			continue
		end
		task.delay(
			Config.BedtimeStaggerSeconds * n,
			toStation,
			player,
			instance.uid,
			model,
			newTrip(instance.uid)
		)
		n += 1
	end
end

function BedtimeService.start()
	ClockService.changed:Connect(function(phase: Types.ClockPhase)
		for _, player in DataService.loadedPlayers() do
			if phase == "night" then
				goToBed(player)
			else
				getUp(player)
			end
		end
	end)
end

return BedtimeService
