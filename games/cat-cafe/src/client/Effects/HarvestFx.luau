--!strict
-- #4251 Harvest Hollow's effects (the limited autumn area, Wed Nov 25 to Sun Dec 6). All on this client, listening
-- only, from what the server already puts in the world (server/World/HarvestWorld, Services/HarvestService):
--   the air     amber leaves fall round you while you are within `airWithin` studs of the Thankful Board (tag
--               HarvestBoard, the middle of the area). A fifth as thick with Reduce Motion, none in Low performance.
--   a pick      a patch pumpkin (tag HarvestPumpkin) whose `Ready` attribute goes false was picked by someone: an
--               orange pop and a ring where it stood, and a beat for whoever listens (HarvestFx.onPick; Audio).
--   a regrow    `Ready` back to true: a small green sprout of sparkles, so you see a pumpkin is back.
--   a regrow spot  while a patch pumpkin is picked (`Ready` false), a small soil mound with a green sprout where it
--               stood, and a thin ring round it that fills toward its `RegrowAt` (os.time), so an empty spot reads as
--               growing back and not broken (Design, spec section 3; regrow is 300 s, 150 s busy). Plain parts, no
--               particles, at most `sproutMost` spots within `within` studs, redrawn every `every` seconds.
--   the glint   every `glintEvery` seconds the nearest ready pumpkins give a small gold glint, the "pick me" cue.
--               None with Reduce Motion or in Low performance.
--   the song    HarvestFx.onArea tells Audio when you walk in or out (the area has no World.Zones box).
--   the pie     a Feast Pie slice baked (ReplicatedStorage's `HarvestPieSlices` rises, HarvestPieService) while you
--               are in the area: gold sparkles and a ring at the Thankful Board; the last slice adds confetti and a
--               gold beam. The first value seen only sets the mark.
--   a pin       a note pinned on the Thankful Board (its `HarvestNotes` attribute changes, HarvestService) while you
--               are in the area: a puff of leaves at the board, and a few gold sparkles when the pin is yours, and a
--               paper flick for whoever listens (HarvestFx.onPin; Audio). The first value seen only sets the mark.
-- Nothing runs until one of those tags is in the world, so the module is idle outside the event. Numbers in
-- Presets.harvestFx.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HarvestSave = require(ReplicatedStorage.Shared.HarvestSave)

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
local inside = false -- whether you were in the area at the last look
local slices: number? = nil -- the Feast Pie's slices as last seen
local areaListeners: { (inside: boolean) -> () } = {}
local arrivedAt: number? = nil -- os.clock() of the last arrival swirl
local sinceGlint = 0
local notesSeen: { [Instance]: string } = {} -- each board's HarvestNotes as last seen
local boardLinks: { [Instance]: RBXScriptConnection } = {} -- each board's one HarvestNotes listener
type PinListener = (at: Vector3, mine: boolean) -> ()
local pinListeners: { PinListener } = {}
type Sprout = { model: Model, fill: Part, shoot: Part, total: number }
local sprouts: { [Instance]: Sprout } = {} -- each shown regrow spot

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

-- What a new Feast Pie slice count means: "slice" when it rose, "full" when it rose to `full` or past it, nil for
-- the first value seen, for no rise and for anything that is not a number.
function HarvestFx.pie(was: number?, now: unknown, full: number): string?
	if type(now) ~= "number" or was == nil or now <= was then
		return nil
	end
	return if now >= full then "full" else "slice"
end

-- Whether walking in plays the arrival swirl: you were outside (or not yet looked at), are inside now, and the last
-- swirl was at least `gap` seconds ago (`since` is nil before the first), so pacing the edge does not repeat it.
function HarvestFx.arrive(was: boolean?, now: boolean, since: number?, gap: number): boolean
	if not now or was == true then
		return false
	end
	return since == nil or since >= gap
end

-- Whether you are in the area: within `within` studs of its middle. `distance` is nil while it is not in the world.
function HarvestFx.within(distance: number?, within: number): boolean
	return distance ~= nil and distance <= within
end

-- Tells `listener` each time you walk into or out of the area (Audio's song), and at once if you are in it now.
function HarvestFx.onArea(listener: (inside: boolean) -> ())
	table.insert(areaListeners, listener)
	if inside then
		task.spawn(listener, true)
	end
end

-- Whether a board's HarvestNotes change is a new pin: a string that differs from the last one seen. The first sight
-- (nil before, a board streaming in) is not news, and neither is the same list again.
function HarvestFx.newPin(was: string?, now: unknown): boolean
	return was ~= nil and type(now) == "string" and now ~= was
end

-- Who pinned last: the userId of the list's last row (HarvestSave.pinNote puts the newest pin last), or nil when the
-- list holds none. Read off the JSON text with a pattern, so it needs no decode (each row has one userId).
function HarvestFx.lastPinner(json: string): number?
	local last: number? = nil
	for digits in string.gmatch(json, '"userId"%s*:%s*(%d+)') do
		last = tonumber(digits)
	end
	return last
end

function HarvestFx.onPin(listener: PinListener)
	table.insert(pinListeners, listener)
end

-- Tells `listener` where a pumpkin was picked near you (Audio's cue).
function HarvestFx.onPick(listener: Listener)
	table.insert(listeners, listener)
end

-- How long a picked spot takes to regrow, from what is left when it is first seen: the busy time if that fits in
-- it, else the lone time. A spot first seen part way through a lone regrow can be taken as busy; it only starts
-- its ring further back.
function HarvestFx.regrowTotal(remaining: number, busy: number, lone: number): number
	return if remaining <= busy then busy else lone
end

-- How far a regrow has come, 0 just picked to 1 ready.
function HarvestFx.regrowShare(remaining: number, total: number): number
	if total <= 0 then
		return 1
	end
	return math.clamp(1 - remaining / total, 0, 1)
end

local function dropSprout(spot: Instance)
	local shown: Sprout? = sprouts[spot]
	if shown ~= nil then
		shown.model:Destroy()
		sprouts[spot] = nil
	end
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
	dropSprout(spot)
	local link: RBXScriptConnection? = links[spot]
	if link ~= nil then
		link:Disconnect()
		links[spot] = nil
	end
end

local function watch(spot: Instance)
	ready[spot] = isReady(spot)
	local link: RBXScriptConnection? = links[spot]
	if link ~= nil then
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

-- The arrival swirl: `arriveSpots` puffs of leaves in a circle `arriveRadius` studs round you, one after another,
-- and a few gold sparkles over your head. None in Low performance; half the leaves with Reduce Motion.
local function swirl(at: Vector3)
	if Context.lowPerformance then
		return
	end
	local p = Presets.harvestFx
	local count = if Context.reducedMotion() then math.ceil(p.arriveCount / 2) else p.arriveCount
	for i = 1, p.arriveSpots do
		task.delay((i - 1) * p.arriveStep, function()
			local turn = (i - 1) / p.arriveSpots * math.pi * 2
			local spot = at
				+ Vector3.new(
					math.cos(turn) * p.arriveRadius,
					p.arriveLift,
					math.sin(turn) * p.arriveRadius
				)
			Particles.burst(p.air, spot, count)
		end)
	end
	Particles.burst(
		p.pieBurst,
		at + Vector3.new(0, p.arriveLift + 2, 0),
		p.arriveSparkles,
		Presets.palette.golden
	)
end

local function stepAir()
	local p = Presets.harvestFx
	local at = middle()
	local focus = Context.focus()
	local distance = if at ~= nil then Context.distance(at) else nil
	local now = HarvestFx.within(distance, p.airWithin)
	if now ~= inside then
		local clock = os.clock()
		local last = arrivedAt
		if
			HarvestFx.arrive(inside, now, if last ~= nil then clock - last else nil, p.arriveGap)
		then
			arrivedAt = clock
			if focus ~= nil then
				swirl(focus)
			end
		end
		inside = now
		for _, listener in areaListeners do
			task.spawn(listener, now)
		end
	end
	local share = HarvestFx.air(
		distance,
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

-- The ground under a pumpkin: a model's pivot is at its base (asset-pipeline), a lone part's middle is half its
-- height up.
local function groundOf(spot: Instance, at: Vector3): Vector3
	if spot:IsA("BasePart") then
		return at - Vector3.new(0, (spot :: BasePart).Size.Y / 2, 0)
	end
	return at
end

local function makeSprout(ground: Vector3, total: number): Sprout
	local p = Presets.harvestFx
	local model = Instance.new("Model")
	model.Name = "EffectsHarvestSprout"
	local flat = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis is X: stand it up
	local ring = Context.effectPart(
		"Ring",
		Vector3.new(0.05, p.sproutRing * 2, p.sproutRing * 2),
		p.sproutRingColour
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = p.sproutRingTransparency
	ring.CFrame = flat * CFrame.new(0.03, 0, 0)
	ring.Parent = model
	local fill = Context.effectPart("Fill", Vector3.new(0.06, 0.1, 0.1), p.regrowColour)
	fill.Shape = Enum.PartType.Cylinder
	fill.Transparency = p.sproutFillTransparency
	fill.CFrame = flat * CFrame.new(0.06, 0, 0)
	fill.Parent = model
	local mound = Context.effectPart("Mound", p.sproutMound, p.sproutSoil)
	local dome = Instance.new("SpecialMesh") -- a Ball part is always round; a sphere mesh fills the flat box
	dome.MeshType = Enum.MeshType.Sphere
	dome.Parent = mound
	mound.CFrame = CFrame.new(ground)
	mound.Parent = model
	local shoot = Context.effectPart("Shoot", p.sproutShoot, p.regrowColour)
	shoot.Parent = model
	model.Parent = Context.folder()
	return { model = model, fill = fill, shoot = shoot, total = total }
end

-- The regrow spots: the nearest `sproutMost` picked pumpkins within `within`, each with its mound, shoot and ring.
local function stepSprouts()
	local p = Presets.harvestFx
	local now = Workspace:GetServerTimeNow()
	local spots: { Instance } = {}
	local distances: { number } = {}
	for spot, isUp in ready do
		local at = if not isUp then Context.positionOf(spot) else nil
		if at ~= nil and type(spot:GetAttribute(p.regrowAttribute)) == "number" then
			table.insert(spots, spot)
			table.insert(distances, Context.distance(at))
		end
	end
	local wanted: { [Instance]: boolean } = {}
	for _, index in HarvestFx.glinters(distances, p.within, p.sproutMost) do
		wanted[spots[index]] = true
	end
	for spot in sprouts do
		if not wanted[spot] then
			dropSprout(spot)
		end
	end
	for spot in wanted do
		local at = Context.positionOf(spot)
		if at == nil then
			continue
		end
		local remaining = math.max(0, (spot:GetAttribute(p.regrowAttribute) :: number) - now)
		local shown: Sprout? = sprouts[spot]
		local sprout: Sprout
		if shown ~= nil then
			sprout = shown
		else
			sprout = makeSprout(
				groundOf(spot, at),
				HarvestFx.regrowTotal(
					remaining,
					HarvestSave.BUSY_REGROW_SECONDS,
					HarvestSave.REGROW_SECONDS
				)
			)
			sprouts[spot] = sprout
		end
		local share = HarvestFx.regrowShare(remaining, sprout.total)
		local ground = groundOf(spot, at)
		local across = math.max(0.1, p.sproutRing * 2 * share)
		sprout.fill.Size = Vector3.new(0.06, across, across)
		local tall = p.sproutShoot.Y * (0.4 + 0.6 * share)
		sprout.shoot.Size = Vector3.new(p.sproutShoot.X, tall, p.sproutShoot.Z)
		sprout.shoot.CFrame =
			CFrame.new(ground + Vector3.new(0, p.sproutMound.Y / 2 + tall / 2 - 0.1, 0))
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

-- The Feast Pie's count changed: celebrate a new slice at the board, if you are in the area to see it.
local function pieChanged()
	local p = Presets.harvestFx
	local now = ReplicatedStorage:GetAttribute(p.pieAttribute)
	local what = HarvestFx.pie(slices, now, p.pieFull)
	if type(now) == "number" then
		slices = now
	end
	local board = middle()
	if what == nil or board == nil or not inside then
		return
	end
	local at = board + Vector3.new(0, p.pieLift, 0)
	Particles.burst(p.pieBurst, at, p.pieCount, Presets.palette.golden)
	Particles.ring(board, Presets.palette.golden, p.pieRing)
	if what == "full" then
		Particles.confetti(at, math.ceil(Context.budget.confetti * p.pieConfetti))
		if not Context.reducedMotion() then
			Particles.beam(
				board,
				Presets.palette.golden,
				p.pieBeamWidth,
				p.pieBeamHeight,
				p.pieBeamSeconds
			)
		end
	end
end

-- A note pinned on a board: leaves at the board if you are in the area to see it, gold sparkles too when it is yours.
local function notesChanged(board: Instance)
	local p = Presets.harvestFx
	local now = board:GetAttribute(p.notesAttribute)
	local fresh = HarvestFx.newPin(notesSeen[board], now)
	if type(now) == "string" then
		notesSeen[board] = now
	end
	local at = Context.positionOf(board)
	if not fresh or not inside or at == nil then
		return
	end
	local mine = HarvestFx.lastPinner(now :: string) == Players.LocalPlayer.UserId
	local lifted = at + Vector3.new(0, p.pinLift, 0)
	local count = if Context.reducedMotion() then math.ceil(p.pinCount / 2) else p.pinCount
	Particles.burst(p.air, lifted, count)
	if mine then
		Particles.burst(p.pieBurst, lifted, p.pinSparkles, Presets.palette.golden)
	end
	for _, listener in pinListeners do
		task.spawn(listener, at, mine)
	end
end

local function forgetBoard(board: Instance)
	notesSeen[board] = nil
	local link: RBXScriptConnection? = boardLinks[board]
	if link ~= nil then
		link:Disconnect()
		boardLinks[board] = nil
	end
end

local function watchBoard(board: Instance)
	local now = board:GetAttribute(Presets.harvestFx.notesAttribute)
	if type(now) == "string" then
		notesSeen[board] = now
	end
	local link: RBXScriptConnection? = boardLinks[board]
	if link ~= nil then
		return
	end
	boardLinks[board] = board
		:GetAttributeChangedSignal(Presets.harvestFx.notesAttribute)
		:Connect(function()
			if board.Parent ~= nil then
				notesChanged(board)
			end
		end)
end

function HarvestFx.start()
	if started then
		return
	end
	started = true
	local p = Presets.harvestFx
	pieChanged() -- sets the mark
	ReplicatedStorage:GetAttributeChangedSignal(p.pieAttribute):Connect(pieChanged)
	for _, spot in CollectionService:GetTagged(p.pumpkinTag) do
		watch(spot)
	end
	CollectionService:GetInstanceAddedSignal(p.pumpkinTag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(p.pumpkinTag):Connect(forget)
	for _, board in CollectionService:GetTagged(p.boardTag) do
		watchBoard(board)
	end
	CollectionService:GetInstanceAddedSignal(p.boardTag):Connect(watchBoard)
	CollectionService:GetInstanceRemovedSignal(p.boardTag):Connect(forgetBoard)
	task.spawn(function()
		while true do
			stepAir()
			stepSprouts()
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
