--!strict
-- The Bellhop Cat's animations (F96, starter-cat.md section 1, on Model-Agent's #708 models): the bell ring, the cap
-- tip, a little bow when it is placed, the sleepy cap over its eyes asleep and the happy hop when it is claimed.
-- Numbers in Presets.bellhop; the poses are Logic.bellRing, capTip, bow and happyHop, drawn by Pose on the head's
-- `_Prop` (the cap) and `_Bell` pieces.
-- - In a cafe: Cats.luau calls Bellhop.layer on every moving cat with CatId "bellhop_cat". A customer coming in within
--   `greet` studs (no order yet) is rung in, and gets the cap tip `tipAfter` seconds later, once each. Asleep (a nap or
--   a doze, at night) the cap slides down over its eyes. A station model that appears after this client began
--   watching its plot (Bellhop.placed) bows.
-- - On its stand in town (tag BellhopStand under Workspace, CatCafe_Street_BellhopStand): the cat baked into the cart
--   is hidden on this client and a copy of the sitting body at the stand's scale sits in its place while the stand is
--   within budget.animRadius, so it breathes, blinks and moves. By day it rings its bell every 8 to 12 s and tips its
--   cap as you walk up; at night it stays awake, quiet (no bell), still tipping its cap (#1023). When the server
--   answers your claim (StarterCatResult true) it bounces, leaps off the cart to you and vanishes in a sparkle, and
--   fades back onto the cart a moment later.
-- Every ring fires Beats.hit("bellRing", the bell's part) for Sound-Agent's bellhopBell. Listening only: nothing here
-- fires a remote or moves a part the server owns (the hidden cart cat only gets LocalTransparencyModifier).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Beats = require(script.Parent.Parent.Audio.Beats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Pose = require(script.Parent.Pose)
local Presets = require(script.Parent.Presets)

local Bellhop = {}

local SCAN_SECONDS = 0.25 -- how often a cafe Bellhop looks for customers coming in
local STAND_SCAN_SECONDS = 0.5 -- how often the stands are checked against the animation radius
local WALK_AWAY = 2 -- studs past walkUp you go before the stand tips its cap to you again
local CLAIM_RANGE = 20 -- studs: the stand nearest you within this hops at your claim

-- What a cafe Bellhop is doing (weak keys: gone with its model).
type CafeState = {
	lastAt: number,
	capDown: number, -- 0 to 1, eased; drawn smoothed
	ringAt: number?,
	lastRing: number,
	tipAt: number?,
	tipQueued: number?, -- when the cap tip after a ring starts
	bowAt: number?,
	scanAt: number,
	greeted: { [Model]: boolean },
	bell: BasePart?,
}

type Stand = {
	model: Model,
	baked: { BasePart }, -- the cart's own cat, hidden on this client while the copy sits in its place
	copy: Model?,
	rig: Pose.Rig?,
	parts: { BasePart }, -- the copy's parts
	bell: BasePart?,
	seat: CFrame, -- the copy's floor on the cart (Pose.floor right after it sits down)
	phase: number,
	lastAt: number,
	capDown: number,
	nextRing: number,
	ringAt: number?,
	tipAt: number?,
	lastTip: number,
	near: boolean, -- you were within walkUp last check
	hopAt: number?, -- the claim's happy hop
	backAt: number?, -- after the hop: hidden until this, then fading back onto the cart
}

local states: { [Model]: CafeState } = setmetatable({}, { __mode = "k" }) :: any
local placedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local stands: { [Model]: Stand } = {}
local tagged: { [Model]: boolean } = {}
local rng = Random.new()
local started = false
local scanAt = 0
local elapsed = 0

function Bellhop.is(model: Model): boolean
	return model:GetAttribute("CatId") == Presets.bellhop.catId
end

-- A new station model of a Bellhop Cat: it bows the first time it moves, if that is soon.
function Bellhop.placed(model: Model)
	if Bellhop.is(model) then
		placedAt[model] = os.clock()
	end
end

-- The bell to ring from: the `_Bell` piece's main part.
local function bellOf(model: Model): BasePart?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name:sub(-5) == "_Bell" then
			local piece = descendant :: Model
			local main = piece.PrimaryPart or piece:FindFirstChildWhichIsA("BasePart", true)
			return if main ~= nil then main :: BasePart else nil
		end
	end
	return nil
end

local function ring(bell: BasePart?)
	if bell ~= nil and bell.Parent ~= nil then
		Beats.hit:Fire("bellRing", bell)
	end
end

local function smooth(k: number): number
	return k * k * (3 - 2 * k)
end

local function toward(value: number, goal: number, step: number): number
	if value < goal then
		return math.min(goal, value + step)
	end
	return math.max(goal, value - step)
end

-- The ring, tip and bow playing now, each cleared once it is over.
local function layers(
	o: Logic.Offsets,
	now: number,
	ringAt: number?,
	tipAt: number?,
	bowAt: number?
): (number?, number?, number?)
	local b = Presets.bellhop
	if ringAt ~= nil then
		local alpha = (now - ringAt) / b.ring.seconds
		if alpha >= 1 then
			ringAt = nil
		else
			Logic.bellRing(o, alpha)
		end
	end
	if tipAt ~= nil then
		local alpha = (now - tipAt) / b.tip.seconds
		if alpha >= 1 then
			tipAt = nil
		elseif alpha >= 0 then
			Logic.capTip(o, alpha)
		end
	end
	if bowAt ~= nil then
		local alpha = (now - bowAt) / b.bow.seconds
		if alpha >= 1 then
			bowAt = nil
		else
			Logic.bow(o, alpha)
		end
	end
	return ringAt, tipAt, bowAt
end

-- Customers coming into the cafe near the cat (CustomerController's models in LocalCustomers, before they order;
-- a seated one is Served): the first time each comes within `greet` studs, a ring and then a cap tip.
local function greet(model: Model, state: CafeState, now: number)
	local folder = Workspace:FindFirstChild("LocalCustomers")
	if folder == nil then
		return
	end
	local b = Presets.bellhop
	local at = model:GetPivot().Position
	for _, child in folder:GetChildren() do
		if
			child.Name ~= "Customer"
			or not child:IsA("Model")
			or state.greeted[child :: Model]
			or child:GetAttribute("Order") ~= nil
			or child:GetAttribute("Served") ~= nil
		then
			continue
		end
		local customer = child :: Model
		if (customer:GetPivot().Position - at).Magnitude <= b.greet then
			state.greeted[customer] = true
			if now - state.lastRing >= b.gap then
				state.lastRing = now
				state.ringAt = now
				ring(state.bell)
			end
			state.tipQueued = now + b.tipAfter
		end
	end
end

local function stateOf(model: Model, now: number): CafeState
	local state = states[model]
	if state == nil then
		local fresh: CafeState = {
			lastAt = now,
			capDown = 0,
			ringAt = nil,
			lastRing = -math.huge,
			tipAt = nil,
			tipQueued = nil,
			bowAt = nil,
			scanAt = 0,
			greeted = setmetatable({}, { __mode = "k" }) :: any,
			bell = bellOf(model),
		}
		states[model] = fresh
		return fresh
	end
	return state
end

-- A cafe Bellhop's own motion on top of its idle (called by Cats each animation step, before it draws).
function Bellhop.layer(model: Model, o: Logic.Offsets, style: Logic.Style, now: number)
	local b = Presets.bellhop
	local state = stateOf(model, now)
	local dt = math.clamp(now - state.lastAt, 0, 0.5)
	state.lastAt = now
	local asleep = Logic.asleep(style)
	state.capDown = toward(state.capDown, if asleep then 1 else 0, dt / b.sleepCap.seconds)
	o.capDown = smooth(state.capDown)
	local placed = placedAt[model]
	if placed ~= nil then
		placedAt[model] = nil
		if now - placed <= b.bowWindow and not asleep then
			state.bowAt = now
		end
	end
	if not asleep and now >= state.scanAt then
		state.scanAt = now + SCAN_SECONDS
		greet(model, state, now)
	end
	local queued = state.tipQueued
	if queued ~= nil and now >= queued then
		state.tipQueued = nil
		state.tipAt = queued
	end
	state.ringAt, state.tipAt, state.bowAt = layers(o, now, state.ringAt, state.tipAt, state.bowAt)
end

-- The stand ------------------------------------------------------------------------------------------------------

local function bakedOf(stand: Model): ({ BasePart }, Model?)
	local parts: { BasePart } = {}
	local body: Model? = nil
	for _, child in stand:GetChildren() do
		if child:IsA("Model") and string.find(child.Name, "_Cat_", 1, true) ~= nil then
			if child.Name:sub(-9) == "_Cat_Body" then
				body = child :: Model
			end
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant :: BasePart)
				end
			end
		end
	end
	return parts, body
end

local function setFade(parts: { BasePart }, k: number)
	for _, part in parts do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = k
		end
	end
end

local function dropCopy(stand: Stand)
	local rig = stand.rig
	if rig ~= nil then
		Pose.release(rig)
	end
	local copy = stand.copy
	if copy ~= nil then
		copy:Destroy()
	end
	stand.copy = nil
	stand.rig = nil
	stand.parts = {}
	stand.bell = nil
	stand.hopAt = nil
	stand.backAt = nil
	setFade(stand.baked, 0)
end

-- Sits a copy of the sitting body on the cart where its own cat is, at the same size, and hides that cat.
local function sitCopy(stand: Stand): boolean
	local b = Presets.bellhop
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	local template = if folder ~= nil then folder:FindFirstChild(b.sitModel) else nil
	local baked, body = bakedOf(stand.model)
	if template == nil or not template:IsA("Model") or body == nil or #baked == 0 then
		return false
	end
	local copy = (template :: Model):Clone() :: Model
	copy.Name = "BellhopStandCat"
	copy:SetAttribute("CatId", b.catId)
	copy:ScaleTo(b.standScale)
	copy:PivotTo((body :: Model):GetPivot())
	local parts: { BasePart } = {}
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			table.insert(parts, part)
		end
	end
	copy.Parent = Context.folder()
	local rig = Pose.bind(copy) -- after the anchoring: Pose binds an unanchored body only to its Motor6Ds
	if rig == nil or rig.usesMotors then
		copy:Destroy()
		return false
	end
	stand.copy = copy
	stand.rig = rig
	stand.parts = parts
	stand.bell = bellOf(copy)
	stand.seat = Pose.floor(rig)
	stand.baked = baked
	setFade(baked, 1)
	return true
end

local function rootOf(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

-- Where the leap lands: in front of you, in your arms.
local function landing(root: BasePart): Vector3
	local h = Presets.bellhop.hop
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local ahead = if look.Magnitude > 0.01 then look.Unit * h.ahead else Vector3.zero
	return root.Position + ahead + Vector3.new(0, h.lift, 0)
end

-- The happy hop: a bounce on the cart, then the leap to you; at the end a sparkle where it lands, and it is gone
-- until `back` seconds on, when it fades back onto the cart. Returns the floor to draw the copy on.
local function hop(stand: Stand, o: Logic.Offsets, now: number): CFrame
	local h = Presets.bellhop.hop
	local hopAt = stand.hopAt :: number
	local alpha = (now - hopAt) / h.seconds
	local root = rootOf()
	if alpha >= 1 or root == nil then
		stand.hopAt = nil
		stand.backAt = now + h.back
		setFade(stand.parts, 1)
		if root ~= nil then
			Particles.burst("shiny", landing(root) + Vector3.new(0, 1, 0), Presets.reveal.sparkles)
		end
		return stand.seat
	end
	Logic.happyHop(o, alpha)
	if alpha < h.bounce then
		return stand.seat
	end
	local from = stand.seat.Position
	local to = landing(root)
	local at = Logic.hopArc(from, to, h.height, (alpha - h.bounce) / (1 - h.bounce))
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.01 then
		return CFrame.new(at) * stand.seat.Rotation
	end
	return CFrame.lookAt(at, at + flat)
end

local function animateStand(stand: Stand, now: number)
	local rig = stand.rig
	if rig == nil then
		return
	end
	if not Pose.read(rig) then
		dropCopy(stand)
		return
	end
	local b = Presets.bellhop
	local dt = math.clamp(now - stand.lastAt, 0, 0.5)
	stand.lastAt = now
	local night = Context.isNight()
	-- the stand is the shop sign, so it stays awake with its face showing at night (#1023: dozing under the cap at
	-- 1.5 scale hid the face); a claim at night wakes a dozing one for the hop
	local dozing = night and not b.standAwake and stand.hopAt == nil
	local o = Logic.idle(if dozing then "doze" else "sit", now + stand.phase, rig.kind)
	stand.capDown = toward(stand.capDown, if dozing then 1 else 0, dt / b.sleepCap.seconds)
	o.capDown = smooth(stand.capDown)
	local floor = stand.seat
	local backAt = stand.backAt
	if stand.hopAt ~= nil then
		floor = hop(stand, o, now)
	elseif backAt ~= nil then
		local k = (now - backAt) / Presets.bellhop.hop.fade
		if k >= 1 then
			stand.backAt = nil
			setFade(stand.parts, 0)
		elseif k >= 0 then
			setFade(stand.parts, 1 - k)
		end
	elseif not night then
		if now >= stand.nextRing then
			stand.nextRing = now + rng:NextNumber(b.every[1], b.every[2])
			stand.ringAt = now
			ring(stand.bell)
		end
		local root = rootOf()
		local distance = if root ~= nil
			then (root.Position - stand.seat.Position).Magnitude
			else math.huge
		if distance <= b.walkUp and not stand.near then
			stand.near = true
			if now - stand.lastTip >= b.tipGap then
				stand.lastTip = now
				stand.tipAt = now
			end
		elseif distance > b.walkUp + WALK_AWAY then
			stand.near = false
		end
	end
	stand.ringAt, stand.tipAt = layers(o, now, stand.ringAt, stand.tipAt, nil)
	Pose.hold(rig, floor)
	Pose.draw(rig, o, -1)
end

-- Sits copies on the stands within the animation radius and takes them off the ones out of it.
local function scanStands()
	local focus = Context.focus()
	local radius = Context.budget.animRadius
	for model in tagged do
		local stand = stands[model]
		local inWorld = model.Parent ~= nil and model:IsDescendantOf(Workspace)
		local near = inWorld
			and focus ~= nil
			and (model:GetPivot().Position - focus).Magnitude <= radius
		if near and stand == nil then
			local fresh: Stand = {
				model = model,
				baked = {},
				copy = nil,
				rig = nil,
				parts = {},
				bell = nil,
				seat = CFrame.identity,
				phase = rng:NextNumber(0, 20),
				lastAt = os.clock(),
				capDown = if Context.isNight() and not Presets.bellhop.standAwake then 1 else 0,
				nextRing = os.clock() + rng:NextNumber(1, Presets.bellhop.every[1]),
				ringAt = nil,
				tipAt = nil,
				lastTip = -math.huge,
				near = false,
				hopAt = nil,
				backAt = nil,
			}
			if sitCopy(fresh) then
				stands[model] = fresh
			end
		elseif not near and stand ~= nil and stand.hopAt == nil then
			dropCopy(stand)
			stands[model] = nil
		end
	end
	for model, stand in stands do
		if not tagged[model] then
			dropCopy(stand)
			stands[model] = nil
		end
	end
end

-- Your claim came back yes (StarterCatResult): the nearest stand's cat hops to you.
function Bellhop.claimed()
	local root = rootOf()
	if root == nil then
		return
	end
	local best: Stand? = nil
	local bestDistance = CLAIM_RANGE
	for _, stand in stands do
		if stand.rig ~= nil and stand.hopAt == nil and stand.backAt == nil then
			local distance = (stand.seat.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = stand, distance
			end
		end
	end
	if best ~= nil then
		best.hopAt = os.clock()
		best.ringAt = nil
		best.tipAt = nil
	end
end

local function step(dt: number)
	local now = os.clock()
	if now >= scanAt then
		scanAt = now + STAND_SCAN_SECONDS
		scanStands()
	end
	elapsed += dt
	if elapsed < 1 / Context.budget.animHz then
		return
	end
	elapsed = 0
	for _, stand in stands do
		animateStand(stand, now)
	end
end

function Bellhop.start()
	if started then
		return
	end
	started = true
	for _, instance in CollectionService:GetTagged("BellhopStand") do
		if instance:IsA("Model") then
			tagged[instance :: Model] = true
		end
	end
	CollectionService:GetInstanceAddedSignal("BellhopStand"):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			tagged[instance :: Model] = true
		end
	end)
	CollectionService:GetInstanceRemovedSignal("BellhopStand"):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			tagged[instance :: Model] = nil
		end
	end)
	-- StarterCatResult(ok, reason) from Gameplay-Engineer's ClaimStarterCat (starter-cat.md section 4)
	Context.whenRemote("StarterCatResult", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(function(ok: unknown)
			if ok == true then
				Bellhop.claimed()
			end
		end)
	end)
	RunService.PreRender:Connect(step)
end

return Bellhop
