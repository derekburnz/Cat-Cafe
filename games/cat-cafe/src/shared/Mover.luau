--!strict
-- Moves an anchored Model along the ground by stepping its pivot every Heartbeat. Used for strays (server)
-- and cosmetic customers (client). Blocks the calling thread until it arrives or `alive()` returns false.

local RunService = game:GetService("RunService")

local Mover = {}

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

-- Walks at `speed` studs per second with a small bob. Returns true on arrival, false when cancelled.
-- The walk is tracked on the ground at the target's height and the bob is drawn on top each frame; stepping
-- from the bobbed pivot instead would add the bob up frame after frame and float the model away.
function Mover.walkTo(model: Model, target: Vector3, speed: number, alive: () -> boolean): boolean
	local elapsed = 0
	local start = model:GetPivot().Position
	local ground = Vector3.new(start.X, target.Y, start.Z)
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
			model:PivotTo(CFrame.lookAt(target, target + direction.Unit))
			return true
		end
		ground += delta.Unit * math.min(speed * dt, distance)
		local shown = ground + Vector3.new(0, math.abs(math.sin(elapsed * 9)) * 0.12, 0)
		local facing = flat(delta)
		if facing.Magnitude < 0.05 then
			model:PivotTo(CFrame.new(shown))
		else
			model:PivotTo(CFrame.lookAt(shown, shown + facing.Unit))
		end
	end
	return false
end

return Mover
