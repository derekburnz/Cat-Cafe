--!strict
-- Signature effects (effects list section 1; design v0.10, round 4 Q8 on 2026-10-27: "Yes thats a great idea make
-- them special because of rarity"): every Legendary and Mythical themed cat carries its own bit of magic, and a
-- gold one wears it in gold, so the rarest gold cats look the most special. Ninja Cat's eyes glow and its coat
-- twinkles, Wizard Cat's stars drift up, Fairy Cat drops a petal now and then, Astro Cat's glow shifts from galaxy
-- blue to mint, and the Super, Ice Cream, Antler, Unicorn, King and Dragon cats get a whoosh, sprinkles, leaves, a
-- horn sparkle, crown glints and sparks. The area-themed cats of F78: Jazz Cat's music notes float up off its glowing
-- saxophone, Balloon Cat's balloons shine and Gnome Cat gives off lucky sparkles (Wizard, Astro and Super Cat are
-- spare cats now; owned ones keep theirs). Which cat gets what, in which colours, is Presets.signature by CatId.
--
-- Cats come from the same replicated state as Cats.luau: the Stray and StuckCat tags, cats inside a Plot with a
-- CatId and the HeldCat a player carries. Glowing eyes are only a material, so every signature cat's eyes glow;
-- the emitters run on the nearest budget.signatureCats within Presets.signatureFx.radius, chosen twice a second.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Signature = {}

-- `stopgap`: a prop's effect sitting on the body until the prop streams in.
type Entry = {
	spec: Presets.Signature,
	emitters: { ParticleEmitter },
	stopgap: boolean,
	gold: boolean?, -- the colours the emitters wear now
	lastAt: Vector3?, -- where the cat stood at the last choice, for a `moving` effect
	nextNote: number,
}

-- A music note on its way up: `from` is where it left the saxophone.
type Note = {
	model: Model,
	gui: BillboardGui,
	anchor: Attachment,
	shapes: { Frame },
	strokes: { UIStroke },
	from: Vector3,
	born: number,
	phase: number,
}

local PICK_SECONDS = 0.5
local DARK_WOOD = Color3.fromRGB(94, 70, 52)

