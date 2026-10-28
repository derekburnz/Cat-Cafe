--!strict
-- Where a cafe's working cats sleep at night (F79, data-model section 12c), read off the art (Model-Agent #511): the
-- two cat trees' Sleep_Top and Sleep_Shelf, every placed decor piece's Sleep_<k> (the Cat Tree Tower's two) and the
-- cat beds of the owner's tier (WorldBuilder.setDressing). Each spot has the way up it from the floor: its piece's
-- Foot, projected onto the floor, then the hop chain (Bedtime.hopChain) through the piece's Hop_ and Sleep points.
-- Pure rules in shared/Bedtime; BedtimeService walks the cats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bedtime = require(ReplicatedStorage.Shared.Bedtime)
local Layout = require(script.Parent.Layout)
local WorldBuilder = require(script.Parent.WorldBuilder)

local SleepSpots = {}

-- The way between the floor and a place: `foot` on the floor where the climb starts, then `hops` from there up,
-- the last one the place itself. No hops for a place on the floor, whose foot is the place.
export type Route = { foot: CFrame, hops: { CFrame } }
-- A sleep spot: its id (Bedtime's spot ids), where the cat lies (its pivot, facing the LookVector) and its route.
export type Spot = { id: string, at: CFrame, foot: CFrame, hops: { CFrame } }

SleepSpots.SAME = 0.3 -- studs apart at which a station and a sleep spot are the same place (an entertainer's tree top)
SleepSpots.RAISED = 0.5 -- studs over the floor from which a station is up on something
SleepSpots.STEP_OFF = 2.5 -- studs in front of a raised station without its own route (the counter) to hop down to

local function onFloor(cframe: CFrame, floorY: number): CFrame
	return cframe - Vector3.new(0, cframe.Y - floorY, 0)
end

-- The Sleep, Hop_ and Foot attachments on a piece of furniture, by name, as world CFrames.
local function points(model: Instance): { [string]: CFrame }
	local found: { [string]: CFrame } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") then
			local name = descendant.Name
			if name == "Foot" or name:match("^Sleep") ~= nil or name:match("^Hop_") ~= nil then
				found[name] = (descendant :: Attachment).WorldCFrame
			end
		end
	end
	return found
end

-- The spot `id` on a piece with `found` points, lying at the point `target`; nil when the piece has no such point.
-- A piece without a Foot is climbed from the floor under the target.
local function spotOn(
	id: string,
	found: { [string]: CFrame },
	target: string,
	floorY: number
): Spot?
	local at: CFrame? = found[target]
	if at == nil then
		return nil
	end
	local heights: { [string]: number } = {}
	for name, cframe in found do
		if name ~= "Foot" then
			heights[name] = cframe.Y - floorY
		end
	end
	local hops: { CFrame } = {}
	for _, name in Bedtime.hopChain(heights, target) do
		table.insert(hops, found[name])
	end
	return { id = id, at = at, foot = onFloor(found.Foot or at, floorY), hops = hops }
end

-- The spot in `spots` at `station`, the same place within SAME studs (an entertainer's tree top), or nil.
function SleepSpots.at(spots: { Spot }, station: CFrame): Spot?
	for _, spot in spots do
		if (spot.at.Position - station.Position).Magnitude <= SleepSpots.SAME then
			return spot
		end
	end
	return nil
end

-- The way between the floor and a station: an entertainer's station on its cat tree's top takes that spot's route
-- (`trees`, SleepSpots.trees); any other raised station (the barista on the counter) is one hop from STEP_OFF studs
-- in front of it; a station on the floor needs no hops.
function SleepSpots.stationRoute(plot: WorldBuilder.Plot, station: CFrame, trees: { Spot }): Route
	local tree = SleepSpots.at(trees, station)
	if tree ~= nil then
		return { foot = tree.foot, hops = tree.hops }
	end
	local floorY = plot.cframe.Y
	if station.Y - floorY > SleepSpots.RAISED then
		local front = Vector3.new(station.LookVector.X, 0, station.LookVector.Z)
		local step = if front.Magnitude > 0.05
			then front.Unit * SleepSpots.STEP_OFF
			else Vector3.zero
		return { foot = onFloor(station + step, floorY), hops = { station } }
	end
	return { foot = onFloor(station, floorY), hops = {} }
end

-- The cat trees' spots (tree_<n>_top and tree_<n>_shelf). A tree whose art has no Sleep_Top (the graybox) offers
-- its entertainer station's anchor as the top, one hop up from in front of it.
function SleepSpots.trees(plot: WorldBuilder.Plot): { Spot }
	local floorY = plot.cframe.Y
	local spots: { Spot } = {}
	for n, station in Bedtime.TREES do
		local furniture: Model? = plot.spotFurniture[station]
		local found = if furniture ~= nil then points(furniture) else {}
		local top = spotOn("tree_" .. n .. "_top", found, "Sleep_Top", floorY)
		local anchor: BasePart? = plot.spots[station]
		if top == nil and anchor ~= nil then
			local route = SleepSpots.stationRoute(plot, anchor.CFrame, {})
			top = {
				id = "tree_" .. n .. "_top",
				at = anchor.CFrame,
				foot = route.foot,
				hops = route.hops,
			}
		end
		if top ~= nil then
			table.insert(spots, top)
		end
		local shelf = spotOn("tree_" .. n .. "_shelf", found, "Sleep_Shelf", floorY)
		if shelf ~= nil then
			table.insert(spots, shelf)
		end
	end
	return spots
end

-- Every sleep spot in the cafe now, in fill order (Bedtime.order): the cat trees, the placed decor with Sleep_<k>
-- points as decor_<its decor spot>_<k>, then the beds standing in Dressing. A bed the owner's tier has but whose
-- art is not in ReplicatedStorage.Assets is its Layout point on the floor.
function SleepSpots.list(plot: WorldBuilder.Plot): { Spot }
	local floorY = plot.cframe.Y
	local byId: { [string]: Spot } = {}
	for _, spot in SleepSpots.trees(plot) do
		byId[spot.id] = spot
	end
	for _, piece in plot.decor:GetChildren() do
		local decorAt = piece:GetAttribute("DecorAt")
		if type(decorAt) ~= "string" then
			continue
		end
		local found = points(piece)
		local k = 1
		while (found["Sleep_" .. k] :: CFrame?) ~= nil do
			local spot = spotOn("decor_" .. decorAt .. "_" .. k, found, "Sleep_" .. k, floorY)
			if spot ~= nil then
				byId[spot.id] = spot
			end
			k += 1
		end
	end
	local tier = plot.model:GetAttribute("Tier")
	for _, bed in Layout.plot.beds do
		local model = plot.dressing:FindFirstChild(bed.id)
		local spot = if model ~= nil then spotOn(bed.id, points(model), "Sleep", floorY) else nil
		if spot == nil and type(tier) == "number" and tier >= bed.tier then
			local at = plot.cframe
				* CFrame.new(bed.x, bed.y, bed.z)
				* CFrame.Angles(0, math.rad(bed.rotY), 0)
			spot = { id = bed.id, at = at, foot = onFloor(at, floorY), hops = {} }
		end
		if spot ~= nil then
			byId[bed.id] = spot
		end
	end
	local ids: { string } = {}
	for id in byId do
		table.insert(ids, id)
	end
	local spots: { Spot } = {}
	for _, id in Bedtime.order(ids) do
		table.insert(spots, byId[id])
	end
	return spots
end

-- The spot `id` in `spots`, or nil once it is gone (a decor cat tree put away).
function SleepSpots.find(spots: { Spot }, id: string): Spot?
	for _, spot in spots do
		if spot.id == id then
			return spot
		end
	end
	return nil
end

return SleepSpots
