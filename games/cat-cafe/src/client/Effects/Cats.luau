--!strict
-- Which cats move on this client and how (design v0.4 sections 1 and 4): role idles at the cafe stations, naps,
-- stuck cats struggling in their traps, strays looking around, and the hiss hop on a missed catch. Only the
-- nearest few within range move (budget.animatedCats within budget.animRadius); the rest stand as the server
-- placed them. Shiny cats in range sparkle, and napping cats show floating z's.
--
-- Cats come from replicated world state only: the Stray and StuckCat tags, and models inside a Plot with a
-- CatId, Napping or Pose attribute (working cats under Plot/Cats, napping cats; data-model section 13).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local Cats = {}

type Entry = {
	model: Model,
	rig: Pose.Rig,
	style: Logic.Style,
	phase: number,
	hissAt: number?,
	yarn: BasePart?,
	naps: { TextLabel }?,
	napGui: BillboardGui?,
}

local ROLES: { [string]: Logic.Style } = {
	barista = "barista",
	waiter = "waiter",
	greeter = "greeter",
	entertainer = "entertainer",
}
local DARK_WOOD = Color3.fromRGB(94, 70, 52)
local PICK_SECONDS = 0.5
local RETRY_SECONDS = 2 -- a cat with no body yet, or a held one, is tried again after this

local known: { [Model]: boolean } = {}
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local retryAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local active: { [Model]: Entry } = {}
local sparkles: { [Model]: ParticleEmitter } = setmetatable({}, { __mode = "k" }) :: any
local rng = Random.new()
local started = false

local drop: (model: Model, entry: Entry) -> ()

-- With streaming a cat's model arrives before its parts and parts come and go. A part arriving lets a cat that
-- could not be bound try again at once, and makes a moving cat bind again whole at the next pick, so a Head or
-- Tail that came late moves too.
local function onPartAdded(model: Model, descendant: Instance)
	if not descendant:IsA("BasePart") then
		return
	end
	retryAt[model] = nil
	local entry: Entry? = active[model]
	if entry ~= nil then
		drop(model, entry)
	end
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	known[model] = true
	if not watched[model] then
		watched[model] = true
		model.DescendantAdded:Connect(function(descendant: Instance)
			onPartAdded(model, descendant)
		end)
	end
end

local function isPlotCat(instance: Instance): boolean
	return instance:IsA("Model")
		and (
			instance:GetAttribute("CatId") ~= nil
			or instance:GetAttribute("Napping") ~= nil
			or instance:GetAttribute("Pose") ~= nil
		)
end

local function watchPlot(plot: Instance)
	for _, descendant in plot:GetDescendants() do
		if isPlotCat(descendant) then
			consider(descendant)
		end
	end
	plot.DescendantAdded:Connect(function(descendant: Instance)
		if isPlotCat(descendant) then
			consider(descendant)
		end
	end)
end

