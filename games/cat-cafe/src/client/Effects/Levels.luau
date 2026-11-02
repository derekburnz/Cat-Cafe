--!strict
-- A cat levelling up (F75, data-model 4b v0.12): when one of your own cafe cats reaches a new level, a small mint
-- sparkle pops over its head and a few glints float up, next to the engineer's toast. Small on purpose: early on a
-- cafe's cats level every couple of minutes. Only the owner sees it, as the design has it, and only within
-- animRadius.
--
-- Source: `Level` on each cat model under a Plot's `Cats` folder (data-model 13 v0.12), watched for a rise; a cat
-- model built at its new level (moved from resting to working, a rejoin) has no rise and plays nothing. The plot's
-- `OwnerUserId` says whose cats they are. Listening only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Levels = {}

local watched: { [Instance]: boolean } = {}
local started = false

local function sparkle(cat: Model)
	if cat:FindFirstChildWhichIsA("BasePart", true) == nil then
		return -- not streamed in
	end
	local frame, size = cat:GetBoundingBox()
	local l = Presets.levelUp
	local top = frame.Position + Vector3.new(0, size.Y / 2 + l.above, 0)
	if Context.distance(top) > Context.budget.animRadius then
		return
	end
	Particles.burst("catchSparkle", top, l.sparkles, l.colour)
	Particles.burst("fishRise", top, l.glints, l.colour)
end

local function watchCat(plot: Instance, cat: Instance)
	if not cat:IsA("Model") or watched[cat] then
		return
	end
	watched[cat] = true
	local level = cat:GetAttribute("Level")
	cat:GetAttributeChangedSignal("Level"):Connect(function()
		local now = cat:GetAttribute("Level")
		local up = Logic.levelledUp(level, now)
		level = now
		if up and plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			sparkle(cat :: Model)
		end
	end)
	cat.Destroying:Connect(function()
		watched[cat] = nil
	end)
end

local function watchCats(plot: Instance, cats: Instance)
	for _, cat in cats:GetChildren() do
		watchCat(plot, cat)
	end
	cats.ChildAdded:Connect(function(cat: Instance)
		watchCat(plot, cat)
	end)
end

local function watchPlot(plot: Instance)
	if watched[plot] then
		return
	end
	watched[plot] = true
	local cats = plot:FindFirstChild("Cats")
	if cats ~= nil then
		watchCats(plot, cats)
		return
	end
	local waiting: RBXScriptConnection? = nil
	waiting = plot.ChildAdded:Connect(function(child: Instance)
		if child.Name == "Cats" and waiting ~= nil then
			waiting:Disconnect()
			watchCats(plot, child)
		end
	end)
end

function Levels.start()
	if started then
		return
	end
	started = true
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
end

return Levels
