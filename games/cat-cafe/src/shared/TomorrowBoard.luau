--!strict
-- #5449 (Design-Agent's d1-hooks-spec of 2026-11-18, hook 3; Derek 2026-11-18 17:00 UTC: "make the daily login
-- rewards more obvious"): the Daily Treat Board on the cafe wall, behind the `tomorrowBoard` switch (off by default).
-- The owner's client puts Model-Agent's CatCafe_Prop_TreatBoard on the plot's TreatBoardAnchor and the wrapped
-- CatCafe_Prop_TomorrowGift on TomorrowGiftAnchor, for the owner only. Each claimed day's red paw stamp shows
-- (_Stamp1 to _Stamp7), and day 2's gold edge (_Glow) lights while day 2 is tomorrow. Tapping the board or the gift
-- opens a card that names tomorrow's prize, with Roblox's notification opt-in (Remind me) when Roblox will prompt.
-- The card only opens on a tap, once a session at most. On a new account's first session the board waits until
-- MIN_PLAYED seconds of play (the quiet start). Shown, it replaces the come back tomorrow card (#3951). No new save
-- field: everything comes from the Daily Treat view the client already has. Day 2's 500 golden fish is the bigTreats
-- row (Catalog.DAILY_TREAT_BIG), earned only, never random and never for Robux (monetization-policy).
-- Pure, so the specs load it.

local Catalog = require(script.Parent.Catalog)
local ShortNumber = require(script.Parent.ShortNumber)
local Types = require(script.Parent.Types)

local TomorrowBoard = {}

TomorrowBoard.FLAG = "tomorrowBoard"
TomorrowBoard.BOARD_ASSET = "CatCafe_Prop_TreatBoard"
TomorrowBoard.GIFT_ASSET = "CatCafe_Prop_TomorrowGift"
TomorrowBoard.BOARD_ANCHOR = "TreatBoardAnchor"
TomorrowBoard.GIFT_ANCHOR = "TomorrowGiftAnchor"
TomorrowBoard.STAMP_PREFIX = "CatCafe_Prop_TreatBoard_Stamp"
TomorrowBoard.GLOW = "CatCafe_Prop_TreatBoard_Glow"
TomorrowBoard.GLOW_DAY = 2 -- the gold edge is day 2's (the 500 golden fish)
TomorrowBoard.MIN_PLAYED = 240 -- seconds into a new account's first session before the board shows (spec: minute 4)
TomorrowBoard.DAY_SECONDS = 86400
-- tomorrow_board report's values: tap (the board or the gift opened the card), remind (Remind me opened Roblox's
-- prompt), ok, closed (the X)
TomorrowBoard.OUTCOMES = table.freeze({ "tap", "remind", "ok", "closed" }) :: { string }
TomorrowBoard.PROMPT_TEXT = "Daily Treat"
TomorrowBoard.REMIND = "Remind me"
TomorrowBoard.OK = "OK!"

-- Whether the board stands in the cafe: the switch on and, on the account's first UTC day (`firstDay`, QuietStart's
-- day number), MIN_PLAYED seconds into this session.
function TomorrowBoard.shows(on: boolean, firstDay: unknown, now: number, played: number): boolean
	if not on then
		return false
	end
	local first = type(firstDay) == "number"
		and firstDay > 0
		and math.floor(now / TomorrowBoard.DAY_SECONDS) == firstDay
	return not first or played >= TomorrowBoard.MIN_PLAYED
end

-- How many paw stamps the board shows: the card's stamps (0 to 7).
function TomorrowBoard.stamps(view: Types.DailyTreatView?): number
	if view == nil then
		return 0
	end
	return math.clamp(math.floor(view.stamp), 0, #Catalog.dailyTreat)
end

-- The day the next stamp pays when it is tomorrow's (today's is claimed), else nil (a stamp is due now).
function TomorrowBoard.tomorrow(view: Types.DailyTreatView?): number?
	if view == nil or view.due then
		return nil
	end
	return view.nextDay
end

-- Whether day 2's gold edge is lit: day 2 is tomorrow.
function TomorrowBoard.glows(view: Types.DailyTreatView?): boolean
	return TomorrowBoard.tomorrow(view) == TomorrowBoard.GLOW_DAY
end

-- A prize in words, biggest first: "500 Golden Fish", "3 golden crates", "$5K", "5 free spins".
local function prizeWords(prize: Types.IndexPrize): { string }
	local out: { string } = {}
	local p = prize :: any
	if type(p.fish) == "number" and p.fish > 0 then
		table.insert(out, ShortNumber.format(p.fish) .. " Golden Fish")
	end
	if type(p.crates) == "table" then
		local count = 0
		local golden = false
		for id, n in p.crates do
			if type(n) == "number" then
				count += n
				golden = golden or string.find(tostring(id), "golden", 1, true) ~= nil
			end
		end
		if count > 0 then
			local kind = if golden then "golden crate" else "crate"
			table.insert(
				out,
				if count == 1 then "a " .. kind else tostring(count) .. " " .. kind .. "s"
			)
		end
	end
	if type(p.traitTokens) == "number" and p.traitTokens > 0 then
		table.insert(out, tostring(p.traitTokens) .. " Trait Tokens")
	end
	if type(p.coins) == "number" and p.coins > 0 then
		table.insert(out, "coins")
	end
	if type(p.spins) == "number" and p.spins > 0 then
		table.insert(
			out,
			if p.spins == 1 then "a free spin" else tostring(p.spins) .. " free spins"
		)
	end
	return out
end

-- The card's title: what the next stamp pays, "Tomorrow: 500 Golden Fish and 5 free spins!" (today's claimed), or
-- "Today: ..." while a stamp is due. `gift` adds the welcome back golden crate (a first-day player's ReturnGift).
function TomorrowBoard.title(view: Types.DailyTreatView?, gift: boolean): string
	local day = if view ~= nil then view.nextDay else 1
	local row = Catalog.dailyTreat[day] or Catalog.dailyTreat[1]
	local words = prizeWords(row.prize)
	if gift and TomorrowBoard.tomorrow(view) ~= nil then
		table.insert(words, 2, "a golden crate")
	end
	while #words > 2 do
		table.remove(words) -- two things fit a phone's card title
	end
	local text = table.concat(words, " and ")
	local when = if TomorrowBoard.tomorrow(view) ~= nil then "Tomorrow" else "Today"
	return when .. ": " .. (if text ~= "" then text else "a treat") .. "!"
end

-- The card's line under the title: which day of the seven it is.
function TomorrowBoard.line(view: Types.DailyTreatView?): string
	local day = if view ~= nil then view.nextDay else 1
	if TomorrowBoard.tomorrow(view) ~= nil then
		return string.format("Day %d of your Daily Treat. Come back tomorrow to claim it.", day)
	end
	return string.format("Day %d of your Daily Treat is ready. Tap the Daily Treat button.", day)
end

return TomorrowBoard
