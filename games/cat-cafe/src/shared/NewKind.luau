--!strict
-- #3529 (Nov 11 read: 147 new players stalled on "five different cats", and nothing in the world says which strays
-- are kinds the player does not have). Behind the `newKindTag` live switch (off until review and QA):
--   a "NEW" tag over every stray, bait cat and stuck cat whose kind the player has never owned (Screens/NewKindTags),
--   one line on the catch card when the kind is new ("New kind! 3/5 for Cozy Cafe" below Tier 2),
--   while "Three different cats" (#4188: four before, #4098: five) is the Grand Opening's next milestone: the goal card's "Catch new kinds of cat 2/3"
--     and, after IDLE_SECONDS with no catch started, the tutorial's marker and trail to the nearest NEW stray,
--   two step_time events say whether the trail showed and was followed (STEPS).
-- No rule changes: spawns, odds and prices stay as they are. No arrows, timers or "hurry" wording. Pure.
local Catalog = require(script.Parent.Catalog)

local NewKind = {}

NewKind.FLAG = "newKindTag"
NewKind.TEXT = "NEW 🐾"
NewKind.KINDS = Catalog.tiers[2].distinctCats -- Tier 2's need and the Grand Opening's "Three different cats" (#4188: 4 before)
NewKind.MILESTONE = "five_cats" -- the Grand Opening milestone the pointer serves
NewKind.RANGE = 60 -- studs: the tag shows within this (the name tag's own range)
NewKind.NEAR = 6 -- studs: inside this the name tag is enough
NewKind.IDLE_SECONDS = 20 -- no catch started for this long: the trail shows
NewKind.TRAIL_SECONDS = 120 -- the trail goes this long after it showed
NewKind.FOLLOWED_STUDS = 25 -- the player came this near the stray: new_kind_trail_followed
NewKind.LABEL = "New kind"
NewKind.LINE = "A kind of cat you don't have yet is close by"
NewKind.CANNON_LINE = "New kinds of cat wait in the Alleyway"
NewKind.NEXT_AREA = "Try the next area"
-- The step_time names (Telemetry.custom "step_time", field 1), each once a session.
NewKind.SHOWN = "new_kind_trail_shown"
NewKind.FOLLOWED = "new_kind_trail_followed"
NewKind.STEPS = { NewKind.SHOWN, NewKind.FOLLOWED }
-- What the client reports (TelemetryReport "new_kind_trail") for each.
NewKind.REPORTS = { shown = NewKind.SHOWN, followed = NewKind.FOLLOWED } :: { [string]: string }

-- Whether a cat of kind `catId` and rarity attribute `rarity` is new to a player with this collection (catId ->
-- anything). A Secret never is (it keeps its "???"), nor a cat whose kind is not revealed (no id).
function NewKind.isNew(collection: { [string]: any }?, catId: unknown, rarity: unknown): boolean
	if type(catId) ~= "string" or catId == "" or rarity == "Secret" then
		return false
	end
	local def = Catalog.getCat(catId :: string)
	if def == nil or def.rarity == "Secret" then
		return false
	end
	return collection ~= nil and collection[catId :: string] == nil
end

-- Whether the tag is up over a new kind `distance` studs away: not while this player is on a catch or rescue bar,
-- not while a net holds the cat, not right beside it and not past RANGE.
function NewKind.shows(isNew: boolean, busy: boolean, lockedBy: unknown, distance: number): boolean
	if not isNew or busy then
		return false
	end
	if type(lockedBy) == "number" and lockedBy ~= 0 then
		return false
	end
	return distance >= NewKind.NEAR and distance <= NewKind.RANGE
end

-- The catch card's line for a new kind: `kinds` different cats owned before this one, at cafe tier `tier`.
function NewKind.line(kinds: number, tier: number): string
	if tier >= 2 then
		return "New kind!"
	end
	local tier2 = Catalog.getTier(2)
	local after = math.clamp(math.floor(kinds) + 1, 1, NewKind.KINDS)
	return string.format(
		"New kind! %d/%d for %s",
		after,
		NewKind.KINDS,
		if tier2 ~= nil then tier2.name else "Tier 2"
	)
end

-- The goal card's title with `kinds` different cats owned; `narrow` on the phone's narrower card.
function NewKind.title(kinds: number, narrow: boolean?): string
	return string.format(
		if narrow then "New kinds of cat 🐾 %d/%d" else "Catch new kinds of cat 🐾 %d/%d",
		math.clamp(math.floor(kinds), 0, NewKind.KINDS),
		NewKind.KINDS
	)
end

-- Whether five different cats is the goal: the switch is on, it is the Grand Opening's next milestone (`current`,
-- GrandOpening.current's id) and the player has fewer than five kinds.
function NewKind.goal(on: boolean, current: string?, kinds: number): boolean
	return on and current == NewKind.MILESTONE and kinds < NewKind.KINDS
end

export type Where = "none" | "stray" | "cannon" | "next"

-- What the trail leads to for a player in wild area `area` (nil in town). Nothing at night. In town: the cannon.
-- In an area: the nearest NEW stray there (`hasNew`), else the camp's cannon with NEXT_AREA when another area is
-- open to them (`otherOpen`), else nothing until the next wave.
function NewKind.where(
	area: string?,
	areasOpen: boolean,
	hasNew: boolean,
	otherOpen: boolean
): Where
	if not areasOpen then
		return "none"
	elseif area == nil then
		return "cannon"
	elseif hasNew then
		return "stray"
	end
	return if otherOpen then "next" else "none"
end

-- Whether the trail shows: the goal is on, the player is not busy (a catch, a rescue, carrying), no catch was
-- started for IDLE_SECONDS (`idle`), and the trail for this count of kinds has not had its TRAIL_SECONDS
-- (`shownFor` nil before it showed). It comes back after each new kind: the caller keeps `shownFor` per count.
function NewKind.trail(goal: boolean, busy: boolean, idle: number, shownFor: number?): boolean
	if not goal or busy then
		return false
	end
	if shownFor ~= nil then
		return shownFor < NewKind.TRAIL_SECONDS
	end
	return idle >= NewKind.IDLE_SECONDS
end

-- Whether a player at `player` has come to the stray at `stray` (flat distance).
function NewKind.followed(player: Vector3, stray: Vector3): boolean
	local dx, dz = player.X - stray.X, player.Z - stray.Z
	return math.sqrt(dx * dx + dz * dz) <= NewKind.FOLLOWED_STUDS
end

return NewKind
