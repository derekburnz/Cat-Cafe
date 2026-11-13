--!strict
-- The Speed Shoes' trail (#3523 section 1, built in #3535): while a player who wears the shoes carries a cat and is
-- on the move, small mint and cream puffs are left at their heels, so everyone nearby can see why they are quick. It
-- stops the moment they stand still, put the cat down or jump off the ground, and it never shows on a walker with no
-- cat, because the shoes only speed up carrying.
--
-- Sources, listening only: the character's `SpeedShoes` attribute (true while the shoes are worn; the server sets it
-- where it puts the shoes on) or the worn model itself (Presets.speedShoes.model) in the character, `CarryingCatId`
-- (CatService) and the Humanoid's own MoveDirection and FloorMaterial. The nearest budget.potionGlows wearers
-- within Presets.speedShoes.radius show it, your own first; Low performance shows none. Nothing blinks: the puffs
-- are a steady thin stream. Numbers in Presets.speedShoes and Presets.emitters.shoeTrail.

local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local SpeedShoes = {}

type Trail = { feet: Attachment, emitter: ParticleEmitter }

local trails: { [Model]: Trail } = {}
local started = false

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

-- The trail's emitter at the heels of a character, made off; nil while its body has not streamed in.
local function build(character: Model): Trail?
	local root = rootOf(character)
	local preset: Presets.EmitterPreset? = Presets.emitters.shoeTrail
	if root == nil or preset == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	local feet = Instance.new("Attachment")
	feet.Name = "SpeedShoesTrail"
	feet.Position =
		Vector3.new(0, Presets.speedShoes.lift - root.Size.Y / 2 - hip, Presets.speedShoes.behind)
	feet.Parent = root
	local emitter = Particles.make(preset)
	emitter.Name = "Trail"
	emitter.Parent = feet
	return { feet = feet, emitter = emitter }
end

-- Whether this character's trail runs now.
local function running(character: Model): boolean
	local p = Presets.speedShoes
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return false
	end
	local wears = character:GetAttribute("SpeedShoes") == true
		or character:FindFirstChild(p.model) ~= nil
	return Logic.shoeTrailOn(
		wears,
		character:GetAttribute("CarryingCatId") ~= nil,
		humanoid.MoveDirection.Magnitude,
		humanoid.FloorMaterial ~= Enum.Material.Air,
		p.moving
	)
end

local function pick()
	local me = Players.LocalPlayer
	local candidates: { Logic.Candidate<Model> } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then rootOf(character) else nil
		if character ~= nil and root ~= nil and running(character) then
			local distance = if player == me then 0 else Context.distance(root.Position)
			table.insert(candidates, { key = character, distance = distance })
		end
	end
	local chosen: { [Model]: boolean } = {}
	for _, character in
		Logic.nearest(candidates, Presets.speedShoes.radius, Context.budget.potionGlows)
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
			Particles.switchOn(trail.emitter, "shoeTrail")
		end
	end
end

function SpeedShoes.start()
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
				warn("[Effects] SpeedShoes: " .. tostring(problem))
			end
			task.wait(Presets.speedShoes.pickEvery)
		end
	end)
end

return SpeedShoes
