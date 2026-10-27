--!strict
-- Potions while they run (F64, data-model 12b): drinking one bursts sparkles in its colour round you with a small
-- ring at your feet, and while it runs a glow of its own kind stays on the drinker so everyone nearby can see it.
-- Tip: gold glints drifting up off the body; Lucky: green and mint glints all round; Swift: light blue wisps left
-- behind at the feet; Steady Paw: soft mint sparkles on the paws; and the quest potions (F73): Big Tip a brighter
-- stream of gold, Gold Rush gold glints all round, Quick Bait food crumbs falling from the paws (Presets.potions).
--
-- Sources: each character's `ActivePotions` (data-model 13: the running ids, oldest drink first; the newest shows)
-- and this player's own ProfileSync `buffs` for the drink pop. The nearest budget.potionGlows drinkers within
-- potionFx.radius show their glow, your own first; Low performance shows none (the HUD timer still does).
-- Listening only.

local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Potions = {}

-- `stopgap`: the hands had not streamed in, so it sits on the root part until they do.
type Glow = { kind: string, emitters: { ParticleEmitter }, made: { Instance }, stopgap: boolean }

local glows: { [Model]: Glow } = {}
local lastBuffs: unknown = nil -- `buffs` at the last ProfileSync that had them
local started = false

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- Just above the ground under a character, relative to its root part.
local function feetOffset(character: Model, root: BasePart): Vector3
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	return Vector3.new(0, 0.2 - root.Size.Y / 2 - hip, 0)
end

-- The two hands of an R15 body, else the arms of an R6 one.
local function handsOf(character: Model): { BasePart }
	for _, pair in { { "LeftHand", "RightHand" }, { "Left Arm", "Right Arm" } } do
		local found: { BasePart } = {}
		for _, name in pair do
			local part = character:FindFirstChild(name)
			if part ~= nil and part:IsA("BasePart") then
				table.insert(found, part :: BasePart)
			end
		end
		if #found > 0 then
			return found
		end
	end
	return {}
end

local function clear(character: Model)
	local glow: Glow? = glows[character]
	if glow ~= nil then
		for _, instance in glow.made do
			instance:Destroy()
		end
		glows[character] = nil
	end
end

-- A kind's emitters on a character, made off; nil while its body has not streamed in.
local function build(character: Model, kind: string): Glow?
	local spec = Presets.potions[kind]
	local root = rootOf(character)
	if spec == nil or root == nil then
		return nil
	end
	local preset: Presets.EmitterPreset? = Presets.emitters[spec.emitter]
	if preset == nil then
		return nil
	end
	local made: { Instance } = {}
	local parents: { Instance } = {}
	if spec.on == "Feet" then
		local feet = Instance.new("Attachment")
		feet.Name = "PotionFeet"
		feet.Position = feetOffset(character, root)
		feet.Parent = root
		table.insert(made, feet)
		table.insert(parents, feet)
	elseif spec.on == "Hands" then
		for _, hand in handsOf(character) do
			table.insert(parents, hand)
		end
	end
	local stopgap = #parents == 0 and spec.on == "Hands"
	if #parents == 0 then
		table.insert(parents, root)
	end
	local emitters: { ParticleEmitter } = {}
	for _, parent in parents do
		local emitter = Particles.make(preset)
		emitter.Name = "Potion"
		emitter.Parent = parent
		table.insert(emitters, emitter)
		table.insert(made, emitter)
	end
	return { kind = kind, emitters = emitters, made = made, stopgap = stopgap }
end

-- Whether every emitter is still on the character (a part that streams out takes its emitter with it) and on the
-- place it belongs (hands that have streamed in since).
local function intact(glow: Glow, character: Model): boolean
	if glow.stopgap and #handsOf(character) > 0 then
		return false
	end
	for _, emitter in glow.emitters do
		if not emitter:IsDescendantOf(character) then
			return false
		end
	end
	return true
end

local function show(glow: Glow)
	local spec = Presets.potions[glow.kind]
	for _, emitter in glow.emitters do
		Particles.switchOn(emitter, spec.emitter)
		emitter.Rate /= #glow.emitters -- the two hands share one glow's rate
	end
end

local function hide(glow: Glow)
	for _, emitter in glow.emitters do
		emitter.Enabled = false
	end
end

local function pick()
	local me = Players.LocalPlayer
	local kinds: { [Model]: string } = {}
	local candidates: { Logic.Candidate<Model> } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil then
			continue
		end
		local kind = Logic.newestPotion(character:GetAttribute("ActivePotions"))
		local root = rootOf(character)
		if kind ~= nil and root ~= nil then
			kinds[character] = kind
			-- your own glow first
			local distance = if player == me then 0 else Context.distance(root.Position)
			table.insert(candidates, { key = character, distance = distance })
		end
	end
	local chosen: { [Model]: boolean } = {}
	for _, character in
		Logic.nearest(candidates, Presets.potionFx.radius, Context.budget.potionGlows)
	do
		chosen[character] = true
	end
	for character, glow in glows do
		if
			character.Parent == nil
			or kinds[character] ~= glow.kind
			or not intact(glow, character)
		then
			clear(character) -- gone, a new kind or the potion ran out
		elseif not chosen[character] then
			hide(glow)
		end
	end
	for character in chosen do
		local glow: Glow? = glows[character]
		if glow == nil then
			glow = build(character, kinds[character])
			if glow ~= nil then
				glows[character] = glow
			end
		end
		if glow ~= nil then
			show(glow)
		end
	end
end

-- The drink pop: sparkles in the potion's colour at your chest and a small ring at your feet.
local function drank(kind: string)
	local spec = Presets.potions[kind]
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then rootOf(character) else nil
	if spec == nil or character == nil or root == nil then
		return
	end
	local fx = Presets.potionFx
	Particles.burst(
		"catchSparkle",
		root.Position + Vector3.new(0, fx.chest, 0),
		fx.sparkles,
		spec.colour
	)
	Particles.ring(
		root.Position + feetOffset(character, root),
		spec.colour,
		fx.ring,
		fx.ringSeconds
	)
end

function Potions.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local buffs = (state :: { [string]: unknown }).buffs
		if type(buffs) ~= "table" then
			return -- a partial sync without them
		end
		local kind = Logic.potionDrunk(lastBuffs, buffs)
		lastBuffs = buffs
		if kind ~= nil then
			drank(kind)
		end
	end)
	task.spawn(function()
		local warned = false
		while true do
			-- one odd character must not end every glow for the session: report it once and keep going
			local ok, problem = pcall(function()
				pick()
			end)
			if not ok and not warned then
				warned = true
				warn("[Effects] Potions: " .. tostring(problem))
			end
			task.wait(Presets.potionFx.pickEvery)
		end
	end)
end

return Potions
