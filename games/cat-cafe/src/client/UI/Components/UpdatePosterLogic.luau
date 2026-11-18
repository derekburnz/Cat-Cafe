--!strict
-- The update poster's words (#4362): what the Town Square poster stand shows for the next update on
-- Config.UpdateEvents. Pure, so the cloud specs check it.
--   next(list, now) -> Entry?        the listed Event that starts first of those not started yet (no quiet time after
--                                    an update, unlike EventRsvp.next: a poster can always show what is next)
--   name(entry) -> string            its short name ("3 NEW WORLDS"), or NEW_UPDATE when the entry has none
--   countdown(startsAt, now) -> string   "Starts in 2 days", "Starts in 18 h 22 min", "Starts in 12 min",
--                                    "Starts in under a minute"
--   live(list, now) -> Entry?        an update that is out now: started, with a liveUntil still ahead (Derek
--                                    2026-11-18: "update the ingame sign to show this update"); the latest started
--   view(list, now) -> View?         all of it, nil when nothing is listed ahead (the stand then shows SOON); an
--                                    update out now wins over the next one, with LIVE_HEADER and LIVE_LINE
local UpdatePosterLogic = {}

UpdatePosterLogic.HEADER = "NEXT UPDATE"
UpdatePosterLogic.NEW_UPDATE = "NEW UPDATE"
UpdatePosterLogic.SOON = "More updates soon!"
UpdatePosterLogic.ACTION = "Notify Me"
UpdatePosterLogic.HINT = "🔔 Walk up for a reminder"
UpdatePosterLogic.LIVE_HEADER = "✨ OUT NOW"
UpdatePosterLogic.LIVE_LINE = "New in the game today!"

export type Entry = {
	id: string,
	startsAt: number,
	name: string?,
	poster: string?,
	liveUntil: number?,
}
export type View = {
	id: string,
	name: string,
	poster: string?,
	countdown: string,
	live: boolean?, -- out now: no countdown and no Notify Me
}

local function valid(entry: unknown): boolean
	if type(entry) ~= "table" then
		return false
	end
	local e = entry :: any
	return type(e.id) == "string"
		and string.match(e.id, "^%d+$") ~= nil
		and type(e.startsAt) == "number"
end

function UpdatePosterLogic.next(list: unknown, now: number): Entry?
	if type(list) ~= "table" then
		return nil
	end
	local best: Entry? = nil
	for _, entry in list :: { any } do
		if valid(entry) and now < entry.startsAt then
			if best == nil or entry.startsAt < best.startsAt then
				best = entry
			end
		end
	end
	return best
end

function UpdatePosterLogic.name(entry: Entry): string
	local name = entry.name
	return if type(name) == "string" and name ~= "" then name else UpdatePosterLogic.NEW_UPDATE
end

function UpdatePosterLogic.countdown(startsAt: number, now: number): string
	local left = math.max(0, math.floor(startsAt - now))
	if left < 60 then
		return "Starts in under a minute"
	end
	local minutes = left // 60
	if minutes < 60 then
		return ("Starts in %d min"):format(minutes)
	end
	local hours = minutes // 60
	if hours < 48 then
		return ("Starts in %d h %d min"):format(hours, minutes % 60)
	end
	return ("Starts in %d days"):format(hours // 24)
end

function UpdatePosterLogic.live(list: unknown, now: number): Entry?
	if type(list) ~= "table" then
		return nil
	end
	local best: Entry? = nil
	for _, entry in list :: { any } do
		local untilAt = if valid(entry) then entry.liveUntil else nil
		if type(untilAt) == "number" and entry.startsAt <= now and now < untilAt then
			if best == nil or entry.startsAt > best.startsAt then
				best = entry
			end
		end
	end
	return best
end

function UpdatePosterLogic.view(list: unknown, now: number): View?
	local out = UpdatePosterLogic.live(list, now)
	if out ~= nil then
		local picture = out.poster
		return {
			id = out.id,
			name = UpdatePosterLogic.name(out),
			poster = if type(picture) == "string" and picture ~= "" then picture else nil,
			countdown = UpdatePosterLogic.LIVE_LINE,
			live = true,
		}
	end
	local entry = UpdatePosterLogic.next(list, now)
	if entry == nil then
		return nil
	end
	local poster = entry.poster
	return {
		id = entry.id,
		name = UpdatePosterLogic.name(entry),
		poster = if type(poster) == "string" and poster ~= "" then poster else nil,
		countdown = UpdatePosterLogic.countdown(entry.startsAt, now),
	}
end

return UpdatePosterLogic
