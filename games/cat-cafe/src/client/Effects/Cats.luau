--!strict
-- Which cats move on this client and how (design v0.4 sections 1 and 4, v0.5 F40 and F44): role idles at the
-- cafe stations, naps (and every working cat asleep at its station at night, when the cafe is closed: curled up,
-- or dozing where it sits or stands in its outfit, F25 and PR #260), the resting cat's loaf now and then, stuck
-- cats struggling in their traps, strays looking around, legs that walk and gallop with the cat's real speed, the
-- pant after a sprint and the hiss hop on a missed catch. Only the nearest few within range move
-- (budget.animatedCats within budget.animRadius); the rest stand as the server placed them. Gold cats in range
-- sparkle, a gold coat seen for the first time bursts with gold sparkles, and napping cats show floating z's.
--
-- Cats come from replicated world state only: the Stray and StuckCat tags, models inside a Plot with a CatId,
-- Napping or Pose attribute (working cats under Plot/Cats, napping cats; data-model section 13), and the HeldCat
-- a player carries (for its sparkle only; it rides its holder's arms).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
	from: Logic.Style?, -- the style it is settling out of, for motion.settle seconds after changedAt
	changedAt: number,
	phase: number,
	hissAt: number?,
	head: BasePart?,
	dustAt: number,
	huffAt: number,
	settleFor: number, -- seconds the settle out of `from` takes
	stretchAt: number?, -- when the stretch playing now started (os.clock)
	stretchSeen: number?, -- the last StretchAt the server set on this cat, so each plays once
	stretchWeight: number, -- 1, or less while a stray that set off mid-stretch lets it go
	nextStretch: number, -- when a stray standing still next stretches
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
local STRETCH_LET_GO = 0.35 -- seconds a stray takes to let go of a stretch when it sets off mid-stretch

local known: { [Model]: boolean } = {}
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local retryAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local active: { [Model]: Entry } = {}
local sparkles: { [Model]: ParticleEmitter } = setmetatable({}, { __mode = "k" }) :: any
local held: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
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

-- A gold cat (F42; the variant was called shiny until 2026-10-27). The server's rename moves the attribute from
-- `Shiny` to `Gold`; both are read until every server sets `Gold`.
local function isGold(model: Instance): boolean
	return model:GetAttribute("Gold") == true or model:GetAttribute("Shiny") == true
end

-- A cat this player has hidden with the Show other cats switch off: the engineer marks it HiddenLocal on this
-- client only and hides its parts, so it gets no motion, sparkle, burst or hiss until the mark clears.
local function hidden(model: Model): boolean
	return model:GetAttribute("HiddenLocal") == true
end

-- Hidden: let go of it at once rather than at the next pick, so no z's, yarn or sparkle linger for a moment.
local function watchHidden(model: Model)
	model:GetAttributeChangedSignal("HiddenLocal"):Connect(function()
		if not hidden(model) then
			return -- picked again at the next pick
		end
		local entry: Entry? = active[model]
		if entry ~= nil then
			drop(model, entry)
		end
		local emitter: ParticleEmitter? = sparkles[model]
		if emitter ~= nil then
			emitter.Enabled = false
		end
	end)
end

-- A gold coat seen for the first time: a burst of gold sparkles and a golden ring (F42). A stuck cat is never
-- marked gold before its rescue (N30), so this is also the rescued gold cat's reveal.
local function reveal(model: Model)
	if hidden(model) then
		return
	end
	local frame, size = model:GetBoundingBox()
	local at = frame.Position + Vector3.new(0, size.Y / 2, 0)
	if Context.distance(at) > Context.budget.ambientRadius then
		return
	end
	Particles.burst("shiny", at, Presets.reveal.sparkles)
	Particles.ring(frame.Position - Vector3.new(0, size.Y / 2 - 0.1, 0), Presets.palette.golden)
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
		-- Only the edge into gold reveals: a server writing both names, or clearing the old one, plays it once.
		local wasGold = isGold(model)
		local function goldChanged()
			local gold = isGold(model)
			if gold and not wasGold then
				reveal(model)
			end
			wasGold = gold
		end
		model:GetAttributeChangedSignal("Gold"):Connect(goldChanged)
		model:GetAttributeChangedSignal("Shiny"):Connect(goldChanged)
		watchHidden(model)
		-- Stood up or put back on all fours (F25): the joints and axes change, so it binds again at the next pick.
		model:GetAttributeChangedSignal("Pose"):Connect(function()
			local entry: Entry? = active[model]
			if entry ~= nil then
				drop(model, entry)
			end
		end)
	end
end

-- The cat a player carries is welded to them, so it never poses, but a gold one sparkles and a rescued or
-- caught gold cat bursts as it is picked up.
local function watchCharacter(character: Model)
	local function onChild(child: Instance, picked: boolean)
		if child.Name == "HeldCat" and child:IsA("Model") then
			if not held[child :: Model] then
				watchHidden(child :: Model)
			end
			held[child :: Model] = true
			if picked and isGold(child) then
				reveal(child :: Model)
			end
		end
	end
	for _, child in character:GetChildren() do
		onChild(child, false) -- already held when this client joined: it sparkles, with no burst
	end
	character.ChildAdded:Connect(function(child: Instance)
		onChild(child, true)
	end)
end

local function watchPlayer(player: Player)
	if player.Character ~= nil then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
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

-- A cat with a job: the server tags it WorkingCat and sets its station's SpotId.
local function isWorking(model: Model): boolean
	return CollectionService:HasTag(model, "WorkingCat") or model:GetAttribute("SpotId") ~= nil
end

local function phaseOf(model: Model): number
	local uid = model:GetAttribute("Uid")
	return Logic.phaseOf(if type(uid) == "string" then uid else model.Name)
end

-- A cat that sits rather than lying down: the sitting body (PR #259), or Pose "sit" at its station (PR #260).
local function seated(model: Model): boolean
	return model:GetAttribute("Pose") == "sit" or Pose.kindOf(model) == "sit"
end

-- Whether a resting cafe cat (Napping, no station) is sat up in a loaf right now: by day, for a while now and then
-- (Derek 2026-10-27). Every client works it out the same from the server clock and the cat's Uid. A seated cat
-- never loafs (the loaf is the walking body's).
function Cats.isLoafing(model: Model): boolean
	return model:GetAttribute("Napping") == true
		and not hidden(model)
		and not isWorking(model)
		and not Context.isNight()
		and not seated(model)
		and Logic.loafing(Workspace:GetServerTimeNow(), phaseOf(model))
end

local function styleOf(model: Model): Logic.Style
	local pose = model:GetAttribute("Pose")
	local night = Context.isNight()
	if
		model:GetAttribute("Napping") == true
		or pose == "nap"
		or (night and isWorking(model)) -- the cafe is closed at night (F44)
	then
		-- A cat stood upright (F25) or seated (PR #260) at its station dozes where it is; one on all fours curls up.
		if pose == "upright" then
			return "doze"
		elseif seated(model) then
			if night or isWorking(model) then
				return "doze"
			end
			-- resting by day on the sitting body: washes a paw now and then
			return if Logic.licking(Workspace:GetServerTimeNow(), phaseOf(model))
				then "lick"
				else "sit"
		end
		return if Cats.isLoafing(model) then "loaf" else "nap"
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

-- Floating z's over a napping cat, drawn by the pose loop: nap.labels z's taking turns, one each time it breathes
-- out (Logic.napZ). The box hangs up and to the right of the head on screen (StudsOffset is in the camera's axes),
-- so the z's always rise up and away from the cat whichever way it is seen from.
local function addNaps(entry: Entry)
	if entry.naps ~= nil or napCount() >= Context.budget.napLabels or hasOwnZzz(entry.model) then
		return
	end
	local z = Presets.nap
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsNap"
	gui.Adornee = partNamed(entry.model, "Head") or entry.rig.body
	gui.Size = UDim2.fromScale(z.box.X, z.box.Y) -- studs
	gui.StudsOffset = z.offset
	gui.LightInfluence = 0
	gui.MaxDistance = z.maxDistance
	local labels: { TextLabel } = {}
	for i = 1, z.labels do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromScale(z.zSize.X, z.zSize.Y)
		label.Position = UDim2.fromScale(z.x, z.y)
		label.Font = Enum.Font.FredokaOne
		label.Text = if i == z.labels then "Z" else "z"
		label.TextScaled = true
		label.TextColor3 = Presets.palette.offwhite
		label.TextStrokeColor3 = DARK_WOOD
		label.TextStrokeTransparency = 0.3
		label.TextTransparency = 1
		label.Parent = gui
		table.insert(labels, label)
	end
	gui.Parent = Context.folder()
	entry.naps = labels
	entry.napGui = gui
end

-- `seconds` is the length of the cat's breath for its style, so the z's keep time with it.
local function animateNaps(labels: { TextLabel }, t: number, seconds: number)
	local z = Presets.nap
	local count = #labels
	if Context.reducedMotion() then
		for i, label in labels do
			local k = (i - 0.5) / count
			local size = z.size + (1 - z.size) * k
			label.Position = UDim2.fromScale(z.x + z.drift * k, z.y - z.rise * k)
			label.Size = UDim2.fromScale(z.zSize.X * size, z.zSize.Y * size)
			label.Rotation = 0
			label.TextTransparency = 0
			label.TextStrokeTransparency = 0.3
		end
		return
	end
	for i, label in labels do
		local x, y, size, fade, tilt = Logic.napZ(i, count, t, seconds)
		label.Position = UDim2.fromScale(x, y)
		label.Size = UDim2.fromScale(z.zSize.X * size, z.zSize.Y * size)
		label.Rotation = tilt
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
	if entry.style == "nap" or entry.style == "doze" then
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
		from = nil,
		changedAt = 0,
		phase = rng:NextNumber(0, 20),
		hissAt = nil,
		head = partNamed(model, "Head"),
		dustAt = 0,
		huffAt = 0,
		settleFor = Presets.motion.settle,
		stretchAt = nil,
		stretchSeen = nil,
		stretchWeight = 1,
		nextStretch = os.clock() + rng:NextNumber(0.3, 1) * Presets.motion.stretch.everyMax,
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

-- Gold cats sparkle (data-model section 2); the server never marks a stuck cat gold before its rescue (N30).
local function lightGold(gold: { Logic.Candidate<Model> })
	local budget = Context.budget
	local lit: { [Model]: boolean } = {}
	for _, model in Logic.nearest(gold, budget.ambientRadius, budget.goldEmitters) do
		lit[model] = true
		local emitter: ParticleEmitter? = sparkles[model]
		if emitter == nil or not emitter:IsDescendantOf(model) then -- none yet, or its body streamed out
			local body = model.PrimaryPart or partNamed(model, "Body")
			local made = if body ~= nil then Particles.attach("shiny", body) else nil
			if made ~= nil then
				if Presets.textures.goldSparkle ~= "" then
					made.Texture = Presets.textures.goldSparkle
				end
				sparkles[model] = made
			end
		else
			Particles.switchOn(emitter, "shiny")
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
	local gold: { Logic.Candidate<Model> } = {}
	for model in held do
		if model.Parent == nil then
			held[model] = nil
		elseif isGold(model) and not hidden(model) then
			table.insert(
				gold,
				{ key = model, distance = (model:GetPivot().Position - focus).Magnitude }
			)
		end
	end
	for model in known do
		if model.Parent == nil then
			known[model] = nil
			continue
		elseif hidden(model) then
			continue -- dropped below; picked again at the first pick after the mark clears
		end
		local distance = (model:GetPivot().Position - focus).Magnitude
		local retry: number? = retryAt[model]
		if retry == nil or retry <= now then
			table.insert(moving, { key = model, distance = distance })
		end
		if isGold(model) then
			table.insert(gold, { key = model, distance = distance })
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
		if model.Parent == nil or hidden(model) or (not keep[model] and entry.hissAt == nil) then
			drop(model, entry)
		else
			local style: Logic.Style = styleOf(model)
			if style ~= entry.style then
				entry.from = entry.style
				entry.changedAt = os.clock()
				entry.settleFor = Logic.settleSeconds(entry.style, style)
				entry.style = style
				dress(entry)
			end
		end
	end
	lightGold(gold)
end

local elapsed = 0

-- The stretch on top of the rest: a stray getting up from a nap to walk off, or a stray standing still now and then. A stray
-- that sets off, or hisses, mid-stretch lets it go over STRETCH_LET_GO seconds instead of snapping out of it.
local function stretch(
	entry: Entry,
	o: Logic.Offsets,
	now: number,
	serverNow: number,
	dt: number,
	fleeing: boolean
)
	local s = Presets.motion.stretch
	local still = entry.rig.speed < Presets.motion.gait.moveFrom
	-- A stray getting up from a nap on its own: the server sets StretchAt (its time) and waits for the stretch
	-- before walking it off. One seen late starts as far in; one already over plays nothing.
	local woke = entry.model:GetAttribute("StretchAt")
	if type(woke) == "number" and woke ~= entry.stretchSeen then
		entry.stretchSeen = woke
		local late = serverNow - woke
		if late < s.seconds and entry.hissAt == nil then
			entry.stretchAt = now - math.max(late, 0)
			entry.stretchWeight = 1
		end
	end
	if
		entry.stretchAt == nil
		and entry.style == "stray"
		and still
		and not fleeing
		and entry.hissAt == nil
		and now >= entry.nextStretch
	then
		entry.stretchAt = now
		entry.stretchWeight = 1
	end
	local at: number? = entry.stretchAt
	if at == nil then
		return
	end
	if not still or entry.hissAt ~= nil then
		entry.stretchWeight -= dt / STRETCH_LET_GO
	end
	local alpha = (now - at) / s.seconds
	if alpha >= 1 or entry.stretchWeight <= 0 then
		entry.stretchAt = nil
		entry.nextStretch = now + rng:NextNumber(s.every, s.everyMax)
		return
	end
	Logic.stretch(o, alpha, entry.rig.kind, entry.stretchWeight)
end

local function step(dt: number)
	elapsed += dt
	if elapsed < 1 / Context.budget.animHz then
		return
	end
	local stepDt = elapsed
	elapsed = 0
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local motion = Presets.motion
	local hiss = motion.hiss
	local gait = motion.gait
	local pant = motion.pant
	for model, entry in active do
		local rig = entry.rig
		if not Pose.read(rig) then
			drop(model, entry)
			continue
		end
		local t = now + entry.phase
		local o = Logic.idle(entry.style, t, rig.kind)
		local from: Logic.Style? = entry.from
		if from ~= nil then
			local k = (now - entry.changedAt) / entry.settleFor
			if k >= 1 then
				entry.from = nil
			else
				o = Logic.mix(Logic.idle(from, t, rig.kind), o, k * k * (3 - 2 * k))
			end
		end
		-- F40: a stray that ran from a missed catch catches its breath until FleeingUntil.
		local fleeing = false
		if entry.style == "stray" then
			local untilAt = model:GetAttribute("FleeingUntil")
			fleeing = type(untilAt) == "number" and untilAt > serverNow
		end
		if fleeing and rig.speed < gait.moveFrom then
			Logic.pant(o, t)
			local head = entry.head
			if head ~= nil and head.Parent ~= nil and now - entry.huffAt >= pant.huffEvery then
				entry.huffAt = now
				Particles.burst("huff", head.Position + head.CFrame.LookVector * 0.3, pant.huff)
			end
		else
			Logic.gait(o, rig.speed, rig.stride)
		end
		if Logic.runFactor(rig.speed) > 0.3 and now - entry.dustAt >= gait.dustEvery then
			entry.dustAt = now
			Particles.burst("kick", Pose.floor(rig).Position, gait.dust)
		end
		stretch(entry, o, now, serverNow, stepDt, fleeing)
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
		Pose.draw(rig, o, alpha)
		local yarn = entry.yarn
		if yarn ~= nil then
			yarn.CFrame = Pose.floor(entry.rig)
				* CFrame.new(o.yarn * Presets.motion.entertainer.yarnStuds, 0.3, -2)
				* CFrame.Angles(0, 0, -o.yarn * 3)
		end
		local naps = entry.naps
		if naps ~= nil then
			animateNaps(naps, t, Logic.breathSeconds(entry.style))
		end
	end
end

-- Makes a cat hiss and hop (a missed catch). A cat that is not moving yet is picked up at once, over budget
-- for a moment, so the hiss is never lost. `lag` is how many seconds ago the miss happened on the server, so the
-- hop lines up with the server's walk back.
function Cats.hiss(model: Model, lag: number?)
	if hidden(model) then
		return
	end
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
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	task.spawn(function()
		while true do
			pick()
			task.wait(PICK_SECONDS)
		end
	end)
	RunService.PreRender:Connect(step)
end

return Cats
