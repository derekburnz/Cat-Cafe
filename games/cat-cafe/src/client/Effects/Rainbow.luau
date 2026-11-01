--!strict
-- Rainbow coats (F99, rainbow-coat.md section 2; Derek 2026-10-30 00:24: "make it obvious looking that its good and
-- better then gold"). Gold sparkles; rainbow moves, glows and leaves a trail. A rainbow cat's own parts take six
-- bright hues that flow from its nose to its tail every 3 seconds, with stripes and patches still showing as darker
-- bands; its eyes, nose, mouth, blush, props and outfit keep their own colours. The nearest few also glow, wear an
-- outline in the band colour and drop rainbow sparkles behind them while they walk or are carried; the rest show
-- still bands. When a rainbow stray spawns, a bundle of rainbow beams rises from it for 3 seconds. Reduce Motion
-- stills the bands and drops the trail and beams; the glow and outline stay.
--
-- Source: the server's `Variant` attribute on cat models ("rainbow"), on strays, carried, working and resting cats
-- alike, and `RainbowSpawned(areaId, catId)` for the beam, hooked when it appears (it only exists once the server has
-- F99). Each part's own colour is kept and comes back when the coat goes. Only this client's copy changes. Numbers in
-- Presets.rainbow and the budget's rainbowCats and rainbowOutlines; Config.RainbowAnimateMax caps the flowing ones.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Rainbow = {}

-- One coat part: its own colour, how far back from the nose it sits (0 to 1) and how bright its band is.
type Coat = { part: BasePart, phase: number, shade: number }

type Cat = {
	model: Model,
	coats: { Coat },
	parts: number, -- BaseParts in the model when it was read; more streaming in means read it again
	root: BasePart?,
	flowing: boolean,
	still: boolean, -- painted with still bands since it last flowed
	holder: Attachment?,
	trail: ParticleEmitter?,
	outline: Highlight?,
	lastAt: Vector3?,
}

local cats: { [Model]: Cat } = {}
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local originals: { [BasePart]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
local flowingNow: { Cat } = {}
local wanted: { [string]: boolean } = {}
for _, piece in Presets.rainbow.pieces do
	wanted[piece] = true
end
local lastStep = 0
local started = false

local function isRainbow(model: Model): boolean
	return model:GetAttribute("Variant") == "rainbow"
end

local function longest(size: Vector3): number
	return math.max(size.X, size.Y, size.Z)
end

-- The coat piece a part belongs to (the end of its name, `CatCafe_Cat_Tabby_Head` is the Head), or nil for the eyes,
-- props, outfits and anything else.
local function pieceOf(part: BasePart): string?
	local tail = part.Name:match("_([^_]+)$") or part.Name
	return if wanted[tail] then tail else nil
end

local function countParts(model: Model): number
	local n = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Reads a cat's coat as it stands: the coat parts by piece, less each piece's face details, and where each sits.
local function bind(model: Model): Cat
	local r = Presets.rainbow
	local pivot = model:GetPivot()
	local byPiece: { [string]: { BasePart } } = {}
	local count = 0
	local body: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			count += 1
			local piece = pieceOf(part)
			if piece ~= nil then
				local list = byPiece[piece]
				if list == nil then
					list = {}
					byPiece[piece] = list
				end
				table.insert(list :: { BasePart }, part)
				if
					piece == "Body"
					and (body == nil or longest(part.Size) > longest((body :: BasePart).Size))
				then
					body = part
				end
			end
		end
	end
	local coats: { Coat } = {}
	local depth: { number } = {}
	local front: number, back: number, lightest: number = math.huge, -math.huge, 0
	for _, list in byPiece do
		local biggest = 0
		for _, part in list do
			biggest = math.max(biggest, longest(part.Size))
		end
		for _, part in list do
			if not Logic.rainbowKeeps(longest(part.Size), biggest, r.keepShare) then
				local own = originals[part] or part.Color
				originals[part] = own
				local z: number = pivot:PointToObjectSpace(part.Position).Z
				front, back = math.min(front, z), math.max(back, z)
				lightest = math.max(lightest, Logic.lightness(own))
				table.insert(coats, { part = part, phase = 0, shade = 1 })
				table.insert(depth, z)
			end
		end
	end
	for i, coat in coats do
		local own = originals[coat.part] or coat.part.Color
		coat.phase = Logic.rainbowPhase(depth[i] or 0, front, back)
		coat.shade = Logic.rainbowShade(Logic.lightness(own), lightest, r.least)
	end
	return {
		model = model,
		coats = coats,
		parts = count,
		root = model.PrimaryPart or body,
		flowing = false,
		still = false,
		holder = nil,
		trail = nil,
		outline = nil,
		lastAt = nil,
	}
end

local function bandAt(t: number, phase: number): Color3
	local r = Presets.rainbow
	return Logic.rainbowAt(r.hues, Logic.rainbowHue(t, phase, r.period, r.spread))
end

-- Colours the coat as the bands stand `t` seconds in (0 for still bands).
local function paint(cat: Cat, t: number)
	for _, coat in cat.coats do
		local part = coat.part
		if part.Parent ~= nil then
			local hue = bandAt(t, coat.phase)
			local s = coat.shade
			part.Color = Color3.new(hue.R * s, hue.G * s, hue.B * s)
		end
	end
	local outline = cat.outline
	if outline ~= nil then
		outline.OutlineColor = bandAt(t, 0.5)
	end
end

local function setOutline(cat: Cat, on: boolean)
	if on then
		if cat.outline == nil then
			local made = Instance.new("Highlight")
			made.Name = "EffectsRainbowOutline"
			made.FillTransparency = 1
			made.OutlineTransparency = Presets.rainbow.outline
			made.OutlineColor = bandAt(0, 0.5)
			made.DepthMode = Enum.HighlightDepthMode.Occluded
			made.Parent = cat.model
			cat.outline = made
		end
		return
	end
	local outline: Highlight? = cat.outline
	if outline ~= nil then
		outline:Destroy()
		cat.outline = nil
	end
end

-- Starts a chosen cat flowing: its glow and trail go on its body.
local function startFlowing(cat: Cat)
	local root = cat.root
	if root == nil or root.Parent == nil then
		return
	end
	local g = Presets.rainbow.glow
	cat.flowing = true
	local holder = Instance.new("Attachment")
	holder.Name = "EffectsRainbow"
	holder.Parent = root
	local light = Instance.new("PointLight")
	light.Color = g.color
	light.Range = g.range
	light.Brightness = g.brightness
	light.Shadows = false
	light.Parent = holder
	local trail = Particles.attach("rainbowTrail", holder)
	if trail ~= nil then
		trail.Enabled = false
	end
	cat.holder, cat.trail = holder, trail
	cat.lastAt = root.Position
end

-- A cat no longer chosen: still bands, no glow, trail or outline.
local function stopFlowing(cat: Cat)
	cat.flowing = false
	local holder = cat.holder
	if holder ~= nil then
		holder:Destroy()
	end
	cat.holder, cat.trail, cat.lastAt = nil, nil, nil
	setOutline(cat, false)
	paint(cat, 0)
	cat.still = true
end

-- The coat goes: every part gets its own colour back.
local function drop(cat: Cat)
	stopFlowing(cat)
	for _, coat in cat.coats do
		local own: Color3? = originals[coat.part]
		if own ~= nil and coat.part.Parent ~= nil then
			coat.part.Color = own
		end
		originals[coat.part] = nil
	end
	cats[cat.model] = nil
end

local function update(model: Model)
	local cat: Cat? = cats[model]
	if isRainbow(model) and model:IsDescendantOf(Workspace) then
		if cat == nil then
			local made = bind(model)
			cats[model] = made
			paint(made, 0)
			made.still = true
		end
	elseif cat ~= nil then
		drop(cat)
	end
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	if watched[model] then
		return
	end
	-- every cat model carries Gold (and Variant from F99); nothing else does
	if model:GetAttribute("Variant") == nil and model:GetAttribute("Gold") == nil then
		return
	end
	watched[model] = true
	model:GetAttributeChangedSignal("Variant"):Connect(function()
		update(model)
	end)
	update(model)
end

-- Every `pick` seconds: the nearest rainbow cats flow, glow and trail; the nearest of those get the outline.
local function pick()
	local r = Presets.rainbow
	local budget = Context.budget
	local cap = (Config :: any).RainbowAnimateMax
	local most = if type(cap) == "number"
		then math.min(budget.rainbowCats, cap)
		else budget.rainbowCats
	local candidates: { Logic.Candidate<Cat> } = {}
	for model, cat in cats do
		if not model:IsDescendantOf(Workspace) then
			drop(cat)
			continue
		end
		if countParts(model) ~= cat.parts then
			-- more of it streamed in (or out): read it again, keeping its glow and trail
			local again = bind(model)
			again.flowing, again.holder, again.trail = cat.flowing, cat.holder, cat.trail
			again.outline, again.lastAt = cat.outline, cat.lastAt
			cats[model] = again
			paint(again, 0)
			again.still = true
			cat = again
		end
		local root = cat.root
		if model:GetAttribute("HiddenLocal") ~= true and root ~= nil and root.Parent ~= nil then
			table.insert(candidates, { key = cat, distance = Context.distance(root.Position) })
		end
	end
	local chosen = Logic.nearest(candidates, r.within, most)
	local on: { [Cat]: boolean } = {}
	local reduced = Context.reducedMotion()
	for i, cat in chosen do
		on[cat] = true
		if not cat.flowing then
			startFlowing(cat)
		end
		setOutline(cat, i <= budget.rainbowOutlines)
		local root, trail = cat.root, cat.trail
		if root ~= nil and trail ~= nil then
			local at = root.Position
			local last = cat.lastAt
			local speed = if last ~= nil then (at - last).Magnitude / r.pick else 0
			cat.lastAt = at
			trail.Enabled = speed > r.moving and not reduced
		end
	end
	for _, cat in cats do
		if cat.flowing and not on[cat] then
			stopFlowing(cat)
		end
	end
	flowingNow = chosen
end

local function step()
	local now = os.clock()
	if now - lastStep < 1 / math.min(Presets.rainbow.hz, Context.budget.animHz) then
		return
	end
	lastStep = now
	local reduced = Context.reducedMotion()
	for _, cat in flowingNow do
		if cat.flowing and cat.model.Parent ~= nil then
			if not reduced then
				paint(cat, now)
				cat.still = false
			elseif not cat.still then
				paint(cat, 0)
				cat.still = true
			end
		end
	end
end

-- Six thin beams, one in each hue, rising round `ground` for a few seconds (none with Reduce Motion).
function Rainbow.beam(ground: Vector3)
	local r = Presets.rainbow
	local b = r.beam
	for i, hue in r.hues do
		local angle = 2 * math.pi * i / #r.hues
		local at = ground + Vector3.new(math.cos(angle) * b.ring, 0, math.sin(angle) * b.ring)
		Particles.beam(at, hue, b.width, b.height, b.seconds)
	end
end

-- The newest rainbow stray of `catId`, or nil while it has not streamed in.
local function newestStray(catId: string): Model?
	local best: Model? = nil
	local bestAt = -math.huge
	for _, instance in CollectionService:GetTagged("Stray") do
		if
			instance:IsA("Model")
			and isRainbow(instance :: Model)
			and instance:GetAttribute("CatId") == catId
		then
			local at = instance:GetAttribute("SpawnedAt")
			local when = if type(at) == "number" then at else 0
			if when > bestAt then
				best, bestAt = instance :: Model, when
			end
		end
	end
	return best
end

-- RainbowSpawned: the beam from the new stray, for anyone close enough to see it, tried a few times while it
-- streams in.
local function spawned(catId: unknown)
	if type(catId) ~= "string" then
		return
	end
	task.spawn(function()
		local b = Presets.rainbow.beam
		for _ = 1, 4 do
			local model = newestStray(catId)
			if model ~= nil then
				local frame, size = model:GetBoundingBox()
				local ground = frame.Position - Vector3.new(0, size.Y / 2, 0)
				if Context.distance(ground) <= b.within then
					Rainbow.beam(ground)
				end
				return
			end
			task.wait(0.5)
		end
	end)
end

function Rainbow.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		while true do
			pick()
			task.wait(Presets.rainbow.pick)
		end
	end)
	RunService.Heartbeat:Connect(step)
	-- RainbowSpawned(areaId, catId) only exists once the server has F99, so it is hooked whenever it appears.
	task.spawn(function()
		local folder = Remotes.folder()
		local function hook(child: Instance): boolean
			if child.Name ~= "RainbowSpawned" or not child:IsA("RemoteEvent") then
				return false
			end
			(child :: RemoteEvent).OnClientEvent:Connect(function(_areaId: unknown, catId: unknown)
				spawned(catId)
			end)
			return true
		end
		local existing = folder:FindFirstChild("RainbowSpawned")
		if existing ~= nil and hook(existing) then
			return
		end
		local waiting: RBXScriptConnection? = nil
		waiting = folder.ChildAdded:Connect(function(child: Instance)
			if hook(child) and waiting ~= nil then
				waiting:Disconnect()
			end
		end)
	end)
end

return Rainbow
