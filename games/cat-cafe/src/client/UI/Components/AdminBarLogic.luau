--!strict
-- #4195 (Derek 2026-11-14, admin events on update days): the words of the admin event's warning banner, HUD timer and
-- Admin Wheel window. Pure, so the spec can check them. The server publishes the admin event (running, or within
-- CafeEvents.ADMIN.warnSeconds of its start) as ReplicatedStorage attributes (CafeEvents.ADMIN_ATTRIBUTES); the
-- client reads them into an Info (Controllers/AdminEventController) and PlayerState.adminWheel says whether this
-- account may still spin.
--   BANNER_SECONDS                     how long the big banner stays at the warning and at the start
--   info(read) -> Info?                the attributes as one table (nil with no admin event shown)
--   clock(seconds) -> string           "2:00", "0:09"
--   line(effects) -> string?           the banner's line for decoded effects (see #4197 below)
--   view(info?, now, wheel?) -> View?  what the banner and the timer say now
--   wheelView(wheel?, now) -> WheelView  the window's Spin button and line
--   SLICES                             each wheel slice's short words and colour, in AdminWheel.PRIZES order
--   LINE_MAX                           the longest banner line that fits the banner on every screen
-- #4197 (part 2): the banner's line comes from the effects (AdminEventEffects), so a new event kind needs no UI
-- change: a `line` the server writes wins, else the first effect key below that is set (wheel, bowlSpeed, catStorm,
-- golden and rainbow, money, traitFree, hunt, fountain, crates, speed), else the title. A Secret Hunt's `hunt` (cats
-- hidden) and `found` (cats found so far; the server writes the attribute again as it changes) add "1/3" to the timer.

local AdminBarLogic = {}

AdminBarLogic.BANNER_SECONDS = 8
AdminBarLogic.LINE_MAX = 46

export type Info = {
	id: string,
	title: string,
	startsAt: number,
	endsAt: number,
	running: boolean,
	wheel: boolean,
	bowlSpeed: number?,
	line: string?, -- what the event does, for the banner (nil: the title)
	found: number?, -- a Secret Hunt: cats found so far
	total: number?, -- a Secret Hunt: cats hidden
}

export type Wheel = { eventId: string, spun: boolean, endsAt: number }

export type View = {
	phase: "soon" | "live",
	big: string, -- the banner's big words
	sub: string, -- the banner's line under them
	pill: string, -- the timer's words before its clock
	time: string, -- the timer's clock
	spin: boolean, -- the timer carries a Spin button: the wheel is up and this account has not spun it
	key: string, -- changes when the banner should come up again (the warning, then the start)
}

export type WheelView = {
	button: string,
	enabled: boolean,
	line: string,
}

-- The slices' short words (the window's list has the full names from AdminWheel.PRIZES) and colours, wheel order.
AdminBarLogic.SLICES = table.freeze({
	{ short = "20 rerolls", color = Color3.fromHex("FFC94D") },
	{ short = "200 fish", color = Color3.fromHex("5CC8FF") },
	{ short = "5 crates", color = Color3.fromHex("F2679E") },
	{ short = "Potions", color = Color3.fromHex("8FD3C1") },
	{ short = "3x money", color = Color3.fromHex("7BE85A") },
	{ short = "Mythical", color = Color3.fromHex("7A3FC4") },
	{ short = "50 + 500", color = Color3.fromHex("E07A3A") },
	{ short = "Secret", color = Color3.fromHex("1E1430") },
})

