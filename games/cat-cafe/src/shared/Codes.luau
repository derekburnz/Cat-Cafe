--!strict
-- Codes and the Codes Cat (F65, data-model section 11d), shared so the code box and RedeemCode agree. Pure.
-- `normalize` cleans what a player typed (codes are not case sensitive), `refusal` says why a code cannot pay, the
-- wrong-code guard locks the box after CodeWrongLimit wrong codes in CodeWrongWindowSeconds, and `circleOpen` keeps
-- the box from flickering on the edge of the CodesCircle.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Codes = {}

Codes.TAG = "CodesCat" -- the station
Codes.CIRCLE = "CodesCircle" -- the part or Model inside the station that marks the circle on the ground
Codes.MAX_BYTES = 40 -- what RedeemCode accepts before trimming

Codes.REDEEMED = "Code redeemed!"
Codes.UNKNOWN = "That code doesn't exist"
Codes.USED = "You already used that code"
Codes.EXPIRED = "That code has expired"
Codes.GROUP = "Join the Cat Cafe group to use this code"
Codes.LOCKED = "Too many tries, wait a minute"
Codes.FAR = "Walk up to the Codes Cat"

-- Wrong codes inside the window and when the lock ends, in one clock (the server's os.clock()).
export type WrongGuard = { wrong: { number }, lockedUntil: number }

-- The code a player typed, trimmed and lowercased, or nil when it cannot be a code: not a string, more than
-- MAX_BYTES before trimming, or not 1 to CodeMaxLength letters and digits after.
function Codes.normalize(raw: unknown): string?
	if type(raw) ~= "string" or #raw > Codes.MAX_BYTES then
		return nil
	end
	local text = string.lower(string.match(raw, "^%s*(.-)%s*$") or "")
	if #text < 1 or #text > Config.CodeMaxLength or string.match(text, "^%w+$") == nil then
		return nil
	end
	return text
end

function Codes.get(code: string): Types.CodeDef?
	return Catalog.codes[code]
end

-- True when the code is not active, has ended, or needs the group before the game belongs to one.
function Codes.expired(def: Types.CodeDef, now: number): boolean
	return not def.active
		or (def.endsAt ~= nil and now >= def.endsAt)
		or (def.requiresGroup == true and Config.GroupId == 0)
end

-- Why the normalized `code` cannot pay for this profile at `now` (os.time()), or nil when it can. `inGroup` is the
-- player's membership of Config.GroupId, asked only for a requiresGroup code; a non-member keeps the code unused.
function Codes.refusal(
	profile: Types.PlayerProfile,
	code: string,
	now: number,
	inGroup: boolean?
): string?
	local def = Catalog.codes[code]
	if def == nil then
		return Codes.UNKNOWN
	end
	if profile.codesRedeemed[def.id] ~= nil then
		return Codes.USED
	end
	if Codes.expired(def, now) then
		return Codes.EXPIRED
	end
	if def.requiresGroup == true and inGroup ~= true then
		return Codes.GROUP
	end
	return nil
end

function Codes.newGuard(): WrongGuard
	return { wrong = {}, lockedUntil = 0 }
end

function Codes.locked(guard: WrongGuard, now: number): boolean
	return now < guard.lockedUntil
end

-- Notes a wrong code at `now`. Returns true when it is the CodeWrongLimit-th inside CodeWrongWindowSeconds, which
-- locks the box for CodeLockSeconds and starts the count again.
function Codes.noteWrong(guard: WrongGuard, now: number): boolean
	local kept: { number } = {}
	for _, at in guard.wrong do
		if now - at < Config.CodeWrongWindowSeconds then
			table.insert(kept, at)
		end
	end
	table.insert(kept, now)
	if #kept >= Config.CodeWrongLimit then
		guard.wrong = {}
		guard.lockedUntil = now + Config.CodeLockSeconds
		return true
	end
	guard.wrong = kept
	return false
end

-- Whether the code box is open with the character `distance` studs (flat) from the circle's centre: it opens at
-- CodesCircleRadius or less and closes past CodesCircleRadius + 1, so standing on the edge never flickers.
function Codes.circleOpen(wasOpen: boolean, distance: number): boolean
	if wasOpen then
		return distance <= Config.CodesCircleRadius + 1
	end
	return distance <= Config.CodesCircleRadius
end

return Codes
