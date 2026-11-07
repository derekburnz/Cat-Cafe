--!strict
-- The Grand Opening ribbon set (#1922, first-hour.md section 1d; Model-Agent's #1928). At roadmap step 8, the last
-- (RoadmapStep, to the owner alone), the red ribbon across your cafe front snaps: its two halves swing down about their
-- brass rosettes in opposite directions, drop a little and fade, while confetti in the cafe palette and a few
-- sparkles burst from the knot. Then the bunting's two balloon clusters by the door bob gently about their ties, on
-- every cafe that has them, near you.
--
-- How: the snap plays on a local copy of your plot's ribbon (CafeService's `GrandOpening` model whose `Asset` is
-- CatCafe_Plot_GrandOpeningRibbon, with its `_RibbonL` and `_RibbonR`
-- child Models, each pivoted on its rosette) and hides the real one on this client, so it doesn't matter when the
-- server removes it. A half swings the way that drops its cut end, read from where it hangs from its pivot.
--
-- Reduce Motion: no swing or drop, the halves just fade, and the confetti is 40% (as all confetti). Low performance:
-- the halves just fade, the budget's smaller confetti, and the balloons hold still (first-hour.md: "the balloon
-- wobble is skipped" on low settings). Listening only. Numbers in Presets.grandOpening.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GrandOpening = {}

type Half = { model: Model, pivot: CFrame, sign: number, parts: { [BasePart]: number } }
type Cluster = { model: Model, base: CFrame, phase: number }

local clusters: { [Model]: Cluster } = {}
local started = false

local function ownPlot(): Model?
	for _, instance in CollectionService:GetTagged("Plot") do
		if
			instance:IsA("Model")
			and instance:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		then
			return instance :: Model
		end
	end
	return nil
end

-- The plot's Grand Opening model showing `assetName`: CafeService names it GrandOpening with an `Asset` attribute
-- (showLookModel); a model that keeps its asset name is found too.
local function lookIn(plot: Instance, assetName: string): Model?
	for _, child in plot:GetChildren() do
		if
			child:IsA("Model")
			and (child:GetAttribute("Asset") == assetName or child.Name == assetName)
		then
			return child :: Model
		end
	end
	return nil
end

local function childEnding(model: Instance, suffix: string): Model?
	for _, child in model:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -#suffix) == suffix then
			return child :: Model
		end
	end
	return nil
end

local function partsOf(model: Instance): { [BasePart]: number }
	local parts: { [BasePart]: number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d :: BasePart] = (d :: BasePart).Transparency
		end
	end
	return parts
end

-- One half, ready to swing: its pivot and which way about the pivot's Z axis drops its far (cut) end.
local function half(model: Model?): Half?
	if model == nil then
		return nil
	end
	local pivot = model:GetPivot()
	local centre = pivot:PointToObjectSpace(model:GetBoundingBox().Position)
	return {
		model = model,
		pivot = pivot,
		-- the half hangs off toward -X in the pivot's frame: turning +Z swings that end down, and the other way
		sign = if centre.X < 0 then 1 else -1,
		parts = partsOf(model),
	}
end

