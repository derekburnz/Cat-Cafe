--!strict
-- #4251 Harvest Hollow's effects (the limited autumn area, Wed Nov 25 to Sun Dec 6). All on this client, listening
-- only, from what the server already puts in the world (server/World/HarvestWorld, Services/HarvestService):
--   the air     amber leaves fall round you while you are within `airWithin` studs of the Thankful Board (tag
--               HarvestBoard, the middle of the area). A fifth as thick with Reduce Motion, none in Low performance.
--   a pick      a patch pumpkin (tag HarvestPumpkin) whose `Ready` attribute goes false was picked by someone: an
--               orange pop and a ring where it stood, and a beat for whoever listens (HarvestFx.onPick; Audio).
--   a regrow    `Ready` back to true: a small green sprout of sparkles, so you see a pumpkin is back.
--   the glint   every `glintEvery` seconds the nearest ready pumpkins give a small gold glint, the "pick me" cue.
--               None with Reduce Motion or in Low performance.
-- Nothing runs until one of those tags is in the world, so the module is idle outside the event. Numbers in
-- Presets.harvestFx.

local CollectionService = game:GetService("CollectionService")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local HarvestFx = {}

type Listener = (at: Vector3) -> ()

local started = false
local ready: { [Instance]: boolean } = {} -- each pumpkin's Ready as last seen
local links: { [Instance]: RBXScriptConnection } = {} -- each watched pumpkin's one Ready listener
local listeners: { Listener } = {}
local box: Part? = nil
local emitter: ParticleEmitter? = nil
local sinceGlint = 0

-- What a pumpkin's `Ready` change means: "pick" when it was ready and is not now, "regrow" the other way, nil for
-- the first sight of it (a pumpkin streaming in is not news) and for no change.
function HarvestFx.change(was: boolean?, now: boolean): string?
	if was == nil or was == now then
		return nil
	end
	return if now then "regrow" else "pick"
end

-- The leaves' rate, as a share of the preset's: 0 for none (out of the area, or Low performance), `calm` with Reduce
-- Motion, else 1. `distance` is to the middle of the area, nil while it is not in the world.
function HarvestFx.air(
	distance: number?,
	within: number,
	low: boolean,
	still: boolean,
	calm: number
): number
	if distance == nil or distance > within or low then
		return 0
	end
	return if still then calm else 1
end

-- The ready pumpkins that glint this round: the nearest `most` within `within` studs. `spots` is each ready
-- pumpkin's distance; the result is their indices, nearest first.
function HarvestFx.glinters(spots: { number }, within: number, most: number): { number }
	local near: { number } = {}
	for index, distance in spots do
		if distance <= within then
			table.insert(near, index)
		end
	end
	table.sort(near, function(a: number, b: number): boolean
		if spots[a] ~= spots[b] then
			return spots[a] < spots[b]
		end
		return a < b
	end)
	local picked: { number } = {}
	for i = 1, math.min(most, #near) do
		picked[i] = near[i]
	end
	return picked
end

-- Tells `listener` where a pumpkin was picked near you (Audio's cue).
function HarvestFx.onPick(listener: Listener)
	table.insert(listeners, listener)
end

local function isReady(spot: Instance): boolean
	return spot:GetAttribute(Presets.harvestFx.readyAttribute) == true
end

local function changed(spot: Instance)
	local now = isReady(spot)
	local what = HarvestFx.change(ready[spot], now)
	ready[spot] = now
	local at = Context.positionOf(spot)
	local p = Presets.harvestFx
	if what == nil or at == nil or Context.distance(at) > p.within then
		return
	end
	local lifted = at + Vector3.new(0, p.lift, 0)
	if what == "pick" then
		Particles.burst(p.pick, lifted, p.pickCount, p.pickColour)
		Particles.ring(at, p.pickColour, p.pickRing)
		for _, listener in listeners do
			task.spawn(listener, at)
		end
	else
		Particles.burst(p.regrow, lifted, p.regrowCount, p.regrowColour)
	end
end

-- Forgets a pumpkin that left the world (streamed out or removed) and its listener, so one that streams back in is
-- a first sight again and never has two listeners (one pick, one pop).
local function forget(spot: Instance)
	ready[spot] = nil
	local link = links[spot]
	if link ~= nil then
		link:Disconnect()
		links[spot] = nil
	end
end

local function watch(spot: Instance)
	ready[spot] = isReady(spot)
	if links[spot] ~= nil then
		return
	end
	links[spot] = spot:GetAttributeChangedSignal(Presets.harvestFx.readyAttribute)
		:Connect(function()
			if spot.Parent ~= nil then
				changed(spot)
			end
		end)
end

local function stopAir()
	local part = box
	if part ~= nil then
		part:Destroy()
	end
	box, emitter = nil, nil
end

-- The middle of the area: the Thankful Board, nil while the area is not built or not streamed in.
local function middle(): Vector3?
	for _, board in CollectionService:GetTagged(Presets.harvestFx.boardTag) do
		local at = Context.positionOf(board)
		if at ~= nil then
			return at
		end
	end
	return nil
end

local function stepAir()
	local p = Presets.harvestFx
	local at = middle()
	local focus = Context.focus()
	local share = HarvestFx.air(
		if at ~= nil then Context.distance(at) else nil,
		p.airWithin,
		Context.lowPerformance,
		Context.reducedMotion(),
		p.calmRate
	)
	if share <= 0 or focus == nil then
		stopAir()
		return
	end
	local part: Part
	local existing = box
	if existing ~= nil then
		part = existing
	else
		part = Context.effectPart("EffectsHarvestAir", p.box, p.pickColour)
		part.Transparency = 1
		part.Parent = Context.folder()
		box = part
		local made = Particles.attach(p.air, part)
		if made ~= nil then
			made.EmissionDirection = Enum.NormalId.Bottom
		end
		emitter = made
	end
	part.CFrame = CFrame.new(focus + Vector3.new(0, p.height, 0))
	local running = emitter
	if running ~= nil then
		Particles.switchOn(running, p.air)
		running.Rate *= share
	end
end

local function stepGlint()
	local p = Presets.harvestFx
	if Context.lowPerformance or Context.reducedMotion() then
		return
	end
	local spots: { Vector3 } = {}
	local distances: { number } = {}
	for spot, isUp in ready do
		if spot.Parent == nil then
			forget(spot)
		elseif isUp then
			local at = Context.positionOf(spot)
			if at ~= nil then
				table.insert(spots, at)
				table.insert(distances, Context.distance(at))
			end
		end
	end
	for _, index in HarvestFx.glinters(distances, p.glintWithin, p.glintMost) do
		Particles.burst(p.glint, spots[index] + Vector3.new(0, p.lift, 0), p.glintCount)
	end
end

function HarvestFx.start()
	if started then
		return
	end
	started = true
	local p = Presets.harvestFx
	for _, spot in CollectionService:GetTagged(p.pumpkinTag) do
		watch(spot)
	end
	CollectionService:GetInstanceAddedSignal(p.pumpkinTag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(p.pumpkinTag):Connect(forget)
	task.spawn(function()
		while true do
			stepAir()
			sinceGlint += p.every
			if sinceGlint >= p.glintEvery then
				sinceGlint = 0
				stepGlint()
			end
			task.wait(p.every)
		end
	end)
end

return HarvestFx
