--!strict
-- #5715 (part of #5686; Design's spec, Growth's early tablet read: park_catch to tier_3 is 83% on phones and 61 to
-- 67% on tablets, and once Tier 3's kinds and Rares are met it is a coins wait with nothing on screen saying how to
-- get them). Behind the switch `tier3Pointer` (off by default): at Tier 2 in the Park, once Tier3Path's kinds and
-- Rares are met and while coins are under Tier 3's cost, one thing is pointed at, highest first:
--   "picnic"  the player's Picnic Basket while a party waits there (PicnicReady);
--   nothing   while Picnic Time runs (the picnic cats and their sign already lead);
--   "cat"     the nearest free Park stray within CAT_STUDS;
--   nothing   with none in range.
-- It ends the moment Tier 3 is funded (the goal card's ready pulse and RANK UP take over), and hides while the player
-- is busy (carrying, a window, a tutorial arrow or the intro). It never opens a menu and never moves the player.
-- Pure: Tier3PointerController gathers the Look and hands the target to Effects/Tier3PointerFx (Motion-FX), which
-- draws the arrow (bigger on a tablet) and the basket's ring; Telemetry logs REPORT under tier3_path (a name that
-- records), field 1 the target's FIELDS word.
--   active(look) -> boolean        whether anything may be pointed at now
--   target(look) -> Target?        the one thing to point at, or nil
--   caption(target) -> string?     the goal card's coins caption for it (GoalCard reads UI.tier3Pointer.caption)

local Tier3Pointer = {}

export type Target = "picnic" | "cat"

export type Look = {
	tier: number, -- the save's tier
	coins: number,
	cost: number?, -- Tier 3's cost (nil when there is no Tier 3)
	pathMet: boolean, -- Tier3Path's kinds and Rares are met (its switch on and no goal line left)
	area: string?, -- the area the player is in (UI.cannon.area)
	busy: boolean, -- carrying, a window, a tutorial arrow or the intro
	picnicReady: boolean, -- a party waits at the basket (the picnicParty switch on)
	picnicRunning: boolean, -- Picnic Time runs
	catNear: boolean, -- a free Park stray is within CAT_STUDS
}

Tier3Pointer.FLAG = "tier3Pointer"
Tier3Pointer.TIER = 2
Tier3Pointer.AREA = "park"
Tier3Pointer.CAT_STUDS = 80
Tier3Pointer.POLL = 1 -- seconds between picks
Tier3Pointer.REPORT = "tier3_pointer" -- TelemetryReport name; its value is one of FIELDS
Tier3Pointer.EVENT = "tier3_path" -- the custom event it is logged under (Tier3Path.PATH_EVENT)
Tier3Pointer.FIELDS = { picnic = "coins_picnic", cat = "coins_cat" }
Tier3Pointer.LOG_MAX = 20 -- target changes logged a session at most

local CAPTIONS: { [Target]: string } = {
	picnic = "Picnic Party: 2x coins",
	cat = "Catch cats: more coins",
}

function Tier3Pointer.active(look: Look): boolean
	return look.tier == Tier3Pointer.TIER
		and look.pathMet
		and look.cost ~= nil
		and look.coins < (look.cost :: number)
		and look.area == Tier3Pointer.AREA
		and not look.busy
end

function Tier3Pointer.target(look: Look): Target?
	if not Tier3Pointer.active(look) then
		return nil
	elseif look.picnicReady and not look.picnicRunning then
		return "picnic"
	elseif look.picnicRunning then
		return nil
	elseif look.catNear then
		return "cat"
	end
	return nil
end

function Tier3Pointer.caption(target: Target?): string?
	return if target ~= nil then CAPTIONS[target] else nil
end

-- The report's value for a target, or nil (nothing is logged for no target).
function Tier3Pointer.field(target: Target?): string?
	return if target ~= nil then Tier3Pointer.FIELDS[target] else nil
end

return Tier3Pointer
