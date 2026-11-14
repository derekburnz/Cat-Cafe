--!strict
-- The Mystic Pool's roll (#3314, trait-station.md section 1a). The server has already rolled; this only shows it:
--   1. Sage Sorrel raises his staff, and the rolled cat floats up over the pool in a sparkle and drops in with a
--      splash.
--   2. The liquid steps grey, green, blue, gold (one step every Presets.mysticPool.step seconds, a bubble burst on
--      each) and stops on the rolled rarity's colour. A mythic flashes on to its own colour (the Mythical cat
--      rarity's pink-red) with a rainbow shimmer, a star burst and confetti.
--   3. The cat pops back out on a splash and `onReveal` runs (the trait card rises). The liquid then fades back to
--      its rest colour and Sorrel lowers his staff.
-- The steps only ever go up and stop on the real rarity (Logic.poolAt), never past it and back, and never pause to
-- fake a "nearly": no near-miss teasing for a young audience. The colours are shared/Traits.RARITIES', so the pool
-- and the card match.
--
--   local skip = MysticPool.roll(station, catModelOrAssetName, "rare", function() showCard() end)
--   -- a tap: skip()  -- jumps straight to the card, from the very first roll
--
-- `station` is Model-Agent's CatCafe_Camp_Park_MysticPool (mysticpool.py: `_Liquid_Glow`, `_Sage_LegF2` with the
-- staff, PoolDrop and StaffTip attachments). `cat` is a cat Model to copy, an asset name in ReplicatedStorage.Assets
-- ("CatCafe_Cat_Tabby_Sit") or nil (the liquid alone). onReveal runs exactly once, whatever happens. Reduce Motion
-- shows the final colour, one sparkle burst and the card at once. Client only, nothing replicates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits"))

local MysticPool = {}

local playing: { [Model]: () -> () } = {} -- station -> its running roll's skip

-- The roll's beats, for the sounds (#3389, Audio followPool): "drop" as the cat splashes in, "step" for each colour
-- step after the first (its number, 2 and up), "mythic" for the Mythic's flash, and "reveal" once per roll as the cat
-- comes back (also on a skip and with Reduce Motion). `at` is the liquid's surface. Listeners only listen.
export type Beat = "drop" | "step" | "mythic" | "reveal"
local listeners: { (beat: Beat, step: number, at: Vector3) -> () } = {}

function MysticPool.onBeat(listener: (beat: Beat, step: number, at: Vector3) -> ())
	table.insert(listeners, listener)
end

local function beat(name: Beat, step: number, at: Vector3)
	for _, listener in listeners do
		task.spawn(listener, name, step, at)
	end
end

-- The rarity's colour from shared/Traits (the card's), grey for an unknown id.
function MysticPool.colourOf(rarity: string): Color3
	for _, r in Traits.RARITIES do
		if r.id == rarity then
			return Color3.fromHex(r.color)
		end
	end
	return Color3.fromHex(Traits.RARITIES[1].color)
end

local function findSuffix(root: Instance, suffix: string): Model?
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and string.sub(d.Name, -#suffix) == suffix then
			return d :: Model
		end
	end
	return nil
end

local function attachment(root: Instance, name: string): Attachment?
	local found = root:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("Attachment") then found :: Attachment else nil
end

local function partsOf(model: Model?): { BasePart }
	local out = {}
	if model ~= nil then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d :: BasePart)
			end
		end
	end
	return out
end

-- A copy of the rolled cat to float, anchored and walk-through, or nil.
local function copyCat(cat: (Model | string)?): Model?
	local source: Instance? = nil
	if typeof(cat) == "Instance" then
		source = cat
	elseif type(cat) == "string" then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		source = if assets ~= nil then assets:FindFirstChild(cat) else nil
	end
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local copy = (source :: Model):Clone() :: Model
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	copy.Name = "MysticPool_Cat"
	copy.Parent = Context.folder()
	return copy
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

export type Rig = {
	surface: Vector3, -- the middle of the liquid's surface
	front: Vector3, -- the way the pool faces (flat or nearly)
	rest: Color3, -- the liquid's own colour
	tip: Attachment?, -- the staff's tip
	paint: (colour: Color3) -> (),
	setArm: (k: number) -> (), -- 0 the staff down, 1 raised
}

-- The pool's moving pieces for one show at `station` (the roll below and the first walk-up's cutscene,
-- Effects/MysticIntroCut): the liquid to paint and Sorrel's staff arm to raise. Read it at the start of each show; a
-- missing piece just does nothing.
function MysticPool.rig(station: Model): Rig
	local p = Presets.mysticPool
	local liquid = partsOf(findSuffix(station, p.liquidSuffix))
	local drop = attachment(station, "PoolDrop")
	local arm = findSuffix(station, p.armSuffix)
	local armRest = if arm ~= nil then arm:GetPivot() else nil
	local turn = station:GetAttribute("SageTurn")
	local right = station:GetPivot():VectorToWorldSpace(
		CFrame.Angles(0, math.rad(if type(turn) == "number" then turn else 0), 0).RightVector
	)
	return {
		surface = if drop ~= nil then drop.WorldPosition else station:GetPivot().Position,
		front = station:GetPivot().LookVector,
		rest = if #liquid > 0 then liquid[1].Color else Color3.new(1, 1, 1),
		tip = attachment(station, "StaffTip"),
		paint = function(colour: Color3)
			for _, part in liquid do
				part.Color = colour
			end
		end,
		setArm = function(k: number)
			if arm ~= nil and armRest ~= nil then
				local spin = CFrame.fromAxisAngle(right, math.rad(p.raiseDegrees) * k)
				arm:PivotTo(CFrame.new(armRest.Position) * spin * armRest.Rotation)
			end
		end,
	}
