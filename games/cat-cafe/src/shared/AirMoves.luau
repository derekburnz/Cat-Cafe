--!strict
-- #4447: the Dragon Keep's air cards on the client (Controllers/AirMovesController), pure so specs can drive them.
-- The server names what the slotted cards allow as player attributes (DragonKeepService): DoubleJump (Double Jump,
-- jump once more in the air) and Glide (hold jump to fall slowly). Movement is the client's on Roblox, so these only
-- shape how the local character moves; nothing here gives a reward.
-- JumpRequest fires again and again while jump is held, so a gap of RELEASE_GAP between two of them is a release,
-- and a request within HOLD_GAP of the last one is a hold.

local AirMoves = {}

AirMoves.RELEASE_GAP = 0.2 -- seconds with no JumpRequest that count as letting go of jump
AirMoves.HOLD_GAP = 0.15 -- seconds since the last JumpRequest that still count as holding it
AirMoves.MIN_AIR = 0.1 -- seconds in the air before the second jump may go (not the ground jump's own repeats)
AirMoves.GLIDE_FALL = 8 -- studs a second, the most a glide falls

export type State = {
	airborneAt: number?, -- when the character left the ground; nil on the ground
	lastRequest: number?, -- the last JumpRequest
	released: boolean, -- jump was let go since leaving the ground
	used: boolean, -- the second jump is spent until the next landing
}

function AirMoves.new(): State
	return { airborneAt = nil, lastRequest = nil, released = false, used = false }
end

-- The character left the ground (freefall) or came down (landed).
function AirMoves.leftGround(state: State, now: number)
	if state.airborneAt == nil then
		state.airborneAt = now
		state.released = false
	end
end
function AirMoves.landed(state: State)
	state.airborneAt = nil
	state.used = false
	state.released = false
end

-- A JumpRequest at `now`: whether it is the second jump (Double Jump slotted, in the air, a fresh press, not spent).
function AirMoves.request(state: State, now: number, canDouble: boolean): boolean
	local last = state.lastRequest
	if last == nil or now - last >= AirMoves.RELEASE_GAP then
		state.released = state.airborneAt ~= nil
	end
	state.lastRequest = now
	local airborne = state.airborneAt
	if
		not canDouble
		or state.used
		or airborne == nil
		or not state.released
		or now - airborne < AirMoves.MIN_AIR
	then
		return false
	end
	state.used = true
	state.released = false
	return true
end

-- The fall speed to hold the character to while gliding, or nil when it is not gliding: Glide slotted, in the air,
-- jump held and falling faster than GLIDE_FALL.
function AirMoves.glideFall(
	state: State,
	now: number,
	canGlide: boolean,
	fallSpeed: number
): number?
	local last = state.lastRequest
	if
		not canGlide
		or state.airborneAt == nil
		or last == nil
		or now - last > AirMoves.HOLD_GAP
		or fallSpeed >= -AirMoves.GLIDE_FALL
	then
		return nil
	end
	return -AirMoves.GLIDE_FALL
end

return AirMoves
