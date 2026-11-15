--!strict
-- Where Effects/DragonRise's camera may stand at the Dragon Keep (#4612, Derek 2026-11-15: "the cut scene for the
-- dragon hatching/upgrading shows from the wall maybe make it show from above"). The yard shots used to stand low
-- out by the gate, so the eye sat in or behind the Keep's front wall (the Keep is left out of the camera's own ray
-- check, so nothing pulled it in). Now the eye is lifted until it looks down at the dragon from above (at least
-- `pitch`), and until the line from it to the dragon clears the walls' top by `gap`. Pure: everything is in the
-- Keep's own frame (yard centre at 0, -Z out the gate), so it is tested without a place.

local KeepShot = {}

export type Walls = { halfX: number, halfZ: number, top: number }

-- Pure: the walls from the Keep model's bounding box, its centre `centre` in the yard centre's frame and its `size`;
-- the top is kept to at most `most` studs so a tall flag or tower does not throw the camera into the sky.
function KeepShot.walls(centre: Vector3, size: Vector3, most: number): Walls
	return {
		halfX = size.X / 2,
		halfZ = size.Z / 2,
		top = math.clamp(centre.Y + size.Y / 2, 0, most),
	}
end

-- Pure: `eye` lifted (X and Z kept) so it looks down on `look` by at least `pitch` radians (none when 0) and, when `look` is in
-- the yard and `eye` outside it, the line between them passes `gap` studs over the walls.
function KeepShot.lift(
	eye: Vector3,
	look: Vector3,
	walls: Walls?,
	gap: number,
	pitch: number
): Vector3
	local y = eye.Y
	if pitch > 0 then
		local flat = math.sqrt((eye.X - look.X) ^ 2 + (eye.Z - look.Z) ^ 2)
		y = math.max(y, look.Y + flat * math.tan(pitch))
	end
	if walls ~= nil then
		local hx, hz = walls.halfX, walls.halfZ
		local inside = math.abs(look.X) < hx and math.abs(look.Z) < hz
		local outside = math.abs(eye.X) > hx or math.abs(eye.Z) > hz
		if inside and outside then
			-- the share of the way from `look` to `eye` at which the line leaves the walls
			local dx, dz = eye.X - look.X, eye.Z - look.Z
			local share = math.huge
			if dx ~= 0 then
				share = math.min(share, ((if dx > 0 then hx else -hx) - look.X) / dx)
			end
			if dz ~= 0 then
				share = math.min(share, ((if dz > 0 then hz else -hz) - look.Z) / dz)
			end
			local need = walls.top + gap
			if share > 0 and share < 1 and need > look.Y then
				y = math.max(y, look.Y + (need - look.Y) / share)
			end
		end
	end
	return Vector3.new(eye.X, y, eye.Z)
end

return KeepShot