end

function MysticPool.roll(
	station: Model,
	cat: (Model | string)?,
	rarity: string,
	onReveal: () -> (),
	lift: number?, -- #3942: seconds the cat rises up the pillar after it pops out (a whole scene); nil or 0 none
	landing: boolean?, -- the Rift Run's hand back: the cat falls from the sky straight in and the liquid is its colour
	liftHeight: number? -- studs over the liquid the lift ends at (Presets.mysticPool.liftHeight by default)
): () -> ()
	local old = playing[station]
	if old ~= nil then
		old() -- one roll at a time per pool: the last one jumps to its end
	end
	local p = Presets.mysticPool
	local revealed = false
	local beatAt = station:GetPivot().Position -- the liquid's surface once it is found below
	local function reveal()
		if not revealed then
			revealed = true
			beat("reveal", 0, beatAt)
			task.spawn(onReveal)
		end
	end

	local rig = MysticPool.rig(station)
	local rest = rig.rest
	local final = MysticPool.colourOf(rarity)
	local steps = Logic.poolSteps(rarity)
	local surface = rig.surface
	beatAt = surface
	local tip = rig.tip
	local paint = rig.paint
	local armK = 0
	local function setArm(k: number)
		armK = k
		rig.setArm(k)
	end

	local copy: Model? = nil
	local loop: RBXScriptConnection? = nil
	local finished = false
	local skip: () -> ()
	local function stop()
		if loop ~= nil then
			loop:Disconnect()
			loop = nil
		end
		if copy ~= nil then
			copy:Destroy()
			copy = nil
		end
		if playing[station] == skip then
			playing[station] = nil
		end
	end
	-- After the card: the liquid fades back to rest and the staff comes down. A new roll takes over at once.
	local function settle(from: Color3, armFrom: number)
		local began = os.clock()
		local fade: RBXScriptConnection
		fade = RunService.Heartbeat:Connect(function()
			if playing[station] ~= nil then
				fade:Disconnect()
				return
			end
			local k = (os.clock() - began) / p.fadeBack
			paint(from:Lerp(rest, ease(k)))
			setArm(armFrom * (1 - ease((os.clock() - began) / p.lower)))
			if k >= 1 then
				fade:Disconnect()
				paint(rest)
				setArm(0)
			end
		end)
	end
	skip = function()
		if finished then
			return
		end
		finished = true
		stop()
		paint(final)
		reveal()
		settle(final, armK)
	end

	if Context.reducedMotion() then
		finished = true
		paint(final)
		Particles.burst("catchSparkle", surface + Vector3.new(0, 1, 0), p.revealSparkles, final)
		reveal()
		task.delay(p.showCat, function()
			if playing[station] == nil then
				settle(final, 0)
			end
		end)
		return function() end
	end
	playing[station] = skip

	copy = copyCat(cat)
	local catSize = if copy ~= nil then copy:GetExtentsSize() else Vector3.zero
	local start = surface + station:GetPivot().LookVector * p.startFront -- in front of the middle, on the liquid
	local over = surface + Vector3.new(0, p.riseHeight, 0)
	local under = surface - Vector3.new(0, p.sink + catSize.Y, 0)
	local facing = station:GetPivot().Rotation * CFrame.Angles(0, math.pi, 0) -- the cat looks out at the players
	-- Derek 2026-11-13 ("cats coming out of trait portal not facing you"): the cat turns to this player's camera,
	-- level, wherever they stand round the pool (and as the scene's camera circles); the pool's front only when
	-- the camera is straight overhead
	local function placeCat(at: Vector3, spin: number)
		if copy == nil then
			return
		end
		local camera = workspace.CurrentCamera
		local yaw = if camera ~= nil then Logic.facePoint(at, camera.CFrame.Position) else nil
		local turn = if yaw ~= nil then CFrame.Angles(0, yaw, 0) else facing
		copy:PivotTo(CFrame.new(at) * turn * CFrame.Angles(0, spin, 0))
	end

	-- the Rift Run's landing (Presets.mysticPool.land): no float up and no colour steps (the realm's gates were the
	-- steps); the cat falls from high over the pool into liquid already its colour, then pops out as ever
	local landed = landing == true
	if landed then
		over = surface + Vector3.new(0, p.landHeight, 0)
		steps = { rarity }
		setArm(1)
	end
	local riseAt = if landed then 0 else p.raise
	local dropAt = if landed then 0 else riseAt + p.rise + p.hang
	local splashAt = dropAt + (if landed then p.landDrop else p.drop)
	local poolEnd = splashAt + (if landed then p.landHold else Logic.poolSeconds(rarity))
	local popEnd = poolEnd + p.popUp
	local liftSeconds = if lift ~= nil and lift > 0 then lift else 0
	local liftTop = if liftHeight ~= nil and liftHeight > 0 then liftHeight else p.liftHeight
	local liftEnd = popEnd + liftSeconds
	local doneAt = liftEnd + p.showCat
	local began = os.clock()
	local lastStep = 0
	local sparkled, splashed, popped = false, false, false
	placeCat(if landed then over else start - Vector3.new(0, catSize.Y + 1, 0), 0)
	if tip ~= nil and not landed then
		Particles.burst("catchSparkle", tip.WorldPosition, p.sparkles, Presets.palette.sparkle)
	end

	loop = RunService.Heartbeat:Connect(function()
		local t = os.clock() - began
		if not landed then
			setArm(ease(t / p.raise))
		end
		if t < riseAt then
			return
		end
		if not sparkled then
			sparkled = true
			Particles.burst(
				"catchSparkle",
				start + Vector3.new(0, 1, 0),
				p.sparkles,
				Presets.palette.sparkle
			)
		end
		if t < dropAt then -- floating up and hanging over the pool, turning slowly
			local k = ease((t - riseAt) / p.rise)
			local at = start:Lerp(over, k) + Vector3.new(0, 0.15 * math.sin(t * 6), 0)
			placeCat(at, k * math.pi * 0.5)
			return
		end
		if t < splashAt then -- falling faster and faster into the liquid
			local k = (t - dropAt) / p.drop
			placeCat(over:Lerp(under, k * k), math.pi * 0.5)
			return
		end
		if not splashed then
			splashed = true
			placeCat(under, 0)
			paint(MysticPool.colourOf(steps[1]))
			Particles.burst("splashDrops", surface, p.splash, Presets.palette.fishBelly)
			Particles.burst("poolBubble", surface, p.bubbles, MysticPool.colourOf(steps[1]))
			if landed then -- out of the rift: a ring and a star burst as it hits the liquid
				Particles.ring(surface + Vector3.new(0, 0.2, 0), final, 10, 0.7)
				Particles.burst(
					"catchSparkle",
					surface + Vector3.new(0, 1, 0),
					p.stars,
					Presets.palette.sparkle
				)
			end
			lastStep = 1
			beat("drop", 1, surface)
		end
		if t < poolEnd and landed then
			paint(final)
			return
		end
		if t < poolEnd then
			local into = t - splashAt
			local i, k = Logic.poolAt(rarity, into)
			local colour = MysticPool.colourOf(steps[i])
			local from = MysticPool.colourOf(steps[math.max(i - 1, 1)])
			paint(from:Lerp(colour, k))
			if i > lastStep then
				lastStep = i
				Particles.burst("poolBubble", surface, p.bubbles, colour)
				beat(if steps[i] == "mythic" then "mythic" else "step", i, surface)
				if steps[i] == "mythic" then
					Particles.burst(
						"catchSparkle",
						surface + Vector3.new(0, 1.5, 0),
						p.stars,
						Presets.palette.sparkle
					)
					Particles.confetti(surface + Vector3.new(0, 2, 0), p.confetti, p.mythicColours)
					Particles.ring(surface + Vector3.new(0, 0.2, 0), colour, 8, 0.9)
				end
			end
			if steps[i] == "mythic" and k >= 1 then -- the rainbow shimmer over the Mythic's colour
				local hue = (into * p.shimmerHz) % 1
				paint(
					colour:Lerp(
						Color3.fromHSV(hue, 0.65, 1),
						p.shimmerMix * (0.5 + 0.5 * math.sin(into * 9))
					)
				)
			end
			return
		end
		if not popped then
			popped = true
			paint(final)
			Particles.burst("splashDrops", surface, p.splash, Presets.palette.fishBelly)
			Particles.burst(
				"catchSparkle",
				surface + Vector3.new(0, 1.5, 0),
				p.revealSparkles,
				final
			)
			finished = true
			reveal()
		end
		if t < popEnd then
			local k = ease((t - poolEnd) / p.popUp)
			placeCat(under:Lerp(surface + Vector3.new(0, p.popHeight, 0), k), 0)
			return
		end
		local floatAt = if liftSeconds > 0 then liftTop else p.popHeight
		if t < liftEnd then -- #3942: up the pillar, turning as it goes
			local k = ease((t - popEnd) / liftSeconds)
			local height = p.popHeight + (liftTop - p.popHeight) * k
			placeCat(surface + Vector3.new(0, height, 0), k * p.liftTurns * math.pi * 2)
			return
		end
		if t < doneAt then
			placeCat(surface + Vector3.new(0, floatAt + 0.15 * math.sin(t * 4), 0), 0)
			return
		end
		stop()
		settle(final, 1)
	end)
	return skip
end

return MysticPool
