--!strict
-- The world side of a catch (design v0.4 section 1): a Miss makes the cat hiss and hop back, a catch pops in the
-- cat's rarity colour (sparkles and a ring under it, confetti from Epic up, a beam of light from Legendary up, a
-- second ring and falling sparkles for a Mythical), and a Purrfect (every circle Perfect) bursts gold with a ring
-- and confetti instead, keeping the beam. The screen side (PERFECT, GOOD and MISS pops, the paw row) is the UI's.
--
-- Sources: this player's own CatchSchedule and CatchResult events, plus the stray's HissAt attribute so every
-- player nearby sees a hiss, not only the catcher. Listening only: nothing here fires a remote.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Cats = require(script.Parent.Cats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Catch = {}

type Scheduled = { model: Model, position: Vector3, ground: Vector3, rarity: string }

local scheduled: { [string]: Scheduled } = {}
local rng = Random.new()
local lastHiss: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
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

-- The floor under the cat, where its ring spreads and its beam starts.
local function bottomOf(model: Model): Vector3
	local frame, size = model:GetBoundingBox()
	return frame.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)
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

-- The hiss: a puff, a "!" over the head and the hop. Once per cat per second, so the catcher's CatchResult and
-- the HissAt attribute never play it twice. `lag` is how long ago the server marked the miss.
local function hiss(model: Model, lag: number?)
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
	Cats.hiss(model, lag)
	Particles.burst("hissPuff", at, Presets.bursts.hissPuff)
	local head = headOf(model)
	if head ~= nil then
		Particles.mark(head, "!", Presets.palette.neonPink, 0.9)
	end
end

-- The beam from Legendary up, and a Mythical's second ring and slow showers of sparkles from the top of the beam.
local function beam(ground: Vector3, rarity: string, colour: Color3)
	local c = Presets.catchPop
	local _, _, beams = Logic.catchPop(rarity)
	if not beams then
		return
	end
	Particles.beam(ground, colour, c.beam.width, c.beam.height, c.beam.seconds)
	if rarity ~= "Mythical" then
		return
	end
	task.delay(c.echo.after, function()
		Particles.ring(
			ground,
			Presets.palette.sparkle,
			c.ring.Mythical * c.echo.scale,
			c.echo.seconds
		)
	end)
	for i = 1, c.shower.bursts do
		task.delay(c.shower.after + (i - 1) * c.shower.every, function()
			local at = ground
				+ Vector3.new(rng:NextNumber(-1.5, 1.5), c.shower.height, rng:NextNumber(-1.5, 1.5))
			Particles.burst(
				"shower",
				at,
				Presets.bursts.shower,
				if i % 2 == 0 then Presets.palette.sparkle else colour
			)
		end)
	end
end

local function purrfect(at: Vector3, ground: Vector3, rarity: string)
	Particles.burst("catchSparkle", at, Presets.bursts.purrfect, Presets.palette.golden)
	Particles.ring(at - Vector3.new(0, 1, 0), Presets.palette.golden)
	Particles.confetti(at, math.ceil(Context.budget.confetti * 0.6), Presets.purrfectColors)
	beam(ground, rarity, Presets.rarity[rarity] or Presets.rarity.Common)
end

local function caught(at: Vector3, ground: Vector3, rarity: string)
	local colour = Presets.rarity[rarity] or Presets.rarity.Common
	local ring, confetti = Logic.catchPop(rarity)
	Particles.burst("catchSparkle", at, Presets.catchSparkle[rarity] or 8, colour)
	Particles.ring(ground, colour, ring, Presets.catchPop.ringSeconds)
	if confetti > 0 then
		Particles.confetti(
			at,
			math.ceil(Context.budget.confetti * confetti),
			{ colour, Presets.palette.sparkle, Presets.palette.offwhite }
		)
	end
	beam(ground, rarity, colour)
end

-- A catch's pop for `rarity` anywhere else something of that rarity is won (a crate piece at the Market): sparkles
-- at `at`, the ring, beam and showers from `ground`.
function Catch.pop(at: Vector3, ground: Vector3, rarity: string)
	caught(at, ground, rarity)
end

local function watchStray(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	model:GetAttributeChangedSignal("HissAt"):Connect(function()
		-- HissAt is the server time of the miss; the server walks the cat back from then, so the hop starts that
		-- far in, and a miss that is already over by the time it replicates plays nothing.
		local at = model:GetAttribute("HissAt")
		if type(at) ~= "number" then
			return
		end
		local lag = math.max(0, Workspace:GetServerTimeNow() - at)
		if lag < Presets.motion.hiss.seconds then
			hiss(model, lag)
		end
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
				ground = bottomOf(model),
				rarity = if type(rarity) == "string" then rarity else "Common",
			}
		end
	end)

	Net.on(
		"CatchResult",
		function(strayId: string, grades: { Logic.Grade }, third: any, fourth: any)
			local entry: Scheduled? = scheduled[strayId]
			scheduled[strayId] = nil
			local model = if entry ~= nil then entry.model else strayById(strayId)
			if type(grades) ~= "table" then
				return
			end
			if Logic.catchSucceeded(third, fourth) then
				-- A catch whose schedule this client missed plays where the cat stands now.
				local spot: Scheduled? = entry
				if spot == nil and model ~= nil then
					local named = model:GetAttribute("Rarity")
					spot = {
						model = model,
						position = topOf(model),
						ground = bottomOf(model),
						rarity = if type(named) == "string" then named else "Common",
					}
				end
				if spot == nil then
					return
				end
				if Logic.isPurrfect(grades) then
					purrfect(spot.position, spot.ground, spot.rarity)
				else
					caught(spot.position, spot.ground, spot.rarity)
				end
			elseif model ~= nil then
				-- v0.4: a catch only fails on a Miss (a late or wild press, or walking out of range).
				Context.shake(Presets.shake.seconds, Presets.shake.studs) -- for the player who missed
				hiss(model)
			end
		end
	)
end

return Catch
