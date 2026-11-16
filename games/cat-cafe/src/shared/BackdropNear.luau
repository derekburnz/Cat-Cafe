--!strict
-- #4857 (Derek 2026-11-16: "phone players look a little laggy when walking around"): Model-Agent's count put the 15
-- area backdrop rings at 19,512 parts, all in every player's Workspace while a player sees one area at a time (the
-- areas sit 1,400 to 2,800 studs apart). With the backdropsNear switch on, each client keeps an area's ring in its
-- own Workspace only while the camera or the character is within MARGIN studs of the ring's box; the rest wait outside Workspace on that client alone (Controllers/BackdropController). The server
-- and other players are not touched. Off (the default) every ring stays as built.
--
-- Roblox terms: a client can re-parent an instance the server made; the change stays on that device and is not sent
-- back. An instance outside Workspace is not drawn and costs the renderer nothing.

local BackdropNear = {}

BackdropNear.FLAG = "backdropsNear" -- shared/LiveFlags, off by default
BackdropNear.MARGIN = 600 -- studs past the ring's box, on the ground plane: well before it shows through the haze
BackdropNear.HOLD = 100 -- studs more before a shown ring goes again, so it does not flip at the edge
BackdropNear.STEP = 0.5 -- seconds between checks
BackdropNear.NAME = "Backdrop" -- WorldBuilder's name for an area's ring, a child of the area's model

-- A ring's box on the ground plane: its centre, its X axis (unit, on the ground) and its half sizes along that axis and
-- the one across it. BackdropController makes one from the ring's GetBoundingBox.
export type Box = { x: number, z: number, ax: number, az: number, halfX: number, halfZ: number }

-- Whether a point is within `margin` studs of a box on the ground plane (height is ignored, so the camera high over an
-- area during a cannon flight still counts). Pure.
function BackdropNear.near(box: Box, point: Vector3, margin: number): boolean
	local dx, dz = point.X - box.x, point.Z - box.z
	local along = dx * box.ax + dz * box.az
	local across = -dx * box.az + dz * box.ax
	return math.abs(along) <= box.halfX + margin and math.abs(across) <= box.halfZ + margin
end

-- Whether a ring stays in Workspace: any of the points (the camera, the character) is near it, or `bound` (kept
-- whatever the distance). A ring already shown keeps HOLD more studs. Pure.
function BackdropNear.keep(box: Box, points: { Vector3 }, shown: boolean, bound: boolean): boolean
	if bound then
		return true
	end
	local margin = BackdropNear.MARGIN + if shown then BackdropNear.HOLD else 0
	for _, point in points do
		if BackdropNear.near(box, point, margin) then
			return true
		end
	end
	return false
end

return BackdropNear
