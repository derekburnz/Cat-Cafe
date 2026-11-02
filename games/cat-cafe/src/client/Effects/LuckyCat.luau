--!strict
-- The Lucky Cat statue by each cafe's door (F88, luck-and-rare-moments.md 1a and 1f; Model-Agent's
-- CatCafe_Plot_LuckyCat_0 to _5). When a plot's statue goes up a level while this client has that plot, sparkles in
-- the new look's colour (clay, bronze, silver, gold, jade) burst over the cat, a ring grows on the plinth and, for gold
-- and jade, confetti; anyone within reach sees it, so the street notices. A join or a plot streaming in plays nothing.
-- The jade statue (level 5, "jade with a rainbow shimmer") shimmers: a faint Highlight over it drifts through the
-- rainbow coat hues, with a few sparkles rising off it now and then; the nearest budget.luckyShimmers do, none in
-- Low performance. Reduce Motion holds the shimmer at one hue with no sparkles. The waving paw is Animation-Engineer's.
--
-- Source (Gameplay-Engineer's #743): a Model named "LuckyCat", a direct child of its plot's model, tagged `LuckyCat`
-- with a number attribute `Level` (0 to 5); a level up destroys it and clones the next level's model under the same
-- parent. Listening only. Numbers in Presets.luckyCat.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local LuckyCat = {}

type Shimmer = { glow: Highlight, phase: number, nextTwinkle: number }

-- The last level this client saw for each plot (the statue's parent), so a swap reads as a level up.
local levels: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local shimmers: { [Model]: Shimmer } = {}
local started = false
local rng = Random.new()

local function levelOf(model: Model): number?
	local value = model:GetAttribute("Level")
	if type(value) == "number" then
		return value
	end
	return Logic.luckyCatLevel(model.Name)
end

local function sparkle(model: Model, level: number)
	local s = Presets.luckyCat
	local pivot = model:GetPivot()
	if Context.distance(pivot.Position) > s.within then
		return
	end
	local at = (pivot * CFrame.new(0, s.centre, 0)).Position
	local colour = s.colours[math.clamp(math.floor(level), 1, #s.colours)]
	Particles.burst("catchSparkle", at, s.sparkles, colour)
	Particles.burst("catchSparkle", at, math.ceil(s.sparkles / 2), Presets.palette.sparkle)
	Particles.ring(pivot.Position + Vector3.new(0, 0.1, 0), colour, s.ring, s.ringSeconds)
	if level >= s.confettiFrom then
		Particles.confetti(
			at,
			math.ceil(Context.budget.confetti * 0.5),
			{ colour, Presets.palette.sparkle }
		)
	end
end

-- A statue this client sees now (added, or its Level set): a level up on its plot sparkles.
local function seen(model: Model)
	local plot = model.Parent
	local level = levelOf(model)
	if plot == nil or level == nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local before = levels[plot]
	levels[plot] = level
	if Logic.luckyLevelUp(before, level) then
		sparkle(model, level)
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	seen(model)
	-- a Level set after the model arrives, or changed in place
	local changed: RBXScriptConnection? = nil
	changed = model:GetAttributeChangedSignal("Level"):Connect(function()
		seen(model)
	end)
	local gone: RBXScriptConnection? = nil
	gone = model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(game) then
			return
		end
		if changed ~= nil then
			changed:Disconnect()
		end
		if gone ~= nil then
			gone:Disconnect()
		end
	end)
end

local function stopShimmer(model: Model)
	local entry = shimmers[model]
	if entry ~= nil then
		entry.glow:Destroy()
		shimmers[model] = nil
	end
end

-- Chooses which jade statues shimmer: the nearest budget.luckyShimmers within reach.
local function pick()
	local s = Presets.luckyCat
	local candidates: { Logic.Candidate<Model> } = {}
	for _, instance in CollectionService:GetTagged("LuckyCat") do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			local model = instance :: Model
			local level = levelOf(model)
			if level ~= nil and level >= s.shimmerFrom then
				table.insert(
					candidates,
					{ key = model, distance = Context.distance(model:GetPivot().Position) }
				)
			end
		end
	end
	local chosen: { [Model]: boolean } = {}
	for _, model in Logic.nearest(candidates, s.shimmerWithin, Context.budget.luckyShimmers) do
		chosen[model] = true
	end
	for model in shimmers do
		if not chosen[model] or model.Parent == nil then
			stopShimmer(model)
		end
	end
	for model in chosen do
		if shimmers[model] == nil then
			local glow = Instance.new("Highlight")
			glow.Name = "EffectsLuckyShimmer"
			glow.FillTransparency = s.fill
			glow.OutlineTransparency = 1
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.Adornee = model
			glow.Parent = Context.folder()
			shimmers[model] = { glow = glow, phase = rng:NextNumber(), nextTwinkle = 0 }
		end
	end
end

local function step()
	local s = Presets.luckyCat
	local hues = Presets.rainbow.hues
	local still = Context.reducedMotion()
	local now = os.clock()
	for model, entry in shimmers do
		if model.Parent == nil then
			stopShimmer(model)
			continue
		end
		local u = if still then entry.phase else entry.phase + now / s.period
		entry.glow.FillColor = Logic.rainbowAt(hues, u)
		if not still and now >= entry.nextTwinkle then
			entry.nextTwinkle = now + s.twinkleEvery
			local at = (model:GetPivot() * CFrame.new(0, s.centre, 0)).Position
			Particles.burst("catchSparkle", at, s.twinkle, Logic.rainbowAt(hues, u + 0.5))
		end
	end
end

function LuckyCat.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("LuckyCat"):Connect(watch)
	for _, instance in CollectionService:GetTagged("LuckyCat") do
		watch(instance)
	end
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			pick()
			task.wait(Presets.luckyCat.pick)
		end
	end)
end

return LuckyCat
