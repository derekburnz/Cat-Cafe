--!strict
-- The camp extras' water (F100, camp-extras.md section 3: "steam off a thermos on the picnic blanket, ... a fish
-- jumping in the pond now and then"; Model-Agent's #750). Under the Sewer's standpipe a drop swells at the mouth,
-- falls onto the Lost and Found's lid and lands in its puddle with a few tiny drops and a ripple, then the next one
-- forms. In the Woods pond the orange fish jumps now and then: it leaves the water in a few drops and a ripple (the
-- fishJump beat, so Sound-Agent's campSplash plays there), arcs over, dives back in a little way on and swims home
-- under the water, turning round on the way, to rest as modelled. Only the nearest few within reach play; Reduce
-- Motion and Low performance hold the fish at rest, and the drips go on like steam. The thermos's steam is Ambient's
-- (its `Steam` attachment). The Yard Sale sign's swing is Motion's (`_Sign_Swing`); the rod cast, the lid rattle and
-- the basket lid are Animation-Engineer's (CampExtras.luau).
--
-- Source: Attachments in Workspace named `Drip` (just under a pipe's mouth; the drop lands on what is below it in
-- the same camp extra) and `FishJump` (on the water over the fish; the fish is that camp extra's child Model ending
-- `_Fish`, pivoted at its middle, its head toward -X). Only this client's copy of the fish moves. Listening only.
-- Numbers in Presets.campWater and the budget's campDrips and campFish.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Beats = require(script.Parent.Parent.Audio.Beats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Splash = require(script.Parent.Splash)

local CampWater = {}

type Drip = {
	mouth: Attachment,
	drop: Part?,
	started: number, -- os.clock() the drop began to swell; 0 while waiting for the next
	landing: Vector3?, -- where this drop lands, read as it starts to fall
	fall: number, -- seconds of its fall
	nextAt: number, -- when the next one swells
	on: boolean,
}

type Phase = "rest" | "jump" | "home"

type Pond = {
	spot: Attachment,
	fish: Model?,
	base: CFrame?, -- the fish's rest as modelled, read as a jump starts
	written: CFrame?, -- where this client last put it
	depth: number, -- studs from its rest up to the water
	dive: number, -- its pitch as it came back into the water
	phase: Phase,
	started: number,
	nextAt: number,
	exited: boolean,
	entered: boolean,
	on: boolean,
}

local drips: { [Attachment]: Drip } = {}
local ponds: { [Attachment]: Pond } = {}
local rng = Random.new()
local started = false

local function between(pair: { number }): number
	return rng:NextNumber(pair[1], pair[2])
end

-- The camp extra a point is on: the Model holding the attachment's part.
local function extraOf(attachment: Attachment): Model?
	local holder = attachment.Parent
	if holder == nil then
		return nil
	end
	local found = holder:FindFirstAncestorWhichIsA("Model")
	if found ~= nil and found:IsA("Model") then
		return found :: Model
	end
	return nil
end

local function fishOf(extra: Model): Model?
	for _, child in extra:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -5) == "_Fish" then
			return child :: Model
		end
	end
	return nil
end

-- Every part anchored, and at least one: a welded or unstreamed fish is left alone.
local function anchored(model: Model): boolean
	local any = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not (descendant :: BasePart).Anchored then
				return false
			end
			any = true
		end
	end
	return any
end

local function consider(instance: Instance)
	if not instance:IsA("Attachment") then
		return
	end
	local attachment = instance :: Attachment
	if attachment.Name == "Drip" and drips[attachment] == nil then
		drips[attachment] = {
			mouth = attachment,
			drop = nil,
			started = 0,
			landing = nil,
			fall = 0,
			nextAt = 0,
			on = false,
		}
	elseif attachment.Name == "FishJump" and ponds[attachment] == nil then
		ponds[attachment] = {
			spot = attachment,
			fish = nil,
			base = nil,
			written = nil,
			depth = 0,
			dive = 0,
			phase = "rest",
			started = 0,
			nextAt = 0,
			exited = false,
			entered = false,
			on = false,
		}
	end
end

-- Drips ------------------------------------------------------------------------------------------------------

