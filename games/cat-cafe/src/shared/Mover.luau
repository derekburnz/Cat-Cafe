--!strict
-- Moves an anchored Model along the ground by stepping its pivot every Heartbeat. Used for strays (server)
-- and cosmetic customers (client). Blocks the calling thread until it arrives or `alive()` returns false.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LiveFlags = require(script.Parent.LiveFlags)

local Mover = {}

-- #4601: every part of a cat is anchored, so each server step sends every part's CFrame to each client near it
-- (60 to 140 parts at 60 Hz, up to about 170 kB/s a walking stray). With the `strayWalkSlow` switch on (LiveFlags,
-- off by default) a server walk writes the model at most every SLOW_STEP seconds and without the bob, and the
-- client eases between the writes (Effects/Pose). The client's own walks (customers) are not touched.
Mover.SLOW_FLAG = "strayWalkSlow"
Mover.SLOW_STEP = 0.1
-- #4601: model attributes that describe a slowed server walk (see walkTo)
Mover.WALK_FROM = "WalkFrom"
Mover.WALK_TO = "WalkTo"
Mover.WALK_SPEED = "WalkSpeed"
Mover.WALK_AT = "WalkAt"

local function slow(): boolean
	return RunService:IsServer()
		and LiveFlags.shown(
			Mover.SLOW_FLAG,
			ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. Mover.SLOW_FLAG)
		)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Rotates the model to face `target` on the XZ plane without moving it. Models face -Z.
function Mover.face(model: Model, target: Vector3)
	local pivot = model:GetPivot()
	local direction = flat(target - pivot.Position)
	if direction.Magnitude < 0.05 then
		return
	end
	model:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + direction.Unit))
end

-- Walks at `speed` studs per second with a small bob. Returns true on arrival, false when cancelled. A cancelled walk
-- (a catch's lock stops a stray where it stands, #2005) sets the model down on the ground, off the bob, unless
-- something else has moved it since the last step.
-- The walk is tracked on the ground at the target's height and the bob is drawn on top each frame; stepping
-- from the bobbed pivot instead would add the bob up frame after frame and float the model away. `draw`, when
-- given, draws each step instead (the client's customers, Effects/CustomerWalk, #1143): the model, its feet's
-- frame on the ground, the studs moved this step and the step's seconds; false back moves it the plain way.
function Mover.walkTo(
	model: Model,
	target: Vector3,
	speed: number,
	alive: () -> boolean,
	draw: ((Model, CFrame, number, number) -> boolean)?
): boolean
	local elapsed = 0
	local start = model:GetPivot().Position
	local ground = Vector3.new(start.X, target.Y, start.Z)
	local placed: CFrame? = nil -- where the last plain step put the model, bob and all
	local slowed = draw == nil and slow()
	local sinceWrite = math.huge -- seconds since the last write, under strayWalkSlow
	if slowed then
		-- The walk itself, so a client can draw it exactly between the 10 Hz writes (Effects/Pose): it is a straight
		-- line from WalkFrom to WalkTo at WalkSpeed studs a second from server time WalkAt. WalkAt goes when it ends.
		model:SetAttribute(Mover.WALK_FROM, ground)
		model:SetAttribute(Mover.WALK_TO, target)
		model:SetAttribute(Mover.WALK_SPEED, speed)
		model:SetAttribute(Mover.WALK_AT, workspace:GetServerTimeNow())
	end
	local function ended()
		if slowed and model.Parent ~= nil then
			model:SetAttribute(Mover.WALK_AT, nil)
		end
	end
	while alive() and model.Parent ~= nil do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local delta = target - ground
		local distance = delta.Magnitude
		if distance <= 0.25 then
			local direction = flat(model:GetPivot().LookVector)
			if direction.Magnitude < 0.05 then
				direction = Vector3.new(0, 0, -1)
			end
			local arrived = CFrame.lookAt(target, target + direction.Unit)
			if draw == nil or not draw(model, arrived, 0, 0) then
				model:PivotTo(arrived)
			end
			ended()
			return true
		end
		local moved = math.min(speed * dt, distance)
		ground += delta.Unit * moved
		local facing = flat(delta)
		if draw ~= nil then
			local feet = if facing.Magnitude < 0.05
				then CFrame.new(ground)
				else CFrame.lookAt(ground, ground + facing.Unit)
			if draw(model, feet, moved, dt) then
				continue
			end
		end
		if slowed then
			sinceWrite += dt
			if sinceWrite < Mover.SLOW_STEP then
				continue
			end
			sinceWrite = 0
		end
		local bob = if slowed then 0 else math.abs(math.sin(elapsed * 9)) * 0.12
		local shown = ground + Vector3.new(0, bob, 0)
		local frame = if facing.Magnitude < 0.05
			then CFrame.new(shown)
			else CFrame.lookAt(shown, shown + facing.Unit)
		model:PivotTo(frame)
		placed = frame
	end
	local last = placed
	if
		last ~= nil
		and model.Parent ~= nil
		and model:GetPivot().Position:FuzzyEq(last.Position, 1e-3)
	then
		model:PivotTo(last - last.Position + ground)
	end
	ended()
	return false
end

return Mover
