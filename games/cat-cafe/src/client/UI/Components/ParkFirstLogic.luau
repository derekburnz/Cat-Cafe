--!strict
-- #2915 (onboarding_v6: 3 of the 10 players who reach Tier 2 never catch a cat in the Park; Design-Agent's spec, step
-- 2): the Park-first hint, its words and timings, and the rules for when each part shows. Pure, so the specs test it.
--   1. Ranking up to Tier 2 turns the rank-up card's button into "Fly to the Park": it takes the player to the
--      cannon and opens the picker with the Park card's Launch ringed (UI.cannon.fly).
--   2. The first landing in the Park, once per account (tipsSeen.park_first): "Strays wait near the camp 🐾", 3 s.
--   3. After NUDGE_AFTER seconds in the Park with no Park cat yet, the nearest free stray within RANGE studs gets the
--      tutorial's flashing ring (Components/StepTarget) for RING_SECONDS, or until it is caught; once a session.
-- Controllers/ParkFirstController runs 2 and 3.

local ParkFirstLogic = {}

ParkFirstLogic.AREA = "park"
ParkFirstLogic.TIP = "park_first" -- shared/Tips.LIST's client tip, saved in tipsSeen by TipSeen
ParkFirstLogic.TELEMETRY = "park_first_hint" -- TelemetryReport value: "toast" or "ring"
ParkFirstLogic.FLY_TEXT = "Fly to the Park"
ParkFirstLogic.TOAST = "Strays wait near the camp 🐾"
ParkFirstLogic.TOAST_SECONDS = 3
ParkFirstLogic.TOAST_AFTER_LANDING = 1 -- the area's name card has the first moment on arrival
ParkFirstLogic.NUDGE_AFTER = 90
ParkFirstLogic.RANGE = 60
ParkFirstLogic.RING_SECONDS = 30
ParkFirstLogic.PICKER_RING_SECONDS = 120 -- the picker's ring waits this long for the player to open it

-- Whether any cat in the collection comes from the Park (Gameplay: there is no first-Park-catch flag in the sync).
function ParkFirstLogic.caught(
	collection: { [string]: number }?,
	areaOf: (catId: string) -> string?
): boolean
	if collection == nil then
		return false
	end
	for catId in collection do
		if areaOf(catId) == ParkFirstLogic.AREA then
			return true
		end
	end
	return false
end

-- The landing toast: the Park, never shown on this account, and no Park cat yet (an older save that already caught
-- one there needs no telling).
function ParkFirstLogic.toastDue(
	destination: string?,
	tipsSeen: { [string]: boolean }?,
	caught: boolean
): boolean
	if destination ~= ParkFirstLogic.AREA or caught then
		return false
	end
	return not (tipsSeen ~= nil and tipsSeen[ParkFirstLogic.TIP] == true)
end

-- The nudge ring: NUDGE_AFTER seconds in the Park on this visit, no Park cat, not rung this session.
function ParkFirstLogic.nudgeDue(inParkFor: number, caught: boolean, rung: boolean): boolean
	return not rung and not caught and inParkFor >= ParkFirstLogic.NUDGE_AFTER
end

export type Stray = {
	position: Vector3,
	area: string?,
	lockedBy: number, -- the catch lock's UserId, 0 when free
	beginner: number, -- F87: another player's beginner stray is theirs
	dropped: boolean, -- a dropped cat walking home is picked up with no circles, so it teaches nothing
}

-- The nearest free Park stray within `range` of `from`, as an index into `strays`, or nil.
function ParkFirstLogic.pick(
	strays: { Stray },
	from: Vector3,
	userId: number,
	range: number
): number?
	local best: number? = nil
	local bestDistance = range
	for index, stray in strays do
		if stray.area ~= ParkFirstLogic.AREA or stray.dropped then
			continue
		end
		if stray.lockedBy ~= 0 and stray.lockedBy ~= userId then
			continue
		end
		if stray.beginner ~= 0 and stray.beginner ~= userId then
			continue
		end
		local distance = (stray.position - from).Magnitude
		if distance <= bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

return ParkFirstLogic
