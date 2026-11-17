--!strict
-- #4543: watches your own cafe's room size (RoomWidth and RoomDepth on your plot, set by the server's cafeGrows) and,
-- when a rank up makes it bigger, tells the Rank Up card to show "Your cafe grew!" for that tier
-- (UI/Components/CafeGrewLogic). The first size read after joining or moving plot is only recorded, so joining with a
-- grown cafe shows nothing. Client only; it sends nothing.
local CafeGrewLogic = require(script.Parent.Parent.UI.Components.CafeGrewLogic)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local CafeGrewController = {}

local TICK_SECONDS = 0.5

local lastPlot: Model? = nil
local lastWidth = 0
local lastDepth = 0

local function tick()
	local state = UIController.state
	local plot = UIController.ownPlot()
	if state == nil or plot == nil then
		lastPlot = nil
		return
	end
	local width, depth = CafeGrewLogic.size(
		plot:GetAttribute(CafeGrewLogic.WIDTH_ATTRIBUTE),
		plot:GetAttribute(CafeGrewLogic.DEPTH_ATTRIBUTE)
	)
	if plot ~= lastPlot then
		lastPlot = plot
	elseif
		CafeGrewLogic.grew(lastWidth, lastDepth, width, depth) and type(state.tier) == "number"
	then
		UI.cafeGrew(state.tier)
	end
	lastWidth, lastDepth = width, depth
end

function CafeGrewController.start()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

return CafeGrewController
