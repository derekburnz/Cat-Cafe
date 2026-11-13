--!strict
-- What a roll board shows (#3611, part of #3608): the list that hovers over a station whose prize is rolled, one row
-- per prize with its pictures, name and chance. The Rummage Bin's board is here (RollBoardLogic.bin); the Yard Sale's
-- lucky pick (#3614) uses the same view and the same component (Components/RollBoard).
-- A view is a title, one line under it, the rows and, sometimes, a foot line:
--   the list      every prize with its chance ("What is inside? One prize each dig.")
--   one prize     the prize kept after a miss ("Waiting for you"), or the prize the bar is being played for
--                 ("Rummage for"): no chances, nothing is random. #3680: no fixed first prize is shown any more
--   empty         the list dimmed with "Fills in m:ss"
-- Pure, so the cloud test runner checks it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local RummageBin = require(Shared:WaitForChild("RummageBin"))
local ShopIcons = require(script.Parent.ShopIcons)

local RollBoardLogic = {}

export type RowView = {
	id: string,
	name: string,
	chance: string?, -- "28%"; nil where nothing is random
	images: { string }, -- the main picture, then a small second one (a food with its golden fish)
	glyph: string, -- drawn until the picture loads
	tier: number, -- 1 to 3: 2 a blue edge, 3 a gold edge and gold chance
}

export type View = {
	title: string,
	line: string,
	rows: { RowView },
	dim: boolean, -- the empty bin: every row faded
	foot: string?,
}

export type BinInput = {
	uses: number, -- wins so far (the Player's BinUses)
	prize: string?, -- the stored prize's row id (the Player's BinPrize)
	nextAt: number, -- the wait's end (the Player's BinNextAt)
	now: number,
	playing: string?, -- the row id the roll, the reveal or the bar is for, while one is up
	rolling: boolean?, -- the roll is passing over the list
}

RollBoardLogic.BIN_TITLE = "RUMMAGE BIN"
RollBoardLogic.BIN_LIST = "What is inside? One prize each dig."
RollBoardLogic.BIN_ROLLING = "Rolling..."
RollBoardLogic.BIN_WAITING = "Waiting for you"
RollBoardLogic.BIN_PLAYING = "Rummage for"

local FISH_GLYPH = "🐟"

function RollBoardLogic.percent(chance: number): string
	return string.format("%d%%", math.floor(chance * 100 + 0.5))
end

-- "4:05" for the wait left; never under 0:01 while it lasts.
function RollBoardLogic.clock(seconds: number): string
	local left = math.max(1, math.ceil(seconds))
	return string.format("%d:%02d", left // 60, left % 60)
end

local function goldenFish(): string?
	return ShopIcons.clean("Fish")
end

-- A bin row's pictures: its food, crate or potion, with the golden fish small beside it when it brings both; a row
-- of golden fish alone wears the fish.
function RollBoardLogic.binImages(row: RummageBin.Row): ({ string }, string)
	local images: { string } = {}
	local glyph = "🎁"
	if row.lure ~= nil then
		local lure = Catalog.getLure(row.lure)
		local key = if lure ~= nil then string.gsub(lure.name, "%s", "") else row.lure
		local image = ShopIcons.image(key)
		if image ~= nil then
			table.insert(images, image)
		end
		glyph = "🍽"
	elseif row.crate ~= nil then
		local image = ShopIcons.crate(row.crate)
		if image ~= nil then
			table.insert(images, image)
		end
		glyph = "📦"
	elseif row.potion ~= nil then
		local image = ShopIcons.potionAll(row.potion)[1]
		if image ~= nil then
			table.insert(images, image)
		end
		glyph = "🧪"
	end
	if row.fish ~= nil then
		local fish = goldenFish()
		if fish ~= nil then
			table.insert(images, fish)
		end
		if #images <= 1 and row.lure == nil and row.crate == nil and row.potion == nil then
			glyph = FISH_GLYPH
		end
	end
	return images, glyph
end

-- One bin row as the board draws it; `chance` false leaves the chance off.
function RollBoardLogic.binRow(row: RummageBin.Row, chance: boolean): RowView
	local images, glyph = RollBoardLogic.binImages(row)
	return {
		id = row.id,
		-- "2 Tuna + 3 golden fish": the board's rows are short
		name = (string.gsub(RummageBin.rowName(row), " and ", " + ")),
		chance = if chance then RollBoardLogic.percent(row.chance or 0) else nil,
		images = images,
		glyph = glyph,
		tier = RummageBin.tier(row),
	}
end

local function list(chance: boolean): { RowView }
	local rows: { RowView } = {}
	for _, row in RummageBin.rollRows() do
		table.insert(rows, RollBoardLogic.binRow(row, chance))
	end
	return rows
end

-- The Rummage Bin's board for this player right now.
function RollBoardLogic.bin(input: BinInput): View
	local title = RollBoardLogic.BIN_TITLE
	if input.playing ~= nil and input.rolling then
		return { title = title, line = RollBoardLogic.BIN_ROLLING, rows = list(true), dim = false }
	end
	local playing = RummageBin.rollRow(input.playing)
	if playing ~= nil then
		return {
			title = title,
			line = RollBoardLogic.BIN_PLAYING,
			rows = { RollBoardLogic.binRow(playing, false) },
			dim = false,
		}
	end
	if input.now < input.nextAt then
		return {
			title = title,
			line = "Fills in " .. RollBoardLogic.clock(input.nextAt - input.now),
			rows = list(true),
			dim = true,
		}
	end
	local waiting = RummageBin.rollRow(input.prize)
	if waiting ~= nil then
		return {
			title = title,
			line = RollBoardLogic.BIN_WAITING,
			rows = { RollBoardLogic.binRow(waiting, false) },
			dim = false,
		}
	end
	-- #3680: no fixed first prize any more: a new account's first rummage is rolled, so it sees the list too
	return { title = title, line = RollBoardLogic.BIN_LIST, rows = list(true), dim = false }
end

-- #3615: the Yard Sale's lucky pick. One row per crate this player can win (the server's own YardPick rows, sent in
-- CampExtrasState, so the chances shown are the chances rolled), chance to one decimal, golden crates with the gold
-- edge. The line says the pick is free and how often, or how long until the next one (rows dimmed).
export type YardRow = { crateId: string, chance: number, golden: boolean, tier: number }
export type YardInput = {
	rows: { YardRow },
	nextAt: number?, -- the next pick's time (server time); nil while one waits
	now: number,
	rolling: boolean?,
}

RollBoardLogic.YARD_TITLE = "LUCKY PICK"
RollBoardLogic.YARD_ROLLING = "Picking..."

-- "38.0%": one decimal, as the Yard Sale's board shows it.
function RollBoardLogic.percent1(chance: number): string
	return string.format("%.1f%%", math.floor(chance * 1000 + 0.5) / 10)
end

function RollBoardLogic.yardLine(): string
	local hours: number = Config.YardSaleRollHours
	return if hours == 1 then "Free every hour" else string.format("Free every %d hours", hours)
end

function RollBoardLogic.yardRow(row: YardRow): RowView
	local crate = Catalog.getCrate(row.crateId)
	local images: { string } = {}
	local image = ShopIcons.crate(row.crateId)
	if image ~= nil then
		table.insert(images, image)
	end
	return {
		id = row.crateId,
		name = if crate ~= nil then crate.name else row.crateId,
		chance = RollBoardLogic.percent1(row.chance),
		images = images,
		glyph = "📦",
		tier = if row.golden then 3 else 1,
	}
end

function RollBoardLogic.yard(input: YardInput): View
	local rows: { RowView } = {}
	for _, row in input.rows do
		table.insert(rows, RollBoardLogic.yardRow(row))
	end
	local title = RollBoardLogic.YARD_TITLE
	if input.rolling then
		return { title = title, line = RollBoardLogic.YARD_ROLLING, rows = rows, dim = false }
	end
	local nextAt = input.nextAt
	if nextAt ~= nil and input.now < nextAt then
		return {
			title = title,
			line = "Next pick in " .. RollBoardLogic.wait(nextAt - input.now),
			rows = rows,
			dim = true,
		}
	end
	return { title = title, line = RollBoardLogic.yardLine(), rows = rows, dim = false }
end

-- "1 h 20 m", "5 m": the wait in whole minutes, never under 1 m.
function RollBoardLogic.wait(seconds: number): string
	local minutes = math.max(1, math.ceil(seconds / 60))
	if minutes >= 60 then
		local hours, rest = minutes // 60, minutes % 60
		return if rest > 0
			then string.format("%d h %d m", hours, rest)
			else string.format("%d h", hours)
	end
	return string.format("%d m", minutes)
end

-- #3615: where `crateId` stands in a lucky pick's rows, or nil.
function RollBoardLogic.rowOf(rows: { any }, crateId: string): number?
	for index, row in rows do
		if row.crateId == crateId then
			return index
		end
	end
	return nil
end

-- The rows the pick's light passes, in order, with the seconds it rests on each: twice down the list from the top,
-- then on to `landing`, slowing evenly. It always moves one row at a time in list order and stops on the row the
-- server chose; it never slows near a golden row or steps back, so there is no near miss.
function RollBoardLogic.rollSteps(
	count: number,
	landing: number
): { { index: number, rest: number } }
	local steps: { { index: number, rest: number } } = {}
	if count <= 0 then
		return steps
	end
	local target = math.clamp(landing, 1, count)
	local total = count * 2 + target
	for step = 1, total do
		local share = if total > 1 then (step - 1) / (total - 1) else 1
		table.insert(steps, { index = (step - 1) % count + 1, rest = 0.05 + 0.2 * share * share })
	end
	return steps
end

-- #3683: how far up the board sits over its point, as BillboardGui.SizeOffset.Y (0.5: its bottom edge on the point,
-- the usual place). When its top would reach into the strip the HUD's day clock holds (`clearBelow`, viewport px
-- from the top; nil when no clock shows) and the two overlap side to side, the board comes down just enough to
-- clear it, at most LOWER_MOST of its own height, so the clock never sits on the title.
--   pointX, pointY  the point over the bin on screen (viewport px)
--   width, height   the board's size on screen (px)
--   clockLeft, clockRight  the clock's edges (viewport px)
RollBoardLogic.LOWER_MOST = 0.6
function RollBoardLogic.sizeOffsetY(
	pointX: number,
	pointY: number,
	width: number,
	height: number,
	clearBelow: number?,
	clockLeft: number?,
	clockRight: number?
): number
	if clearBelow == nil or height <= 0 then
		return 0.5
	end
	if clockLeft ~= nil and clockRight ~= nil then
		if pointX + width / 2 < clockLeft or pointX - width / 2 > clockRight then
			return 0.5
		end
	end
	local over = clearBelow - (pointY - height)
	if over <= 0 then
		return 0.5
	end
	return 0.5 - math.min(over / height, RollBoardLogic.LOWER_MOST)
end

return RollBoardLogic
