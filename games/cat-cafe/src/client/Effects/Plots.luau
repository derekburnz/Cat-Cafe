--!strict
-- Effects that follow the cafes and the area gates (design v0.4 sections 2, 3 and 5):
-- - a rank up: confetti and a smoke puff at the cafe front, for any cafe in range, so the street sees it;
-- - a claim: the For Rent shutters roll up and the sign fades when a player takes an empty plot;
-- - a gate: its barrier dissolves with sparkles and confetti the first time it opens for this player this
--   session, played when the player is close enough to see it.
-- Driven by the replicated Plot attributes OwnerUserId and Tier (data-model section 13) and each gate's
-- RequiresTier (tag AreaGate), so nothing here needs a remote. WorldController still opens the gate itself; the
-- dissolve is a copy of the closed barrier fading out over it.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Plots = {}

type Cached = { source: BasePart, copy: BasePart }

type PlotState = {
	owner: number,
	tier: number,
	ownerChangedAt: number,
	shutters: { Cached },
	signs: { Cached },
	hidden: { BasePart },
	queued: boolean,
}

type GateState = {
	requires: number,
	looks: { [BasePart]: number },
	center: Vector3,
	size: Vector3,
	pending: boolean,
}

local GATE_CHECK_SECONDS = 0.5

local plots: { [Model]: PlotState } = {}
local gates: { [Instance]: GateState } = {}
local ownTier: number? = nil
local started = false

local function numberAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function endsWith(text: string, suffix: string): boolean
	return #text >= #suffix and text:sub(-#suffix) == suffix
end

local function frontOf(plot: Model): Vector3
	local door = plot:FindFirstChild("Door")
	if door ~= nil and door:IsA("BasePart") then
		return (door :: BasePart).Position + Vector3.new(0, 3, 0)
	end
	return plot:GetPivot().Position + Vector3.new(0, 6, 0)
end

-- True for parts of the For Rent dressing (CatCafe_Plot_ForRent, or any model with ForRent in its name).
local function inForRent(part: Instance, plot: Model): boolean
	local stop: Instance = plot
	local ancestor = part.Parent
	while ancestor ~= nil and ancestor ~= stop do
		if ancestor.Name:find("ForRent", 1, true) ~= nil then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

-- A copy made now, while the dressing is there: at a claim the server may remove it in the same moment.
local function copyOf(part: BasePart): BasePart
	local copy = part:Clone() :: BasePart
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CastShadow = false
	copy.LocalTransparencyModifier = 0
	return copy
end

local function cache(state: PlotState, plot: Model, instance: Instance)
	if not instance:IsA("BasePart") or not inForRent(instance, plot) then
		return
	end
	local part = instance :: BasePart
	part.LocalTransparencyModifier = 0
	if endsWith(part.Name, "_Shutter") then
		table.insert(state.shutters, { source = part, copy = copyOf(part) })
	elseif endsWith(part.Name, "_Sign") then
		table.insert(state.signs, { source = part, copy = copyOf(part) })
	end
end

local function recache(state: PlotState, plot: Model)
	for _, part in state.hidden do
		part.LocalTransparencyModifier = 0
	end
	state.hidden = {}
	state.shutters = {}
	state.signs = {}
	for _, descendant in plot:GetDescendants() do
		cache(state, plot, descendant)
	end
end

-- Shows a cached copy where its source stands and hides the source on this client.
local function stage(state: PlotState, cached: Cached): (BasePart, CFrame)
	local source = cached.source
	local copy = cached.copy
	local frame = if source.Parent ~= nil then source.CFrame else copy.CFrame
	if source.Parent ~= nil then
		source.LocalTransparencyModifier = 1
		table.insert(state.hidden, source)
	end
	copy.CFrame = frame
	copy.Parent = Context.folder()
	return copy, frame
end

