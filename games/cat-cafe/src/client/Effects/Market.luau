--!strict
-- The world side of opening a Cafe Crate at the Golden Fish Market (F53, golden-fish.md section 4). The window plays
-- the reveal card (the UI's); here a puff of ice sparkle comes off the stall's counter and the won piece's rarity
-- pops out of it, the same pop a catch of that rarity gets (Catch.pop): sparkles and a ring in the rarity colour,
-- confetti from Epic up, a beam from Legendary up and a second ring and showers for a Mythical. It plays the moment
-- CrateResult arrives, in the won piece's colour from the first frame, and never builds up or shows a better rarity
-- first, so nothing looks like a near miss (monetization-policy). A duplicate pops the same; its golden fish back
-- sparkle on the player (Fish.luau). Only the opener sees it, near a stall. Listening only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Catch = require(script.Parent.Catch)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Market = {}

local started = false

-- The stall this player opened the crate at: the nearest one in Workspace within reach (the stall's template in
-- ReplicatedStorage.Assets may carry the tag too).
local function nearestStall(): Instance?
	local best: Instance? = nil
	local bestDistance = Presets.market.within
	for _, station in CollectionService:GetTagged("FishMarket") do
		local at = if station:IsDescendantOf(Workspace) then Context.positionOf(station) else nil
		if at ~= nil then
			local distance = Context.distance(at)
			if distance <= bestDistance then
				best, bestDistance = station, distance
			end
		end
	end
	return best
end

-- Where the pop comes from: the top of the stand-in stall's `FishCrate`, else the middle of the counter's ice on the
-- modelled stall (market.py), measured from its pivot at the base centre with the counter front toward -Z.
local function counterTop(station: Instance): Vector3?
	local crate = station:FindFirstChild("FishCrate", true)
	if crate ~= nil and crate:IsA("BasePart") then
		local part = crate :: BasePart
		return part.Position + Vector3.new(0, Logic.halfExtents(part.CFrame, part.Size).Y, 0)
	end
	local m = Presets.market
	if station:IsA("Model") then
		return ((station :: Model):GetPivot() * CFrame.new(0, m.counterY, m.counterZ)).Position
	end
	return Context.positionOf(station)
end

local function opened(decorId: string)
	local def = Catalog.getDecor(decorId)
	local station = nearestStall()
	if def == nil or station == nil then
		return -- walked off before the answer came: the window's toast says what it was
	end
	local top = counterTop(station)
	if top == nil then
		return
	end
	local m = Presets.market
	Particles.burst("dust", top, m.puff, Presets.palette.fishBelly)
	Catch.pop(top + Vector3.new(0, m.above, 0), top, def.rarity or "Common")
end

function Market.start()
	if started then
		return
	end
	started = true
	-- CrateResult(crateId, decorId, duplicate, refund); decorId is "" when the open was refused.
	Net.on("CrateResult", function(_crateId: unknown, decorId: unknown)
		if type(decorId) == "string" and decorId ~= "" then
			opened(decorId)
		end
	end)
end

return Market
