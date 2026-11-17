--!strict
-- What the till's tip button shows, from the plot's display attributes and the cafe's layout (F61, data-model
-- section 12):
--   amount(count, total) -> number   the tips waiting, 0 unless TipPiles is above 0 and TipPilesAmount a positive
--                                    number (attribute values come in as `any`, so a wrong type reads 0)
--   TILL                             the till on the counter top in plot space, where the button floats: the
--                                    counter stands at Layout.plot.counter (0, 0, PlotDepth / 2 - 3) and the till
--                                    at x 0.7 to 1.7, 3 up
--   onPlot(offset, width?, depth?)   true for a point in plot space inside the box CollectTips accepts: the
--                                    server's WorldBuilder.inSafeZone box, front garden to yard and a stud wider
--   room(plot) -> (width, depth)     #4543: the room standing on the plot (its RoomWidth and RoomDepth attributes,
--                                    44 x 34 without them); till(depth) is TILL in that room (the counter moves
--                                    back with the back wall)
-- Plot space is the plot model's GetPivot() (WorldBuilder sets WorldPivot; -Z faces the street). No Theme, Format
-- or CFrame here, so the cloud test runner (no fonts, no CFrame) can load and test it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local World = Config.World
local HALF_W: number = World.PlotWidth / 2
local HALF_D: number = World.PlotDepth / 2
local TillTips = {}

TillTips.TILL = Vector3.new(1.2, 3, HALF_D - 3)

function TillTips.amount(count: any, total: any): number
	if type(count) ~= "number" or count <= 0 then
		return 0
	end
	if type(total) ~= "number" or total ~= total or total <= 0 or total == math.huge then
		return 0
	end
	return total
end

function TillTips.room(plot: Instance): (number, number)
	local width, depth = plot:GetAttribute("RoomWidth"), plot:GetAttribute("RoomDepth")
	if type(width) ~= "number" or type(depth) ~= "number" then
		return World.PlotWidth, World.PlotDepth
	end
	return width, depth
end

function TillTips.till(depth: number): Vector3
	return TillTips.TILL + Vector3.new(0, 0, depth - World.PlotDepth)
end

function TillTips.onPlot(offset: Vector3, width: number?, depth: number?): boolean
	local halfW = if width ~= nil then width / 2 else HALF_W
	local back = -HALF_D + (depth or World.PlotDepth)
	return math.abs(offset.X) <= halfW + 1
		and offset.Z >= -HALF_D - 1 - World.FrontGardenDepth
		and offset.Z <= back + 1 + World.YardDepth
end

return TillTips
