--!strict
-- #3666 (Derek 2026-11-12: "is there a way to run it for only half of users and see stat difference?" and "I think
-- split it 50 50"), behind the `introSplit` switch (IntroSplit.FLAG, off by default): the intro scene plays itself
-- on a first join for half of new players, and the other half keeps today's start with no scene (#3162), so the two
-- halves' first minutes can be compared.
-- A save joins the test once, as it loads in its first session with the intro never seen and the switch on. Its
-- group comes from the account number alone (even: the scene), so it never depends on the server or the hour, and
-- it is kept in the save's telemetry record (introGroup), so later sessions' funnel steps carry the same group.
-- Telemetry puts the group on every onboarding and first hour step as custom field 3 and logs intro_group once.
-- Saves that were never in the test have no group and are untouched. Pure.

local IntroSplit = {}

IntroSplit.FLAG = "introSplit" -- LiveFlags, off by default
IntroSplit.ON = "intro_on" -- the scene plays itself on the first join
IntroSplit.OFF = "intro_off" -- no scene: the ? Tutorial tile glows and replays it
-- #4001: the intro test, its arm from a Creator Hub Experiment's `introMode` (IntroModeService; Derek 19:31 UTC: "make
-- the ABC test"): "full" plays today's intro on the first join, "short" the three shot intro, "none" puts the save in
-- OFF (no scene, straight to the tutorial steps). An arm from the config joins whatever the `introSplit` switch says.
IntroSplit.FULL = "intro_full"
IntroSplit.SHORT = "intro_short"
IntroSplit.EVENT = "intro_group" -- Telemetry.custom, once as a save joins the test (field 1: the group)
IntroSplit.FIRST_SESSIONS = 1 -- stats.sessions at most this as the save loads

-- The group an account falls in.
function IntroSplit.group(userId: number): string
	return if math.floor(userId) % 2 == 0 then IntroSplit.ON else IntroSplit.OFF
end

-- A saved group made safe, or nil.
function IntroSplit.valid(raw: unknown): string?
	if
		raw == IntroSplit.ON
		or raw == IntroSplit.OFF
		or raw == IntroSplit.FULL
		or raw == IntroSplit.SHORT
	then
		return raw :: string
	end
	return nil
end

-- Whether a loading save joins the test now: the switch on, no group yet, its first session, the intro never seen.
function IntroSplit.joins(
	on: boolean,
	sessions: number,
	introSeen: boolean,
	group: string?
): boolean
	return on and group == nil and sessions <= IntroSplit.FIRST_SESSIONS and not introSeen
end

-- #4001: the group an Experiment's introMode value puts a new save in, or nil (no experiment, or another value).
function IntroSplit.fromMode(mode: unknown): string?
	if mode == "full" then
		return IntroSplit.FULL
	elseif mode == "short" then
		return IntroSplit.SHORT
	elseif mode == "none" then
		return IntroSplit.OFF
	end
	return nil
end

-- Whether the intro plays itself on a join for a save in `group`: Config.IntroAutoPlay (`base`) for everyone, or
-- the scene half while the switch is on. With the switch off again nobody new gets the scene.
function IntroSplit.plays(group: string?, on: boolean, base: boolean): boolean
	return base
		or group == IntroSplit.FULL
		or group == IntroSplit.SHORT
		or (on and group == IntroSplit.ON)
end

-- A funnel step's custom fields with the group as field 3 (fields 1 and 2 padded with "-"); unchanged with no group.
function IntroSplit.fields(group: string?, fields: { string }): { string }
	if group == nil then
		return fields
	end
	return { fields[1] or "-", fields[2] or "-", group }
end

return IntroSplit
