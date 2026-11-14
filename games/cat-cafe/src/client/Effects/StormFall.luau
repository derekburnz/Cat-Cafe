--!strict
-- A Cat Storm's strays fall out of the sky (#4197, admin events). The server drops extra strays while the storm runs
-- and marks each with the `StormCat` attribute (shared/CatStorm). Where one appears near you a streak of light drops
-- onto the spot from high above, a ring spreads and sparkles puff as it lands, and whoever listens hears it
-- (StormFall.onLand: Audio plays the landing). While the storm runs, slow sparkles drift down round you so the
-- whole area reads as under it. Reduce Motion and Low performance keep only the small puff: no streak, no ring, no
-- drift. A Secret cat lands the same way as any other; nothing here shows what the stray is.
--
-- Source: the `Stray` tag and the attribute; the storm itself from ReplicatedStorage's AdminEvent* attributes
-- (Effects/AdminEventLogic). Listening only. Numbers in Presets.stormFall.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CatStorm = require(ReplicatedStorage.Shared.CatStorm)

local AdminEventLogic = require(script.Parent.AdminEventLogic)
local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local StormFall = {}

local started = false
local second, falls = 0, 0 -- the falls drawn in this second
local drift: Part? = nil
local driftEmitter: ParticleEmitter? = nil
local landListeners: { (at: Vector3) -> () } = {}

-- Who wants to know about a landing (Audio plays it there).
function StormFall.onLand(listener: (at: Vector3) -> ())
	table.insert(landListeners, listener)
end

-- What a landing draws: the whole fall, only its puff (Reduce Motion, Low performance), or nothing (too far, or
-- over this second's count).
function StormFall.plan(
	distance: number,
	drawn: number,
	still: boolean,
	radius: number,
	most: number
): "fall" | "puff" | "none"
	if distance > radius or drawn >= most then
		return "none"
	end
	return if still then "puff" else "fall"
end

-- Whether the drift runs: a storm is on, and neither Reduce Motion nor Low performance.
function StormFall.drifts(storm: boolean, still: boolean): boolean
	return storm and not still
end

local function still(): boolean
	return Context.reducedMotion() or Context.lowPerformance
end

local function land(at: Vector3)
	local p = Presets.stormFall
	Particles.ring(at + Vector3.new(0, 0.1, 0), p.colour, p.ring, p.ringSeconds)
	Particles.burst(p.puff, at + Vector3.new(0, 0.5, 0), p.puffCount)
	for _, listener in landListeners do
		task.spawn(listener, at)
	end
end

local function fall(model: Model)
	local p = Presets.stormFall
	if model.Parent == nil or model:FindFirstChildWhichIsA("BasePart", true) == nil then
		return
	end
	local frame, size = model:GetBoundingBox()
	local at = frame.Position - Vector3.new(0, size.Y / 2, 0)
	local now = math.floor(os.clock())
	if now ~= second then
		second, falls = now, 0
	end
	local plan =
		StormFall.plan(Context.distance(at), falls, still(), p.within, Context.budget.areaPuffs)
	if plan == "none" then
		return
	end
	falls += 1
	if plan == "puff" then
		Particles.burst(p.puff, at + Vector3.new(0, 0.5, 0), p.puffCount)
		return
	end
	local streak = Context.effectPart("EffectsStormStreak", p.streak, p.colour)
	streak.Material = Enum.Material.Neon
	streak.Transparency = 0.25
	streak.CFrame = CFrame.new(at + Vector3.new(0, p.height, 0))
	streak.Parent = Context.folder()
	local info = TweenInfo.new(p.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(streak, info, {
		CFrame = CFrame.new(at + Vector3.new(0, p.streak.Y / 2, 0)),
		Transparency = 0.6,
	}):Play()
	Debris:AddItem(streak, p.seconds + 0.05)
	task.delay(p.seconds, land, at)
end

local function consider(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	if model:GetAttribute(CatStorm.ATTRIBUTE) == true then
		task.defer(fall, model)
		return
	end
	-- the server marks it just after it spawns it: wait a moment for the attribute
	local connection: RBXScriptConnection? = nil
	connection = model:GetAttributeChangedSignal(CatStorm.ATTRIBUTE):Connect(function()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
		if model:GetAttribute(CatStorm.ATTRIBUTE) == true then
			fall(model)
		end
	end)
	task.delay(Presets.stormFall.markWait, function()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end)
end

local function decode(json: string): any
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok then data else nil
end

local function stormOn(): boolean
	local view = AdminEventLogic.read(function(name: string): any
		return ReplicatedStorage:GetAttribute(name)
	end, decode)
	return view ~= nil
		and view.catStorm > 1
		and AdminEventLogic.runs(view, Workspace:GetServerTimeNow())
end

local function stopDrift()
	local part = drift
	if part ~= nil then
		part:Destroy()
	end
	drift, driftEmitter = nil, nil
end

local function tickDrift()
	local p = Presets.stormFall
	local focus = Context.focus()
	if focus == nil or not StormFall.drifts(stormOn(), still()) then
		stopDrift()
		return
	end
	local box: Part
	local existing = drift
	if existing ~= nil then
		box = existing
	else
		box = Context.effectPart("EffectsStormDrift", p.driftBox, p.colour)
		box.Transparency = 1
		box.Parent = Context.folder()
		drift = box
		local made = Particles.attach(p.drift, box)
		if made ~= nil then
			made.EmissionDirection = Enum.NormalId.Bottom
		end
		driftEmitter = made
	end
	box.CFrame = CFrame.new(focus + Vector3.new(0, p.driftHeight, 0))
	local emitter = driftEmitter
	if emitter ~= nil then
		Particles.switchOn(emitter, p.drift)
	end
end

function StormFall.start()
	if started then
		return
	end
	started = true
	-- strays already here when you join did not just fall
	CollectionService:GetInstanceAddedSignal("Stray"):Connect(consider)
	task.spawn(function()
		while true do
			tickDrift()
			task.wait(Presets.stormFall.driftEvery)
		end
	end)
end

return StormFall