-- The snap, on a local copy of `ribbon`; the real one is hidden on this client.
local function snap(ribbon: Model)
	local g = Presets.grandOpening
	local copy = ribbon:Clone()
	for part in partsOf(ribbon) do
		part.Transparency = 1
	end
	for part in partsOf(copy) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	copy.Parent = Context.folder()
	local knot = copy:GetBoundingBox().Position
	local halves: { Half } = {}
	for _, suffix in { "_RibbonL", "_RibbonR" } do
		local h = half(childEnding(copy, suffix))
		if h ~= nil then
			table.insert(halves, h)
		end
	end
	-- the rosettes stay with the ribbon's root: they fade with the halves
	local root: { [BasePart]: number } = {}
	for part, t in partsOf(copy) do
		local inHalf = false
		for _, h in halves do
			if h.parts[part] ~= nil then
				inHalf = true
			end
		end
		if not inHalf then
			root[part] = t
		end
	end

	Particles.confetti(
		knot,
		math.ceil(Context.budget.confetti * g.confetti),
		Presets.grandOpeningColors
	)
	Particles.burst("catchSparkle", knot, g.sparkles, Presets.palette.golden)

	local still = Context.reducedMotion() or Context.lowPerformance
	local swing = if still then 0 else g.swing
	local total = swing + g.fade
	local began = os.clock()
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= total or copy.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			copy:Destroy()
			return
		end
		local turn = if swing > 0
			then Logic.easeOutBack(math.min(1, t / math.max(swing, 1e-3)))
			else 0
		local fade = math.clamp((t - swing) / g.fade, 0, 1)
		for _, h in halves do
			if not still then
				local drop = g.drop * fade * fade
				h.model:PivotTo(
					CFrame.new(0, -drop, 0)
						* h.pivot
						* CFrame.Angles(0, 0, h.sign * math.rad(g.degrees) * turn)
				)
			end
			for part, base in h.parts do
				part.Transparency = base + (1 - base) * fade
			end
		end
		for part, base in root do
			part.Transparency = base + (1 - base) * fade
		end
	end)
end

local function onStep(n: unknown)
	if type(n) ~= "number" or n < Presets.grandOpening.lastStep then
		return
	end
	local plot = ownPlot()
	local ribbon = if plot ~= nil then lookIn(plot, Presets.grandOpening.ribbon) else nil
	if ribbon ~= nil then
		snap(ribbon)
	end
end

-- The balloon clusters near you, found again every `pick` seconds.
local function findClusters()
	local g = Presets.grandOpening
	local seen: { [Model]: boolean } = {}
	if not Context.lowPerformance and not Context.reducedMotion() then
		local count = 0
		for _, plot in CollectionService:GetTagged("Plot") do
			local bunting = lookIn(plot, g.bunting)
			if bunting ~= nil and count < g.most then
				for _, suffix in { "_LeftBalloons", "_RightBalloons" } do
					local cluster = childEnding(bunting, suffix)
					if
						cluster ~= nil
						and Context.distance(cluster:GetPivot().Position) <= g.within
					then
						seen[cluster] = true
						count += 1
						if clusters[cluster] == nil then
							clusters[cluster] = {
								model = cluster,
								base = cluster:GetPivot(),
								phase = if suffix == "_LeftBalloons" then 0 else 1.7,
							}
						end
					end
				end
			end
		end
	end
	for model, c in clusters do
		if not seen[model] then
			if model.Parent ~= nil then
				model:PivotTo(c.base) -- back as built
			end
			clusters[model] = nil
		end
	end
end

function GrandOpening.start()
	if started then
		return
	end
	started = true
	-- RoadmapStep arrives with Gameplay-Engineer's #1915; until then there is nothing to wait on (no infinite yield)
	task.spawn(function()
		local folder = Remotes.folder()
		local function hook(child: Instance)
			if child.Name == "RoadmapStep" and child:IsA("RemoteEvent") then
				(child :: RemoteEvent).OnClientEvent:Connect(onStep)
				return true
			end
			return false
		end
		local found = folder:FindFirstChild("RoadmapStep")
		if found == nil or not hook(found) then
			local added: RBXScriptConnection? = nil
			added = folder.ChildAdded:Connect(function(child)
				if hook(child) and added ~= nil then
					added:Disconnect()
				end
			end)
		end
	end)
	task.spawn(function()
		while true do
			findClusters()
			task.wait(Presets.grandOpening.pick)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if next(clusters) == nil then
			return
		end
		local g = Presets.grandOpening
		local now = os.clock()
		for model, c in clusters do
			if model.Parent ~= nil then
				local z = math.rad(g.wobble) * math.sin(now * g.hz * 2 * math.pi + c.phase)
				local x = math.rad(g.wobble * 0.6)
					* math.sin(now * g.hz * 1.3 * 2 * math.pi + c.phase * 2)
				model:PivotTo(c.base * CFrame.Angles(x, 0, z))
			end
		end
	end)
end

return GrandOpening
