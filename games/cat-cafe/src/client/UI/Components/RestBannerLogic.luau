--!strict
-- #3701 (Derek 2026-11-12: "the message that pops up about stay in cafe for 2x money only pops up once not everytime
-- your in cafe and also gets cut off make it more obvious redo the banner and shorter clear message"): which of the
-- cafe rest banner's three states shows, and its words, kept apart from the banner so they can be tested without a
-- screen (afk-cafe.md section 6a).
--   welcome   each time the player comes into their own cafe or onto its doorstep, WELCOME_SECONDS long, at most
--             once every WELCOME_GAP seconds
--   counting  from COUNT_AFTER seconds without input until the rest starts, with the time left
--   resting   while the server says the player rests
-- In a 2x party the rest adds nothing, so no line names 2x and the count is skipped.

local RestBannerLogic = {}

export type State = "welcome" | "counting" | "resting"

export type View = {
	rest: boolean?, -- the server's CafeRest while this client is idle: true doubled, false in a party, nil not resting
	zone: boolean?, -- the server's CafeRestZone: true a rest here would double, false in a party, nil not in the zone
	sinceInput: number, -- seconds since this client's last input
	welcomeAge: number?, -- seconds since the welcome last came up, nil when it never has
	calm: boolean, -- no window, minigame, intro or hidden UI
	wait: number, -- Config.AfkCafeSeconds
}

RestBannerLogic.WELCOME_SECONDS = 5
RestBannerLogic.WELCOME_GAP = 60
RestBannerLogic.COUNT_AFTER = 10
RestBannerLogic.GRACE = 5 -- the count holds at its last second this long while the server takes the rest up
RestBannerLogic.MAX_CHARS = 26 -- the big line's most, so it fits a phone on one row

-- The state to show now (nil for none) and, while counting, the whole seconds left.
function RestBannerLogic.pick(view: View): (State?, number)
	if not view.calm then
		return nil, 0
	end
	if view.rest ~= nil then
		return "resting", 0
	end
	if view.zone == nil then
		return nil, 0
	end
	if
		view.zone
		and view.sinceInput >= RestBannerLogic.COUNT_AFTER
		and view.sinceInput < view.wait + RestBannerLogic.GRACE
	then
		return "counting", math.max(1, math.ceil(view.wait - view.sinceInput))
	end
	local age = view.welcomeAge
	if age ~= nil and age < RestBannerLogic.WELCOME_SECONDS then
		return "welcome", 0
	end
	return nil, 0
end

-- Whether a walk into the zone brings the welcome up: never more than once every WELCOME_GAP seconds, so stepping in
-- and out of the door does not flash it.
function RestBannerLogic.welcomeDue(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= RestBannerLogic.WELCOME_GAP
end

-- 80 -> "1:20"
function RestBannerLogic.clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- The big line, the small line and the badge's letters. `doubled` false in a 2x party.
function RestBannerLogic.words(
	state: State,
	doubled: boolean,
	remaining: number
): (string, string, string)
	if state == "counting" then
		return "2x money in " .. RestBannerLogic.clock(remaining), "Almost resting", "zz"
	end
	if state == "resting" then
		if doubled then
			return "2x money ON", "Resting in your cafe", "2x"
		end
		return "Resting in your cafe", "Your cats keep earning", "zz"
	end
	if doubled then
		return "Stand still for 2x money", "Your cats earn double while you rest", "2x"
	end
	return "Rest here, cats still earn", "Even while you are away", "zz"
end

return RestBannerLogic
