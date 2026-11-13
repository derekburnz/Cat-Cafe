--!strict
-- The Rummage Bin's prize roll and reward show (#3608, Derek 2026-11-12: "plays an animations that ticks through the
-- options a couple times before landing on one ... better the reward better the vfx"). The list over the bin is
-- the UI's; this gives it the roll's timing and plays what happens at the bin itself.
--   BinRoll.steps(count, target)     the ticks of a roll over `count` rows that stops on row `target`:
--                                    { { index, at } }, `at` in seconds from the start (Logic.binRollSteps with
--                                    Presets.binRoll's numbers). The caller lights row `index` at each `at`.
--   BinRoll.seconds(count, target)   how long that roll takes, to the last tick
--   BinRoll.rattle(bin, seconds)     the bin tips side to side while the roll runs; returns a function that stops
--                                    it early and stands the bin back exactly as it was
--   BinRoll.tier(chance)             1 common, 2 good, 3 best, from the prize row's chance (nil: a fixed prize)
--   BinRoll.landed(bin, tier)        as the roll stops: nothing for a common prize, a blue ring and sparkles for a
--                                    good one, a short gold light column for the best (gone before the bar starts)
--   BinRoll.reward(bin, tier)        the win's show at the bin: sparkles, then a ground ring and confetti for a
--                                    good prize (its lid hops), then a gold light column and a small shake for the
--                                    best one (its lid flies up and fades)
--   BinRoll.play(bin, count, target, tier, onTick, onDone)   one whole roll in one call: rattle, a call per row
--                                    lit, the landing, and a returned function that skips to the stop (a tap)
--   BinRoll.win(bin, tier)           the reward show plus its sound beat
--   BinRoll.reveal(bin, tier, onDone)   a fixed prize's short reveal with no roll ("Your prize!"); returns a skip
--   BinRoll.hop(bin, to, tier, image?)   the prize hops from the bin to the player as a small bright ball, or with
--                                    the prize's picture (#3885) that picture pops up out of the bin into the hands
--   BinRoll.onBeat(listener)         "tick", "land" and "win" beats for the sounds (Audio follows them)
-- The roll always ends on the prize the server already picked and never lingers on another row. Reduce Motion
-- drops the rattle, the shake and most confetti. On this client only; listening only.

local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local BinRoll = {}

function BinRoll.steps(count: number, target: number): { { index: number, at: number } }
	local p = Presets.binRoll
	return Logic.binRollSteps(count, target, p.laps, p.first, p.last)
end

function BinRoll.seconds(count: number, target: number): number
	local steps = BinRoll.steps(count, target)
	local last = steps[#steps]
	return if last ~= nil then last.at else 0
end

function BinRoll.tier(chance: number?): number
	local p = Presets.binRoll
	return Logic.binRewardTier(chance, p.good, p.best)
end

-- The middle of the bin's base and its size, or nil for a bin with no parts yet.
local function base(bin: Instance): (Vector3?, Vector3)
	if bin:IsA("Model") then
		local model = bin :: Model
		local ok, frame, size = pcall(function(): (CFrame, Vector3)
			return model:GetBoundingBox()
		end)
		if ok and size.Magnitude > 0 then
			return frame.Position - Vector3.new(0, size.Y / 2, 0), size
		end
	elseif bin:IsA("BasePart") then
		local part = bin :: BasePart
		return part.Position - Vector3.new(0, part.Size.Y / 2, 0), part.Size
	end
	return nil, Vector3.zero
end

local rattling: { [Instance]: () -> () } = {}

function BinRoll.rattle(bin: Instance, seconds: number): () -> ()
	local before = rattling[bin]
	if before ~= nil then
		before()
	end
	if not bin:IsA("Model") or Context.reducedMotion() then
		return function() end
	end
	local model = bin :: Model
	local p = Presets.binRoll
	local rest = model:GetPivot()
	local found = base(model)
	if found == nil then
		return function() end
	end
	local foot: Vector3 = found
	local started = os.clock()
	local step: RBXScriptConnection? = nil
	local function stop()
		if step ~= nil then
			step:Disconnect()
			step = nil
			if model.Parent ~= nil then
				model:PivotTo(rest)
			end
		end
		if rattling[bin] == stop then
			rattling[bin] = nil
		end
	end
	step = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if t >= seconds or model.Parent == nil then
			stop()
			return
		end
		-- tips about the base, easing out over the last fifth so it settles instead of snapping back
		local fade = math.clamp((seconds - t) / (seconds * 0.2), 0, 1)
		local angle = math.rad(p.rattle) * math.sin(t * p.rattleHz * 2 * math.pi) * fade
		local about = CFrame.new(foot)
		model:PivotTo(about * CFrame.Angles(0, 0, angle) * about:Inverse() * rest)
	end)
	rattling[bin] = stop
	return stop
end

local function play(bin: Instance, tier: number, shows: { any })
	local p = Presets.binRoll
	local found = base(bin)
	if found == nil then
		return
	end
	local foot: Vector3 = found
	local index = math.clamp(math.floor(tier), 1, #shows)
	local show = shows[index]
	local colour = p.colours[index]
	local out = foot + Vector3.new(0, p.lift, 0)
	if show.sparkles > 0 then
		Particles.burst(p.emitter, out, show.sparkles, colour)
	end
	if show.ring > 0 then
		Particles.ring(foot, colour, show.ring)
	end
	if show.confetti > 0 then
		Particles.confetti(out, math.ceil(Context.budget.confetti * show.confetti))
	end
	if show.beam > 0 and not Context.reducedMotion() then
		Particles.beam(foot, colour, 1.2, show.beam, show.beamSeconds)
	end
	if show.shake > 0 then
		Context.shake(0.25, show.shake)
	end
end

function BinRoll.landed(bin: Instance, tier: number)
	play(bin, tier, Presets.binRoll.landed)
end

-- The lid's hop or fly on a win. A copy of the bin's closed lid does the moving, on this client only, while the
-- bin's own looks (the closed lid, and the open one with the prizes if the bin has not flipped to empty yet) are
-- hidden with LocalTransparencyModifier (BinController owns their Transparency); they show again as the copy lands
-- or fades out. A second win on the same bin ends the first move before it starts its own.
local popping: { [Instance]: () -> () } = {}

local function popLid(bin: Instance, tier: number)
	local p = Presets.binRoll
	local move = p.lid[math.clamp(math.floor(tier), 1, #p.lid)]
	if move.seconds <= 0 or Context.reducedMotion() then
		return
	end
	local before = popping[bin]
	if before ~= nil then
		before()
	end
	local lid: Model? = nil
	local hidden: { BasePart } = {}
	for _, child in bin:GetChildren() do
		if not child:IsA("Model") then
			continue
		end
		if lid == nil and child.Name:sub(-#p.lidSuffix) == p.lidSuffix then
			lid = child :: Model
		end
		for _, piece in child:GetDescendants() do
			if piece:IsA("BasePart") then
				table.insert(hidden, piece :: BasePart)
			end
		end
	end
	if lid == nil then
		return
	end
	local real: Model = lid
	local copy = real:Clone()
	local pieces: { BasePart } = {}
	for _, piece in copy:GetDescendants() do
		if piece:IsA("BasePart") then
			local part = piece :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 0
			table.insert(pieces, part)
		end
	end
	for _, part in hidden do
		part.LocalTransparencyModifier = 1
	end
	local rest = real:GetPivot()
	copy.Parent = Context.folder()
	local started = os.clock()
	local step: RBXScriptConnection? = nil
	local function finish()
		if step == nil then
			return
		end
		step:Disconnect()
		step = nil
		copy:Destroy()
		for _, part in hidden do
			part.LocalTransparencyModifier = 0
		end
		if popping[bin] == finish then
			popping[bin] = nil
		end
	end
	step = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - started) / move.seconds
		if u >= 1 or copy.Parent == nil then
			finish()
			return
		end
		local up, faded = Logic.binLidPop(u, move.height, move.fly)
		copy:PivotTo(
			rest * CFrame.new(0, up, 0) * CFrame.Angles(0, move.turns * 2 * math.pi * u, 0)
		)
		if faded > 0 then
			for _, part in pieces do
				part.Transparency = faded
			end
		end
	end)
	popping[bin] = finish
end

function BinRoll.reward(bin: Instance, tier: number)
	play(bin, tier, Presets.binRoll.tiers)
	popLid(bin, tier)
end

-- Sounds follow the roll's own beats, so they stay in step with it (Audio hooks this): "tick" as each row lights,
-- "land" with the prize's tier as it stops, "win" with the tier from BinRoll.win.
local listeners: { (beat: string, tier: number?, at: Vector3?) -> () } = {}

function BinRoll.onBeat(listener: (beat: string, tier: number?, at: Vector3?) -> ())
	table.insert(listeners, listener)
end

local function beat(name: string, tier: number?, bin: Instance)
	local at = base(bin)
	for _, listener in listeners do
		task.spawn(listener, name, tier, at)
	end
end

-- Plays one whole roll at `bin` over `count` rows, stopping on row `target` (a prize of `tier`): the bin rattles,
-- `onTick(index)` is called as each row lights (the board lights it), and at the stop the landing effect plays and
-- `onDone()` is called once. Returns a function that skips to the stop at once (a tap): the last row lights, the
-- landing plays, `onDone()` is called. Nothing here decides the prize.
function BinRoll.play(
	bin: Instance,
	count: number,
	target: number,
	tier: number,
	onTick: (index: number) -> (),
	onDone: (() -> ())?
): () -> ()
	local steps = BinRoll.steps(count, target)
	local last = steps[#steps]
	local finished = false
	local stopRattle = BinRoll.rattle(bin, if last ~= nil then last.at else 0)
	local function finish()
		if finished then
			return
		end
		finished = true
		stopRattle()
		if last ~= nil then
			onTick(last.index)
		end
		BinRoll.landed(bin, tier)
		beat("land", tier, bin)
		if onDone ~= nil then
			onDone()
		end
	end
	task.spawn(function()
		local started = os.clock()
		for i, step in steps do
			local wait = step.at - (os.clock() - started)
			if wait > 0 then
				task.wait(wait)
			end
			if finished then
				return
			end
			if i < #steps then
				onTick(step.index)
				beat("tick", nil, bin)
			end
		end
		finish()
	end)
	return finish
end

-- A fixed prize (a first rummage) has no roll: the bin gives one short rattle, then the landing plays, its row is
-- lit by `onDone()`. Returns a function that skips to the reveal at once.
function BinRoll.reveal(bin: Instance, tier: number, onDone: (() -> ())?): () -> ()
	local seconds = Presets.binRoll.reveal
	local finished = false
	local stopRattle = BinRoll.rattle(bin, seconds)
	local function finish()
		if finished then
			return
		end
		finished = true
		stopRattle()
		BinRoll.landed(bin, tier)
		beat("land", tier, bin)
		if onDone ~= nil then
			onDone()
		end
	end
	task.delay(seconds, finish)
	return finish
end

-- #3885: the prize's picture pops up out of the bin, grows, then arcs into the player's hands and shrinks there
-- (Logic.binPrizePop), with sparkles at the pop and at the catch. The picture is a BillboardGui on a hidden part, so
-- it always faces the camera; its size is in studs.
local function popPrize(
	from: Vector3,
	to: () -> Vector3?,
	first: Vector3,
	colour: Color3,
	image: string
)
	local p = Presets.binRoll
	local q = p.prize
	local holder = Context.effectPart("BinPrizePop", Vector3.one * 0.2, colour)
	holder.Transparency = 1
	holder.Position = from
	local board = Instance.new("BillboardGui")
	board.Name = "Prize"
	board.LightInfluence = 0
	board.AlwaysOnTop = true
	board.Size = UDim2.fromScale(q.size * q.from, q.size * q.from)
	board.Adornee = holder
	board.Parent = holder
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.Image = image
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = board
	holder.Parent = Context.folder()
	Particles.burst(p.emitter, from, q.sparkles, colour)
	local started = os.clock()
	local last: Vector3 = first
	local step: RBXScriptConnection? = nil
	step = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - started) / q.seconds
		local target = to()
		if target ~= nil then
			last = target
		end
		if alpha >= 1 or target == nil or holder.Parent == nil then
			if step ~= nil then
				step:Disconnect()
			end
			holder:Destroy()
			Particles.burst(p.emitter, last, q.catchSparkles, colour)
			Particles.ring(last, colour, q.catchRing)
			return
		end
		local at, grow = Logic.binPrizePop(from, last, alpha)
		holder.Position = at
		board.Size = UDim2.fromScale(q.size * grow, q.size * grow)
	end)
end

-- The prize hops out of the bin to the player: a small bright ball in the tier's colour arcs from the top of the
-- bin to `to()` (asked every frame, so it follows a moving player; nil ends it) and ends in a few sparkles there.
-- With Reduce Motion only the sparkles at the player play.
function BinRoll.hop(bin: Instance, to: () -> Vector3?, tier: number, image: string?)
	local p = Presets.binRoll
	local found = base(bin)
	local first = to()
	if found == nil or first == nil then
		return
	end
	local colour = p.colours[math.clamp(math.floor(tier), 1, #p.colours)]
	if Context.reducedMotion() then
		Particles.burst(p.emitter, first, p.hop.sparkles, colour)
		return
	end
	local from: Vector3 = found + Vector3.new(0, p.lift, 0)
	if image ~= nil and image ~= "" then
		popPrize(from, to, first, colour, image)
		return
	end
	local ball = Context.effectPart("BinPrizeHop", Vector3.one * p.hop.size, colour)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Position = from
	ball.Parent = Context.folder()
	local started = os.clock()
	local last: Vector3 = first
	local step: RBXScriptConnection? = nil
	step = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - started) / p.hop.seconds
		local target = to()
		if target ~= nil then
			last = target
		end
		if alpha >= 1 or target == nil or ball.Parent == nil then
			if step ~= nil then
				step:Disconnect()
			end
			ball:Destroy()
			Particles.burst(p.emitter, last, p.hop.sparkles, colour)
			return
		end
		ball.Position = Logic.hopArc(from, last, p.hop.height, alpha)
	end)
end

-- The win: the reward show at the bin and its "win" beat.
function BinRoll.win(bin: Instance, tier: number)
	BinRoll.reward(bin, tier)
	beat("win", tier, bin)
end

return BinRoll
