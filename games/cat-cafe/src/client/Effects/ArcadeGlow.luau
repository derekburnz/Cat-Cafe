--!strict
-- The Cat Arcade cabinet's idle glow (#3062; Gameplay-Engineer's cabinet is tagged "ArcadeCabinet" with a Neon part
-- named `Screen`). Near it, the screen's colour drifts slowly through `colours` (one step every `step` seconds, far
-- under 3 Hz) and a few soft sparkles rise off its top, so it reads as switched on from across the Town Square. Past
-- `within` studs it rests on its first colour and the sparkles stop. Reduce Motion holds the first colour and keeps
-- the sparkles off; Low performance keeps the colour drift only. On this client only; listening only.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local ArcadeGlow = {}

type Cabinet = { screen: BasePart, base: Color3, emitter: ParticleEmitter?, index: number }

local TAG = "ArcadeCabinet"
local cabinets: { [Instance]: Cabinet } = {}
local started = false

local function screenOf(cabinet: Instance): BasePart?
	local screen = cabinet:FindFirstChild(Presets.arcadeGlow.screen, true)
	return if screen ~= nil and screen:IsA("BasePart") then screen :: BasePart else nil
end

local function stopSparkles(c: Cabinet)
	local emitter = c.emitter
	if emitter ~= nil then
		local holder = emitter.Parent
		if holder ~= nil then
			holder:Destroy()
		end
		c.emitter = nil
	end
end

local function rest(c: Cabinet)
	stopSparkles(c)
	if c.index ~= 0 then
		c.index = 0
		c.screen.Color = c.base
	end
end

local function step()
	local p = Presets.arcadeGlow
	local still = Context.reducedMotion()
	for instance, c in cabinets do
		if not instance:IsDescendantOf(game) or c.screen.Parent == nil then
			stopSparkles(c)
			cabinets[instance] = nil
			continue
		end
		local top = c.screen.Position + Vector3.new(0, c.screen.Size.Y / 2 + p.lift, 0)
		if still or Context.distance(c.screen.Position) > p.within then
			rest(c)
			continue
		end
		c.index = c.index % #p.colours + 1
		TweenService:Create(c.screen, TweenInfo.new(p.step * 0.8, Enum.EasingStyle.Sine), {
			Color = p.colours[c.index],
		}):Play()
		if Context.lowPerformance then
			stopSparkles(c)
		elseif c.emitter == nil then
			c.emitter = Particles.attach(p.emitter, Particles.anchor("ArcadeGlow", top))
			local made = c.emitter
			if made ~= nil then
				Particles.switchOn(made, p.emitter)
			end
		end
	end
end

local function added(instance: Instance)
	if cabinets[instance] ~= nil then
		return
	end
	local screen = screenOf(instance)
	if screen == nil then
		return
	end
	cabinets[instance] = { screen = screen, base = screen.Color, emitter = nil, index = 0 }
end

function ArcadeGlow.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged(TAG) do
		added(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(added)
	task.spawn(function()
		while true do
			step()
			task.wait(Presets.arcadeGlow.step)
		end
	end)
end

return ArcadeGlow
