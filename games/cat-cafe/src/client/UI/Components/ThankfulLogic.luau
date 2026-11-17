--!strict
-- #4251 Harvest Hollow's Thankful Board (harvest-hollow-spec sections 5 and 6): what the board's face and the note
-- picker show. Pure, so the specs check it.
--   pie(count, goal, slices) -> Pie      the slices baked (0 to 8), "Feast Pie 3/8 baked" and "12,345 / 25,000 harvest
--                                        cats", or "The Feast Pie is baked!" once full
--   notes(json) -> { Note }              the board's HarvestNotes attribute (JSON [{userId, note}], newest last) as
--                                        notes to draw, newest first, at most HarvestSave.NOTE_KEEP; bad rows dropped
--   notesFrom(rows) -> { Note }          the same from the decoded rows
--   helpedLine(helped) -> string         under the pie: whether this player has helped yet
--   headshot(userId) -> string           the avatar picture's content id (no yield, no name shown)
--   pickLine(now, lastPin) -> string?    the picker's wait line while the server's 10 s gap runs, else nil

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HarvestSave =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HarvestSave")) :: any

local ThankfulLogic = {}

ThankfulLogic.TAG = "HarvestBoard" -- HarvestWorld.BOARD_TAG
ThankfulLogic.PROMPT = "HarvestBoardPrompt"
ThankfulLogic.NOTES_ATTRIBUTE = "HarvestNotes"
ThankfulLogic.COUNT_ATTRIBUTE = "HarvestPieCount"
ThankfulLogic.GOAL_ATTRIBUTE = "HarvestPieGoal"
ThankfulLogic.SLICES_ATTRIBUTE = "HarvestPieSlices"
ThankfulLogic.SLICES = 8 -- HarvestSave.PIE_SLICES
ThankfulLogic.PIN_GAP = 10 -- seconds, HarvestService's NOTE_GAP
ThankfulLogic.TITLE = "Thankful Board"

local function commas(value: number): string
	local text = tostring(math.floor(value))
	while true do
		local grouped, count = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
		text = grouped
		if count == 0 then
			return text
		end
	end
end

export type Pie = { slices: number, title: string, line: string, done: boolean }

function ThankfulLogic.pie(count: unknown, goal: unknown, slices: unknown): Pie
	local made = if type(count) == "number" then math.max(math.floor(count), 0) else 0
	local target = if type(goal) == "number" and goal > 0
		then math.floor(goal)
		else HarvestSave.PIE_GOAL :: number
	local baked = if type(slices) == "number"
		then math.clamp(math.floor(slices), 0, ThankfulLogic.SLICES)
		else 0
	local done = baked >= ThankfulLogic.SLICES
	return {
		slices = baked,
		done = done,
		title = if done
			then "The Feast Pie is baked!"
			else ("Feast Pie %d/%d baked"):format(baked, ThankfulLogic.SLICES),
		line = ("%s / %s harvest cats"):format(commas(math.min(made, target)), commas(target)),
	}
end

export type Note = { userId: number, text: string }

-- The decoded rows as notes to draw, newest first (the list is newest last), at most NOTE_KEEP; bad rows dropped.
function ThankfulLogic.notesFrom(rows: unknown): { Note }
	local out: { Note } = {}
	if type(rows) ~= "table" then
		return out
	end
	local list = rows :: { any }
	for index = #list, 1, -1 do
		local row = list[index]
		if
			type(row) == "table"
			and type(row.userId) == "number"
			and HarvestSave.validNote(row.note)
		then
			table.insert(out, { userId = row.userId, text = HarvestSave.NOTES[row.note] })
			if #out >= HarvestSave.NOTE_KEEP then
				break
			end
		end
	end
	return out
end

-- JSON to a table (the UI gate's shim has no HttpService decode, so its scene swaps this)
ThankfulLogic.decode = function(json: string): unknown
	return HttpService:JSONDecode(json)
end

function ThankfulLogic.notes(json: unknown): { Note }
	if type(json) ~= "string" or json == "" then
		return {}
	end
	local ok, decoded = pcall(ThankfulLogic.decode, json)
	return if ok then ThankfulLogic.notesFrom(decoded) else {}
end

function ThankfulLogic.helpedLine(helped: boolean?): string
	return if helped == true
		then "You helped bake it! 🥧"
		else "Catch a harvest cat to add a slice"
end

function ThankfulLogic.headshot(userId: number): string
	return ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(userId)
end

function ThankfulLogic.pickLine(now: number, lastPin: number?): string?
	if lastPin == nil then
		return nil
	end
	local left = math.ceil(ThankfulLogic.PIN_GAP - (now - lastPin))
	if left <= 0 then
		return nil
	end
	return ("Pinned! Pick again in %d s"):format(left)
end

return ThankfulLogic
