--!strict
-- The world side of opening a Cafe Crate at the Golden Fish Market (F53, golden-fish.md section 4). The window plays
-- the reveal card (the UI's); here the stall's crate lid hops off with a puff and the won piece's rarity pops out of
-- it, the same pop a catch of that rarity gets (Catch.pop): sparkles and a ring in the rarity colour, confetti from
-- Epic up, a beam from Legendary up and a second ring and showers for a Mythical. It plays the moment CrateResult
-- arrives, in the won piece's colour from the first frame, and never builds up or shows a better rarity first, so
-- nothing looks like a near miss (monetization-policy). A duplicate pops the same; its golden fish back sparkle on
-- the player (Fish.luau). Only the opener sees it, near a stall. Listening only.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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

-- The stall's crate on the counter: `FishCrate`, or an asset part named `..._FishCrate`.
local function crateOf(station: Instance): BasePart?
	local direct = station:FindFirstChild("FishCrate", true)
	if direct ~= nil and direct:IsA("BasePart") then
		return direct :: BasePart
	end
	for _, descendant in station:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name:sub(-10) == "_FishCrate" then
			return descendant :: BasePart
		end
	end
	return nil
end

-- The stall this player opened the crate at: the nearest one within reach.
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

-- The top of the stall's crate and the size of its lid, or a spot over the counter for a stall without one.
local function crateTop(station: Instance): (Vector3?, Vector3)
	local m = Presets.market
	local crate = crateOf(station)
	if crate ~= nil then
		local half = Logic.halfExtents(crate.CFrame, crate.Size)
		return crate.Position + Vector3.new(0, half.Y, 0),
			Vector3.new(half.X * 2, m.lidThick, half.Z * 2)
	end
	local at = Context.positionOf(station)
	local lid = Vector3.new(2, m.lidThick, 1.2)
	return if at ~= nil then at + Vector3.new(0, m.counter, 0) else nil, lid
end

-- The lid hops up, tips and fades. A flash of motion, so none with Reduce Motion.
local function lidPop(top: Vector3, size: Vector3)
	if Context.reducedMotion() then
		return
	end
	local m = Presets.market
	local lid = Context.effectPart("CrateLid", size, Presets.palette.goldDark)
	lid.Material = Enum.Material.Metal
	lid.CFrame = CFrame.new(top + Vector3.new(0, size.Y / 2, 0))
	lid.Parent = Context.folder()
	local info = TweenInfo.new(m.lidSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(lid, info, {
		CFrame = CFrame.new(top + Vector3.new(0, m.lidRise, 0))
			* CFrame.Angles(math.rad(m.lidTilt), 0, 0),
		Transparency = 1,
	}):Play()
	Debris:AddItem(lid, m.lidSeconds + 0.1)
end

local function opened(decorId: string)
	local def = Catalog.getDecor(decorId)
	if def == nil then
		return
	end
	local station = nearestStall()
	if station == nil then
		return -- walked off before the answer came: the window's toast says what it was
	end
	local top, lid = crateTop(station)
	if top == nil then
		return
	end
	local m = Presets.market
	lidPop(top, lid)
	Particles.burst("dust", top, m.puff)
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
