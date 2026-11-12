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

return RollBoardLogic
