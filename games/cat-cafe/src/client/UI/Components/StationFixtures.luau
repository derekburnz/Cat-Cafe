--!strict
-- Made-up station views for a Studio look check (Review-QA, #4103). init.luau reads them only while
-- RunService:IsStudio() and the Workspace attribute StationTest names a station, so a window can be opened before its
-- tier exists in the test place. Nothing here reaches the server: a press still goes out and the server refuses it.
--   "booth"     the Ticket Booth with 1,100 tickets, a rush running and three prizes short
--   "keep"      the Dragon Keep at Drake with two cards slotted
--   "keephand"  the same with a stage hand of three cards up
local StationFixtures = {}

local function prize(
	id: string,
	name: string,
	line: string,
	price: number,
	left: number?,
	per: string?,
	blocker: string?
): { [string]: any }
	return {
		id = id,
		name = name,
		line = line,
		price = price,
		left = left,
		per = per,
		blocker = blocker,
	}
end

local function booth(now: number): { [string]: any }
	local short = "Not enough tickets yet"
	return {
		tickets = 1100,
		spent = 0,
		rushEndsAt = now + 1800,
		rushUsedToday = true,
		weekEndsAt = now + 3 * 86400,
		ready = 3,
		prizes = {
			prize("fish25", "25 golden fish", "25 golden fish", 300, 4, "day"),
			prize("traitToken", "Trait Token", "One Mystic Pool roll", 700, 3, "week"),
			prize("goldenCrate", "Golden Crate", "A golden Cafe Crate", 900, 2, "day"),
			prize("bigGoldRush", "Big Gold Rush Potion", "30 minutes", 1200, nil, nil, short),
			prize("bigLucky", "Big Lucky Potion", "30 minutes", 1200, nil, nil, short),
			prize("swiftPaws", "Swift Paws", "1 hour of Big Swift Potion", 800, nil, nil),
		},
	}
end

local function keep(hand: boolean): { [string]: any }
	return {
		warmth = 1480,
		stage = 3,
		stageName = "Drake",
		nextAt = 2500,
		slots = { "warmTips", "sharpEye", "" },
		binder = { warmTips = true, sharpEye = true, emberTips = true },
		hand = if hand then { "warmTips", "emberTips", "sharpEye" } else {},
		handKind = if hand then "stage" else nil,
		hands = if hand then 1 else 0,
		colour = "ruby",
		sets = {},
		napping = false,
		kept = 312,
		odds = { Common = 45, Rare = 30, Epic = 15, Legendary = 8, Mythic = 2 },
	}
end

-- The PlayerState fields to stand in for, and the station to open, or nil for "" or a name it doesn't know.
function StationFixtures.views(which: string, now: number): ({ [string]: any }?, string?)
	if which == "booth" then
		return { ticketBooth = booth(now) }, "ticketBooth"
	elseif which == "keep" or which == "keephand" then
		return { dragon = keep(which == "keephand") }, "dragon"
	end
	return nil, nil
end

return StationFixtures