local function stopDrip(d: Drip)
	d.on = false
	d.started = 0
	d.landing = nil
	local drop = d.drop
	if drop ~= nil then
		drop:Destroy()
	end
	d.drop = nil
end

local function dropOf(d: Drip): Part
	local existing = d.drop
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local o = Presets.campWater.drip
	local drop = Context.effectPart("CampDrip", Vector3.new(o.size, o.size, o.size), o.colour)
	drop.Shape = Enum.PartType.Ball
	drop.Transparency = 1
	drop.Parent = Context.folder()
	d.drop = drop
	return drop
end

-- What the drop lands on below the mouth (the lid, its puddle), within reach in the same camp extra.
local function landingOf(d: Drip, from: Vector3): Vector3
	local o = Presets.campWater.drip
	local extra = extraOf(d.mouth)
	if extra ~= nil then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { extra }
		local hit = Workspace:Raycast(from, Vector3.new(0, -o.reach, 0), params)
		if hit ~= nil then
			return hit.Position
		end
	end
	return from - Vector3.new(0, o.fallback, 0)
end

local function stepDrip(d: Drip, now: number)
	local o = Presets.campWater.drip
	local mouth = d.mouth
	if mouth.Parent == nil then
		stopDrip(d)
		return
	end
	if d.started == 0 then
		if now < d.nextAt then
			return
		end
		d.started = now
		d.landing = nil
	end
	local top = mouth.WorldPosition
	local t = now - d.started
	local grown, fallen = Logic.dripAt(t, o.swell, o.gravity)
	local drop = dropOf(d)
	if t >= o.swell and d.landing == nil then
		local landing = landingOf(d, top)
		d.landing = landing
		d.fall = Logic.dripFall(top.Y - landing.Y - o.size, o.gravity)
	end
	local landing = d.landing
	if landing ~= nil and t >= o.swell + d.fall then
		drop.Transparency = 1
		Particles.burst("dripSplash", landing + Vector3.new(0, 0.05, 0), o.splash)
		Splash.ripple(landing, o.ripple, o.rippleFrom)
		d.started = 0
		d.landing = nil
		d.nextAt = now + between(o.gap)
		return
	end
	local size = math.max(o.size * grown, 0.02)
	drop.Size = Vector3.new(size, size, size)
	drop.Transparency = o.transparency
	drop.CFrame = CFrame.new(top - Vector3.new(0, size / 2 + fallen, 0))
end

-- The fish ---------------------------------------------------------------------------------------------------

-- Whether something else (the server placing the camp again) moved the fish since this client last put it.
local function movedOff(p: Pond, fish: Model): boolean
	local written = p.written
	if written == nil then
		return false
	end
	local now = fish:GetPivot()
	return (now.Position - written.Position).Magnitude > 0.01
		or now.LookVector:Dot(written.LookVector) < 0.9999
end

local function place(p: Pond, fish: Model, cframe: CFrame)
	fish:PivotTo(cframe)
	p.written = cframe
end

-- Back to its rest as modelled, unless it was moved off it.
local function restFish(p: Pond)
	local fish, base = p.fish, p.base
	if p.phase ~= "rest" and fish ~= nil and base ~= nil and fish.Parent ~= nil then
		if not movedOff(p, fish) then
			place(p, fish, base)
		end
	end
	p.phase = "rest"
	p.base = nil
	p.written = nil
end

local function startJump(p: Pond, now: number): boolean
	local extra = extraOf(p.spot)
	local fish = if extra ~= nil then fishOf(extra) else nil
	if fish == nil or not anchored(fish) then
		return false
	end
	local base = fish:GetPivot()
	p.fish = fish
	p.base = base
	p.written = nil
	p.depth = math.max(0, p.spot.WorldPosition.Y - base.Position.Y)
	p.phase = "jump"
	p.started = now
	p.exited = false
	p.entered = false
	return true
end

-- Drops and a ripple where the fish goes through the water, `u` of the way through its jump.
local function splashAt(p: Pond, u: number, drops: number, diameter: number)
	local f = Presets.campWater.fish
	local base = p.base :: CFrame
	local forward = Logic.fishArc(u, f.length, p.depth, f.peak)
	local at = (base * CFrame.new(f.headX * forward, p.depth, 0)).Position
	Particles.burst("splashDrops", at + Vector3.new(0, 0.1, 0), drops)
	Splash.ripple(at, diameter)
