--!strict
-- The world side of a catch (design v0.4 section 1): a Miss makes the cat hiss and hop back, a catch sparkles in
-- the cat's rarity colour, and a Purrfect (every circle Perfect) bursts gold with a ring and confetti. The screen
-- side (PERFECT, GOOD and MISS pops, the paw row) is the UI's.
--
-- Sources: this player's own CatchSchedule and CatchResult events, plus the stray's HissAt attribute so every
-- player nearby sees a hiss, not only the catcher. Listening only: nothing here fires a remote.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cats = require(script.Parent.Cats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Catch = {}

type Scheduled = { model: Model, position: Vector3, rarity: string }

local SHAKE_STEP = "PurrPotEffectsShake"

local scheduled: { [string]: Scheduled } = {}
local lastHiss: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local rng = Random.new()
local started = false

local function strayById(strayId: string): Model?
	for _, instance in CollectionService:GetTagged("Stray") do
		if instance:IsA("Model") and instance:GetAttribute("StrayId") == strayId then
			return instance :: Model
		end
	end
	return nil
end

-- Just above the cat, where its sparkle or puff should come from.
local function topOf(model: Model): Vector3
	local frame, size = model:GetBoundingBox()
	return frame.Position + Vector3.new(0, size.Y / 2 + 0.3, 0)
end

local function headOf(model: Model): BasePart?
	local head = model:FindFirstChild("Head", true)
	if head ~= nil and head:IsA("BasePart") then
		return head :: BasePart
	end
	local primary = model.PrimaryPart
	if primary ~= nil then
		return primary
	end
	return model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
end

-- A small camera shake for the player who missed. Runs after the camera scripts each frame, so the offset never
-- piles up; off with Reduce Motion.
local function shake()
	if Context.reducedMotion() then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local s = Presets.shake
	local began = os.clock()
	RunService:UnbindFromRenderStep(SHAKE_STEP)
	RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - began
		if t >= s.seconds then
			RunService:UnbindFromRenderStep(SHAKE_STEP)
			return
		end
		local k = (1 - t / s.seconds) * s.studs
		camera.CFrame = camera.CFrame * CFrame.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0)
	end)
end

-- The hiss: a puff, a "!" over the head and the hop. Once per cat per second, so the catcher's CatchResult and
-- the HissAt attribute never play it twice.
local function hiss(model: Model)
	if model.Parent == nil then
		return
	end
	local now = os.clock()
	local last: number? = lastHiss[model]
	if last ~= nil and now - last < 1 then
		return
	end
	local at = topOf(model)
	if Context.distance(at) > Context.budget.animRadius then
		return
	end
	lastHiss[model] = now
	Cats.hiss(model)
	Particles.burst("hissPuff", at, Presets.bursts.hissPuff)
	local head = headOf(model)
	if head ~= nil then
		Particles.mark(head, "!", Presets.palette.neonPink, 0.9)
	end
end

local function purrfect(at: Vector3)
	Particles.burst("catchSparkle", at, Presets.bursts.purrfect, Presets.palette.golden)
	Particles.ring(at - Vector3.new(0, 1, 0), Presets.palette.golden)
	Particles.confetti(at, math.ceil(Context.budget.confetti * 0.6), Presets.purrfectColors)
end

local function caught(at: Vector3, rarity: string)
	local colour = Presets.rarity[rarity] or Presets.rarity.Common
	Particles.burst("catchSparkle", at, Presets.catchSparkle[rarity] or 8, colour)
end

local function watchStray(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	model:GetAttributeChangedSignal("HissAt"):Connect(function()
		hiss(model)
	end)
end

function Catch.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged("Stray") do
		watchStray(instance)
	end
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(watchStray)

	-- The stray is locked in place for the whole catch, so where it stood at the schedule is where the result
	-- plays, even if the server removes the caught cat in the same moment it answers.
	Net.on("CatchSchedule", function(strayId: string)
		local model = strayById(strayId)
		if model ~= nil then
			local rarity = model:GetAttribute("Rarity")
			scheduled[strayId] = {
				model = model,
				position = topOf(model),
				rarity = if type(rarity) == "string" then rarity else "Common",
			}
		end
	end)

	Net.on(
		"CatchResult",
		function(strayId: string, scores: { number }, _chance: number, success: boolean)
			local entry: Scheduled? = scheduled[strayId]
			scheduled[strayId] = nil
			local model = if entry ~= nil then entry.model else strayById(strayId)
			if type(scores) ~= "table" then
				return
			end
			if success then
				local at = if entry ~= nil
					then entry.position
					elseif model ~= nil then topOf(model)
					else nil
				if at == nil then
					return
				end
				if Logic.isPurrfect(scores) then
					purrfect(at)
				else
					caught(at, if entry ~= nil then entry.rarity else "Common")
				end
			elseif Logic.hasMiss(scores) and model ~= nil then
				shake()
				hiss(model)
			end
		end
	)
end

return Catch