local entries: { [Model]: Entry } = {}
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local eyeColour: { [BasePart]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
local notes: { Note } = {}
local noteLoop: RBXScriptConnection? = nil
local noteCount = 0 -- notes made, so every other one is a pair
local started = false

-- A gold cat (F42); `Shiny` is the attribute's name on servers from before the rename.
local function isGold(model: Instance): boolean
	return model:GetAttribute("Gold") == true or model:GetAttribute("Shiny") == true
end

-- A cat this player hid with the Show other cats switch off (HiddenLocal): no effect until the mark clears.
local function hidden(model: Model): boolean
	return model:GetAttribute("HiddenLocal") == true
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

local function volume(part: BasePart): number
	local size = part.Size
	return size.X * size.Y * size.Z
end

-- The `most` biggest parts of a prop ("Prop" or "Prop2": parts named that or ending _Prop / _Prop2).
local function propParts(model: Model, prop: string, most: number): { BasePart }
	local suffix = "_" .. prop
	local found: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		local name = descendant.Name
		if descendant:IsA("BasePart") and (name == prop or name:sub(-#suffix) == suffix) then
			table.insert(found, descendant :: BasePart)
		end
	end
	table.sort(found, function(a: BasePart, b: BasePart): boolean
		return volume(a) > volume(b)
	end)
	while #found > most do
		table.remove(found)
	end
	return found
end

local function isProp(spec: Presets.Signature): boolean
	return spec.on == "Prop" or spec.on == "Prop2"
end

-- Where a cat's effect goes, and whether that is only a stopgap: its Body or Head, or the biggest parts of its
-- prop, else the body while the prop has not streamed in.
local function partsFor(model: Model, spec: Presets.Signature): ({ BasePart }, boolean)
	if isProp(spec) then
		local found = propParts(model, spec.on, spec.props or 1)
		if #found > 0 then
			return found, false
		end
	end
	local part = partNamed(model, if isProp(spec) then "Body" else spec.on) or model.PrimaryPart
	return if part ~= nil then { part } else {}, isProp(spec)
end

local function isEyeName(name: string): boolean
	local tail = name:sub(-4)
	return tail == "Eye1" or tail == "Eye2"
end

-- The biggest part of an eye piece: the iris, with the highlight the small one beside it.
local function biggest(piece: Instance): BasePart?
	local best: BasePart? = nil
	local most = 0
	for _, child in piece:GetChildren() do
		if child:IsA("BasePart") then
			local size = (child :: BasePart).Size
			local volume = size.X * size.Y * size.Z
			if volume > most then
				best, most = child :: BasePart, volume
			end
		end
	end
	return best
end

-- Each eye's iris: on the new bodies an Eye1 or Eye2 piece is a Model of the iris and its highlight; on an older
-- cat the eye is one part.
local function irises(model: Model): { BasePart }
	local found: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if not isEyeName(descendant.Name) then
			continue
		end
		if descendant:IsA("Model") then
			local part = biggest(descendant)
			if part ~= nil then
				table.insert(found, part)
			end
		elseif descendant:IsA("BasePart") then
			local parent = descendant.Parent
			if parent == nil or not (parent:IsA("Model") and isEyeName(parent.Name)) then
				table.insert(found, descendant :: BasePart)
			end
		end
	end
	return found
end

-- Glowing eyes (modelled with cats.py glow_eyes): the iris turns Neon in its own colour, or in `goldEyes` on a gold
-- cat whose eyes are its effect.
local function lightEyes(model: Model, entry: Entry)
	local spec = entry.spec
	if spec.eyes ~= true then
		return
	end
	local goldEyes = if isGold(model) then spec.goldEyes else nil
	for _, part in irises(model) do
		local own: Color3? = eyeColour[part]
		local colour = if own ~= nil then own else part.Color
		eyeColour[part] = colour
		part.Material = Enum.Material.Neon
		part.Color = goldEyes or colour
	end
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	if entries[model] ~= nil then
		return
	end
	local spec: Presets.Signature? = nil
	local catId = model:GetAttribute("CatId")
	if type(catId) == "string" then
		spec = Presets.signature[catId]
	elseif not waiting[model] then
		-- a cat whose CatId lands after the model does: looked at again once it does
		waiting[model] = true
		model:GetAttributeChangedSignal("CatId"):Once(function()
			waiting[model] = nil
			consider(model)
		end)
	end
	if spec == nil then
		return
	end
	local entry: Entry =
		{ spec = spec, emitters = {}, stopgap = false, gold = nil, lastAt = nil, nextNote = 0 }
	entries[model] = entry
	lightEyes(model, entry)
	if watched[model] then
		return -- the same model back after it left the world: its connections are still there
	end
	watched[model] = true
	local function relight()
		local current: Entry? = entries[model]
		if current ~= nil then
			lightEyes(model, current)
		end
	end
	model.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("BasePart") and isEyeName(descendant.Name) then
			relight() -- an eye streamed in
		end
	end)
	model:GetAttributeChangedSignal("Gold"):Connect(relight)
	model:GetAttributeChangedSignal("Shiny"):Connect(relight)
end

local function isPlotCat(instance: Instance): boolean
	return instance:IsA("Model") and instance:GetAttribute("CatId") ~= nil
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

local function watchCharacter(character: Model)
	local function onChild(child: Instance)
		if child.Name == "HeldCat" then
			consider(child)
		end
	end
	for _, child in character:GetChildren() do
		onChild(child)
	end
	character.ChildAdded:Connect(onChild)
end

local function watchPlayer(player: Player)
	if player.Character ~= nil then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

local function switchOff(entry: Entry)
	for _, emitter in entry.emitters do
		emitter.Enabled = false
	end
end

-- Notes ------------------------------------------------------------------------------------------------------

-- A drawn music note in `colour`, `size` studs tall: a tilted round head, a stem and a flag, or as a pair two heads
-- and stems joined by a beam.
local function drawNote(colour: Color3, pair: boolean): (BillboardGui, { Frame }, { UIStroke })
	local n = Presets.notes
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsNote"
	gui.Size = UDim2.fromScale(n.size * (if pair then 1 else 0.7), n.size)
	gui.LightInfluence = 0
	gui.MaxDistance = n.maxDistance
	local shapes: { Frame } = {}
	local strokes: { UIStroke } = {}
	local function shape(x: number, y: number, w: number, h: number, turn: number, round: boolean)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(x, y)
		frame.Size = UDim2.fromScale(w, h)
		frame.Rotation = turn
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = colour
		if round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = frame
		end
		local stroke = Instance.new("UIStroke")
		stroke.Color = DARK_WOOD
		stroke.Thickness = 1
		stroke.Parent = frame
		frame.Parent = gui
		table.insert(shapes, frame)
		table.insert(strokes, stroke)
	end
	if pair then
		shape(0.24, 0.84, 0.4, 0.22, -20, true)
		shape(0.74, 0.74, 0.4, 0.22, -20, true)
		shape(0.41, 0.47, 0.07, 0.7, 0, false)
		shape(0.91, 0.37, 0.07, 0.7, 0, false)
		shape(0.66, 0.08, 0.56, 0.1, -11, false)
	else
		shape(0.33, 0.84, 0.58, 0.22, -20, true)
		shape(0.58, 0.46, 0.1, 0.72, 0, false)
		shape(0.76, 0.2, 0.42, 0.09, 40, false)
	end
	return gui, shapes, strokes
end

local function stepNotes()
	local n = Presets.notes
	local now = os.clock()
	local i = 1
	while i <= #notes do
		local note = notes[i]
		local age = now - note.born
		if age >= n.seconds or note.model.Parent == nil then
			note.gui:Destroy()
			note.anchor:Destroy()
			notes[i] = notes[#notes]
			notes[#notes] = nil
		else
			local offset, shown = Logic.note(age, note.phase)
			note.anchor.Position = note.from + offset
			for _, frame in note.shapes do
				frame.BackgroundTransparency = 1 - shown
			end
			for _, stroke in note.strokes do
				stroke.Transparency = 1 - shown * 0.6
			end
			i += 1
		end
	end
	if #notes == 0 and noteLoop ~= nil then
		noteLoop:Disconnect()
		noteLoop = nil
	end
end

-- The next note off a Jazz Cat's saxophone, when one is due and it has fewer than `most` in the air.
local function playNote(model: Model, entry: Entry, colors: { Color3 })
	local n = Presets.notes
	local now = os.clock()
	local first: ParticleEmitter? = entry.emitters[1]
	local sax = if first ~= nil then first.Parent else nil
	if now < entry.nextNote or sax == nil or not sax:IsA("BasePart") or #colors == 0 then
		return
	end
	local alive = 0
	for _, note in notes do
		if note.model == model then
			alive += 1
		end
	end
	if alive >= n.most then
		return
	end
	entry.nextNote = now + n.every
	noteCount += 1
	local part = sax :: BasePart
	local from = part.Position + Vector3.new(0, part.Size.Y / 2 + n.above, 0)
	local gui, shapes, strokes = drawNote(colors[(noteCount - 1) % #colors + 1], noteCount % 2 == 0)
	local anchor = Particles.anchor("EffectsNote", from)
	gui.Adornee = anchor
	gui.Parent = Context.folder()
	table.insert(notes, {
		model = model,
		gui = gui,
		anchor = anchor,
		shapes = shapes,
		strokes = strokes,
		from = from,
		born = now,
		phase = noteCount * 1.7,
	})
	if noteLoop == nil then
		noteLoop = RunService.PreRender:Connect(stepNotes)
	end
end

-- Whether a cat's emitters are all still on it, and where they belong (a prop that has streamed in since).
local function intact(model: Model, entry: Entry): boolean
	if #entry.emitters == 0 then
		return false
	end
	for _, emitter in entry.emitters do
		if not emitter:IsDescendantOf(model) then
			return false
		end
	end
	return not (entry.stopgap and #propParts(model, entry.spec.on, 1) > 0)
end

-- Shows a cat's effect: its emitters made on the right parts the first time (or again once a part streamed out and
-- back), in the gold colours on a gold cat, and on unless it only runs while the cat moves and it stood still.
local function show(model: Model, entry: Entry, at: Vector3)
	local spec = entry.spec
	if not intact(model, entry) then
		for _, emitter in entry.emitters do
			emitter:Destroy()
		end
		table.clear(entry.emitters)
		local preset: Presets.EmitterPreset? = Presets.emitters[spec.emitter]
		local parts, stopgap = partsFor(model, spec)
		if #parts == 0 or preset == nil then
			return -- no body yet (streaming); tried again at the next choice
		end
		for _, part in parts do
			local fresh = Particles.make(preset)
			fresh.Name = "Signature"
			fresh.Parent = part
			table.insert(entry.emitters, fresh)
		end
		entry.stopgap = stopgap
		entry.gold = nil
	end
	local gold = isGold(model)
	local colors = Logic.signatureColors(model:GetAttribute("CatId"), gold) or spec.colors
	if entry.gold ~= gold then
		for _, emitter in entry.emitters do
			Particles.paint(emitter, colors)
		end
		entry.gold = gold
	end
	local lastAt = entry.lastAt
	entry.lastAt = at
	if spec.moving == true then
		local moved = lastAt ~= nil and (at - lastAt).Magnitude >= Presets.signatureFx.movedStuds
		if not moved then
			switchOff(entry)
			return
		end
	end
	for _, emitter in entry.emitters do
		Particles.switchOn(emitter, spec.emitter)
		emitter.Rate /= #entry.emitters -- a prop's parts share one cat's rate
	end
	if spec.notes == true and not entry.stopgap then
		playNote(model, entry, colors)
	end
end

local function pick()
	local focus = Context.focus()
	if focus == nil then
		return
	end
	local candidates: { Logic.Candidate<Model> } = {}
	for model, entry in entries do
		if model.Parent == nil then
			entries[model] = nil
		elseif hidden(model) then
			switchOff(entry)
		else
			table.insert(
				candidates,
				{ key = model, distance = (model:GetPivot().Position - focus).Magnitude }
			)
		end
	end
	local shown: { [Model]: boolean } = {}
	for _, model in
		Logic.nearest(candidates, Presets.signatureFx.radius, Context.budget.signatureCats)
	do
		local entry: Entry? = entries[model]
		if entry ~= nil then
			shown[model] = true
			show(model, entry, model:GetPivot().Position)
		end
	end
	for model, entry in entries do
		if not shown[model] then
			switchOff(entry)
			entry.lastAt = nil
		end
	end
end

function Signature.start()
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
end

return Signature
