--!strict
-- #4197: the air of an admin event. While Golden Hour or Money Storm runs (the AdminEvent* attributes on
-- ReplicatedStorage, read by Effects/AdminEventLogic; the effect's name picks the drift, AdminEventLogic.airOf), slow
-- gold motes or quicker coin glints fall round you, so the event reads in the world and not only on its banner. One
-- emitter on one unseen part that follows the camera's focus. None with Reduce Motion or in Low performance.
-- Listening only. Numbers in Presets.adminAir.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AdminEventLogic = require(script.Parent.AdminEventLogic)
local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local AdminAir = {}

local started = false
local box: Part? = nil
local emitter: ParticleEmitter? = nil
local shown: string? = nil -- the preset the emitter was made from

-- The emitter preset to run: the running event's drift, nil for none, with Reduce Motion or in Low performance.
function AdminAir.pick(
	air: string?,
	running: boolean,
	still: boolean,
	kinds: { [string]: string }
): string?
	if air == nil or not running or still then
		return nil
	end
	return kinds[air]
end

local function decode(json: string): any
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok then data else nil
end

local function stop()
	local part = box
	if part ~= nil then
		part:Destroy()
	end
	box, emitter, shown = nil, nil, nil
end

local function tick()
	local p = Presets.adminAir
	local view = AdminEventLogic.read(function(name: string): any
		return ReplicatedStorage:GetAttribute(name)
	end, decode)
	local preset = AdminAir.pick(
		AdminEventLogic.airOf(view),
		AdminEventLogic.runs(view, Workspace:GetServerTimeNow()),
		Context.lowPerformance or Context.reducedMotion(),
		p.kinds
	)
	local focus = Context.focus()
	if preset == nil or focus == nil then
		stop()
		return
	end
	if shown ~= preset then
		stop()
	end
	local part: Part
	local existing = box
	if existing ~= nil then
		part = existing
	else
		part = Context.effectPart("EffectsAdminAir", p.box, Presets.palette.golden)
		part.Transparency = 1
		part.Parent = Context.folder()
		box, shown = part, preset
		local made = Particles.attach(preset, part)
		if made ~= nil then
			made.EmissionDirection = Enum.NormalId.Bottom
		end
		emitter = made
	end
	part.CFrame = CFrame.new(focus + Vector3.new(0, p.height, 0))
	local running = emitter
	if running ~= nil then
		Particles.switchOn(running, preset)
	end
end

function AdminAir.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			tick()
			task.wait(Presets.adminAir.every)
		end
	end)
end

return AdminAir
