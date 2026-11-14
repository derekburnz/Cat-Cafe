--!strict
-- #4195 (Derek 2026-11-14, admin events on update days): the words of the admin event's warning banner, HUD timer and
-- Admin Wheel window. Pure, so the spec can check them. The server publishes the admin event (running, or within
-- CafeEvents.ADMIN.warnSeconds of its start) as ReplicatedStorage attributes (CafeEvents.ADMIN_ATTRIBUTES); the
-- client reads them into an Info (Controllers/AdminEventController) and PlayerState.adminWheel says whether this
-- account may still spin.
--   BANNER_SECONDS                     how long the big banner stays at the warning and at the start
--   info(read) -> Info?                the attributes as one table (nil with no admin event shown)
--   clock(seconds) -> string           "2:00", "0:09"
--   view(info?, now, wheel?) -> View?  what the banner and the timer say now
--   wheelView(wheel?, now) -> WheelView  the window's Spin button and line
--   SLICES                             each wheel slice's short words and colour, in AdminWheel.PRIZES order

local AdminEventLogic = {}

AdminEventLogic.BANNER_SECONDS = 8

export type Info = {
	id: string,
	title: string,
	startsAt: number,
	endsAt: number,
	running: boolean,
	wheel: boolean,
	bowlSpeed: number?,
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
AdminEventLogic.SLICES = table.freeze({
	{ short = "20 rerolls", color = Color3.fromHex("FFC94D") },
	{ short = "200 fish", color = Color3.fromHex("5CC8FF") },
	{ short = "5 crates", color = Color3.fromHex("F2679E") },
	{ short = "Potions", color = Color3.fromHex("8FD3C1") },
	{ short = "3x money", color = Color3.fromHex("7BE85A") },
	{ short = "Mythical", color = Color3.fromHex("7A3FC4") },
	{ short = "50 + 500", color = Color3.fromHex("E07A3A") },
	{ short = "Secret", color = Color3.fromHex("1E1430") },
})

-- `read(name)` gives one attribute (ReplicatedStorage:GetAttribute). `names` is CafeEvents.ADMIN_ATTRIBUTES.
function AdminEventLogic.info(
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
	local wheel, bowlSpeed = false, nil
	local raw = read(names.effects)
	if type(raw) == "string" and raw ~= "" then
		local ok, effects = pcall(decode, raw)
		if ok and type(effects) == "table" then
			local data = effects :: { [string]: any }
			wheel = data.wheel == true
			if type(data.bowlSpeed) == "number" and data.bowlSpeed > 1 then
				bowlSpeed = data.bowlSpeed
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
	}
end

function AdminEventLogic.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

-- What the event does, in one line for the banner.
local function what(info: Info): string
	if info.wheel then
		return "One free spin on the Admin Wheel for everyone"
	end
	if info.bowlSpeed ~= nil then
		return ("Bait bowls bring cats %dx faster"):format(math.floor(info.bowlSpeed))
	end
	return info.title
end

-- `wheel` is PlayerState.adminWheel. Nil once the event is over.
function AdminEventLogic.view(info: Info?, now: number, wheel: Wheel?): View?
	if info == nil or now >= info.endsAt then
		return nil
	end
	if now < info.startsAt then
		local left = AdminEventLogic.clock(info.startsAt - now)
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
		pill = info.title,
		time = AdminEventLogic.clock(info.endsAt - now) .. " left",
		spin = canSpin,
		key = info.id .. ":live",
	}
end

-- The window's Spin button and the line under it. `spinning` while the wheel turns; `won` the prize's words once
-- it lands.
function AdminEventLogic.wheelView(
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
			.. AdminEventLogic.clock(wheel.endsAt - now),
	}
end

return AdminEventLogic
