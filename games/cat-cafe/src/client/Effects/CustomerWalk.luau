--!strict
-- Customers walking with a step instead of a hop (Derek 2026-11-04, #1143: "walking looks like mini hopping"). The
-- cosmetic customers (Controllers/CustomerController) are loose anchored parts on a pivot at the feet, moved along the
-- floor by shared Mover.walkTo. CustomerController passes CustomerWalk.draw as walkTo's draw hook: each step it lays
-- the parts out round the ground frame Mover gives it, the legs swinging about the hips and the arms the other way
-- about the shoulders, one cycle per Presets.customerWalk.stride studs walked, the body rolling a little and dropping
-- as the legs leave the upright so the feet stay on the floor (Logic.customerPiece, Logic.customerStep). It eases in
-- as a walk starts, and one Heartbeat for every customer eases each back to standing once its steps stop (at the
-- counter, at a turn in the route, at the seat). Past the animation radius, or in Low performance mode, draw says no
-- and Mover moves the model whole as before. Client only; nothing replicates.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local CustomerWalk = {}

-- 0 the body, 1 and 2 the left and right legs, 3 and 4 the left and right arms
local KINDS: { [string]: number } = { legL = 1, legR = 2, armL = 3, armR = 4 }

type Rig = {
	model: Model,
	parts: { BasePart },
	rest: { CFrame }, -- each part in the pivot's frame, standing
	kind: { number },
	frames: { CFrame }, -- reused every step
	phase: number,
	weight: number,
	lastStep: number,
	-- a part came or went (a dish handed over the counter rides in its hands, CafeOrders)
	dirty: boolean,
}

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any
local settling: { [Rig]: boolean } = {}
local connection: RBXScriptConnection? = nil

local function build(model: Model): Rig
	local c = Presets.customerWalk
	local pivot = model:GetPivot()
	local parts: { BasePart } = {}
	local rest: { CFrame } = {}
	local kind: { number } = {}
	-- a bag or the like hanging at that side: its arm stays still
	local hangs = { L = false, R = false }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local at = pivot:ToObjectSpace(part.CFrame)
			local half = part.Size.Y / 2
			local bottom, top = at.Position.Y - half, at.Position.Y + half
			local piece = Logic.customerPiece(at.Position.X, bottom, top)
			local out = math.abs(at.Position.X) >= c.armFrom
			if piece == nil and out and top < c.armBottom and top > 0.5 then
				hangs[if at.Position.X < 0 then "L" else "R"] = true
			end
			table.insert(parts, part)
			table.insert(rest, at)
			table.insert(kind, if piece ~= nil then KINDS[piece] else 0)
		end
	end
	for i, k in kind do
		if (k == 3 and hangs.L) or (k == 4 and hangs.R) then
			kind[i] = 0
		end
	end
	local rig: Rig = {
		model = model,
		parts = parts,
		rest = rest,
		kind = kind,
		frames = table.clone(rest),
		phase = 0,
		weight = 0,
		lastStep = 0,
		dirty = false,
	}
	local function changed(descendant: Instance)
		if descendant:IsA("BasePart") then
			rig.dirty = true
		end
	end
	model.DescendantAdded:Connect(changed)
	model.DescendantRemoving:Connect(changed)
	return rig
end

-- Drops the parts that left `rig`'s model and adds the ones that came, riding with the body where they are now
-- round its pivot (which this keeps on the feet).
local function resync(rig: Rig)
	rig.dirty = false
	local pivot = rig.model:GetPivot()
	local known: { [BasePart]: boolean } = {}
	for i = #rig.parts, 1, -1 do
		local part = rig.parts[i]
		if part:IsDescendantOf(rig.model) then
			known[part] = true
		else
			table.remove(rig.parts, i)
			table.remove(rig.rest, i)
			table.remove(rig.kind, i)
			table.remove(rig.frames, i)
		end
	end
	for _, descendant in rig.model:GetDescendants() do
		if descendant:IsA("BasePart") and not known[descendant :: BasePart] then
			local part = descendant :: BasePart
			local at: CFrame = pivot:ToObjectSpace(part.CFrame)
			table.insert(rig.parts, part)
			table.insert(rig.rest, at)
			table.insert(rig.kind, 0)
			table.insert(rig.frames, part.CFrame)
		end
	end
end

-- Lays `rig` out round `ground` (the feet's frame) at its phase and weight.
local function lay(rig: Rig, ground: CFrame)
	local c = Presets.customerWalk
	if rig.dirty then
		resync(rig)
	end
	local leg, arm, drop, roll = Logic.customerStep(rig.phase, rig.weight, Context.reducedMotion())
	local body = ground * CFrame.new(0, drop, 0) * CFrame.Angles(0, 0, roll)
	local hipL, hipR = CFrame.Angles(leg, 0, 0), CFrame.Angles(-leg, 0, 0)
	local armL, armR = CFrame.Angles(arm, 0, 0), CFrame.Angles(-arm, 0, 0)
	for i, rest in rig.rest do
		local k = rig.kind[i]
		if k == 0 then
			rig.frames[i] = body * rest
		else
			local p = rest.Position
			local hinge = Vector3.new(p.X, if k <= 2 then c.hip else c.shoulder, 0)
			local turn = hipL
			if k == 2 then
				turn = hipR
			elseif k == 3 then
				turn = armL
			elseif k == 4 then
				turn = armR
			end
			rig.frames[i] = body * CFrame.new(hinge) * turn * CFrame.new(-hinge) * rest
		end
	end
	rig.model.WorldPivot = ground
	Workspace:BulkMoveTo(rig.parts, rig.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Eases every customer that stopped walking back to standing, then lets it go.
local function settle(dt: number)
	local c = Presets.customerWalk
	local now = os.clock()
	for rig in settling do
		if rig.model.Parent == nil then
			settling[rig] = nil
		elseif now - rig.lastStep > c.idleAfter then
			rig.weight = math.max(0, rig.weight - dt / c.settle)
			lay(rig, rig.model:GetPivot())
			if rig.weight <= 0 then
				settling[rig] = nil
			end
		end
	end
	if next(settling) == nil and connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

-- Mover.walkTo's draw hook: draws `model` one step of `moved` studs along, its feet at `ground`. False when it is
-- not drawn here (out of range, Low performance), so Mover moves it whole.
function CustomerWalk.draw(model: Model, ground: CFrame, moved: number, dt: number): boolean
	local c = Presets.customerWalk
	local rig = rigs[model]
	if Context.lowPerformance or Context.distance(ground.Position) > Context.budget.animRadius then
		return false
	end
	if rig == nil then
		rig = build(model)
		rigs[model] = rig
	end
	local r = rig :: Rig
	r.phase = (r.phase + moved / c.stride * 2 * math.pi) % (2 * math.pi)
	r.weight = math.min(1, r.weight + dt / c.easeIn)
	r.lastStep = os.clock()
	lay(r, ground)
	settling[r] = true
	if connection == nil then
		connection = RunService.Heartbeat:Connect(settle)
	end
	return true
end

return CustomerWalk
