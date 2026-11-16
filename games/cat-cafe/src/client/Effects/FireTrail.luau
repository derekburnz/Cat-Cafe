--!strict
-- Fire Trail, the Dragon Keep's look-only Wing card (#4558; Derek 2026-11-15: "the cosmetic ones that add trails are
-- not even working"): while a player with the card slotted walks on the ground, small warm embers rise from their
-- heels, so everyone nearby sees it. It stops when they stand still or leave the ground.
--
-- Sources, listening only: the player's `FireTrail` attribute (DragonKeepService sets it from the slotted cards while
-- the dragonKeep switch is on) and the Humanoid's own MoveDirection and FloorMaterial. The nearest
-- budget.potionGlows walkers within Presets.fireTrail.radius show it, your own first; Low performance shows none.
-- Numbers in Presets.fireTrail and Presets.emitters.fireTrail.

local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local FireTrail = {}

type Trail = { feet: Attachment, emitter: ParticleEmitter }

local trails: { [Model]: Trail } = {}
local started = false

-- Whether the embers run: the card is on and the walker moves on the ground at `least` of full speed or more.
function FireTrail.on(card: boolean, moving: number, grounded: boolean, least: number): boolean
	if moving ~= moving then
		return false
	end
	return card and grounded and moving >= least
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

local function clear(character: Model)
	local trail: Trail? = trails[character]
	if trail ~= nil then
		trail.feet:Destroy()
		trails[character] = nil
	end
end

-- The embers' emitter at the heels of a character, made off; nil while its body has not streamed in.
local function build(character: Model): Trail?
	local root = rootOf(character)
	local preset: Presets.EmitterPreset? = Presets.emitters.fireTrail
	if root == nil or preset == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	local feet = Instance.new("Attachment")
	feet.Name = "FireTrail"
	feet.Position =
		Vector3.new(0, Presets.fireTrail.lift - root.Size.Y / 2 - hip, Presets.fireTrail.behind)
	feet.Parent = root
	local emitter = Particles.make(preset)
	emitter.Name = "Embers"
	emitter.Parent = feet
	return { feet = feet, emitter = emitter }
end

local function running(player: Player, character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return false
	end
	return FireTrail.on(
		player:GetAttribute("FireTrail") == true,
		humanoid.MoveDirection.Magnitude,
		humanoid.FloorMaterial ~= Enum.Material.Air,
		Presets.fireTrail.moving
	)
end

local function pick()
	local me = Players.LocalPlayer
	local candidates: { Logic.Candidate<Model> } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then rootOf(character) else nil
		if character ~= nil and root ~= nil and running(player, character) then
			local distance = if player == me then 0 else Context.distance(root.Position)
			table.insert(candidates, { key = character, distance = distance })
		end
	end
	local chosen: { [Model]: boolean } = {}
	for _, character in
		Logic.nearest(candidates, Presets.fireTrail.radius, Context.budget.potionGlows)
	do
		chosen[character] = true
	end
	for character, trail in trails do
		if character.Parent == nil or not trail.emitter:IsDescendantOf(character) then
			clear(character)
		elseif not chosen[character] then
			trail.emitter.Enabled = false
		end
	end
	for character in chosen do
		local trail: Trail? = trails[character]
		if trail == nil then
			trail = build(character)
			if trail ~= nil then
				trails[character] = trail
			end
		end
		if trail ~= nil then
			Particles.switchOn(trail.emitter, "fireTrail")
		end
	end
end

function FireTrail.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local warned = false
		while true do
			-- one odd character must not end every trail for the session: report it once and keep going
			local ok, problem = pcall(function(): string?
				pick()
				return nil
			end)
			if not ok and not warned then
				warned = true
				warn("[Effects] FireTrail: " .. tostring(problem))
			end
			task.wait(Presets.fireTrail.pickEvery)
		end
	end)
end

return FireTrail