-- A whole number 0 or more, or nil.
local function whole(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value > 1e6 then
		return nil
	end
	return math.floor(value)
end

-- A multiplier over 1, as "5x" (nil when it is not one).
local function times(value: unknown): string?
	if type(value) ~= "number" or value ~= value or value <= 1 or value > 100 then
		return nil
	end
	return ("%dx"):format(math.floor(value))
end

-- The banner's line for each effect key, in order: the first key the effects set gives the line.
local LINES: { { key: string, say: (any, { [string]: any }) -> string? } } = {
	{
		key = "wheel",
		say = function(v)
			return if v == true then "One free spin on the Admin Wheel for everyone" else nil
		end,
	},
	{
		key = "bowlSpeed",
		say = function(v)
			local x = times(v)
			return if x then ("Bait bowls bring cats %s faster"):format(x) else nil
		end,
	},
	{
		key = "catStorm",
		say = function(v)
			local x = times(v)
			return if x then ("Strays rain in every area, Mythical %s"):format(x) else nil
		end,
	},
	{
		key = "golden",
		say = function(v, data)
			local gold, rainbow = times(v), times(data.rainbow)
			if gold and rainbow then
				return ("Gold coats %s, rainbow %s on every catch"):format(gold, rainbow)
			end
			return if gold then ("Gold coats %s on every catch"):format(gold) else nil
		end,
	},
	{
		key = "money",
		say = function(v)
			local x = times(v)
			return if x then ("%s cafe money for everyone"):format(x) else nil
		end,
	},
	{
		key = "traitFree",
		say = function(v)
			return if v == true then "Trait rolls are free, with extra rarity luck" else nil
		end,
	},
	{
		key = "hunt",
		say = function(v)
			local n = whole(v)
			if n == nil or n < 1 then
				return nil
			end
			return if n == 1
				then "Find the hidden Secret cat and keep it"
				else ("Find the %d hidden Secret cats and keep them"):format(n)
		end,
	},
	{
		key = "fountain",
		say = function(v)
			return if v == true then "The Town Square fountain sprays golden fish" else nil
		end,
	},
	{
		key = "crates",
		say = function(v)
			return if v == true then "Golden crates drop into every area" else nil
		end,
	},
	{
		key = "speed",
		say = function(v)
			return if v == true then "Speed Shoes for all, cannons fly 2x as far" else nil
		end,
	},
}

-- What the event does, from its decoded effects: the server's own `line`, else the first known effect's words.
function AdminBarLogic.line(data: { [string]: any }): string?
	local own = data.line
	if type(own) == "string" and own ~= "" and #own <= AdminBarLogic.LINE_MAX then
		return own
	end
	for _, entry in LINES do
		local value = data[entry.key]
		if value ~= nil then
			local words = entry.say(value, data)
			if words ~= nil then
				return words
			end
		end
	end
	return nil
end

-- `read(name)` gives one attribute (ReplicatedStorage:GetAttribute). `names` is CafeEvents.ADMIN_ATTRIBUTES.
function AdminBarLogic.info(
	read: (string) -> unknown,
	names: { [string]: string },
	decode: (string) -> unknown
): Info?
	local id = read(names.id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local startsAt, endsAt = read(names.startsAt), read(names.endsAt)
	if type(startsAt) ~= "number" or type(endsAt) ~= "number" or endsAt <= startsAt then
		return nil
	end
	local title = read(names.title)
	local wheel, bowlSpeed, line, found, total = false, nil, nil, nil, nil
	local raw = read(names.effects)
	if type(raw) == "string" and raw ~= "" then
		local ok, effects = pcall(decode, raw)
		if ok and type(effects) == "table" then
			local data = effects :: { [string]: any }
			wheel = data.wheel == true
			if type(data.bowlSpeed) == "number" and data.bowlSpeed > 1 then
				bowlSpeed = data.bowlSpeed
			end
			line = AdminBarLogic.line(data)
			local hidden = whole(data.hunt)
			if hidden ~= nil and hidden > 0 then
				total = hidden
				found = math.min(whole(data.found) or 0, hidden)
			end
		end
	end
	return {
		id = id,
		title = if type(title) == "string" and title ~= "" then title else "Admin Event",
		startsAt = startsAt,
		endsAt = endsAt,
		running = read(names.running) == true,
		wheel = wheel,
		bowlSpeed = bowlSpeed,
		line = line,
		found = found,
		total = total,
	}
end

function AdminBarLogic.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

-- What the event does, in one line for the banner.
local function what(info: Info): string
	if info.line ~= nil then
		return info.line
	end
	return AdminBarLogic.line({ wheel = info.wheel, bowlSpeed = info.bowlSpeed }) or info.title
end

-- The timer's words while it runs: the title, and a Secret Hunt's "1/3".
local function pillLive(info: Info): string
	if info.total ~= nil then
		return ("%s %d/%d"):format(info.title, info.found or 0, info.total)
	end
	return info.title
end

-- `wheel` is PlayerState.adminWheel. Nil once the event is over.
function AdminBarLogic.view(info: Info?, now: number, wheel: Wheel?): View?
	if info == nil or now >= info.endsAt then
		return nil
	end
	if now < info.startsAt then
		local left = AdminBarLogic.clock(info.startsAt - now)
		return {
			phase = "soon",
			big = "ADMIN EVENT IN " .. left,
			sub = what(info),
			pill = info.title .. " in",
			time = left,
			spin = false,
			key = info.id .. ":soon",
		}
	end
	local canSpin = info.wheel and wheel ~= nil and wheel.eventId == info.id and not wheel.spun
	return {
		phase = "live",
		big = string.upper(info.title) .. " NOW!",
		sub = what(info),
		pill = pillLive(info),
		time = AdminBarLogic.clock(info.endsAt - now) .. " left",
		spin = canSpin,
		key = info.id .. ":live",
	}
end

-- The window's Spin button and the line under it. `spinning` while the wheel turns; `won` the prize's words once
-- it lands.
function AdminBarLogic.wheelView(
	wheel: Wheel?,
	now: number,
	spinning: boolean,
	won: string?
): WheelView
	if spinning then
		return { button = "Spinning...", enabled = false, line = "Good luck!" }
	end
	if won ~= nil then
		return { button = "Spun", enabled = false, line = "You won " .. won .. "!" }
	end
	if wheel == nil or now >= wheel.endsAt then
		return {
			button = "Closed",
			enabled = false,
			line = "The Admin Wheel is closed. Watch for the next update!",
		}
	end
	if wheel.spun then
		return {
			button = "Spun",
			enabled = false,
			line = "You have spun this wheel. See you at the next update!",
		}
	end
	return {
		button = "SPIN (free)",
		enabled = true,
		line = "Free for everyone online. Nothing to buy. Ends in "
			.. AdminBarLogic.clock(wheel.endsAt - now),
	}
end

return AdminBarLogic
