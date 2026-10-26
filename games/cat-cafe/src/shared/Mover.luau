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
function Mover.walkTo(model: Model, target: Vector3, speed: number, alive: () -> boolean): boolean
	local elapsed = 0
	while alive() and model.Parent ~= nil do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local pivot = model:GetPivot()
		local delta = target - pivot.Position
		local distance = delta.Magnitude
		if distance <= 0.25 then
			local direction = flat(pivot.LookVector)
			if direction.Magnitude < 0.05 then
				direction = Vector3.new(0, 0, -1)
			end
			model:PivotTo(CFrame.lookAt(target, target + direction.Unit))
			return true
		end
		local step = math.min(speed * dt, distance)
		local nextPosition = pivot.Position + delta.Unit * step
		local facing = flat(delta)
		local bob = Vector3.new(0, math.abs(math.sin(elapsed * 9)) * 0.12, 0)
		if facing.Magnitude < 0.05 then
			model:PivotTo(CFrame.new(nextPosition + bob))
		else
			model:PivotTo(CFrame.lookAt(nextPosition + bob, nextPosition + bob + facing.Unit))
		end
	end
	return false
end

return Mover
