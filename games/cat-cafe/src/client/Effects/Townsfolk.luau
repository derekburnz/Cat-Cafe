--!strict
-- The townsfolk cats (#2687 part 2: "a small crowd of townsfolk cats around the station"): Model-Agent's
-- CatCafe_NPC_Townsfolk_<Name> sitting cats (#2783) on a grown camp's Townsfolk_1..3 Attachments. On this client,
-- each one within budget.ambientRadius:
-- - idles: its head wanders and nods a little, an ear twitches now and then and its tail sways, every cat on its own
--   phase so a camp's crowd never moves as one;
-- - greets you as you come within greetRadius: the head turns to you (and follows you while you stay, within
--   followLimit), and the front paw on your side lifts and waves. The same cat greets you again after greetAgain.
-- Nothing moves with Reduce Motion. Placement is not done here: whoever puts the townsfolk at the camps (the camp
-- growth, #2687 part 2) just parents the models under Workspace, and they are found by name.
--
-- The pieces are the child Models Model-Agent pivots at their joints: `_Head` (with `_EarL`, `_EarR`, the eyes and
-- the hat `_Prop` inside it, so they turn with it), `_Tail`, `_LegF1` and `_LegF2`. Every part is drawn from its
-- frame in the body's (the PrimaryPart's) space as first seen, so a model moved after it arrives is followed, and a
-- cat that goes out of range is put back on those frames. Listening only.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Townsfolk = {}

local PREFIX = "CatCafe_NPC_Townsfolk_"

type Piece = {
	pivot: CFrame, -- the joint, in the body's space
	parts: { BasePart },
	offsets: { CFrame }, -- each part in the body's space
}

type Cat = {
	model: Model,
	body: BasePart,
	head: Piece?,
	earL: Piece?,
	earR: Piece?,
	tail: Piece?,
	legL: Piece?, -- _LegF1, on the cat's -X side
	legR: Piece?, -- _LegF2
	phase: number,
	flickAt: number, -- when the next ear twitch starts
	flickEar: number, -- 1 left, 2 right
	near: boolean, -- you are within greetRadius
	greetAt: number?, -- the wave started then
	greetLeg: number, -- 1 left, 2 right
	greetedAt: number, -- the last greet, for greetAgain
	yaw: number, -- the head's turn as last drawn, degrees
	pitch: number,
	resting: boolean, -- drawn at rest (out of range or Reduce Motion)
}

local cats: { [Model]: Cat } = {}
local rng = Random.new()
local started = false

local function endsWith(name: string, suffix: string): boolean
	return string.sub(name, -#suffix) == suffix
end

-- The child Model of `model` (any depth) whose name ends with `suffix`, as a Piece in `body`'s space. Its parts are
-- taken out of `taken`, so a part inside the head and inside an ear only moves with the ear.
local function pieceOf(
	model: Model,
	suffix: string,
	body: BasePart,
	taken: { [BasePart]: boolean }
): Piece?
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") and endsWith(descendant.Name, suffix) then
			local piece = descendant :: Model
			local parts: { BasePart } = {}
			local offsets: { CFrame } = {}
			for _, inner in piece:GetDescendants() do
				if inner:IsA("BasePart") and not taken[inner :: BasePart] then
					local part = inner :: BasePart
					taken[part] = true
					table.insert(parts, part)
					local offset: CFrame = body.CFrame:ToObjectSpace(part.CFrame)
					table.insert(offsets, offset)
				end
			end
			return {
				pivot = body.CFrame:ToObjectSpace(piece:GetPivot()),
				parts = parts,
				offsets = offsets,
			}
		end
	end
	return nil
end

local function add(instance: Instance)
	if
		not instance:IsA("Model")
		or string.sub(instance.Name, 1, #PREFIX) ~= PREFIX
		or cats[instance :: Model]
	then
		return
	end
	local model = instance :: Model
	-- a townsfolk model's own parts are its pieces' parts, so a piece Model (its name has the prefix too) is skipped
	if
		model.Parent ~= nil
		and model.Parent:IsA("Model")
		and string.sub(model.Parent.Name, 1, #PREFIX) == PREFIX
	then
		return
	end
	local body = model.PrimaryPart
	if body == nil then
		return
	end
	-- the ears first, so their parts move with the ears and not only with the head
	local taken: { [BasePart]: boolean } = {}
	local earL = pieceOf(model, "_EarL", body, taken)
	local earR = pieceOf(model, "_EarR", body, taken)
	local tail = pieceOf(model, "_Tail", body, taken)
	local legL = pieceOf(model, "_LegF1", body, taken)
	local legR = pieceOf(model, "_LegF2", body, taken)
	local head = pieceOf(model, "_Head", body, taken)
	local now = os.clock()
	cats[model] = {
		model = model,
		body = body,
		head = head,
		earL = earL,
		earR = earR,
		tail = tail,
		legL = legL,
		legR = legR,
		phase = rng:NextNumber(),
		flickAt = now
			+ rng:NextNumber(Presets.townsfolk.flick.every[1], Presets.townsfolk.flick.every[2]),
		flickEar = 1,
		near = false,
		greetAt = nil,
		greetLeg = 1,
		greetedAt = -math.huge,
		yaw = 0,
		pitch = 0,
		resting = true,
	}
	model.Destroying:Connect(function()
		cats[model] = nil
	end)
end

-- Adds `piece`'s parts, turned `turn` about its joint and then carried by `carry` (the body's space), to the lists.
local function place(
	piece: Piece?,
	body: CFrame,
	carry: CFrame,
	turn: CFrame,
	parts: { BasePart },
	frames: { CFrame }
)
	if piece == nil then
		return
	end
	local about = carry * piece.pivot * turn * piece.pivot:Inverse()
	for i, part in piece.parts do
		if part.Parent ~= nil then
			table.insert(parts, part)
			table.insert(frames, body * about * piece.offsets[i])
		end
	end
end

-- The turn about a joint for `pitch` (about X, degrees), `yaw` (about Y) and `roll` (about Z).
local function turnOf(pitch: number, yaw: number, roll: number): CFrame
	return CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
end

local function draw(cat: Cat, now: number, dt: number, focus: Vector3?, calm: boolean)
	local c = Presets.townsfolk
	local body = cat.body.CFrame
	local inRange = focus ~= nil
		and (body.Position - focus).Magnitude <= Context.budget.ambientRadius
	if calm or not inRange then
		if not cat.resting then
			cat.resting = true
			cat.yaw, cat.pitch, cat.greetAt, cat.near = 0, 0, nil, false
			local parts: { BasePart } = {}
			local frames: { CFrame } = {}
			for _, piece in { cat.head, cat.earL, cat.earR, cat.tail, cat.legL, cat.legR } do
				place(piece, body, CFrame.identity, CFrame.identity, parts, frames)
			end
			if #parts > 0 then
				Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end
		return
	end
	cat.resting = false

	-- you, in the cat's own space
	local you = body:PointToObjectSpace(focus :: Vector3)
	local flat = Vector3.new(you.X, 0, you.Z).Magnitude
	local near = flat <= c.greetRadius
	if near and not cat.near and now - cat.greetedAt >= c.greetAgain then
		cat.greetAt = now
		cat.greetedAt = now
		cat.greetLeg = if you.X < 0 then 1 else 2
	end
	cat.near = near

	local idleYaw, idlePitch, tailYaw = Logic.townsfolkIdle(now, cat.phase, c)
	local wantYaw, wantPitch = idleYaw, idlePitch
	if near then
		wantYaw = Logic.lookYaw(you.X, you.Z, c.followLimit)
		wantPitch = math.clamp(math.deg(math.atan2(you.Y - 1, math.max(flat, 0.5))), -10, 20)
	end
	local ease = 1 - math.exp(-c.turn * dt)
	cat.yaw += (wantYaw - cat.yaw) * ease
	cat.pitch += (wantPitch - cat.pitch) * ease

	if now >= cat.flickAt + c.flick.seconds then
		cat.flickAt = now + rng:NextNumber(c.flick.every[1], c.flick.every[2])
		cat.flickEar = rng:NextInteger(1, 2)
	end
	local flick = Logic.townsfolkFlick(now - cat.flickAt, c.flick.seconds, c.flick.degrees)

	local lift: number?, side = nil, 0
	if cat.greetAt ~= nil then
		lift, side = Logic.townsfolkWave(now - (cat.greetAt :: number), c.wave)
		if lift == nil then
			cat.greetAt = nil
		end
	end

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	local head = cat.head
	local headTurn = turnOf(cat.pitch, cat.yaw, 0)
	local carry = if head ~= nil
		then head.pivot * headTurn * head.pivot:Inverse()
		else CFrame.identity
	place(head, body, CFrame.identity, headTurn, parts, frames)
	-- ears ride the head and twitch back about their own base
	place(
		cat.earL,
		body,
		carry,
		turnOf(if cat.flickEar == 1 then -flick else 0, 0, 0),
		parts,
		frames
	)
	place(
		cat.earR,
		body,
		carry,
		turnOf(if cat.flickEar == 2 then -flick else 0, 0, 0),
		parts,
		frames
	)
	place(cat.tail, body, CFrame.identity, turnOf(0, tailYaw, 0), parts, frames)
	local leftLift = if lift ~= nil and cat.greetLeg == 1 then lift else 0
	local rightLift = if lift ~= nil and cat.greetLeg == 2 then lift else 0
	place(
		cat.legL,
		body,
		CFrame.identity,
		turnOf(leftLift, 0, if cat.greetLeg == 1 then side else 0),
		parts,
		frames
	)
	place(
		cat.legR,
		body,
		CFrame.identity,
		turnOf(rightLift, 0, if cat.greetLeg == 2 then -side else 0),
		parts,
		frames
	)
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function step(dt: number)
	local now = os.clock()
	local focus = Context.focus()
	local calm = Context.reducedMotion()
	for _, cat in cats do
		if cat.model.Parent == nil or cat.body.Parent == nil then
			continue
		end
		draw(cat, now, dt, focus, calm)
	end
end

function Townsfolk.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		add(descendant)
	end
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and string.sub(descendant.Name, 1, #PREFIX) == PREFIX then
			-- its parts arrive after it; wait a frame so the pieces are all there
			task.defer(add, descendant)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return Townsfolk
