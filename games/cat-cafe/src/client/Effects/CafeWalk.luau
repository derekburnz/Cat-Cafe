--!strict
-- Cafe cats on the move (Derek 2026-10-29 19:45: "make the cats move around cafe not just waddle back and fourth
-- while sitting"), on this client only. A working cat sits at its station on the seated body (B), or stands there on
-- the work body (S, #826), a model the server owns. To walk, this client hides that model (LocalTransparencyModifier; its rate tag moves onto the walker
-- and its sparkles pause) and walks a copy of the cat on the walking body (A), dressed in its role's outfit, then
-- brings the copy back and shows the station model again. The server's model never moves, so nothing replicates.
--
--   CafeWalk.go(cat, route, opts)  walks `cat` (a station cat in your own cafe) from where it is through `route`
--                                   (world points on the cafe floor), then stands facing opts.faceAt; opts.tray rides
--                                   level on its head, its underside on the body's Carry attachment at the ear tips,
--                                   with any hat taller than the ears hidden under it, and opts.arrived runs when it
--                                   gets there. False if it cannot go.
--   CafeWalk.home(cat, done)        walks it back the way it came, sits it at its station and then runs `done`
--                                   (at once if it is not away). A go() before it is back sends it off again and
--                                   drops `done`.
--   CafeWalk.isAway(cat)            whether it is up and about.
--
-- It rises out of a sit as it gets up and sinks into one as it sits back down (or, from a station cat standing on the
-- work body, S, #826, drops from its back legs onto all fours and rears back up), trots steady under a tray with its
-- chin up, and plays the tip sweep at the pile (Moments.TipSwept: it rears up and drags the coins in, and the tray
-- with the coin bag hops from the pile onto its head) and the drop at the till (Moments.TipBanked: a quick dip),
-- pausing its walk for each (F90, cats-make-orders.md section 6; Logic.crouch, trayCarry, sweepPose, bankNod).
--
-- By itself it sends an idle waiter in your own cafe on a stroll now and then (Presets.cafeWalk): onto the nearest
-- lane, along it to a chair's Approach point, a look over the table, and back. F90's orders (cats-make-orders.md,
-- Gameplay-Engineer's Controllers/CafeOrders) call go() and home() with real routes and a tray; a go() takes over an
-- idle stroll. A walk ends at once, the station model shown again, if that model goes, the cafe closes for the
-- night, the cat is sent to bed (Bedtime), it is hidden, or the camera goes out of range.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CatDress = require(ReplicatedStorage.Shared.CatDress)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local CafeWalk = {}

export type Options = {
	faceAt: Vector3?, -- where it looks once it gets there (a table)
	tray: Model?, -- carried level on its head, placed each frame; the caller makes and removes it (a dish or the
	-- coin bag goes inside the tray Model, on its Item attachment, so it moves with it)
	speed: number?, -- studs a second; Presets.cafeWalk.speed by default
	arrived: (() -> ())?, -- runs once when it gets to the end of the route
}

type State = "up" | "walk" | "stand" | "settle" | "down"

-- A tip sweep at the pile or a drop at the till (F90), from `at` (os.clock()), facing `toward`; the walk waits for it.
type Action = { kind: "sweep" | "bank", at: number, toward: Vector3 }

type Walk = {
	station: Model,
	home: CFrame, -- the station model's pivot, where it sits
	walker: Model,
	rig: Pose.Rig,
	head: BasePart?,
	carry: Attachment?, -- Model-Agent's Carry attachment over the ears (#778), where a tray's underside goes
	tall: { BasePart }, -- head props and hats that rise above Carry, hidden while a tray rides on the head
	hidden: { BasePart }, -- the station model's parts, faded out on this client
	cover: number, -- how far they are faded out now, for a part that arrives mid walk
	shown: { BasePart }, -- the walker's parts
	tags: { [BillboardGui]: Instance? }, -- the station's rate tags, moved onto the walker, with their own Adornee
	paused: { [Instance]: boolean }, -- the station's sparkles, switched off, with whether each was on
	watch: RBXScriptConnection?, -- the station model's DescendantAdded, so what arrives mid walk is taken too
	state: State,
	stateAt: number,
	position: Vector3,
	yaw: number,
	route: { Vector3 }, -- the leg it is walking, starting where it set off
	marks: { number }, -- studs along `route` at each point after the first
	nextMark: number,
	travelled: number,
	passed: { Vector3 }, -- the points it has walked through since it got up and not yet back past, the station first
	speed: number, -- now, for the legs
	stride: number,
	phase: number,
	options: Options,
	goingHome: boolean,
	done: (() -> ())?,
	idle: boolean, -- an idle stroll of its own
	standUntil: number, -- when an idle stroll heads home
	carrying: number, -- 0 to 1 of the way into carrying a tray (Presets.cafeWalk.carry.ease)
	action: Action?,
	standing: boolean, -- the station model stands on the work body (S, #826), so it gets up from standing
}

local walks: { [Model]: Walk } = {}
local nextStroll: { [Model]: number } = {}
local rng = Random.new()
local started = false
local scanAt = 0

local WORKING = "WorkingCat"
local SCAN_SECONDS = 0.5
local EASE = 8 -- how fast the legs catch up with the walking speed, per second

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

local function setFade(parts: { BasePart }, k: number)
	for _, part in parts do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = k
		end
	end
end

local function partsOf(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant :: BasePart)
		end
	end
	return parts
end

local function assets(): Instance?
	return ReplicatedStorage:FindFirstChild("Assets")
end

-- The walking body (A) of the cat at `station`, gold if it is, as the server's AssetRegistry.cloneCat picks it.
local function walkingTemplate(station: Model): Model?
	local catId = station:GetAttribute("CatId")
	local folder = assets()
	if type(catId) ~= "string" or folder == nil then
		return nil
	end
	local names = { Catalog.catModelName(catId) }
	if station:GetAttribute("Gold") == true then
		table.insert(names, 1, Catalog.goldModelName(catId))
	end
	for _, name in names do
		local found = folder:FindFirstChild(name)
		if found ~= nil and found:IsA("Model") then
			return found :: Model
		end
	end
	return nil
end

-- A copy of the cat on the walking body in its role's outfit, at `home`, faded out, never colliding or blocking a
-- click; with the station's Uid and CatId so its idles keep their own timing and look.
local function makeWalker(station: Model, home: CFrame): Model?
	local template = walkingTemplate(station)
	if template == nil then
		return nil
	end
	local walker = (template :: Model):Clone() :: Model
	walker.Name = "CafeWalker"
	for _, key in { "Uid", "CatId", "Gold", "Rarity", "Variant" } do -- Variant: a rainbow coat flows on it too
		walker:SetAttribute(key, station:GetAttribute(key))
	end
	local role = station:GetAttribute("Role")
	local folder = assets()
	if type(role) == "string" and folder ~= nil then
		-- the walking body has slots for the head pieces, the bow tie and the cape (Model-Agent's #778) and for the
		-- walking cuts of the vest, the sash and the apron (#787; CatDress picks the _Walk cut, #789), none of them on a
		-- cat with a Back prop
		CatDress.dress(walker, role, function(name: string): Model?
			local found = folder:FindFirstChild(name)
			return if found ~= nil and found:IsA("Model")
				then (found :: Model):Clone() :: Model
				else nil
		end)
	end
	walker:PivotTo(home)
	for _, part in partsOf(walker) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.LocalTransparencyModifier = 1
	end
	walker.Parent = Context.folder()
	return walker
end

-- The walker's head part: the biggest part of its Head piece, for the tray.
local function headOf(walker: Model): BasePart?
	local best: BasePart? = nil
	for _, part in partsOf(walker) do
		local piece = part.Parent
		local named = string.sub(part.Name, -5) == "_Head"
			or (piece ~= nil and string.sub(piece.Name, -5) == "_Head")
		if named and (best == nil or part.Size.Magnitude > (best :: BasePart).Size.Magnitude) then
			best = part
		end
	end
	return best
end

-- The walker's Carry attachment (in its Head part, at the ear tips), or nil on a body without one.
local function carryOf(walker: Model): Attachment?
	local found = walker:FindFirstChild("Carry", true)
	return if found ~= nil and found:IsA("Attachment") then found :: Attachment else nil
end

-- Whether a part is a prop on the cat rather than the cat: a dressed outfit piece (CatDress gives its parts Follows) or
-- a part of the cat's own `_Prop` or `_Prop2` Model.
local function isProp(part: BasePart, walker: Model): boolean
	if part:GetAttribute("Follows") ~= nil then
		return true
	end
	local at: Instance? = part.Parent
	while at ~= nil and at ~= (walker :: Instance) do
		local name = at.Name
		if string.sub(name, -5) == "_Prop" or string.sub(name, -6) == "_Prop2" then
			return true
		end
		at = at.Parent
	end
	return false
end

-- The props whose top rises above the Carry attachment (a chef's hat, a top hat, the role hats), which a tray on the
-- head would cut through (cats-make-orders.md: "props on the Head move aside"); glasses, a bow tie or a collar stay.
local function tallProps(walker: Model, carry: Attachment?): { BasePart }
	local out: { BasePart } = {}
	if carry == nil then
		return out
	end
	local over = carry.WorldPosition.Y + Presets.cafeWalk.tallAbove
	for _, part in partsOf(walker) do
		if isProp(part, walker) then
			local cf = part.CFrame
			local top = cf.Position.Y
				+ Logic.halfHeight(part.Size, cf.RightVector, cf.UpVector, cf.LookVector)
			if top > over then
				table.insert(out, part)
			end
		end
	end
	return out
end

local function setRoute(walk: Walk, points: { Vector3 })
	walk.route = { walk.position }
	for _, point in points do
		table.insert(walk.route, point)
	end
	walk.marks = {}
	local total = 0
	for i = 2, #walk.route do
		total += (walk.route[i] - walk.route[i - 1]).Magnitude
		table.insert(walk.marks, total)
	end
	walk.nextMark = 1
	walk.travelled = 0
end

-- Fades the station model's parts out by `k` (1 hidden).
local function cover(walk: Walk, k: number)
	walk.cover = k
	setFade(walk.hidden, k)
end

-- Takes one of the station model's pieces for the walk: a part fades with the rest, a rate tag rides over the walker,
-- a sparkle pauses.
local function take(walk: Walk, descendant: Instance)
	if descendant:IsA("BasePart") then
		local part = descendant :: BasePart
		table.insert(walk.hidden, part)
		part.LocalTransparencyModifier = walk.cover
	elseif descendant:IsA("BillboardGui") then
		local gui = descendant :: BillboardGui
		walk.tags[gui] = gui.Adornee
		gui.Adornee = walk.rig.body
	elseif
		descendant:IsA("ParticleEmitter")
		or descendant:IsA("Beam")
		or descendant:IsA("Trail")
		or descendant:IsA("Light")
	then
		walk.paused[descendant] = (descendant :: any).Enabled;
		(descendant :: any).Enabled = false
	end
end

-- Gives the station model back: shown, its tags and sparkles where they were, the walker gone.
local function finish(walk: Walk)
	walks[walk.station] = nil
	local watch = walk.watch
	walk.watch = nil
	if watch ~= nil then
		watch:Disconnect()
	end
	setFade(walk.hidden, 0)
	for gui, adornee in walk.tags do
		if gui.Parent ~= nil then
			(gui :: any).Adornee = adornee -- nil puts it back over its own part
		end
	end
	for instance, on in walk.paused do
		if instance.Parent ~= nil then
			(instance :: any).Enabled = on
		end
	end
	walk.walker:Destroy()
	local done = walk.done
	walk.done = nil
	if done ~= nil then
		task.spawn(done)
	end
end

local function ownCafe(cat: Model): boolean
	local player = Players.LocalPlayer
	return player ~= nil and cat:GetAttribute("OwnerUserId") == player.UserId
end

-- Whether a station cat may be up and about now.
local function free(cat: Model): boolean
	return cat.Parent ~= nil
		and ownCafe(cat)
		and (cat:GetAttribute("Pose") == "sit" or cat:GetAttribute("Pose") == "work")
		and cat:GetAttribute("Bedtime") == nil
		and cat:GetAttribute("HiddenLocal") ~= true
		and not Context.isNight()
		and Context.distance(cat:GetPivot().Position) <= Presets.cafeWalk.range
end

local function begin(cat: Model, idle: boolean): Walk?
	local existing = walks[cat]
	if existing ~= nil then
		return existing
	end
	if not free(cat) then
		return nil
	end
	local home = cat:GetPivot()
	local walker = makeWalker(cat, home)
	if walker == nil then
		return nil
	end
	local rig = Pose.bind(walker) -- after the anchoring: Pose binds an unanchored body only to its Motor6Ds
	if rig == nil or rig.usesMotors then
		walker:Destroy()
		return nil
	end
	local carry = carryOf(walker)
	local walk: Walk = {
		station = cat,
		home = home,
		walker = walker,
		rig = rig,
		head = headOf(walker),
		carry = carry,
		tall = tallProps(walker, carry),
		hidden = {},
		cover = 0,
		shown = partsOf(walker),
		tags = {},
		paused = {},
		watch = nil,
		state = "up",
		stateAt = os.clock(),
		position = home.Position,
		yaw = Logic.yawOf(home.LookVector),
		route = { home.Position },
		marks = {},
		nextMark = 1,
		travelled = 0,
		passed = { home.Position },
		speed = 0,
		stride = 0,
		phase = Logic.phaseOf(tostring(cat:GetAttribute("Uid") or cat.Name)) * 100,
		options = {},
		goingHome = false,
		done = nil,
		idle = idle,
		standUntil = math.huge,
		carrying = 0,
		action = nil,
		standing = cat:GetAttribute("Pose") == "work" or Pose.kindOf(cat) == "work",
	}
	for _, descendant in cat:GetDescendants() do
		take(walk, descendant)
	end
	walk.watch = cat.DescendantAdded:Connect(function(descendant: Instance)
		take(walk, descendant)
	end)
	walks[cat] = walk
	return walk
end

-- Sets a walk with a new route going: one getting up finishes getting up first, one sitting back down gets up again
-- from as far as it had faded, and any other walks on.
local function walkOn(walk: Walk)
	local now = os.clock()
	if walk.state == "down" then
		-- as far up as it had sunk: the sit and the cross-fade both run back from there
		local rise = Presets.cafeWalk.sit.rise
		local r = math.clamp((now - walk.stateAt) / rise, 0, 1)
		walk.state = "up"
		walk.stateAt = now - (1 - r) * rise
	elseif walk.state ~= "up" then
		walk.state = "walk"
		walk.stateAt = now
	end
end

function CafeWalk.go(cat: Model, route: { Vector3 }, options: Options?): boolean
	if #route == 0 then
		return false
	end
	local walk = begin(cat, false)
	if walk == nil then
		return false
	end
	-- the way home goes back through where this walk turned off, so it never cuts a corner across a table
	local last: Vector3? = walk.passed[#walk.passed]
	if last == nil or (walk.position - last).Magnitude > 0.3 then
		table.insert(walk.passed, walk.position)
	end
	walk.idle = false
	walk.options = options or {}
	walk.goingHome = false
	walk.done = nil
	setRoute(walk, route)
	walkOn(walk)
	return true
end

function CafeWalk.home(cat: Model, done: (() -> ())?)
	local walk = walks[cat]
	if walk == nil then
		if done ~= nil then
			task.spawn(done)
		end
		return
	end
	-- a second home() keeps the first one's `done` too
	local before = walk.done
	walk.done = if before ~= nil and done ~= nil
		then function()
			before()
			done()
		end
		else done or before
	if walk.goingHome and (walk.state == "settle" or walk.state == "down") then
		return -- already back and sitting down
	end
	local back: { Vector3 } = {}
	for i = #walk.passed, 1, -1 do
		table.insert(back, walk.passed[i])
	end
	if #back == 0 then
		table.insert(back, walk.home.Position)
	end
	walk.goingHome = true
	walk.options = { speed = walk.options.speed }
	setRoute(walk, back)
	walkOn(walk)
end

function CafeWalk.isAway(cat: Model): boolean
	return walks[cat] ~= nil
end

-- An idle stroll for `cat`: to a chair within reach of its station, chosen at random, looking over its table.
local function stroll(cat: Model)
	local plot = if cat.Parent ~= nil then cat.Parent.Parent else nil
	local tables = if plot ~= nil then plot:FindFirstChild("Tables") else nil
	if tables == nil then
		return
	end
	local station = cat:GetPivot().Position
	local choices: { { aisle: Vector3, approach: Vector3, faceAt: Vector3 } } = {}
	for _, descendant in tables:GetDescendants() do
		if descendant:IsA("Model") and string.match(descendant.Name, "^Chair_") ~= nil then
			local aisle, approach =
				descendant:GetAttribute("Aisle"), descendant:GetAttribute("Approach")
			if
				typeof(aisle) == "Vector3"
				and typeof(approach) == "Vector3"
				and (approach - station).Magnitude <= Presets.cafeWalk.reach
			then
				-- look at the table the chair is drawn up to (its group's other model), else at the chair
				local faceAt = descendant:GetPivot().Position
				local group = descendant.Parent
				if group ~= nil then
					for _, sibling in group:GetChildren() do
						if
							sibling:IsA("Model")
							and string.match(sibling.Name, "^Chair_") == nil
						then
							faceAt = sibling:GetPivot().Position
						end
					end
				end
				table.insert(choices, { aisle = aisle, approach = approach, faceAt = faceAt })
			end
		end
	end
	if #choices == 0 then
		return
	end
	local pick = choices[rng:NextInteger(1, #choices)]
	local walk = begin(cat, true)
	if walk == nil then
		return
	end
	walk.options = { faceAt = pick.faceAt }
	setRoute(walk, Logic.strollRoute(station, pick.aisle, pick.approach))
end

local function count(): number
	local n = 0
	for _ in walks do
		n += 1
	end
	return n
end

-- Every so often: which of your own waiters set off on a stroll.
local function scan(now: number)
	local c = Presets.cafeWalk
	if Context.reducedMotion() or Context.isNight() then
		return
	end
	for _, tagged in CollectionService:GetTagged(WORKING) do
		if not tagged:IsA("Model") then
			continue
		end
		local cat = tagged :: Model
		if cat:GetAttribute("Role") ~= "waiter" or walks[cat] ~= nil or not ownCafe(cat) then
			continue
		end
		local due = nextStroll[cat]
		if due == nil then
			nextStroll[cat] = now + between(c.every)
		elseif now >= due then
			nextStroll[cat] = now + between(c.every)
			if count() < c.most and free(cat) then
				stroll(cat)
			end
		end
	end
	for cat in nextStroll do
		if cat.Parent == nil then
			nextStroll[cat] = nil
		end
	end
end

-- Whether a walk must stop at once.
local function broken(walk: Walk): boolean
	local cat = walk.station
	return cat.Parent == nil
		or walk.walker.Parent == nil
		or cat:GetAttribute("Bedtime") ~= nil
		or cat:GetAttribute("HiddenLocal") == true
		or Context.isNight()
		or (walk.idle and Context.reducedMotion())
		or Context.distance(walk.home.Position) > Presets.cafeWalk.range * 1.25
end

-- Turns the walker toward `at` on the floor, at most `turn` radians.
local function face(walk: Walk, at: Vector3, turn: number)
	local way = Vector3.new(at.X - walk.position.X, 0, at.Z - walk.position.Z)
	if way.Magnitude > 1e-3 then
		walk.yaw = Logic.turnToward(walk.yaw, Logic.yawOf(way), turn)
	end
end

local function advance(walk: Walk, now: number, dt: number)
	local c = Presets.cafeWalk
	local turn = math.rad(c.turn) * dt
	local target = 0
	local crouch = 0 -- how far down into a sit the walker is (getting up or sitting down)
	local faded = 0 -- how far the walker is faded out
	-- a sweep or a drop at the till holds the walk where it is, facing the pile or the till
	local action = walk.action
	local alpha = -1
	if action ~= nil then
		alpha = (now - action.at)
			/ (if action.kind == "sweep" then c.sweep.seconds else c.bank.seconds)
		if alpha >= 1 or (walk.state ~= "walk" and walk.state ~= "stand") then
			walk.action = nil
			action = nil
			alpha = -1
		end
	end
	if walk.state == "up" then
		local into = now - walk.stateAt
		local k = math.clamp(into / c.fade, 0, 1)
		local r = math.clamp(into / c.sit.rise, 0, 1)
		cover(walk, k)
		faded = 1 - k
		setFade(walk.shown, faded)
		crouch = 1 - r * r * (3 - 2 * r)
		if r >= 1 then
			walk.state = if #walk.route > 1 then "walk" else "stand"
			walk.stateAt = now
		end
	elseif walk.state == "walk" and action ~= nil then
		face(walk, action.toward, turn)
	elseif walk.state == "walk" then
		target = walk.options.speed or c.speed
		walk.travelled += walk.speed * dt
		local position, heading, arrived = Logic.along(walk.route, walk.travelled)
		while walk.marks[walk.nextMark] ~= nil and walk.travelled >= walk.marks[walk.nextMark] do
			walk.nextMark += 1
			if walk.goingHome then
				table.remove(walk.passed) -- back at it, so a go() from here does not walk out to it again
			else
				table.insert(walk.passed, walk.route[walk.nextMark])
			end
		end
		walk.position = position
		walk.yaw = Logic.turnToward(walk.yaw, Logic.yawOf(heading), turn)
		if arrived then
			walk.stateAt = now
			if walk.goingHome then
				walk.state = "settle"
			else
				walk.state = "stand"
				walk.standUntil = now + between(c.pause)
				local arrivedHook = walk.options.arrived
				walk.options.arrived = nil
				if arrivedHook ~= nil then
					task.spawn(arrivedHook)
				end
			end
		end
	elseif walk.state == "stand" then
		local faceAt = if action ~= nil then action.toward else walk.options.faceAt
		if faceAt ~= nil then
			face(walk, faceAt, turn)
		end
		if walk.idle and now >= walk.standUntil then
			CafeWalk.home(walk.station)
		end
	elseif walk.state == "settle" then
		local yaw = Logic.yawOf(walk.home.LookVector)
		walk.yaw = Logic.turnToward(walk.yaw, yaw, turn)
		walk.position = walk.home.Position
		if walk.yaw == yaw then
			walk.state = "down"
			walk.stateAt = now
		end
	elseif walk.state == "down" then
		-- it sinks into the sit over sit.rise; the station model fades back in over the last `fade` of it
		local into = now - walk.stateAt
		local r = math.clamp(into / c.sit.rise, 0, 1)
		local k = math.clamp((into - (c.sit.rise - c.fade)) / c.fade, 0, 1)
		faded = k
		setFade(walk.shown, faded)
		cover(walk, 1 - k)
		crouch = r * r * (3 - 2 * r)
		if r >= 1 then
			finish(walk)
			return
		end
	end

	if walk.action ~= action then
		-- one that started just now, from the arrived hook above (a TipSwept, then the go() with the coin bag)
		action = walk.action
		alpha = 0
	end

	-- the tray: with the coin bag it waits where the pile was until the sweep scoops it up onto the head
	local tray, head, carry = walk.options.tray, walk.head, walk.carry
	local carrying = tray ~= nil and tray.Parent ~= nil
	local scoop, arc = 1, 0
	if action ~= nil and action.kind == "sweep" then
		scoop, arc = Logic.sweepScoop(alpha)
	end
	local into = dt / c.carry.ease
	walk.carrying =
		math.clamp(walk.carrying + (if carrying and scoop > 0 then into else -into), 0, 1)
	local held = walk.carrying * walk.carrying * (3 - 2 * walk.carrying)

	-- the walker: where it is, with the legs going at the speed it walks
	walk.speed += (target - walk.speed) * math.min(1, dt * EASE)
	if walk.speed < 0.05 and target == 0 then
		walk.speed = 0
	end
	walk.stride += walk.speed * dt / Logic.strideLength(walk.speed)
	local rig = walk.rig
	if not Pose.read(rig) then
		finish(walk)
		return
	end
	local floor = CFrame.new(walk.position) * CFrame.Angles(0, walk.yaw, 0)
	Pose.hold(rig, floor)
	local o = Logic.idle("stray", now + walk.phase, rig.kind)
	Logic.gait(o, walk.speed, walk.stride, held)
	Logic.trayCarry(o, held)
	Logic.crouch(o, crouch, walk.standing)
	if action ~= nil then
		if action.kind == "sweep" then
			Logic.sweepPose(o, alpha)
		else
			Logic.bankNod(o, alpha)
		end
	end
	Pose.draw(rig, o, -1)
	if carrying then
		-- level and turned with the walker, its underside on the ear tips (Carry), else just over the head's top
		local top = if carry ~= nil and carry.Parent ~= nil
			then carry.WorldPosition
			elseif head ~= nil then head.Position + Vector3.new(
				0,
				head.Size.Y / 2 + c.trayLift,
				0
			)
			else nil
		if top ~= nil and action ~= nil and scoop < 1 then
			top = action.toward:Lerp(top, scoop) + Vector3.new(0, arc, 0)
		end
		if top ~= nil then
			(tray :: Model):PivotTo(CFrame.new(top) * CFrame.Angles(0, walk.yaw, 0))
		end
	end
	-- tall head props step aside as a tray comes onto the head and come back once it is set down, and fade with the
	-- rest of the walker as it gets up or sits down
	setFade(walk.tall, math.max(held, faded))
end

-- A tip sweep at the pile or a drop at the till for a cat on the move (F90; Gameplay-Engineer's CafeOrders fires
-- them in your own cafe). Not with Reduce Motion: the walk just goes on.
local function onTip(kind: "sweep" | "bank", cat: unknown, position: unknown)
	if typeof(cat) ~= "Instance" or typeof(position) ~= "Vector3" or Context.reducedMotion() then
		return
	end
	local walk = walks[cat :: any]
	if walk ~= nil then
		walk.action = { kind = kind, at = os.clock(), toward = position :: Vector3 }
	end
end

local function step(dt: number)
	local now = os.clock()
	if now >= scanAt then
		scanAt = now + SCAN_SECONDS
		scan(now)
	end
	for _, walk in walks do
		if broken(walk) then
			finish(walk)
		else
			advance(walk, now, dt)
		end
	end
end

function CafeWalk.start()
	if started then
		return
	end
	started = true
	RunService.PreRender:Connect(step)
	local swept, banked = (Moments :: any).TipSwept, (Moments :: any).TipBanked
	if swept ~= nil then
		swept:Connect(function(cat: unknown, position: unknown)
			onTip("sweep", cat, position)
		end)
	end
	if banked ~= nil then
		banked:Connect(function(cat: unknown, position: unknown)
			onTip("bank", cat, position)
		end)
	end
end

return CafeWalk
