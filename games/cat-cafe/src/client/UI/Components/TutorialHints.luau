--!strict
-- The tutorial strip's line for each step (F87, easy-start.md section 2e). Each line names the input the player last
-- used: a letter key on a keyboard, "tap" on touch and the plain button name on a gamepad, so a line on touch never
-- names a letter key. UIController keeps each step's trail target and asks UI.tutorial.hint(state) for the words.
--   line(view) -> string?                     the step's line, nil from DONE (the first loop is done)
--   resting(cats, spots, tier) -> boolean     a cat rests while a role slot its tier opens is free (step 2's choice)
--   upgrade(step, levels) -> string?          #1796: the upgrade the step asks for, "tables" at step 3 and "lure_bowl"
--                                             at step 4 until it is owned, so the HUD's Upgrades tile and that row in
--                                             Upgrades glow (Components/TutorialGlow); nil otherwise
-- The steps (server tutorialStep): below 2 the first catch, 2 the first check-in with no free slot, 3 the first
-- table, 4 the Bait bowl and food in it, 5 done. Each line keeps to about 50 characters, one line on the strip.
-- Pure, so the cloud spec runner checks it.

local TipQueue = require(script.Parent.TipQueue)

local TutorialHints = {}

TutorialHints.DONE = 5

export type View = {
	step: number,
	device: TipQueue.Device,
	resting: boolean?, -- step 2: a cat rests while a role slot is free
	bowl: boolean?, -- step 4: the Bait bowl is owned
	baited: boolean?, -- step 4: food is in it
}

type Line = string | { keyboard: string, touch: string, gamepad: string }

local LINES: { [string]: Line } = {
	-- the trail leads to the beginner's own cat, past the Alleyway camp since the cannon (F84; easy-start.md says the
	-- words follow the town), so the line names the trail rather than the place
	catch = {
		keyboard = "Follow the trail and catch the cat! Click by it",
		touch = "Follow the trail and catch the cat! Tap NET by it",
		gamepad = "Follow the trail and catch the cat! Press R2 by it",
	},
	job = {
		keyboard = "Open Cats (C) and give your new cat a job",
		touch = "Tap Cats and give your new cat a job",
		gamepad = "Open Cats and give your new cat a job",
	},
	more = {
		keyboard = "Catch more cats, or buy a table in Upgrades (U)",
		touch = "Catch more cats, or tap Upgrades for a table",
		gamepad = "Catch more cats, or buy a table in Upgrades",
	},
	table = {
		keyboard = "Buy a table in Upgrades (U): more tips per cat",
		touch = "Tap Upgrades and buy a table: more tips per cat",
		gamepad = "Open Upgrades and buy a table: more tips per cat",
	},
	bowl = {
		keyboard = "Buy the Bait bowl in Upgrades (U)",
		touch = "Tap Upgrades and buy the Bait bowl",
		gamepad = "Open Upgrades and buy the Bait bowl",
	},
	food = {
		keyboard = "Put Kibble in your bowl on the back step (F)",
		touch = "Tap the Bait bowl and put Kibble in it",
		gamepad = "Put Kibble in your bowl on the back step",
	},
	waiting = "A cat is on its way to your bowl",
}

-- Which line the view asks for, nil when none.
local function pick(view: View): string?
	local step = view.step
	if step < 2 then
		return "catch"
	elseif step == 2 then
		return if view.resting then "job" else "more"
	elseif step == 3 then
		return "table"
	elseif step == 4 then
		if not view.bowl then
			return "bowl"
		end
		return if view.baited then "waiting" else "food"
	end
	return nil
end

TutorialHints.TABLE = "tables"
TutorialHints.BOWL = "lure_bowl"

function TutorialHints.upgrade(step: number?, levels: { [string]: number }?): string?
	local owned: { [string]: number } = levels or {}
	if step == 3 then
		return TutorialHints.TABLE
	elseif step == 4 and (owned[TutorialHints.BOWL] or 0) < 1 then
		return TutorialHints.BOWL
	end
	return nil
end

function TutorialHints.line(view: View): string?
	local id = pick(view)
	local line: Line? = if id ~= nil then LINES[id] else nil
	if line == nil then
		return nil
	end
	return if type(line) == "string" then line else (line :: any)[view.device]
end

-- Step 2 asks for a job when a cat rests and a role slot the tier opens is free (UIController's
-- hasRestingCatAndFreeSpot, which reads the shared catalog's spots; here the UI catalog's).
-- cats: uid to { spotId? }; spots: { id, tier }.
function TutorialHints.resting(cats: { [string]: any }?, spots: { any }?, tier: number): boolean
	local resting = false
	local used: { [string]: boolean } = {}
	local owned: { [string]: any } = cats or {}
	for _, cat in owned do
		local spot: string? = cat.spotId
		if spot == nil then
			resting = true
		else
			used[spot] = true
		end
	end
	if not resting then
		return false
	end
	local slots: { any } = spots or {}
	for _, spot in slots do
		if tier >= spot.tier and not used[spot.id] then
			return true
		end
	end
	return false
end

return TutorialHints
