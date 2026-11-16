--!strict
-- The Dragon Keep's set looks (Derek 2026-11-15 18:36: sets get cosmetic effects on top of their bonuses). A player
-- with a card set lit wears one soft look per family, bigger at level 5 than at 3, so everyone nearby sees it:
--   flame  warm embers rising off the body          claw   quick steel glints
--   wing   pale feather motes drifting down         hoard  gold coin glints falling
--   heart  pink sparkles floating up                crown  a gold sparkle halo over the head
-- Source, listening only: the player's `DragonSets` attribute (DragonKeepService.applyReach, #4575), a comma list like
-- "flame5,claw3" (family and level), nil with no set lit or the dragonKeep switch off. The nearest
-- budget.potionGlows players within Presets.dragonSets.radius show theirs, your own first; Low performance shows
-- none. Numbers in Presets.dragonSets and Presets.emitters.dragonSet*.

local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local KeepSets = {}

type Worn = { [string]: { emitter: ParticleEmitter, level: number } }

local worn: { [Model]: Worn } = {}
local started = false

-- Pure: the families and levels in a `DragonSets` value: only known families, level 5 at 5 or more, else 3 (a lit
-- set is level 3 at least). Anything that is not a string reads as no sets.
function KeepSets.parse(value: unknown): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) ~= "string" or value == "" then
		return out
	end
	local families = Presets.dragonSets.families
	for _, entry in string.split(value, ",") do
		local family, digits = string.match(entry, "^%s*(%a+)(%d+)%s*$")
		local level = tonumber(digits)
		if family ~= nil and level ~= nil and families[family] ~= nil and level >= 3 then
			local at = if level >= 5 then 5 else 3
			out[family] = math.max(out[family] or 0, at)
		end
	end
	return out
end

-- Pure: a look's rate and size scale at `level`: 1 at 3, the `big` numbers at 5.
function KeepSets.scale(level: number): (number, number)
	local p = Presets.dragonSets
	if level >= 5 then
		return p.bigRate, p.bigSize
	end
	return 1, 1
end

local function partOf(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name)
	if part ~= nil and part:IsA("BasePart") then
		return part :: BasePart
	end
	return nil
end

local function clear(character: Model)
	local looks = worn[character]
	if looks ~= nil then
		for _, look in looks do
			look.emitter:Destroy()
		end
		worn[character] = nil
	end
end

local function off(character: Model)
	local looks = worn[character]
	if looks ~= nil then
		for _, look in looks do
			look.emitter.Enabled = false
		end
	end
end

-- Puts `sets` on `character`: one emitter per family (the crown's on the head, the rest on the body), made once,
-- sized and rated for its level, and any family no longer lit switched off.
local function wear(character: Model, sets: { [string]: number })
	local root = partOf(character, "HumanoidRootPart")
	if root == nil then
		return
	end
	local p = Presets.dragonSets
	local looks: Worn = worn[character] or {}
	worn[character] = looks
	for family, look in looks do
		if sets[family] == nil then
			look.emitter.Enabled = false
		end
	end
	for family, level in sets do
		local name = p.families[family]
		local preset: Presets.EmitterPreset? = Presets.emitters[name]
		if preset ~= nil then
			local look = looks[family]
			if look == nil or look.emitter.Parent == nil then
				local holder: BasePart = if p.onHead[family]
					then partOf(character, "Head") or root
					else root
				local emitter = Particles.make(preset)
				emitter.Name = "DragonSet_" .. family
				emitter.Parent = holder
				look = { emitter = emitter, level = 0 }
				looks[family] = look
			end
			local made = look :: { emitter: ParticleEmitter, level: number }
			local rate, size = KeepSets.scale(level)
			if made.level ~= level then
				made.level = level
				made.emitter.Size = NumberSequence.new(preset.size[1] * size, preset.size[2] * size)
			end
			made.emitter.Rate = preset.rate * rate * Context.budget.rateScale
			made.emitter.Enabled = true
		end
	end
end

local function pick()
	local me = Players.LocalPlayer
	local candidates: { Logic.Candidate<Model> } = {}
	local lit: { [Model]: { [string]: number } } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then partOf(character, "HumanoidRootPart") else nil
		if character ~= nil and root ~= nil then
			local sets = KeepSets.parse(player:GetAttribute("DragonSets"))
			if next(sets) ~= nil then
				lit[character] = sets
				local distance = if player == me then 0 else Context.distance(root.Position)
				table.insert(candidates, { key = character, distance = distance })
			end
		end
	end
	local chosen: { [Model]: boolean } = {}
	for _, character in
		Logic.nearest(candidates, Presets.dragonSets.radius, Context.budget.potionGlows)
	do
		chosen[character] = true
	end
	for character in worn do
		if character.Parent == nil then
			clear(character)
		elseif not chosen[character] then
			off(character)
		end
	end
	for character in chosen do
		wear(character, lit[character])
	end
end

function KeepSets.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local warned = false
		while true do
			-- one odd character must not end every look for the session: report it once and keep going
			local ok, problem = pcall(function(): string?
				pick()
				return nil
			end)
			if not ok and not warned then
				warned = true
				warn("[Effects] KeepSets: " .. tostring(problem))
			end
			task.wait(Presets.dragonSets.pickEvery)
		end
	end)
end

return KeepSets
