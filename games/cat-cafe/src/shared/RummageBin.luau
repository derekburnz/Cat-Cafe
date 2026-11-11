--!strict
-- The Rummage Bin (#3050, Derek2 2026-11-10: "rummage bin but not money make the rewards like rare or better food
-- some gold fish some crates etc make it often also like every 15 minutes or smth"): a bin at the Alleyway camp. One
-- press plays a short bar, the rescue bar on the rescue remotes under the spot id RummageBin.SPOT; a win pulls one
-- prize out and starts the wait, a miss costs nothing and is tried again BinMissRetrySeconds later.
--
-- Pure: `now` is os.time() and rolls are passed in. The save is { nextAt, uses } (save version 48): `nextAt` the
-- os.time() the bin is full again (0 on a new save, so it is ready at once), `uses` the wins so far. The wait runs
-- offline too and nothing banks: one rummage waits at most. The account's first BinFirstUses rummages are easier
-- (BinFirstEase on top of the Alleyway's own ease) and the wait after each but the last of them is
-- BinFirstRepeatSeconds; every later wait is BinCooldownSeconds. The first win is always BinFirstPrizes[1] (Tuna,
-- which points at the bowl), the second BinFirstPrizes[2] (an Alley Crate, which points at the Market); after that
-- each win is a roll of BinTable, whose chances add to 1 and show on the bin's prompt before the press
-- (monetization-policy section 2; nothing here is sold or sped up, and no timer shows: Monetization-Agent 11-10).

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Rescue = require(script.Parent.Rescue)
local Types = require(script.Parent.Types)

local RummageBin = {}

RummageBin.SPOT = "bin_alley" -- its bar's id on RescueBegin, RescuePress, RescueCancel, RescueChallenge, RescueResult
RummageBin.AREA = "alley"
RummageBin.TAG = "RummageBin" -- the placed model (WorldBuilder)
RummageBin.PROMPT = "RummagePrompt"
RummageBin.FLAG = "alleyBin" -- LiveFlags: off hides the prompt; saves keep their fields
RummageBin.NEXT_AT_ATTRIBUTE = "BinNextAt" -- on the Player: the wait's nextAt, for the prompt's words and the look
RummageBin.NAME = "Rummage Bin"
RummageBin.ACTION = "Rummage"
RummageBin.EMPTY = "Empty for now 🐾" -- no countdown (Monetization-Agent 11-10)
RummageBin.TRAP = "rummage_bin" -- the challenge's trap type: a plain bar
RummageBin.RANGE_STUDS = 10 -- the prompt's reach; the server allows a little past it
local RARITY: Types.Rarity = "Common"
RummageBin.RARITY = RARITY -- the bar's pace

export type Row = {
	id: string,
	chance: number,
	lure: string?,
	fish: number?,
	crate: string?,
	potion: string?,
}

function RummageBin.fresh(): Types.RummageBinSave
	return { nextAt = 0, uses = 0 }
end

-- A saved value made whole at `now`: whole numbers, no wait longer than one cooldown from now (a damaged or
-- future-dated save would otherwise keep the bin shut until real time caught up).
function RummageBin.sanitize(raw: unknown, now: number): Types.RummageBinSave
	local save = RummageBin.fresh()
	if type(raw) ~= "table" then
		return save
	end
	local value = raw :: any
	local function whole(x: unknown, high: number): number
		if type(x) == "number" and x == x and x > 0 then
			return math.min(math.floor(x), high)
		end
		return 0
	end
	save.nextAt = whole(value.nextAt, now + Config.BinCooldownSeconds)
	save.uses = whole(value.uses, 2 ^ 31)
	return save
end

function RummageBin.ready(save: Types.RummageBinSave, now: number): boolean
	return now >= save.nextAt
end

-- Whether the next rummage is one of the account's easy first ones.
function RummageBin.early(save: Types.RummageBinSave): boolean
	return save.uses < Config.BinFirstUses
end

local function rowById(id: string): Row?
	for _, row in Config.BinTable :: { Row } do
		if row.id == id then
			return row
		end
	end
	return nil
end

-- The BinTable row a win brings after `uses` earlier wins, for a roll in [0, 1).
function RummageBin.rowFor(uses: number, roll: number): Row
	local first = Config.BinFirstPrizes[uses + 1]
	local fixed = if first ~= nil then rowById(first) else nil
	if fixed ~= nil then
		return fixed
	end
	local rows = Config.BinTable :: { Row }
	local total = 0
	for _, row in rows do
		total += row.chance
		if roll < total then
			return row
		end
	end
	return rows[#rows]
end

function RummageBin.prize(row: Row): Types.IndexPrize
	local prize: Types.IndexPrize = {}
	if row.lure ~= nil then
		prize.lures = { [row.lure] = 1 }
	end
	if row.fish ~= nil then
		prize.fish = row.fish
	end
	if row.crate ~= nil then
		prize.crates = { [row.crate] = 1 }
	end
	if row.potion ~= nil then
		prize.potions = { [row.potion] = 1 }
	end
	return prize
end

-- A win at `now`: counts it, starts the wait and returns the row it brought.
function RummageBin.win(save: Types.RummageBinSave, now: number, roll: number): Row
	local row = RummageBin.rowFor(save.uses, roll)
	save.uses += 1
	save.nextAt = now
		+ (
			if save.uses < Config.BinFirstUses
				then Config.BinFirstRepeatSeconds
				else Config.BinCooldownSeconds
		)
	return row
end

-- The bar: a Common rescue bar with the Alleyway's fewer hits (2 hits, RescuePatience paws), its zone BinZoneWidth
-- and its marker BinBarSpeed in absolute numbers (whatever the rescue bars' widths and speeds are), and for an early
-- rummage BinFirstEase's wider zones and slower marker on top.
function RummageBin.challenge(
	early: boolean,
	now: number,
	roll: () -> number
): Types.RescueChallenge
	local ease = if early then Config.BinFirstEase else nil
	local area = Config.RescueAreaEase[RummageBin.AREA]
	-- newChallenge multiplies the rescue numbers by these scales, so they are the target over what it starts from
	local zone = Config.BinZoneWidth * (if ease ~= nil then ease.zone else 1)
	local speed = Config.BinBarSpeed * (if ease ~= nil then ease.speed else 1)
	local zoneFrom = Config.RescueZoneWidth[RARITY] * (if area ~= nil then area.zone else 1)
	local speedFrom = Config.RescueBarSpeed[RARITY] * (if area ~= nil then area.speed else 1)
	return Rescue.newChallenge(
		RARITY,
		RummageBin.TRAP,
		now,
		roll,
		zone / zoneFrom,
		RummageBin.AREA,
		speed / speedFrom
	)
end

-- A fresh attempt on that bar (Rescue.pressBar judges its presses).
function RummageBin.attempt(challenge: Types.RescueChallenge): Rescue.Attempt
	return Rescue.newAttempt(challenge, RARITY)
end

-- What a row is called: "Tuna", "5 golden fish", "Alley Crate", "Lucky Potion".
function RummageBin.rowName(row: Row): string
	if row.lure ~= nil then
		local lure = Catalog.getLure(row.lure)
		return if lure ~= nil then lure.name else row.lure
	elseif row.fish ~= nil then
		return string.format("%d golden fish", row.fish)
	elseif row.crate ~= nil then
		local crate = Catalog.getCrate(row.crate)
		return if crate ~= nil then crate.name else row.crate
	elseif row.potion ~= nil then
		local potion = Catalog.getPotion(row.potion)
		return if potion ~= nil then potion.name else row.potion
	end
	return row.id
end

local function percent(chance: number): string
	return string.format("%d%%", math.floor(chance * 100 + 0.5))
end

-- The chances for the prompt's note, in the table's order over two lines so they fit a phone:
-- "Tuna 40%  ·  5 golden fish 25%  ·  Salmon 12%" then the rest.
function RummageBin.oddsLine(): string
	local rows = Config.BinTable :: { Row }
	local half = math.ceil(#rows / 2)
	local lines: { string } = {}
	for from = 1, #rows, half do
		local parts: { string } = {}
		for index = from, math.min(from + half - 1, #rows) do
			local row = rows[index]
			table.insert(
				parts,
				string.format("%s %s", RummageBin.rowName(row), percent(row.chance))
			)
		end
		table.insert(lines, table.concat(parts, "  ·  "))
	end
	return table.concat(lines, "\n")
end

-- The bar's closing words for a win of row `id` (`first`: the account's first win): the title and the line under it.
function RummageBin.winWords(id: string, first: boolean): (string, string)
	local row = rowById(id)
	if row == nil then
		return "Found something!", ""
	end
	local title = RummageBin.rowName(row) .. "!"
	if row.lure ~= nil then
		local lure = Catalog.getLure(row.lure)
		local rarity = if lure ~= nil then lure.rarity else "Rare"
		return title,
			if first
				then string.format("%s food! Put it in your bowl 🐾", rarity)
				else "Food for your bowl"
	elseif row.crate ~= nil then
		return title, "Open it at the Golden Fish Market"
	elseif row.potion ~= nil then
		return title, "It's in your Bag"
	end
	return title, ""
end

return RummageBin
