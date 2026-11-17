--!strict
-- #4543: watches your own cafe's room size (RoomWidth and RoomDepth on your plot, set by the server's cafeGrows) and,
-- when a rank up makes it bigger, tells the Rank Up card to show "Your cafe grew!" for the new tier
-- (UI/Components/CafeGrewLogic). A growth counts only within RANK_WINDOW seconds of a tier rise this session, in
-- either order (the plot's size and the tier reach the client separately): on join the plot is claimed at 44 x 34 and
-- grows to your tier a moment later, which is no rank up. Client only; it sends nothing.
local CafeGrewLogic = require(script.Parent.Parent.UI.Components.CafeGrewLogic)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local CafeGrewController = {}

local TICK_SECONDS = 0.5

local lastPlot: Model? = nil
local lastWidth = 0
local lastDepth = 0
local lastTier: number? = nil
local rankUpAt: number? = nil -- os.clock() of this session's last tier rise
local grewAt: number? = nil -- os.clock() of the last growth not yet matched to a rank up

local function tick()
	local now = os.clock()
	local state = UIController.state
	local tier: number? = if state ~= nil and type(state.tier) == "number" then state.tier else nil
	if tier ~= nil then
		if lastTier ~= nil and tier > lastTier then
			rankUpAt = now
		end
		lastTier = tier
	end
	local plot = UIController.ownPlot()
	if tier == nil or plot == nil then
		lastPlot = nil
		return
	end
	local width, depth = CafeGrewLogic.size(
		plot:GetAttribute(CafeGrewLogic.WIDTH_ATTRIBUTE),
		plot:GetAttribute(CafeGrewLogic.DEPTH_ATTRIBUTE)
	)
	if plot ~= lastPlot then
		lastPlot = plot
	elseif CafeGrewLogic.grew(lastWidth, lastDepth, width, depth) then
		grewAt = now
	end
	lastWidth, lastDepth = width, depth
	if CafeGrewLogic.fromRankUp(grewAt, rankUpAt) then
		grewAt = nil
		UI.cafeGrew(tier)
	elseif grewAt ~= nil and now - grewAt > CafeGrewLogic.RANK_WINDOW then
		grewAt = nil -- a growth with no rank up (the join refresh) is dropped
	end
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