local function partNamed(model: Model, name: string): BasePart?
	local direct = model:FindFirstChild(name, true)
	if direct ~= nil and direct:IsA("BasePart") then
		return direct :: BasePart
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name:sub(-(#name + 1)) == "_" .. name then
			return descendant :: BasePart
		end
	end
	return nil
end

-- Working cats carry Role (data-model 13); until then the station's SpotType says the role.
local function roleOf(model: Model): string?
	local role = model:GetAttribute("Role")
	if type(role) == "string" then
		return string.lower(role)
	end
	local spotId = model:GetAttribute("SpotId")
	local holder = model.Parent
	local plot = if holder ~= nil then holder.Parent else nil
	local spots = if plot ~= nil then plot:FindFirstChild("Spots") else nil
	local spot = if spots ~= nil and type(spotId) == "string"
		then spots:FindFirstChild(spotId)
		else nil
	local spotType = if spot ~= nil then spot:GetAttribute("SpotType") else nil
	return if type(spotType) == "string" then string.lower(spotType) else nil
end

local function styleOf(model: Model): Logic.Style
	if model:GetAttribute("Napping") == true or model:GetAttribute("Pose") == "nap" then
		return "nap"
	elseif CollectionService:HasTag(model, "StuckCat") then
		return "stuck"
	elseif CollectionService:HasTag(model, "Stray") then
		return "stray"
	end
	local role = roleOf(model)
	local style: Logic.Style? = if role ~= nil then ROLES[role] else nil
	return style or "sit"
end

local function napCount(): number
	local count = 0
	for _, entry in active do
		if entry.naps ~= nil then
			count += 1
		end
	end
	return count
end

-- The For Rent doorstep cat comes with its own floating Zzz prop (a sibling ending _Zzz), so it gets no labels.
local function hasOwnZzz(model: Model): boolean
	local holder = model.Parent
	if holder == nil then
		return false
	end
	for _, sibling in holder:GetChildren() do
		if sibling.Name:sub(-4) == "_Zzz" then
			return true
		end
	end
	return false
end

-- Floating z's over a napping cat, drawn by the pose loop (three labels, one rising after another).
local function addNaps(entry: Entry)
	if entry.naps ~= nil or napCount() >= Context.budget.napLabels or hasOwnZzz(entry.model) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsNap"
	gui.Adornee = partNamed(entry.model, "Head") or entry.rig.body
	gui.Size = UDim2.fromScale(1.6, 2) -- studs
	gui.StudsOffsetWorldSpace = Vector3.new(0.5, 1.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = Presets.nap.maxDistance
	local labels: { TextLabel } = {}
	for _, text in { "z", "z", "Z" } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromScale(0.4, 0.28)
		label.Position = UDim2.fromScale(0.3, 0.8)
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = Presets.palette.offwhite
		label.TextStrokeColor3 = DARK_WOOD
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		table.insert(labels, label)
	end
	gui.Parent = Context.folder()
	entry.naps = labels
	entry.napGui = gui
end

local function animateNaps(labels: { TextLabel }, t: number)
	if Context.reducedMotion() then
		for i, label in labels do
			label.Position = UDim2.fromScale(0.3 + 0.2 * i, 0.85 - 0.25 * i)
			label.TextTransparency = 0
		end
		return
	end
	local rise = Presets.nap.riseSeconds
	for i, label in labels do
		local along = (t / rise + (i - 1) / #labels) % 1
		label.Position = UDim2.fromScale(0.3 + 0.45 * along, 0.85 - 0.75 * along)
		local fade = if along < 0.15 then 1 - along / 0.15 else (along - 0.15) / 0.85
		label.TextTransparency = fade
		label.TextStrokeTransparency = 0.3 + 0.7 * fade
	end
end

-- The entertainer's yarn ball, a client-only prop it bats back and forth.
local function addYarn(entry: Entry)
	if entry.yarn ~= nil then
		return
	end
	local ball = Context.effectPart("Yarn", Vector3.new(0.6, 0.6, 0.6), Presets.palette.aurora)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Fabric
	ball.Parent = Context.folder()
	entry.yarn = ball
end

local function removeYarn(entry: Entry)
	local yarn = entry.yarn
	if yarn ~= nil then
		yarn:Destroy()
		entry.yarn = nil
	end
end

local function removeNaps(entry: Entry)
	local gui = entry.napGui
	if gui ~= nil then
		gui:Destroy()
		entry.napGui = nil
		entry.naps = nil
	end
end

-- The props that go with a style: the yarn ball for the entertainer, the z's for a nap.
local function dress(entry: Entry)
	if entry.style == "entertainer" then
		addYarn(entry)
	else
		removeYarn(entry)
	end
	if entry.style == "nap" then
		addNaps(entry)
	else
		removeNaps(entry)
	end
end

local function bind(model: Model): Entry?
	local rig = Pose.bind(model)
	if rig == nil then
		retryAt[model] = os.clock() + RETRY_SECONDS
		return nil
	end
	retryAt[model] = nil
	local entry: Entry = {
		model = model,
		rig = rig,
		style = styleOf(model),
		phase = rng:NextNumber(0, 20),
		hissAt = nil,
		yarn = nil,
		naps = nil,
		napGui = nil,
	}
	active[model] = entry
	dress(entry)
	return entry
end

function drop(model: Model, entry: Entry)
	Pose.release(entry.rig)
	removeYarn(entry)
	removeNaps(entry)
	active[model] = nil
end

-- Shiny cats sparkle (data-model section 2); the server never marks a stuck cat shiny before its rescue (N30).
local function lightShinies(shiny: { Logic.Candidate<Model> })
	local budget = Context.budget
	local lit: { [Model]: boolean } = {}
	for _, model in Logic.nearest(shiny, budget.ambientRadius, budget.shinyEmitters) do
		lit[model] = true
		local emitter: ParticleEmitter? = sparkles[model]
		if emitter == nil or not emitter:IsDescendantOf(model) then -- none yet, or its body streamed out
			local body = model.PrimaryPart or partNamed(model, "Body")
			local made = if body ~= nil then Particles.attach("shiny", body) else nil
			if made ~= nil then
				if Presets.textures.shinySparkle ~= "" then
					made.Texture = Presets.textures.shinySparkle
				end
				sparkles[model] = made
			end
		else
			emitter.Enabled = true
		end
	end
	for model, emitter in sparkles do
		if not lit[model] then
			emitter.Enabled = false
		end
	end
end

local function pick()
	local focus = Context.focus()
	if focus == nil then
		return
	end
	local budget = Context.budget
	local now = os.clock()
	local moving: { Logic.Candidate<Model> } = {}
	local shiny: { Logic.Candidate<Model> } = {}
	for model in known do
		if model.Parent == nil then
			known[model] = nil
			continue
		end
		local distance = (model:GetPivot().Position - focus).Magnitude
		local retry: number? = retryAt[model]
		if retry == nil or retry <= now then
			table.insert(moving, { key = model, distance = distance })
		end
		if model:GetAttribute("Shiny") == true then
			table.insert(shiny, { key = model, distance = distance })
		end
	end
	local keep: { [Model]: boolean } = {}
	for _, model in Logic.nearest(moving, budget.animRadius, budget.animatedCats) do
		keep[model] = true
		local current: Entry? = active[model]
		if current == nil then
			bind(model)
		end
	end
	for model, entry in active do
		if model.Parent == nil or (not keep[model] and entry.hissAt == nil) then
			drop(model, entry)
		else
			local style: Logic.Style = styleOf(model)
			if style ~= entry.style then
				entry.style = style
				dress(entry)
			end
		end
	end
	lightShinies(shiny)
end

local elapsed = 0

local function step(dt: number)
	elapsed += dt
	if elapsed < 1 / Context.budget.animHz then
		return
	end
	elapsed = 0
	local now = os.clock()
	local hiss = Presets.motion.hiss
	for model, entry in active do
		local o = Logic.idle(entry.style, now + entry.phase)
		local alpha = -1
		local hissAt = entry.hissAt
		if hissAt ~= nil then
			alpha = (now - hissAt) / hiss.seconds
			if alpha >= 1 then
				entry.hissAt = nil
				alpha = -1
			else
				Logic.hiss(o, alpha)
			end
		end
		if not Pose.apply(entry.rig, o, alpha) then
			drop(model, entry)
			continue
		end
		local yarn = entry.yarn
		if yarn ~= nil then
			yarn.CFrame = Pose.floor(entry.rig)
				* CFrame.new(o.yarn * Presets.motion.entertainer.yarnStuds, 0.3, -2)
				* CFrame.Angles(0, 0, -o.yarn * 3)
		end
		local naps = entry.naps
		if naps ~= nil then
			animateNaps(naps, now + entry.phase)
		end
	end
end

-- Makes a cat hiss and hop (a missed catch). A cat that is not moving yet is picked up at once, over budget
-- for a moment, so the hiss is never lost. `lag` is how many seconds ago the miss happened on the server, so the
-- hop lines up with the server's walk back.
function Cats.hiss(model: Model, lag: number?)
	local entry: Entry? = active[model]
	if entry == nil and model.Parent ~= nil then
		entry = bind(model)
	end
	if entry ~= nil then
		entry.hissAt = os.clock() - (lag or 0)
		Pose.startHop(entry.rig)
	end
end

function Cats.start()
	if started then
		return
	end
	started = true
	for _, tag in { "Stray", "StuckCat" } do
		for _, instance in CollectionService:GetTagged(tag) do
			consider(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(consider)
	end
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)

	task.spawn(function()
		while true do
			pick()
			task.wait(PICK_SECONDS)
		end
	end)
	RunService.PreRender:Connect(step)
end

return Cats
