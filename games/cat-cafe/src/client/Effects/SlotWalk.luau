--!strict
-- A cafe cat walking to its new spot (#2050, Derek2 2026-11-07: cats "appear on a role as greeter then like teleport
-- part by part really quick away"). When a cat changes spot (Auto Equip moving a resting cat onto a role, a role
-- emptied back to a nap spot, a placement by hand), the server destroys its model and builds a new one at the new
-- spot in the same moment (CafeService.refreshPlot), so on every screen the cat jumped across the room. Desktop-
-- Tester's capture on 2026-11-07 showed exactly that: a Uid gone from nap_2 and back as greeter_1 0.1 s later, 25.8
-- studs away. Now, when a model whose Uid left the same plot's Cats a moment ago (Presets.slotWalk.window) appears
-- more than `minStuds` away, this client hides the new model and walks a copy of the cat (its walking body, gold if
-- it is) from where it was to it, round the tables (PathfindingService, else straight), then fades the copy out as
-- the new model fades in. It hurries to arrive within `maxSeconds`. A spot up off the floor (the counter top, a cat
-- tree's cushion) more than `maxRise` above or below the last one gets no walk; a nap bed's cushion is within it, so
-- a cat sent back to rest walks to its bed too.
-- Skipped (the cat just appears, as before) with Reduce Motion, at night, for a cat built asleep or on a bedtime
-- trip, a hidden cat, or one out of animRadius. The copy never collides or blocks a click; nothing here fires a
-- remote or moves the server's model. Cats.luau and CafeWalk leave a model with SlotWalk.MARK alone.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Context = require(script.Parent.Context)
local GoldTone = require(ReplicatedStorage.Shared.GoldTone)
local Logic = require(script.Parent.Logic)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local SlotWalk = {}

-- The local mark on the new model while its copy walks to it.
SlotWalk.MARK = "SlotWalkLocal"

type Left = { from: CFrame, at: number }

type Walk = {
	model: Model,
	copy: Model,
	rig: Pose.Rig,
	rest: { CFrame }, -- each part's frame at bind, in the copy's own floor space
	hidden: { BasePart },
	shown: { BasePart },
	route: { Vector3 },
	travelled: number,
	speed: number,
	stride: number,
	yaw: number,
	phase: number,
	arrivedAt: number?,
	planned: boolean,
}

local AGENT = { AgentRadius = 0.8, AgentHeight = 2, AgentCanJump = false }

local left: { [Instance]: { [string]: Left } } = {} -- per Cats folder: each Uid that just left it, and from where
local walks: { [Model]: Walk } = {}
local stepping: RBXScriptConnection? = nil
-- where each cafe cat stands, read once its parts are here: by the time a removed model's ChildRemoved fires its
-- parts may be gone, and an empty model's pivot is the world origin (Desktop-Tester 2026-11-07: a one-frame flash)
local placed: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function partsOf(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

local function setFade(parts: { BasePart }, k: number)
	for _, part in parts do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = k
		end
	end
end

-- The walking body (A) of `model`'s cat, gold if it is, as the server's AssetRegistry.cloneCat picks it.
-- The second result: the copy made from it must be toned gold (GoldTone.apply, #4133: gold from the base model).
local function walkingTemplate(model: Model): (Model?, boolean)
	local catId = model:GetAttribute("CatId")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if type(catId) ~= "string" or assets == nil then
		return nil, false
	end
	local names, tone = { Catalog.catModelName(catId) }, false
	if model:GetAttribute("Gold") == true then
		names, tone = GoldTone.names(Catalog.goldModelName(catId), Catalog.catModelName(catId))
	end
	for _, name in names do
		local found = assets:FindFirstChild(name)
		if found ~= nil and found:IsA("Model") then
			return found :: Model, tone
		end
	end
	return nil, false
end

-- Why a walk ended, left on the cat's model on this client only for a tester to read (#2050): the reason, and the
-- position about to be drawn, the copy's body as read and the two ends of its way, each rounded to 0.1 stud.
local function note(walk: Walk, reason: string, position: Vector3?, body: Vector3?)
	if walk.model.Parent == nil then
		return
	end
	local function at(v: Vector3?): string
		return if v == nil then "-" else string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
	end
	walk.model:SetAttribute(
		"SlotWalkEnd",
		string.format(
			"%s drawn=%s body=%s from=%s to=%s planned=%s speed=%.1f travelled=%.1f",
			reason,
			at(position),
			at(body),
			at(walk.route[1]),
			at(walk.route[#walk.route]),
			tostring(walk.planned),
			walk.speed,
			walk.travelled
		)
	)
end

local function finish(walk: Walk)
	walks[walk.model] = nil
	setFade(walk.hidden, 0)
	if walk.model.Parent ~= nil then
		walk.model:SetAttribute(SlotWalk.MARK, nil)
	end
	walk.copy:Destroy()
end

-- The walk's speed for its route: Presets.slotWalk.speed, quicker when the way is long, so it arrives within maxSeconds.
local function settle(walk: Walk)
	local length = 0
	for i = 2, #walk.route do
		length += (walk.route[i] - walk.route[i - 1]).Magnitude
	end
	local s = Presets.slotWalk
	walk.speed = math.max(s.speed, length / s.maxSeconds)
	walk.planned = true
end

-- Round the tables from `from` to `to` when PathfindingService finds a way that stays near the straight line and the
-- floor (Logic.walkableWay), else straight. A way found after planWait comes too late: the copy is walking straight.
local function plan(walk: Walk, from: Vector3, to: Vector3)
	local s = Presets.slotWalk
	task.delay(s.planWait, function()
		if walks[walk.model] == walk and not walk.planned then
			settle(walk)
		end
	end)
	task.spawn(function()
		local path = PathfindingService:CreatePath(AGENT)
		local ok = pcall(function()
			path:ComputeAsync(from, to)
		end)
		if walks[walk.model] ~= walk or walk.planned then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			local found: { Vector3 } = {}
			for i, waypoint in path:GetWaypoints() do
				if i > 1 then
					table.insert(found, waypoint.Position)
				end
			end
			if Logic.walkableWay(found, from, to, s.detour, s.waypointRise) then
				local route = { from }
				for _, p in found do
					table.insert(route, Vector3.new(p.X, to.Y, p.Z))
				end
				route[#route] = to
				walk.route = route
			end
		end
		settle(walk)
	end)
end

local function begin(model: Model, from: CFrame): boolean
	local s = Presets.slotWalk
	if
		walks[model] ~= nil
		or model.Parent == nil
		or Context.reducedMotion()
		or Context.isNight()
	then
		return false
	end
	if
		model:GetAttribute("Bedtime") ~= nil
		or model:GetAttribute("Asleep") == true
		or model:GetAttribute("HiddenLocal") == true
		or model:GetAttribute("BedTripAt") ~= nil
	then
		return false
	end
	local to = model:GetPivot()
	local rise = math.abs(to.Position.Y - from.Position.Y)
	if (to.Position - from.Position).Magnitude < s.minStuds or rise > s.maxRise then
		return false -- next door, or up on the counter or a cat tree: it just appears there
	end
	local radius = Context.budget.animRadius
	if Context.distance(to.Position) > radius and Context.distance(from.Position) > radius then
		return false
	end
	local template, tone = walkingTemplate(model)
	if template == nil then
		return false
	end
	local copy = template:Clone() :: Model
	if tone then
		GoldTone.apply(copy)
	end
	copy.Name = "SlotWalker"
	for _, tag in CollectionService:GetTags(copy) do
		CollectionService:RemoveTag(copy, tag)
	end
	for _, key in { "Uid", "CatId", "Gold", "Rarity", "Variant" } do
		copy:SetAttribute(key, model:GetAttribute(key))
	end
	-- along the floor: a nap bed's Sleep point sits up on its cushion, so the walk keeps to the lower of the two
	-- heights and the cross-fade at the end lifts it onto the bed
	local floorY = math.min(from.Position.Y, to.Position.Y)
	local start = Vector3.new(from.Position.X, floorY, from.Position.Z)
	local goal = Vector3.new(to.Position.X, floorY, to.Position.Z)
	local look = Vector3.new(goal.X - start.X, 0, goal.Z - start.Z)
	copy:PivotTo(
		CFrame.lookAt(start, start + (if look.Magnitude > 1e-3 then look else from.LookVector))
	)
	local shown = partsOf(copy)
	for _, part in shown do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.LocalTransparencyModifier = 0
	end
	copy.Parent = Context.folder()
	local rig = Pose.bind(copy) -- after the anchoring: Pose binds an unanchored body only to its Motor6Ds
	if rig == nil or rig.usesMotors then
		copy:Destroy()
		return false
	end
	-- the copy is this client's alone, so its pose is drawn from its parts as bound, every frame: whatever else moves
	-- one of them between frames (Desktop-Tester 2026-11-07 read its body hundreds of studs off for a frame, and
	-- earlier far below the map) is never read back as where the cat is
	local floor0 = Pose.floor(rig)
	local rest: { CFrame } = {}
	for i, frame in rig.base do
		rest[i] = floor0:ToObjectSpace(frame)
	end
	local hidden = partsOf(model)
	setFade(hidden, 1)
	model:SetAttribute(SlotWalk.MARK, true)
	local walk: Walk = {
		model = model,
		copy = copy,
		rig = rig,
		rest = rest,
		hidden = hidden,
		shown = shown,
		route = { start, goal },
		travelled = 0,
		speed = s.speed,
		stride = 0,
		yaw = Logic.yawOf(if look.Magnitude > 1e-3 then look else from.LookVector),
		phase = Logic.phaseOf(tostring(model:GetAttribute("Uid") or model.Name)) * 100,
		arrivedAt = nil,
		planned = false,
	}
	walks[model] = walk
	plan(walk, start, goal)
	if stepping == nil then
		stepping = RunService.PreRender:Connect(SlotWalk.step)
	end
	return true
end

-- #2946: walks a copy of `model` (a cat already at its spot) in from `from`, as a spot change does: the first bait's
-- cat comes in from the yard (Effects/FirstBaitCut). False when it cannot (the same rules as a spot change), and the
-- cat just stays where it is.
function SlotWalk.walkIn(model: Model, from: CFrame): boolean
	return begin(model, from)
end

local function advance(walk: Walk, now: number, dt: number): boolean
	local s = Presets.slotWalk
	local speed = 0
	local position: Vector3
	local heading: Vector3
	if walk.arrivedAt == nil and walk.planned then
		walk.travelled += walk.speed * dt
		local arrived: boolean
		position, heading, arrived = Logic.along(walk.route, walk.travelled)
		speed = walk.speed
		if arrived then
			walk.arrivedAt = now
		end
	else
		position, heading = Logic.along(walk.route, walk.travelled)
	end
	local route = walk.route
	if
		position ~= position
		or Logic.flatDistanceToSegment(position, route[1], route[#route]) > s.detour
		or math.abs(position.Y - route[#route].Y) > s.waypointRise
	then
		note(walk, "offway", position, walk.rig.body.Position)
		return false -- never drawn anywhere but on its way: the cat just shows at its new spot
	end
	-- the new model stays hidden the whole way, parts that replicate after the walk began included, and whatever
	-- else wrote its LocalTransparencyModifier (Desktop-Tester 2026-11-07: the cat at nap_4 showed beside its copy)
	walk.hidden = partsOf(walk.model)
	if walk.model:GetAttribute(SlotWalk.MARK) ~= true then
		walk.model:SetAttribute(SlotWalk.MARK, true)
	end
	if walk.arrivedAt == nil then
		setFade(walk.hidden, 1)
	end
	local flat = Vector3.new(heading.X, 0, heading.Z)
	if flat.Magnitude > 1e-3 then
		walk.yaw = Logic.turnToward(walk.yaw, Logic.yawOf(flat), math.rad(s.turn) * dt)
	end
	if walk.arrivedAt ~= nil then
		-- turn to face the way the new model does as the two cross-fade
		local target = Logic.yawOf(walk.model:GetPivot().LookVector)
		walk.yaw = Logic.turnToward(walk.yaw, target, math.rad(s.turn) * dt)
		speed = 0
	end
	walk.stride += speed * dt / Logic.strideLength(math.max(speed, 0.1))
	local rig = walk.rig
	if not Pose.read(rig) then
		note(walk, "unread", position, nil)
		return false
	end
	-- its pose from the parts as bound, its floor at the origin, which Pose.hold then moves onto the way
	local base = rig.base
	for i, frame in walk.rest do
		base[i] = frame
	end
	Pose.hold(rig, CFrame.new(position) * CFrame.Angles(0, walk.yaw, 0))
	local o = Logic.idle("stray", now + walk.phase, rig.kind)
	Logic.gait(o, speed, walk.stride, 0)
	Pose.draw(rig, o, -1)
	walk.copy:SetAttribute("WalkDrawn", position)
	walk.copy:SetAttribute("WalkBody", rig.body.Position)
	local arrivedAt = walk.arrivedAt
	if arrivedAt ~= nil then
		local k = math.clamp((now - arrivedAt) / s.fade, 0, 1)
		setFade(walk.shown, k)
		setFade(walk.hidden, 1 - k)
		if k >= 1 then
			note(walk, "arrived", position, rig.body.Position)
			return false
		end
	end
	return true
end

function SlotWalk.step(dt: number)
	local now = os.clock()
	for model, walk in walks do
		local gone = if model.Parent == nil
			then "removed"
			elseif walk.copy.Parent == nil then "copy removed"
			elseif model:GetAttribute("HiddenLocal") == true then "hidden"
			elseif
				model:GetAttribute("Bedtime") ~= nil or model:GetAttribute("BedTripAt") ~= nil
			then "bedtime"
			else nil
		if gone ~= nil then
			note(walk, gone, nil, nil)
			finish(walk)
		elseif not advance(walk, now, dt) then
			finish(walk)
		end
	end
	if next(walks) == nil and stepping ~= nil then
		stepping:Disconnect()
		stepping = nil
	end
end

-- Whether `model` is hidden while its copy walks to it.
function SlotWalk.isWalking(model: Model): boolean
	return walks[model] ~= nil
end

-- `go` once `model` has its parts here: a model can arrive before its descendants have replicated, and then it has
-- nothing to hide and no place of its own to walk to yet (its pivot reads the world origin). Gives up after a second.
local function whenBuilt(model: Model, go: () -> ())
	if model:FindFirstChildWhichIsA("BasePart", true) ~= nil then
		go()
		return
	end
	local done = false
	local added: RBXScriptConnection
	added = model.DescendantAdded:Connect(function(descendant: Instance)
		if not done and descendant:IsA("BasePart") then
			done = true
			added:Disconnect()
			task.defer(go) -- the rest of the model lands in the same batch
		end
	end)
	task.delay(1, function()
		if not done then
			done = true
			added:Disconnect()
		end
	end)
end

local function watchCats(cats: Instance)
	if left[cats] ~= nil then
		return
	end
	local recent: { [string]: Left } = {}
	left[cats] = recent
	cats.ChildRemoved:Connect(function(child: Instance)
		if not child:IsA("Model") then
			return
		end
		local model = child :: Model
		local uid = model:GetAttribute("Uid")
		local walk = walks[model]
		local from: CFrame? = if walk ~= nil
			then CFrame.new((Logic.along(walk.route, walk.travelled))) -- still on its way: from where its copy is
			else placed[model]
		placed[model] = nil
		if walk ~= nil then
			finish(walk)
		end
		if type(uid) == "string" and from ~= nil then
			recent[uid] = { from = from, at = os.clock() }
		end
	end)
	cats.ChildAdded:Connect(function(child: Instance)
		if not child:IsA("Model") then
			return
		end
		local model = child :: Model
		local uid = model:GetAttribute("Uid")
		local was = if type(uid) == "string" then recent[uid] else nil
		if was ~= nil then
			recent[uid :: string] = nil
		end
		whenBuilt(model, function()
			if model.Parent == nil then
				return
			end
			placed[model] = model:GetPivot()
			if was ~= nil and os.clock() - was.at <= Presets.slotWalk.window then
				begin(model, was.from)
			end
		end)
	end)
	for _, child in cats:GetChildren() do
		if child:IsA("Model") then
			local model = child :: Model
			whenBuilt(model, function()
				if model.Parent ~= nil then
					placed[model] = model:GetPivot()
				end
			end)
		end
	end
	-- forget anything that left and never came back
	task.spawn(function()
		while cats.Parent ~= nil do
			task.wait(5)
			local now = os.clock()
			for uid, was in recent do
				if now - was.at > Presets.slotWalk.window then
					recent[uid] = nil
				end
			end
		end
		left[cats] = nil
	end)
end

local function watchPlot(plot: Instance)
	local cats = plot:FindFirstChild("Cats")
	if cats ~= nil then
		watchCats(cats)
		return
	end
	local added: RBXScriptConnection
	added = plot.ChildAdded:Connect(function(child: Instance)
		if child.Name == "Cats" then
			added:Disconnect()
			watchCats(child)
		end
	end)
end

function SlotWalk.start()
	if started then
		return
	end
	started = true
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
end

return SlotWalk
