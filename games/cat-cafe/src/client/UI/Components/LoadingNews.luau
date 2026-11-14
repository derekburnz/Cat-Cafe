--!strict
-- #4314 (Derek 2026-11-14: "can feature some of the new updates on the loading screen also"): the WHAT'S NEW card on
-- the cute loading screen (Screens/Intro) turns through these, one every LoadingNews.SECONDS. Each has a title, one
-- line, a picture (up to three tiles with an emoji and a word each, or `secret`: dark cat shapes only, never a Secret
-- cat's look, the dark-shape rule) and `at`, the server time it opens (nil: out already). whenText says when.
-- Pure, so the cloud spec runner checks it. Edit the list with each update.

local LoadingNews = {}

export type Tile = { emoji: string, word: string, color: string }
export type Entry = {
	key: string,
	title: string,
	line: string,
	at: number?, -- os.time() it opens; nil: out now
	back: string, -- the picture's backing colour (hex)
	tiles: { Tile }?,
	secret: boolean?,
}

LoadingNews.SECONDS = 3.2 -- per card
LoadingNews.ET_OFFSET = -5 * 3600 -- Eastern Standard Time (no daylight saving from 2026-11-01 to 2027-03-14)

LoadingNews.ENTRIES = {
	{
		key = "worlds",
		title = "3 New Worlds",
		line = "Snowy, Water Park and Castle",
		at = 1794772800, -- Sunday 2026-11-15 20:00 UTC
		back = "BFE6FF",
		tiles = {
			{ emoji = "❄️", word = "Snowy", color = "EAF6FF" },
			{ emoji = "🌊", word = "Water Park", color = "7FD3F2" },
			{ emoji = "🏰", word = "Castle", color = "C9B8F0" },
		},
	},
	{
		key = "rift",
		title = "Rift Run",
		line = "Roll a Mythic or Secret trait and the rift opens!",
		at = 1794704400, -- Sunday 2026-11-15 01:00 UTC
		back = "3B2E63",
		tiles = { { emoji = "🌀", word = "Rift Run", color = "8E6BE8" } },
	},
	{
		key = "outfits",
		title = "Outfit Packs",
		line = "Winter, Stylish, Chef and Space looks in the Store",
		back = "FFD9E6",
		tiles = {
			{ emoji = "🧣", word = "Winter", color = "EAF6FF" },
			{ emoji = "🍳", word = "Chef", color = "FFF4D6" },
			{ emoji = "🚀", word = "Space", color = "D9D2FF" },
		},
	},
	{
		key = "secret",
		title = "10 Secret Cats",
		line = "Hidden in every area. Can you find them?",
		at = 1794799800, -- Monday 2026-11-16 03:30 UTC (Sunday 10:30 PM ET)
		back = "3A2F4A",
		secret = true,
	},
} :: { Entry }

local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

-- "Out now!" once open (or with no time), else "Sunday 3 PM ET" or "Sunday 10:30 PM ET"
function LoadingNews.whenText(at: number?, now: number): string
	if at == nil or now >= at then
		return "Out now!"
	end
	local t = os.date("!*t", at + LoadingNews.ET_OFFSET) :: any
	local hour: number = t.hour
	local half = if hour >= 12 then "PM" else "AM"
	local twelve = if hour % 12 == 0 then 12 else hour % 12
	local minute: number = t.min
	local wday: number = t.wday
	local clock = if minute == 0 then tostring(twelve) else ("%d:%02d"):format(twelve, minute)
	return ("%s %s %s ET"):format(DAYS[wday], clock, half)
end

-- the entry shown `seconds` after the screen came up, and its index
function LoadingNews.pick(seconds: number): (Entry, number)
	local count = #LoadingNews.ENTRIES
	local index = math.floor(math.max(seconds, 0) / LoadingNews.SECONDS) % count + 1
	return LoadingNews.ENTRIES[index], index
end

-- the tip under the count, for the device in hand
function LoadingNews.tip(input: string): string
	if input == "touch" then
		return "Tip: stand by a cat and tap CATCH!"
	elseif input == "gamepad" then
		return "Tip: stand by a cat and hold X!"
	end
	return "Tip: stand by a cat and hold E!"
end

return LoadingNews