local function rollUp(plot: Model, state: PlotState)
	local shutters = state.shutters
	local signs = state.signs
	state.shutters = {}
	state.signs = {}
	local front = frontOf(plot)
	if Context.distance(front) > Presets.rankUp.within then
		return
	end
	local s = Presets.shutter
	local roll = TweenInfo.new(s.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local fade =
		TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, s.seconds)
	for _, cached in shutters do
		local copy, frame = stage(state, cached)
		local size = copy.Size
		-- Rolls up into its top edge: the height shrinks while the centre rises to keep the top in place.
		local top = frame * CFrame.new(0, size.Y / 2, 0)
		TweenService:Create(
			copy,
			roll,
			{ Size = Vector3.new(size.X, 0.2, size.Z), CFrame = top * CFrame.new(0, -0.1, 0) }
		):Play()
		TweenService:Create(copy, fade, { Transparency = 1 }):Play()
		Debris:AddItem(copy, s.seconds + 0.4)
		Particles.burst(
			"dust",
			(frame * CFrame.new(0, -size.Y / 2, 0)).Position,
			Presets.bursts.dust
		)
	end
	local flip = TweenInfo.new(s.signSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	for _, cached in signs do
		local copy, frame = stage(state, cached)
		TweenService
			:Create(copy, flip, { CFrame = frame * CFrame.Angles(0, math.pi, 0), Transparency = 1 })
			:Play()
		Debris:AddItem(copy, s.signSeconds + 0.2)
	end
	Particles.confetti(front, math.ceil(Context.budget.confetti * 0.5))
	if #shutters == 0 then
		Particles.burst("dust", front, Presets.bursts.dust)
	end
end

local function rankUp(plot: Model, mine: boolean)
	local front = frontOf(plot)
	if Context.distance(front) > Presets.rankUp.within then
		return
	end
	local count = if mine then math.ceil(Context.budget.confetti * 1.5) else Context.budget.confetti
	Particles.confetti(front + Vector3.new(0, 2, 0), count)
	Particles.burst("smokePuff", front, Presets.bursts.smokePuff)
end

-- Gates -----------------------------------------------------------------------------------------------------

-- How the gate looked closed. WorldController shows an open gate at 0.85, so a part already that clear was
-- recorded after it opened and gets WorldController's closed look instead.
local function closedLook(part: BasePart): number
	if part.Transparency < 0.85 then
		return part.Transparency
	end
	return if part.Name == "Bars" then 0.35 else 0
end

local function watchGate(instance: Instance)
	local requires = instance:GetAttribute("RequiresTier")
	local existing: GateState? = gates[instance]
	if type(requires) ~= "number" or existing ~= nil then
		return
	end
	local looks: { [BasePart]: number } = {}
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			looks[descendant :: BasePart] = closedLook(descendant :: BasePart)
		end
	end
	local center = Vector3.zero
	local size = Vector3.one
	if instance:IsA("Model") then
		local frame, extents = (instance :: Model):GetBoundingBox()
		center = frame.Position
		size = extents
	elseif instance:IsA("BasePart") then
		center = (instance :: BasePart).Position
		size = (instance :: BasePart).Size
		looks[instance :: BasePart] = closedLook(instance :: BasePart)
	end
	gates[instance] =
		{ requires = requires, looks = looks, center = center, size = size, pending = false }
end

local function openGates(previous: number, tier: number)
	local requires: { [Instance]: number } = {}
	for gate, state in gates do
		requires[gate] = state.requires
	end
	for _, gate in Logic.newlyOpen(requires, previous, tier) do
		local state: GateState? = gates[gate]
		if state ~= nil then
			state.pending = true
		end
	end
end

local function dissolve(state: GateState)
	state.pending = false
	local g = Presets.gate
	local info = TweenInfo.new(g.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for part, look in state.looks do
		if part.Parent ~= nil and look < 1 then
			local copy = copyOf(part)
			for _, child in copy:GetChildren() do
				child:Destroy() -- no lights, signs or prompts on the fading copy
			end
			copy.Transparency = look
			copy.Parent = Context.folder()
			TweenService:Create(copy, info, { Transparency = 1, Size = copy.Size * 1.06 }):Play()
			Debris:AddItem(copy, g.seconds + 0.1)
		end
	end
	local center = state.center
	Particles.burst("gateSparkle", center, Presets.bursts.gateSparkle)
	Particles.confetti(center + Vector3.new(0, 2, 0), Context.budget.confetti)
	Particles.ring(center - Vector3.new(0, state.size.Y / 2 - 0.2, 0), Presets.palette.mint)
end

local function checkGates()
	for _, state in gates do
		if state.pending and Context.distance(state.center) <= Presets.gate.playWithin then
			dissolve(state)
		end
	end
end

-- Plots -----------------------------------------------------------------------------------------------------

local function evaluate(plot: Model, state: PlotState)
	state.queued = false
	if plot.Parent == nil then
		plots[plot] = nil
		return
	end
	local owner = numberAttribute(plot, "OwnerUserId")
	local tier = numberAttribute(plot, "Tier")
	local now = os.clock()
	local change =
		Logic.plotChange(state.owner, state.tier, owner, tier, now - state.ownerChangedAt)
	if owner ~= state.owner then
		state.ownerChangedAt = now
	end
	local mine = owner ~= 0 and owner == Players.LocalPlayer.UserId
	if change == "claim" then
		rollUp(plot, state)
	elseif change == "release" then
		recache(state, plot)
	elseif change == "rankUp" then
		rankUp(plot, mine)
	end
	if mine then
		local previous = ownTier
		if change == "rankUp" and previous ~= nil then
			openGates(previous, tier)
		end
		ownTier = tier
	end
	state.owner = owner
	state.tier = tier
end

local function watchPlot(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local plot = instance :: Model
	local existing: PlotState? = plots[plot]
	if existing ~= nil then
		return
	end
	local state: PlotState = {
		owner = numberAttribute(plot, "OwnerUserId"),
		tier = numberAttribute(plot, "Tier"),
		ownerChangedAt = os.clock(),
		shutters = {},
		signs = {},
		hidden = {},
		queued = false,
	}
	plots[plot] = state
	if state.owner ~= 0 and state.owner == Players.LocalPlayer.UserId then
		ownTier = state.tier
	end
	for _, descendant in plot:GetDescendants() do
		cache(state, plot, descendant)
	end
	plot.DescendantAdded:Connect(function(descendant: Instance)
		cache(state, plot, descendant)
	end)
	local function queue()
		if not state.queued then
			state.queued = true
			task.defer(evaluate, plot, state)
		end
	end
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(queue)
	plot:GetAttributeChangedSignal("Tier"):Connect(queue)
end

function Plots.start()
	if started then
		return
	end
	started = true
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
	for _, gate in CollectionService:GetTagged("AreaGate") do
		watchGate(gate)
	end
	CollectionService:GetInstanceAddedSignal("AreaGate"):Connect(watchGate)
	task.spawn(function()
		while true do
			task.wait(GATE_CHECK_SECONDS)
			checkGates()
		end
	end)
end

return Plots
