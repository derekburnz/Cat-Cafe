--!strict
-- The cat follower's motion (#5172, switch catFollower). Gameplay-Engineer's FollowerController walks each follower,
-- a copy of the cat's model in Workspace.Followers named Follower_<userId>, with one PivotTo a frame, and sets two
-- attributes on it: Moving (false after 3 seconds standing still) and Popped (os.clock() when it pops to its player
-- from far off). This draws the cat on top of that walk, on this client only:
--   - the walk or trot at the speed it really crosses the floor, legs, head and tail as a stray's;
--   - legs out and tucked while it hops (the floor under it rising or falling fast);
--   - once Moving is false it settles into a loaf and grooms a paw now and then, as a resting cafe cat does;
--   - a small puff of smoke where it pops in.
-- The controller already shows other players' followers only near and at most 8 on a phone, so every follower it
-- makes is drawn. The pose comes from the copy's own pose as bound (Pose.rest), never from its parts, so the pose
-- drawn last frame is never taken into the next one. Nothing here moves the follower or reaches the server.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local Follower = {}

Follower.FOLDER = "Followers"

type Entry = {
	rig: Pose.Rig,
	rest: { CFrame },
	toFloor: CFrame, -- the floor (Pose.floor) in the model pivot's space, as bound
	floor: CFrame, -- the floor drawn last frame
	stride: number,
	speed: number,
	lastFloor: Vector3?,
	climb: number, -- studs a second the floor rises (a hop), smoothed
	phase: number,
	style: Logic.Style,
	from: Logic.Style?,
	changedAt: number,
	settleFor: number,
	popSeen: unknown,
}

local entries: { [Model]: Entry } = {}
local started = false

local function bind(model: Model): Entry?
	local rig = Pose.bind(model)
	if rig == nil then
		return nil
	end
	local floor = Pose.floor(rig)
	return {
		rig = rig,
		rest = Pose.rest(rig),
		toFloor = model:GetPivot():ToObjectSpace(floor),
		floor = floor,
		stride = 0,
		speed = 0,
		lastFloor = nil,
		climb = 0,
		phase = Logic.phaseOf(model.Name) * 100,
		style = "stray" :: Logic.Style,
		from = nil,
		changedAt = 0,
		settleFor = Presets.motion.settle,
		popSeen = model:GetAttribute("Popped"),
	}
end

-- The style it should take now: walking, or once Moving is false a loaf with a paw wash now and then.
local function styleOf(model: Model, now: number, phase: number): Logic.Style
	local style: Logic.Style = "stray"
	if model:GetAttribute("Moving") == false then
		style = if Logic.licking(now, phase) then "lick" :: Logic.Style else "loaf" :: Logic.Style
	end
	return style
end

local function draw(model: Model, entry: Entry, now: number, dt: number): boolean
	local f = Presets.follower
	local rig = entry.rig
	if not Pose.read(rig) then
		return false
	end
	-- Where the controller has the cat: its body as the controller's PivotTo put it. A frame with no PivotTo since
	-- the last draw would read the drawn pose back, so it keeps last frame's floor.
	local floor = entry.floor
	if Pose.rewritten(rig) then
		floor = model:GetPivot() * entry.toFloor
	end
	entry.floor = floor
	local position = floor.Position
	local last = entry.lastFloor
	entry.lastFloor = position
	if last ~= nil and dt > 0 then
		local ground = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
		local k = math.min(1, dt * f.speedEase)
		entry.speed += (math.min(ground / dt, f.speedMax) - entry.speed) * k
		entry.climb += ((position.Y - last.Y) / dt - entry.climb) * k
	end
	entry.stride += entry.speed * dt / Logic.strideLength(math.max(entry.speed, 0.1))
	Pose.holdRest(rig, entry.rest, floor)

	local style: Logic.Style = styleOf(model, now, entry.phase)
	if style ~= entry.style then
		entry.from = entry.style
		entry.settleFor = Logic.settleSeconds(entry.style, style)
		entry.changedAt = now
		entry.style = style
	end
	local t = now + entry.phase
	local o = Logic.idle(entry.style, t, rig.kind)
	local from: Logic.Style? = entry.from
	if from ~= nil then
		local k = (now - entry.changedAt) / entry.settleFor
		if k >= 1 then
			entry.from = nil
		else
			o = Logic.mix(Logic.idle(from, t, rig.kind), o, k * k * (3 - 2 * k))
		end
	end
	if entry.style == "stray" then
		Logic.gait(o, entry.speed, entry.stride, 0)
		-- in the air: the front legs reach out going up and the back legs trail, then tuck in coming down
		local air = math.clamp(entry.climb / f.hopClimb, -1, 1)
		if math.abs(air) > 0.1 then
			o.bodyPitch += math.rad(f.hopPitch) * air
			o.pawFL += math.rad(f.hopReach) * math.abs(air)
			o.pawFR += math.rad(f.hopReach) * math.abs(air)
			o.pawBL -= math.rad(f.hopTrail) * math.abs(air)
			o.pawBR -= math.rad(f.hopTrail) * math.abs(air)
		end
	end
	Pose.draw(rig, o, -1)

	local popped = model:GetAttribute("Popped")
	if popped ~= entry.popSeen then
		entry.popSeen = popped
		entry.lastFloor = nil -- a pop is no walk: the legs do not run to catch up
		entry.speed = 0
		Particles.burst("smokePuff", position + Vector3.new(0, f.puffHeight, 0), f.puff)
	end
	return true
end

local function step(dt: number)
	local folder = Workspace:FindFirstChild(Follower.FOLDER)
	if folder == nil and next(entries) == nil then
		return
	end
	local now = os.clock()
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and entries[child :: Model] == nil then
				local model = child :: Model
				local made = bind(model)
				if made ~= nil then
					entries[model] = made
				end
			end
		end
	end
	for model, entry in entries do
		if model.Parent == nil or not draw(model, entry, now, dt) then
			entries[model] = nil
		end
	end
end

function Follower.start()
	if started then
		return
	end
	started = true
	RunService.PreRender:Connect(step)
end

return Follower