end

local function stepFish(p: Pond, now: number)
	local f = Presets.campWater.fish
	local fish, base = p.fish, p.base
	if fish == nil or base == nil or fish.Parent == nil or movedOff(p, fish) then
		restFish(p)
		p.nextAt = now + between(f.every)
		return
	end
	if p.phase == "jump" then
		local u = (now - p.started) / f.seconds
		local out, back = Logic.fishSurface(p.depth, f.peak)
		if not p.exited and u >= out then
			p.exited = true
			splashAt(p, out, f.exitDrops, f.exitRipple)
			Beats.hit:Fire("fishJump", p.spot)
		end
		if not p.entered and u >= back then
			p.entered = true
			splashAt(p, back, f.entryDrops, f.entryRipple)
		end
		if u >= 1 then
			local _, _, dive = Logic.fishArc(1, f.length, p.depth, f.peak)
			p.dive = dive
			p.phase = "home"
			p.started = now
			u = 1
		end
		local forward, up, pitch = Logic.fishArc(u, f.length, p.depth, f.peak)
		place(
			p,
			fish,
			base * CFrame.new(f.headX * forward, up, 0) * CFrame.Angles(0, 0, f.headX * pitch)
		)
	else
		local u = (now - p.started) / f.back
		if u >= 1 then
			restFish(p)
			p.nextAt = now + between(f.every)
			return
		end
		local along, yaw, pitch = Logic.fishReturn(u, f.length, f.turn, p.dive)
		place(
			p,
			fish,
			base
				* CFrame.new(f.headX * along, 0, 0)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(0, 0, f.headX * pitch)
		)
	end
end

-- The once a second choice ------------------------------------------------------------------------------------

local function pick()
	local w = Presets.campWater
	local budget = Context.budget
	local now = os.clock()
	local dripCandidates: { Logic.Candidate<Drip> } = {}
	for attachment, d in drips do
		if not attachment:IsDescendantOf(Workspace) then
			stopDrip(d)
			drips[attachment] = nil
		else
			table.insert(
				dripCandidates,
				{ key = d, distance = Context.distance(attachment.WorldPosition) }
			)
		end
	end
	local dripOn: { [Drip]: boolean } = {}
	for _, d in Logic.nearest(dripCandidates, w.within, budget.campDrips) do
		dripOn[d] = true
		if not d.on then
			d.on = true
			d.started = 0
			d.nextAt = now + between(w.drip.gap)
		end
	end
	for _, d in drips do
		if d.on and not dripOn[d] then
			stopDrip(d)
		end
	end

	local still = Context.reducedMotion() or budget.campFish <= 0
	local fishCandidates: { Logic.Candidate<Pond> } = {}
	for attachment, p in ponds do
		if not attachment:IsDescendantOf(Workspace) then
			restFish(p)
			ponds[attachment] = nil
		elseif not still then
			table.insert(
				fishCandidates,
				{ key = p, distance = Context.distance(attachment.WorldPosition) }
			)
		end
	end
	local fishOn: { [Pond]: boolean } = {}
	if not still then
		for _, p in Logic.nearest(fishCandidates, w.within, budget.campFish) do
			fishOn[p] = true
			if not p.on then
				p.on = true
				p.nextAt = now + between(w.fish.first)
			end
		end
	end
	for _, p in ponds do
		if p.on and not fishOn[p] then
			p.on = false
			restFish(p)
		end
	end
end

local function step()
	local now = os.clock()
	for _, d in drips do
		if d.on then
			stepDrip(d, now)
		end
	end
	local still = Context.reducedMotion()
	for _, p in ponds do
		if not p.on then
			continue
		elseif still then
			-- Reduce Motion turned on mid jump: home at once; pick turns it off within the second
			restFish(p)
		elseif p.phase == "rest" then
			if now >= p.nextAt and not startJump(p, now) then
				p.nextAt = now + between(Presets.campWater.fish.every)
			end
		else
			stepFish(p, now)
		end
	end
end

function CampWater.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(consider)
	task.spawn(function()
		while true do
			pick()
			task.wait(Presets.campWater.pick)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return CampWater
