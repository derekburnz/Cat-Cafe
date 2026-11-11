--!strict
-- A Golden find (#3222, Derek2 2026-11-11: "add golden decor's that are a super low drop chance"): when a freed cat
-- leaves you one of the drop-only Golden lawn pieces, the server's toast starts "Golden find! " (LawnService.giveDrop).
-- On this player's screen a gold beam shoots up off them, gold confetti and sparkles burst out and two gold rings
-- spread at their feet, so a find this rare (1 in 400 freed cats) feels like one. Reduce Motion keeps the sparkles
-- only; Low performance keeps the beam and rings with fewer pieces. Listening only: it reads the Toast remote and
-- fires nothing.

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local GoldenFind = {}

local started = false
local lastAt = -math.huge

-- Whether a toast line is a Golden find.
function GoldenFind.matches(text: unknown): boolean
	return type(text) == "string"
		and string.sub(text, 1, #Presets.goldenFind.prefix) == Presets.goldenFind.prefix
end

-- Plays the find on this player, at most once every `gap` seconds.
function GoldenFind.play()
	local p = Presets.goldenFind
	local now = os.clock()
	if now - lastAt < p.gap then
		return
	end
	lastAt = now
	local at = Context.focus()
	if at == nil then
		return
	end
	local feet = at - Vector3.new(0, p.feet, 0)
	local few = Context.lowPerformance
	Particles.burst(
		"catchSparkle",
		at + Vector3.new(0, p.lift, 0),
		if few then p.sparkles // 2 else p.sparkles,
		Presets.palette.golden
	)
	if Context.reducedMotion() then
		return -- the beam and rings skip themselves too; confetti flies, so it goes as well
	end
	Particles.beam(feet, Presets.palette.golden, p.beamWidth, p.beamHeight, p.beamSeconds)
	Particles.confetti(
		at + Vector3.new(0, p.lift, 0),
		if few then p.confetti // 2 else p.confetti,
		p.colours
	)
	for ring = 1, p.rings do
		task.delay((ring - 1) * p.ringGap, function()
			Particles.ring(feet, Presets.palette.golden, p.ring * ring, p.ringSeconds)
		end)
	end
end

function GoldenFind.start()
	if started then
		return
	end
	started = true
	Context.whenRemote("Toast", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(function(text: unknown)
			if GoldenFind.matches(text) then
				GoldenFind.play()
			end
		end)
	end)
end

return GoldenFind
