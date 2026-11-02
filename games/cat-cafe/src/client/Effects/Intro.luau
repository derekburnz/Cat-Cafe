--!strict
-- The intro cutscene (F72, intro-cutscene.md section 2: "a small puff"): in shot 4 the demo Tuxedo leaves your arms
-- and appears seated at the waiter spot. A small cream puff goes off where it left you and another round it in its
-- seat with a few sparkles, so the swap reads as a little bit of magic rather than a cut. This screen only, like the
-- rest of the intro.
--
-- Source: `Moments.IntroCatSeated(from, seated)` from the IntroController, hooked once Moments has it (#471), so a
-- build without it is fine. Listening only. Numbers in Presets.introPuff.

local Moments = require(script.Parent.Parent.Moments)

local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Intro = {}

local started = false

local function seated(from: Vector3, model: Model)
	local p = Presets.introPuff
	Particles.burst("smokePuff", from, p.from)
	local at = if model:FindFirstChildWhichIsA("BasePart", true) ~= nil
		then model:GetBoundingBox().Position
		else from
	Particles.burst("smokePuff", at, p.seat)
	Particles.burst("gateSparkle", at, p.sparkle)
end

function Intro.start()
	if started then
		return
	end
	started = true
	-- the engineer's moment, once Moments has it (#471); until then the swap is a plain cut
	local moments = Moments :: any
	if moments.IntroCatSeated ~= nil then
		moments.IntroCatSeated:Connect(function(from: unknown, model: unknown)
			if
				typeof(from) == "Vector3"
				and typeof(model) == "Instance"
				and (model :: Instance):IsA("Model")
			then
				seated(from :: Vector3, model :: Model)
			end
		end)
	end
end

return Intro
