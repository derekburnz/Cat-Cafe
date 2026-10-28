--!strict
-- The world side of opening a Cafe Crate at the Golden Fish Market (F53, golden-fish.md section 4). The window plays
-- the reveal card (the UI's); here a puff of ice sparkle comes off the stall's counter and the won piece's rarity
-- pops out of it, the same pop a catch of that rarity gets (Catch.pop): sparkles and a ring in the rarity colour,
-- confetti from Epic up, a beam from Legendary up and a second ring and showers for a Mythical. It plays the moment
-- CrateResult arrives, in the won piece's colour from the first frame, and never builds up or shows a better rarity
-- first, so nothing looks like a near miss (monetization-policy). A duplicate pops the same; its golden fish back
-- sparkle on the player (Fish.luau). Only the opener sees it, near a stall. Listening only.
--
-- The crate itself (Model-Agent's crates.py, `ReplicatedStorage.Assets.CatCafe_Prop_Crate_<Pool>` and `_Gold`): the
-- crate that was opened appears on the counter facing you at the same instant, its lid (the child Model ending
-- `_Lid`) swings up on its back hinge as the pop comes out of it, and it fades away a moment later. Before the models
-- land, or for a crate with none, the pop comes off the bare counter as before.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local shown: Model? = nil -- the crate on the counter now; the next open takes its place

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

-- The opened crate's model in ReplicatedStorage.Assets, or nil before the models land.
local function crateTemplate(crateId: string): Model?
	local crate = Catalog.getCrate(crateId)
	local name: string? = if crate ~= nil
		then Logic.crateModelName(crate.area, crate.golden)
		else nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if name == nil or assets == nil then
		return nil
	end
	local found = assets:FindFirstChild(name :: string)
	return if found ~= nil and found:IsA("Model") then found :: Model else nil
end

local function lidOf(model: Model): Model?
	for _, child in model:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -4) == "_Lid" then
			return child :: Model
		end
	end
	return nil
end

local function removeShown()
	if shown ~= nil then
		shown:Destroy()
		shown = nil
	end
end

-- Swings the lid up about its back edge, the hinge (the crate's front is -Z), from closed to `lidDegrees`.
local function openLid(lid: Model, facing: CFrame)
	local c = Presets.marketCrate
	local box, size = lid:GetBoundingBox()
	local centre = facing:PointToObjectSpace(box.Position)
	local half = Logic.halfExtents(facing:ToObjectSpace(box), size)
	local hinge = facing * CFrame.new(centre + Vector3.new(0, -half.Y, half.Z))
	local closed = lid:GetPivot()
	local function swing(degrees: number)
		lid:PivotTo(hinge * CFrame.Angles(math.rad(degrees), 0, 0) * hinge:Inverse() * closed)
	end
	if Context.reducedMotion() then
		swing(c.lidDegrees)
		return
	end
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - began
		if lid.Parent == nil or elapsed >= c.lidSeconds then
			if connection ~= nil then
				connection:Disconnect()
			end
		end
		if lid.Parent ~= nil then
			swing(Logic.lidAngle(elapsed, c.lidSeconds, c.lidDegrees))
		end
	end)
end

-- Puts a copy of the crate on the counter at `top`, its front toward you, opens it and fades it away after a moment.
-- Returns the open crate's rim, where the pop comes out.
local function showCrate(template: Model, top: Vector3): Vector3
	removeShown()
	local c = Presets.marketCrate
	local model = template:Clone() :: Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	model:ScaleTo(c.scale)
	-- the base centre under the box, wherever the model's pivot is (the template stands unturned)
	local box, size = model:GetBoundingBox()
	local height = Logic.halfExtents(box, size).Y * 2
	local base = model:GetPivot():PointToObjectSpace(box.Position - Vector3.new(0, height / 2, 0))
	local facing = CFrame.new(top)
	local focus = Context.focus()
	if focus ~= nil and Vector3.new(focus.X - top.X, 0, focus.Z - top.Z).Magnitude > 0.1 then
		facing = CFrame.lookAt(top, Vector3.new(focus.X, top.Y, focus.Z))
	end
	model:PivotTo(facing * CFrame.new(-base))
	model.Name = "EffectsMarketCrate"
	model.Parent = Context.folder()
	shown = model
	local rim = height
	local lid = lidOf(model)
	if lid ~= nil then
		local lidBox, lidSize = lid:GetBoundingBox()
		rim = facing:PointToObjectSpace(lidBox.Position).Y
			- Logic.halfExtents(facing:ToObjectSpace(lidBox), lidSize).Y
		openLid(lid, facing)
	end
	task.delay(c.hold, function()
		if model.Parent == nil then
			return -- the next open took its place
		end
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				TweenService:Create(descendant, TweenInfo.new(c.fade), { Transparency = 1 }):Play()
			end
		end
		task.delay(c.fade, function()
			if shown == model then
				shown = nil
			end
			model:Destroy()
		end)
	end)
	return top + Vector3.new(0, rim, 0)
end

local function opened(crateId: string, decorId: string)
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
	local template = crateTemplate(crateId)
	local from = if template ~= nil then showCrate(template, top) else top
	Particles.burst("dust", from, m.puff, Presets.palette.fishBelly)
	Catch.pop(from + Vector3.new(0, m.above, 0), top, def.rarity or "Common")
end

function Market.start()
	if started then
		return
	end
	started = true
	-- CrateResult(crateId, decorId, duplicate, refund); decorId is "" when the open was refused.
	Net.on("CrateResult", function(crateId: unknown, decorId: unknown)
		if type(crateId) == "string" and type(decorId) == "string" and decorId ~= "" then
			opened(crateId, decorId)
		end
	end)
end

return Market
