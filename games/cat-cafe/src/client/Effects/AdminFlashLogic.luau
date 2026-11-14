--!strict
-- #4325 (Derek 2026-11-14: "I think the admin events are not flashy enough because people always leave"): the pure
-- half of Effects/AdminFlash, so the cloud spec runner checks it. It reads Effects/AdminEventLogic's View.
--   kindOf(view)                the row of KINDS the event shows as (its first effect in KINDS' order), or nil
--   headline(view)              the reward in a few big characters: "x4 MONEY", "x4 BOWL SPEED", else the title
--   stay(view)                  why to stay, in one short line: "Stay and cash in!"
--   lasting(view)               "for 10 minutes", "for 90 seconds"
--   lookOf(view)                which of Presets.adminFlash.looks the world takes while it runs
--   rainOf(view)                which of Presets.adminAir.kinds falls round you while it runs
--   step(view, now, seenAt, p)  what the screen shows now: the 3, 2, 1 before the start, the name splash, the strip,
--                               its last minute
--   earned(total, before, after) the running "You earned" sum: money that came in, never what was spent
--   pulse(t, hz, amount)        the last minute's slow swell, 1 to 1 + amount
--   money(n, symbol)            12340 -> "+$12,340"
-- The words count down nothing but the event's own start and end, and sell nothing.

local AdminEventLogic = require(script.Parent.AdminEventLogic)

local AdminFlashLogic = {}

type View = AdminEventLogic.View

export type Kind = {
	name: string, -- the effect: bowlSpeed, catStorm or one of AdminEventLogic.EXTRA's names
	head: string, -- `%s` takes the effect's number
	stay: string,
	look: string,
	rain: string,
}
export type Spec = {
	countFrom: number, -- the 3, 2, 1 begins this many seconds before the start
	splashSeconds: number,
	stripAfter: number, -- the strip comes in this long after the start, or after a late joiner first sees it
	lastSeconds: number, -- the strip's last minute
	lastMinEvent: number, -- an event shorter than this has no last minute look
}
export type Step = {
	phase: "none" | "count" | "splash" | "run",
	count: number, -- 3, 2, 1 while phase is "count", else 0
	strip: boolean, -- the strip shows
	last: boolean, -- the last minute
	left: number, -- seconds to the end (to the start while phase is "count")
	since: number, -- seconds into the splash or the run
}

-- In the order an event with several effects picks its look: the first one it has.
AdminFlashLogic.KINDS = {
	{
		name = "moneyStorm",
		head = "x%s MONEY",
		stay = "Stay and cash in!",
		look = "gold",
		rain = "moneyStorm",
	},
	{
		name = "goldBoost",
		head = "x%s GOLD CATS",
		stay = "Stay and catch a gold one!",
		look = "gold",
		rain = "goldBoost",
	},
	{
		name = "rainbowBoost",
		head = "x%s RAINBOW CATS",
		stay = "Stay and catch a rainbow one!",
		look = "rainbow",
		rain = "rainbowBoost",
	},
	{
		name = "catStorm",
		head = "x%s MYTHICAL CATS",
		stay = "Cats are raining. Go catch them!",
		look = "storm",
		rain = "catStorm",
	},
	{
		name = "bowlSpeed",
		head = "x%s BOWL SPEED",
		stay = "Fill your bowls now!",
		look = "rose",
		rain = "bowlSpeed",
	},
	{
		name = "secretHunt",
		head = "%s SECRET CATS",
		stay = "They are hiding. Go find them!",
		look = "violet",
		rain = "secretHunt",
	},
	{
		name = "traitParty",
		head = "FREE TRAIT ROLLS",
		stay = "Roll while it lasts!",
		look = "violet",
		rain = "traitParty",
	},
	{
		name = "fishFountain",
		head = "GOLDEN FISH",
		stay = "Run to the Town Square fountain!",
		look = "blue",
		rain = "fishFountain",
	},
	{
		name = "crateDrop",
		head = "GOLDEN CRATES",
		stay = "Crates are dropping. Go grab them!",
		look = "gold",
		rain = "crateDrop",
	},
	{
		name = "speedRush",
		head = "SPEED SHOES",
		stay = "Everyone is fast. Go catch cats!",
		look = "mint",
		rain = "speedRush",
	},
} :: { Kind }
AdminFlashLogic.DEFAULT_LOOK = "rose"
AdminFlashLogic.DEFAULT_STAY = "Stay and play!"

-- 4 -> "4", 1.5 -> "1.5"
local function times(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

local function valueOf(view: View, name: string): number?
	if name == "bowlSpeed" then
		return if view.bowlSpeed > 1 then view.bowlSpeed else nil
	elseif name == "catStorm" then
		return if view.catStorm > 1 then view.catStorm else nil
	end
	local extra = view.extra
	return if extra ~= nil then extra[name] else nil
end

function AdminFlashLogic.kindOf(view: View?): (Kind?, number)
	if view == nil then
		return nil, 0
	end
	for _, row in AdminFlashLogic.KINDS do
		local value = valueOf(view, row.name)
		if value ~= nil then
			return row, value
		end
	end
	return nil, 0
end

function AdminFlashLogic.headline(view: View): string
	local row, value = AdminFlashLogic.kindOf(view)
	if row == nil then
		return string.upper(view.title)
	end
	if string.find(row.head, "%s", 1, true) ~= nil then
		return string.format(row.head, times(value))
	end
	return row.head
end

function AdminFlashLogic.stay(view: View): string
	local row = AdminFlashLogic.kindOf(view)
	return if row ~= nil then row.stay else AdminFlashLogic.DEFAULT_STAY
end

function AdminFlashLogic.lookOf(view: View?): string?
	if view == nil then
		return nil
	end
	local row = AdminFlashLogic.kindOf(view)
	return if row ~= nil then row.look else AdminFlashLogic.DEFAULT_LOOK
end

function AdminFlashLogic.rainOf(view: View?): string?
	local row = AdminFlashLogic.kindOf(view)
	return if row ~= nil then row.rain else nil
end

-- "for 10 minutes", "for 1 minute", "for 90 seconds": the event's whole length.
function AdminFlashLogic.lasting(view: View): string
	local seconds = math.max(0, math.floor(view.endsAt - view.startsAt + 0.5))
	if seconds < 120 and seconds % 60 ~= 0 then
		return string.format("for %d seconds", seconds)
	end
	local minutes = math.floor(seconds / 60 + 0.5)
	return if minutes == 1 then "for 1 minute" else string.format("for %d minutes", minutes)
end

local NONE: Step = { phase = "none", count = 0, strip = false, last = false, left = 0, since = 0 }

-- `seenAt`: when this client first saw the event running (nil before it has), so a player who joins while it runs
-- still gets the name splash, counted from then.
function AdminFlashLogic.step(view: View?, now: number, seenAt: number?, p: Spec): Step
	if view == nil or now >= view.endsAt then
		return NONE
	end
	if not AdminEventLogic.runs(view, now) then
		local to = view.startsAt - now
		if to > 0 and to <= p.countFrom then
			return {
				phase = "count",
				count = math.ceil(to),
				strip = false,
				last = false,
				left = to,
				since = 0,
			}
		end
		return NONE
	end
	local from = math.max(view.startsAt, seenAt or view.startsAt)
	local since = math.max(0, now - from)
	local left = view.endsAt - now
	local last = left <= p.lastSeconds and view.endsAt - view.startsAt >= p.lastMinEvent
	return {
		phase = if since < p.splashSeconds then "splash" else "run",
		count = 0,
		strip = since >= p.stripAfter,
		last = last,
		left = left,
		since = since,
	}
end

-- Adds what came in between two readings of the player's money; a drop (something bought) takes nothing away.
function AdminFlashLogic.earned(total: number, before: number?, after: number?): number
	if before == nil or after == nil or after ~= after or before ~= before then
		return total
	end
	if after > before then
		return total + (after - before)
	end
	return total
end

-- A slow swell `hz` times a second: 1 at rest, 1 + amount at its top.
function AdminFlashLogic.pulse(t: number, hz: number, amount: number): number
	return 1 + amount * (0.5 - 0.5 * math.cos(2 * math.pi * hz * t))
end

-- 12340 -> "+$12,340"
function AdminFlashLogic.money(n: number, symbol: string): string
	local whole = tostring(math.max(0, math.floor(n)))
	local out = whole
	while true do
		local replaced, count = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
		out = replaced
		if count == 0 then
			break
		end
	end
	return "+" .. symbol .. out
end

return AdminFlashLogic
