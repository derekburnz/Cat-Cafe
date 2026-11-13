--!strict
-- Mouse Dash on the UI (#3296, mouse-dash.md section 5). Pure, so the cloud spec runner checks it. The rules and
-- every judgement are the server's (shared/MouseDash, MouseDashService); this lays the board out and words the card:
--   layout(width, height)    where the nine holes and the hearts, score and best go on a board of that size. The
--                            score strip is on the left on a wide board and on top on a tall one, always HUD_GAP clear
--                            of the holes (Derek, 2026-11-11: the corner symbol was "too close to the possible spawn
--                            and distracting"), and each hole is as big as fits, MIN_HOLE (64 px) or more where the
--                            board allows
--   holeAt(layout, hole)     a hole's top left corner; holes are numbered row by row from the top left
--   keyHole(keyName)         Q W E / A S D / Z X C to holes 1 to 9
--   stickHole(x, y)          the gamepad's left stick to a hole; resting is the centre
--   records(state)           "Best 37 · Arcade Legend · Mouser"
--   lastLine(result)         "Score 12 · Best 37", with "New best!" and how it ended
--   endWords(result)         the board's last word: "You win!", "Nice try!"
--   prizeRows(today)         the arcade's ten prizes with today's ticks (shared with Circle Streak)
--   nextRow(points, today)   that row itself, nil once every prize is earned (#3553: the top banner while playing)
--   bannerWords(row)         "Salmon at 30", or ALL_EARNED for nil
--   progress(points, row)    how full the banner's bar is (0 to 1) and its "24/30"
--   prizePicture(prize)      a prize's uploaded picture and the glyph that stands in until it loads
--   timeLeft(endsAt, now)    the run's clock, "1:32", and whether it is nearly out
--   freeLine(state)          "1 free play today" or "Come back tomorrow for a free play"
--   FACES                    the stand-in faces, shown only until the picture sheet has loaded
--   SHEET, CELLS, ART        the uploaded picture sheet (assets/cat-cafe/exports/icons/CatCafe_Sheet_Arcade_MouseDash),
--                            its 256 px cells by name, and each kind's picture up and hit
--   BACKDROP                 the cellar floor behind the holes

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arcade = require(Shared:WaitForChild("Arcade")) :: any
local MouseDash = require(Shared:WaitForChild("MouseDash")) :: any

local ShopIcons = require(script.Parent.ShopIcons)

local MouseDashLogic = {}

MouseDashLogic.WINDOW = "MouseDash"
MouseDashLogic.MIN_HOLE = 64
MouseDashLogic.HOLE_GAP = 8
MouseDashLogic.HUD_GAP = 24 -- clear space between the score strip and the nearest hole
MouseDashLogic.HUD_SIDE = 104 -- the strip's width on the left of a wide board
MouseDashLogic.HUD_TOP = 44 -- its height on top of a tall board
MouseDashLogic.MAX_HOLE = 132
-- #3553: the next prize's banner. On a tall board it is a row between the strip and the holes, on a wide one a block
-- in the strip's column under the best (picture and bar only where the column is short).
MouseDashLogic.BANNER_ROW = 40
MouseDashLogic.BANNER_GAP = 6
MouseDashLogic.BANNER_FROM = 106 -- where the column's block starts, under hearts, score and best
MouseDashLogic.BANNER_FULL = 110 -- the block's height with its words
MouseDashLogic.BANNER_SMALL = 64 -- picture and bar only
MouseDashLogic.GIFT = "rbxassetid://95020228483506" -- Model-Agent's gift, for the Prizes button (#3553)
MouseDashLogic.RULE_LINE = "Bop the mice, +1 each and +3 for a golden one. Let sleeping kittens nap. "
	.. "Three hearts: a mouse that gets away, a woken kitten or a tap on an empty hole costs one. "
	.. "Three minutes a game. Your first game each day is free, and each prize pays once a day."
MouseDashLogic.FASTER = "Faster!"
MouseDashLogic.READY = "Ready?"
MouseDashLogic.TIME_UP = "Time's up!"
MouseDashLogic.TIME_LOW = 10 -- the clock turns red for its last seconds

MouseDashLogic.FACES = {
	mouse = { face = "🐭", color = "#B9BEC9" },
	golden = { face = "🐭", color = "#FFD34D" },
	kitten = { face = "😴", color = "#F6E3C5" },
} :: { [string]: { face: string, color: string } }

-- Model-Agent's sheet (#3400, uploaded 2026-11-12): 1024 px, cells of 256, every piece centred in its cell. Hole and
-- HoleFront share a frame, so an animal drawn between them rises out of the hole.
MouseDashLogic.SHEET = "rbxassetid://106053188764774"
MouseDashLogic.BACKDROP = "rbxassetid://116753136904678"
MouseDashLogic.CELL = 256
MouseDashLogic.CELLS = {
	Mouse = { 0, 0 },
	MouseHit = { 256, 0 },
	GoldMouse = { 512, 0 },
	GoldMouseHit = { 768, 0 },
	Kitten = { 0, 256 },
	KittenAwake = { 256, 256 },
	Hole = { 512, 256 },
	HoleFront = { 768, 256 },
	Dust = { 0, 512 },
	Paw = { 256, 512 },
	PawBop = { 512, 512 },
	Heart = { 768, 512 },
	HeartEmpty = { 0, 768 },
	Cheese = { 256, 768 },
	MouseDash = { 512, 768 },
} :: { [string]: { number } }
MouseDashLogic.ART = {
	mouse = { up = "Mouse", hit = "MouseHit" },
	golden = { up = "GoldMouse", hit = "GoldMouseHit" },
	kitten = { up = "Kitten", hit = "KittenAwake" },
} :: { [string]: { up: string, hit: string } }

export type Layout = {
	side: "left" | "top",
	hole: number, -- a hole's side in px
	gap: number,
	gridX: number, -- the grid's top left corner
	gridY: number,
	grid: number, -- the grid's side
	hudX: number,
	hudY: number,
	hudW: number,
	hudH: number,
	-- #3553, the next prize's banner: "row" across a tall board, "column" or "small" in a wide board's strip,
	-- "none" where there is no room for it
	banner: "row" | "column" | "small" | "none",
	bannerX: number,
	bannerY: number,
	bannerW: number,
	bannerH: number,
}

function MouseDashLogic.layout(width: number, height: number): Layout
	local gap = MouseDashLogic.HOLE_GAP
	local clear = MouseDashLogic.HUD_GAP
	local function holeFor(side: number): number
		return math.floor((side - gap * 2) / 3)
	end
	-- try both; the one with the bigger holes wins (a phone held sideways gets the strip on the left)
	local leftSide = math.min(width - MouseDashLogic.HUD_SIDE - clear, height)
	local topSide = math.min(width, height - MouseDashLogic.HUD_TOP - clear)
	local left = holeFor(leftSide) >= holeFor(topSide)
	local hole = math.clamp(holeFor(if left then leftSide else topSide), 8, MouseDashLogic.MAX_HOLE)
	local grid = hole * 3 + gap * 2
	if left then
		local used = MouseDashLogic.HUD_SIDE + clear + grid
		local x = math.floor(math.max(0, (width - used) / 2))
		local y = math.floor(math.max(0, (height - grid) / 2))
		local room = grid - MouseDashLogic.BANNER_FROM
		local mode: "column" | "small" | "none" = if room >= MouseDashLogic.BANNER_FULL
			then "column"
			elseif room >= MouseDashLogic.BANNER_SMALL then "small"
			else "none"
		return {
			side = "left",
			hole = hole,
			gap = gap,
			gridX = x + MouseDashLogic.HUD_SIDE + clear,
			gridY = y,
			grid = grid,
			hudX = x,
			hudY = y,
			hudW = MouseDashLogic.HUD_SIDE,
			hudH = grid,
			banner = mode,
			bannerX = x,
			bannerY = y + MouseDashLogic.BANNER_FROM,
			bannerW = MouseDashLogic.HUD_SIDE,
			bannerH = if mode == "column"
				then MouseDashLogic.BANNER_FULL
				elseif mode == "small" then MouseDashLogic.BANNER_SMALL
				else 0,
		}
	end
	-- the banner's row only where the holes stay as big as without it, or at least MIN_HOLE
	local extra = MouseDashLogic.BANNER_ROW + MouseDashLogic.BANNER_GAP
	local withRow =
		math.clamp(holeFor(math.min(width, topSide - extra)), 8, MouseDashLogic.MAX_HOLE)
	local row = withRow >= math.min(hole, MouseDashLogic.MIN_HOLE)
	if row then
		hole = withRow
		grid = hole * 3 + gap * 2
	else
		extra = 0
	end
	local used = MouseDashLogic.HUD_TOP + extra + clear + grid
	local y = math.floor(math.max(0, (height - used) / 2))
	local x = math.floor(math.max(0, (width - grid) / 2))
	return {
		side = "top",
		hole = hole,
		gap = gap,
		gridX = x,
		gridY = y + MouseDashLogic.HUD_TOP + extra + clear,
		grid = grid,
		hudX = x,
		hudY = y,
		hudW = grid,
		hudH = MouseDashLogic.HUD_TOP,
		banner = if row then "row" else "none",
		bannerX = x,
		bannerY = y + MouseDashLogic.HUD_TOP + MouseDashLogic.BANNER_GAP,
		bannerW = grid,
		bannerH = if row then MouseDashLogic.BANNER_ROW else 0,
	}
end

function MouseDashLogic.holeAt(layout: Layout, hole: number): (number, number)
	local index = math.clamp(math.floor(hole), 1, MouseDash.HOLES) - 1
	local step = layout.hole + layout.gap
	return layout.gridX + (index % 3) * step, layout.gridY + (index // 3) * step
end

local KEYS: { [string]: number } = { Q = 1, W = 2, E = 3, A = 4, S = 5, D = 6, Z = 7, X = 8, C = 9 }
MouseDashLogic.KEYS = KEYS

function MouseDashLogic.keyHole(keyName: string): number?
	return KEYS[keyName]
end

-- The left stick (x right, y up, each -1 to 1) to a hole: past half way picks the row or column on that side.
function MouseDashLogic.stickHole(x: number, y: number): number
	local column = if x < -0.5 then 0 elseif x > 0.5 then 2 else 1
	local row = if y > 0.5 then 0 elseif y < -0.5 then 2 else 1
	return row * 3 + column + 1
end

function MouseDashLogic.records(state: any): string
	if type(state) ~= "table" or state.loaded ~= true then
		return "Waking up..."
	end
	local best: number = if type(state.best) == "number" then state.best else 0
	local seconds: number = if type(state.bestSeconds) == "number" then state.bestSeconds else 0
	local parts: { string } =
		{ if best > 0 then "Best " .. MouseDash.words(best, seconds) else "No best yet" }
	if state.legend == true then
		table.insert(parts, Arcade.LEGEND_TITLE)
	end
	if state.mouser == true then
		table.insert(parts, MouseDash.MOUSER_TITLE)
	end
	return table.concat(parts, " · ")
end

function MouseDashLogic.endWords(result: any): string
	if type(result) ~= "table" then
		return "Nice try!"
	end
	if result.win == true then
		return "You win!"
	end
	if result.newBest == true then
		return "New best!"
	end
	if result.reason == "time" then
		return MouseDashLogic.TIME_UP
	end
	return "Nice try!"
end

function MouseDashLogic.lastLine(result: any): string
	if type(result) ~= "table" or type(result.points) ~= "number" then
		return ""
	end
	local line = "Score " .. MouseDash.words(result.points, result.seconds or 0)
	if result.newBest == true then
		line ..= " · New best!"
	elseif type(result.best) == "number" then
		line ..= " · Best " .. MouseDash.words(result.best, result.bestSeconds or 0)
	end
	return line
end

export type PrizeRow = { at: number, name: string, paid: boolean, prize: any }

function MouseDashLogic.prizeRows(today: any): { PrizeRow }
	local rows: { PrizeRow } = {}
	local paid: { number } = if type(today) == "table" then today else {}
	for _, milestone in Arcade.milestones() do
		table.insert(rows, {
			at = milestone.at,
			name = milestone.name,
			paid = table.find(paid, milestone.at) ~= nil,
			prize = milestone.prize,
		})
	end
	return rows
end

-- The next prize not yet paid today above `points`, for the line under the score.
function MouseDashLogic.nextPrize(points: number, today: any): string
	for _, row in MouseDashLogic.prizeRows(today) do
		if row.at > points and not row.paid then
			return string.format("Next prize: %s at %d", row.name, row.at)
		end
	end
	return "All of today's prizes won!"
end

-- #3553 (Derek 2026-11-12: "just show next reward with an image in top banner when playing"): the next prize's own
-- row, nil once none is left for today.
function MouseDashLogic.nextRow(points: number, today: any): PrizeRow?
	for _, row in MouseDashLogic.prizeRows(today) do
		if row.at > points and not row.paid then
			return row
		end
	end
	return nil
end

MouseDashLogic.ALL_EARNED = "All prizes earned!"
MouseDashLogic.FREE_PLAY = "1 free play today"
MouseDashLogic.FREE_USED = "Come back tomorrow for a free play"

function MouseDashLogic.bannerWords(row: PrizeRow?): string
	if row == nil then
		return MouseDashLogic.ALL_EARNED
	end
	return string.format("%s at %d", row.name, row.at)
end

-- The banner's bar: the score's share of the next prize's score, and "24/30". Full with no words once all are earned.
function MouseDashLogic.progress(points: number, row: PrizeRow?): (number, string)
	if row == nil or row.at <= 0 then
		return 1, ""
	end
	local have = math.clamp(math.floor(points), 0, row.at)
	return have / row.at, string.format("%d/%d", have, row.at)
end

export type Picture = { image: string?, glyph: string }

-- A prize's picture: the real item icon (ShopIcons), with a glyph until it loads or for a kind with no picture.
function MouseDashLogic.prizePicture(prize: any): Picture
	if type(prize) ~= "table" then
		return { image = nil, glyph = "🎁" }
	end
	local function first(map: any): string?
		if type(map) == "table" then
			for id in map do
				if type(id) == "string" then
					return id
				end
			end
		end
		return nil
	end
	local lure, potion, crate = first(prize.lures), first(prize.potions), first(prize.crates)
	if lure ~= nil then
		return { image = ShopIcons.food(lure), glyph = "🍣" }
	elseif potion ~= nil then
		return { image = ShopIcons.potion(potion), glyph = "🧪" }
	elseif crate ~= nil then
		return { image = ShopIcons.crate(crate), glyph = "📦" }
	elseif type(prize.fish) == "number" then
		return { image = ShopIcons.prize("fish"), glyph = "🐟" }
	end
	return { image = nil, glyph = "🎁" }
end

-- The run's clock: "1:32" for the whole seconds left until `endsAt`, "0:00" once out, "" with no clock (an older
-- server sends none). Also whether it is in its last TIME_LOW seconds.
function MouseDashLogic.timeLeft(endsAt: number?, now: number): (string, boolean)
	if endsAt == nil then
		return "", false
	end
	local left = math.max(0, math.ceil(endsAt - now))
	return string.format("%d:%02d", left // 60, left % 60), left <= MouseDashLogic.TIME_LOW
end

function MouseDashLogic.freeLine(state: any): string
	if type(state) ~= "table" or state.loaded ~= true then
		return ""
	end
	return if state.free == true then MouseDashLogic.FREE_PLAY else MouseDashLogic.FREE_USED
end

return MouseDashLogic
