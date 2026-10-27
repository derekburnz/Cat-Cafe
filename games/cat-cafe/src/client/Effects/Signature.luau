--!strict
-- Signature effects (effects list section 1; design v0.10, round 4 Q8 on 2026-10-27: "Yes thats a great idea make
-- them special because of rarity"): every Legendary and Mythical themed cat carries its own bit of magic, and a
-- gold one wears it in gold, so the rarest gold cats look the most special. Ninja Cat's eyes glow and its coat
-- twinkles, Wizard Cat's stars drift up, Fairy Cat drops a petal now and then, Astro Cat's glow shifts from galaxy
-- blue to mint, and the Super, Ice Cream, Antler, Unicorn, King and Dragon cats get a whoosh, sprinkles, leaves, a
-- horn sparkle, crown glints and sparks. Which cat gets what, in which colours, is Presets.signature by CatId.
--
-- Cats come from the same replicated state as Cats.luau: the Stray and StuckCat tags, cats inside a Plot with a
-- CatId and the HeldCat a player carries. Glowing eyes are only a material, so every signature cat's eyes glow;
-- the emitters run on the nearest budget.signatureCats within Presets.signatureFx.radius, chosen twice a second.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Signature = {}

type Entry = {
	spec: Presets.Signature,
	emitter: ParticleEmitter?,
	gold: boolean?, -- the colours the emitter wears now
	lastAt: Vector3?, -- where the cat stood at the last choice, for a `moving` effect
}

local PICK_SECONDS = 0.5

local entries: { [Model]: Entry } = {}
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local eyeColour: { [BasePart]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
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
	local entry: Entry = { spec = spec, emitter = nil, gold = nil, lastAt = nil }
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
	local emitter = entry.emitter
	if emitter ~= nil then
		emitter.Enabled = false
	end
end

-- Shows a cat's effect: its emitter made on the right part the first time (or again once that part streamed out
-- and back), in the gold colours on a gold cat, and on unless it only runs while the cat moves and it stood still.
local function show(model: Model, entry: Entry, at: Vector3)
	local spec = entry.spec
	local emitter = entry.emitter
	if emitter == nil or not emitter:IsDescendantOf(model) then
		local part = partNamed(model, spec.on) or model.PrimaryPart
		local preset: Presets.EmitterPreset? = Presets.emitters[spec.emitter]
		if part == nil or preset == nil then
			return -- no body yet (streaming); tried again at the next choice
		end
		local fresh = Particles.make(preset)
		fresh.Name = "Signature"
		fresh.Parent = part
		entry.emitter = fresh
		entry.gold = nil
		emitter = fresh
	end
	local made = emitter :: ParticleEmitter
	local gold = isGold(model)
	if entry.gold ~= gold then
		local colors = Logic.signatureColors(model:GetAttribute("CatId"), gold)
		Particles.paint(made, colors or spec.colors)
		entry.gold = gold
	end
	local lastAt = entry.lastAt
	entry.lastAt = at
	if spec.moving == true then
		local moved = lastAt ~= nil and (at - lastAt).Magnitude >= Presets.signatureFx.movedStuds
		if not moved then
			made.Enabled = false
			return
		end
	end
	Particles.switchOn(made, spec.emitter)
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
