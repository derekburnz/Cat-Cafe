--!strict
-- Made-up station views for a Studio look check (Review-QA, #4103). init.luau reads them only while
-- RunService:IsStudio() and the Workspace attribute StationTest names a station, so a window can be opened before its
-- tier exists in the test place. Nothing here reaches the server: a press still goes out and the server refuses it.
--   "booth"     the Ticket Booth with 1,100 tickets, a rush running and three prizes short
--   "keep"      the Dragon Keep at Drake with two cards slotted
--   "keephand"  the same with a stage hand of three cards up
--   "fusion"     the Fusion Observatory with the dome free: six normal and five gold copies of this player's first
--                kind of cat, three of a second kind ("almost")
--   "fusionrun"  the same with a Gold fusion 6:42 from done
--   "fusiondone" the same with a Rainbow fusion waiting to be collected
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

-- Copies of the player's first two kinds of cat (by uid order, so the same each time), as Fusion's ready and almost
-- lists need five of one coat. Their uids start with "test_"; the server owns none of them.
local function fusionCats(cats: { [string]: any }?): ({ [string]: any }, string)
	local kinds: { string } = {}
	local uids: { string } = {}
	for uid in cats or {} do
		table.insert(uids, uid)
	end
	table.sort(uids)
	for _, uid in uids do
		local catId = (cats :: any)[uid].catId
		if type(catId) == "string" and not table.find(kinds, catId) then
			table.insert(kinds, catId)
		end
		if #kinds == 2 then
			break
		end
	end
	local first = kinds[1] or "tabby"
	local second = kinds[2] or first
	local out: { [string]: any } = {}
	local function add(
		prefix: string,
		catId: string,
		variant: string,
		count: number,
		levelFrom: number
	)
		for copy = 1, count do
			out["test_" .. prefix .. copy] = {
				catId = catId,
				variant = variant,
				level = levelFrom + copy * 3,
				xp = 0,
				charm = 50,
				trait = if copy == 2 then { id = "bigTipper_epic" } else nil,
			}
		end
	end
	add("base", first, "base", 6, 1)
	add("gold", first, "gold", 5, 10)
	if second ~= first then
		add("almost", second, "base", 3, 1)
	end
	return out, first
end

local function fusion(which: string, now: number, cats: { [string]: any }?): { [string]: any }
	local made, catId = fusionCats(cats)
	local view: { [string]: any } = {
		ready = false,
		goldSeconds = 600,
		rainbowSeconds = 3600,
		made = { gold = 2, rainbow = 0 },
	}
	if which == "fusionrun" then
		view.running = { catId = catId, coat = "gold", doneAt = now + 402, level = 12 }
	elseif which == "fusiondone" then
		view.running =
			{ catId = catId, coat = "rainbow", doneAt = now - 5, level = 34, name = "Mochi" }
		view.ready = true
	end
	return { fusion = view, cats = made }
end

-- The PlayerState fields to stand in for, and the station to open, or nil for "" or a name it doesn't know.
function StationFixtures.views(
	which: string,
	now: number,
	cats: { [string]: any }?
): ({ [string]: any }?, string?)
	if which == "booth" then
		return { ticketBooth = booth(now) }, "ticketBooth"
	elseif which == "keep" or which == "keephand" then
		return { dragon = keep(which == "keephand") }, "dragon"
	elseif which == "fusion" or which == "fusionrun" or which == "fusiondone" then
		return fusion(which, now, cats), "fusion"
	end
	return nil, nil
end

return StationFixtures
