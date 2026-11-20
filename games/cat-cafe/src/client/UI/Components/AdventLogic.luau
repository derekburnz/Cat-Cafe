--!strict
-- #5502 the Christmas advent calendar's card, the part with no instances (shared/Advent holds the dates and rules;
-- the server alone decides what opens). Reads PlayerState.advent, the server's view { live, opened, due, ready,
-- reason }, and says what each of the 24 doors shows. Pure, so the spec loads it.
--   shows(view) -> boolean            the card, the Rewards row and the board's prompt show
--   cells(view) -> { Cell }           the 24 doors in order
--   headline(view) -> string          the one line over the doors
--   rowLine(view) -> string           the Rewards list's row
--   prizeText(prize, catName?, compact?) -> string   a door's prize in a few words
--   dateText(n) -> string             "Dec 9", the UTC day door n opens

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Advent = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Advent"))

local AdventLogic = {}

AdventLogic.DOORS = Advent.DOORS

export type View = { live: boolean, opened: number, due: number, ready: boolean, reason: string }
-- opened: its prize is paid. ready: a tap opens it now. waiting: its date has come, but an earlier door or today's
-- catch-ups come first. locked: its date has not come.
export type CellState = "opened" | "ready" | "waiting" | "locked"
export type Cell = { n: number, state: CellState, cat: string?, prize: any, date: string }

local MONTHS =
	{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local POTIONS: { [string]: string } = { lucky_potion = "Lucky", swift_potion = "Swift" }

function AdventLogic.shows(view: View?): boolean
	return view ~= nil and view.live == true
end

function AdventLogic.dateText(n: number): string
	local at = os.date("!*t", Advent.doorAt(n)) :: any
	return ("%s %d"):format(MONTHS[at.month] or "", at.day)
end

local function count(amount: number, one: string, many: string): string
	return ("%d %s"):format(amount, if amount == 1 then one else many)
end

-- `compact` (a short screen's small tile): parts joined with a comma, which wraps better than " + ".
function AdventLogic.prizeText(prize: any, catName: string?, compact: boolean?): string
	local parts: { string } = {}
	if catName ~= nil then
		table.insert(parts, catName)
	end
	if type(prize) == "table" then
		if type(prize.fish) == "number" then
			table.insert(parts, count(prize.fish, "golden fish", "golden fish"))
		end
		if type(prize.spins) == "number" then
			table.insert(parts, count(prize.spins, "spin", "spins"))
		end
		if type(prize.snowflakes) == "number" then
			table.insert(parts, count(prize.snowflakes, "Snowflake", "Snowflakes"))
		end
		if type(prize.traitTokens) == "number" then
			table.insert(parts, count(prize.traitTokens, "trait token", "trait tokens"))
		end
		if type(prize.coinSeconds) == "number" then
			local hours = prize.coinSeconds / 3600
			table.insert(
				parts,
				if hours >= 1
					then ("%d h of cafe pay"):format(math.floor(hours + 0.5))
					else ("%d min of cafe pay"):format(
						math.floor(prize.coinSeconds / 60 + 0.5)
					)
			)
		end
		if type(prize.crates) == "table" then
			local crates = 0
			for _, amount in prize.crates do
				crates += amount
			end
			table.insert(parts, count(crates, "golden crate", "golden crates"))
		end
		if type(prize.potions) == "table" then
			-- in a fixed order, so the words never shuffle
			for _, id in { "lucky_potion", "swift_potion" } do
				local amount = prize.potions[id]
				if type(amount) == "number" then
					table.insert(
						parts,
						count(amount, POTIONS[id] .. " potion", POTIONS[id] .. " potions")
					)
				end
			end
		end
	end
	return if #parts > 0
		then table.concat(parts, if compact == true then ", " else " + ")
		else "A gift"
end

function AdventLogic.cells(view: View?): { Cell }
	local opened = if view ~= nil then view.opened else 0
	local due = if view ~= nil then view.due else 0
	local ready = view ~= nil and view.ready == true
	local out: { Cell } = {}
	for _, door in Advent.DOOR_LIST do
		local state: CellState = if door.n <= opened
			then "opened"
			elseif door.n == opened + 1 and ready then "ready"
			elseif door.n <= due then "waiting"
			else "locked"
		table.insert(out, {
			n = door.n,
			state = state,
			cat = door.cat,
			prize = door.prize,
			date = AdventLogic.dateText(door.n),
		})
	end
	return out
end

function AdventLogic.headline(view: View?): string
	if view == nil or not view.live then
		return "The calendar opens on Dec 1"
	elseif view.ready then
		return ("Door %d is ready!"):format(view.opened + 1)
	elseif view.reason == "done" then
		return "All 24 doors opened. Merry Christmas!"
	elseif view.opened < view.due then
		return "More doors tomorrow"
	end
	return "Next door tomorrow"
end

function AdventLogic.rowLine(view: View?): string
	if view ~= nil and view.ready then
		return ("Advent door %d"):format(view.opened + 1)
	end
	return ("Advent calendar %d/%d"):format(if view ~= nil then view.opened else 0, Advent.DOORS)
end

return AdventLogic
