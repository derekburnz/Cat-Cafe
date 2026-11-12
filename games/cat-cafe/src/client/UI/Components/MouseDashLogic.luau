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
--   FACES                    the stand-in faces until the picture sheet is uploaded

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arcade = require(Shared:WaitForChild("Arcade")) :: any
local MouseDash = require(Shared:WaitForChild("MouseDash")) :: any

local MouseDashLogic = {}

MouseDashLogic.WINDOW = "MouseDash"
MouseDashLogic.MIN_HOLE = 64
MouseDashLogic.HOLE_GAP = 8
MouseDashLogic.HUD_GAP = 24 -- clear space between the score strip and the nearest hole
MouseDashLogic.HUD_SIDE = 104 -- the strip's width on the left of a wide board
MouseDashLogic.HUD_TOP = 44 -- its height on top of a tall board
MouseDashLogic.MAX_HOLE = 132
MouseDashLogic.RULE_LINE = "Bop the mice, +1 each and +3 for a golden one. Let sleeping kittens nap. "
	.. "Three hearts. Your first game each day is free, and each prize pays once a day."
MouseDashLogic.FASTER = "Faster!"
MouseDashLogic.READY = "Ready?"

MouseDashLogic.FACES = {
	mouse = { face = "🐭", color = "#B9BEC9" },
	golden = { face = "🐭", color = "#FFD34D" },
	kitten = { face = "😴", color = "#F6E3C5" },
} :: { [string]: { face: string, color: string } }

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
		return {
			side = "left",
			hole = hole,
			gap = gap,
			gridX = x + MouseDashLogic.HUD_SIDE + clear,
			gridY = math.floor(math.max(0, (height - grid) / 2)),
			grid = grid,
			hudX = x,
			hudY = math.floor(math.max(0, (height - grid) / 2)),
			hudW = MouseDashLogic.HUD_SIDE,
			hudH = grid,
		}
	end
	local used = MouseDashLogic.HUD_TOP + clear + grid
	local y = math.floor(math.max(0, (height - used) / 2))
	local x = math.floor(math.max(0, (width - grid) / 2))
	return {
		side = "top",
		hole = hole,
		gap = gap,
		gridX = x,
		gridY = y + MouseDashLogic.HUD_TOP + clear,
		grid = grid,
		hudX = x,
		hudY = y,
		hudW = grid,
		hudH = MouseDashLogic.HUD_TOP,
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

return MouseDashLogic
