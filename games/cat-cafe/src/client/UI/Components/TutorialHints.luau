--!strict
-- The tutorial strip's line for each step (F87, easy-start.md section 2e). Each line names the input the player last
-- used: a letter key on a keyboard, "tap" on touch and the plain button name on a gamepad, so a line on touch never
-- names a letter key. UIController keeps each step's trail target and asks UI.tutorial.hint(state) for the words.
--   line(view) -> string?                     the step's line, nil from DONE (the first loop is done)
--   resting(cats, spots, tier) -> boolean     a cat rests while a role slot its tier opens is free (step 2's choice)
--   upgrade(step, levels) -> string?          #1796: the upgrade the step asks for, "tables" at step 3 and "lure_bowl"
--                                             at step 4 until it is owned, so the HUD's Upgrades tile and that row in
--                                             Upgrades glow (Components/TutorialGlow); nil otherwise
--   closeUpgrades(step, levels) -> boolean    #3880: the table and bowl are bought, so Upgrades' X glows
--   view(state, spots, device?) -> View       #2697: the view of a player's state, for line and ask
--   ask(view) -> string?                      #2697: what the step asks for ("catch", "job", "more", "second",
--                                             "table", "bowl", "food", "waiting" or "arrived"), so each screen rings its own part
--                                             of it
--                                             (Components/StepTarget): "job" the HUD's Cats tile and Equip Best,
--                                             "food" the HUD's Bowl tile and the Kibble row's Use
-- The steps (server tutorialStep): below 2 the first catch, 2 the first check-in with no free slot, 3 the first
-- table, 4 the Bait bowl, food in it and (#3158) its first cat tamed or let go, 5 done. Each line keeps to about 50 characters, one line on the strip.
-- #2912 (Nov 10 read: 21% leave between the first customer served and the second cat): step 3 with one cat asks for
-- another cat or the table ("second"), and UIController rings the nearest Alleyway stray. #3022: "one cat" is one
-- cat caught, since every cafe also has its starter Tabby.
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
	arrived: boolean?, -- step 4: the food's cat is at the bowl (#3158)
	-- #2912: how many cats the player has caught (#3022: stats.catsCaught; nil: not known, step 3 asks for the table
	-- alone)
	cats: number?,
	-- #3238: the areas are shut (dusk to sunrise), so step 3's "second" line says when the strays are back
	night: boolean?,
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
	second = {
		keyboard = "Catch another cat, or buy a table in Upgrades (U)",
		touch = "Catch another cat, or tap Upgrades for a table",
		gamepad = "Catch another cat, or buy a table in Upgrades",
	},
	-- #3238: the "second" line at night, when no stray waits; kept to the strip's one line
	secondNight = {
		keyboard = "Strays return at sunrise, or buy a table (U)",
		touch = "Strays return at sunrise, or tap Upgrades",
		gamepad = "Strays return at sunrise, or open Upgrades",
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
	-- #3158: step 4 lasts until the first bowl cat is tamed or let go
	arrived = "Your bowl cat is here! Tame it",
}

-- What the view asks for, nil when none.
local function pick(view: View): string?
	local step = view.step
	if step < 2 then
		return "catch"
	elseif step == 2 then
		return if view.resting then "job" else "more"
	elseif step == 3 then
		return if view.cats ~= nil and view.cats < 2 then "second" else "table"
	elseif step == 4 then
		if not view.bowl then
			return "bowl"
		end
		if view.arrived then
			return "arrived"
		end
		return if view.baited then "waiting" else "food"
	end
	return nil
end

TutorialHints.TABLE = "tables"
TutorialHints.BOWL = "lure_bowl"
TutorialHints.KIBBLE = "kibble" -- the food step's line names it, so its row's Use rings

function TutorialHints.ask(view: View): string?
	return pick(view)
end

-- The view of `state` (a PlayerState), with the catalog's spots for step 2's choice.
-- `areasOpen` false from dusk to sunrise (the Clock folder's AreasOpen, #3238).
function TutorialHints.view(
	state: any,
	spots: { any }?,
	device: TipQueue.Device?,
	areasOpen: boolean?
): View
	local levels: { [string]: number } = state.upgradeLevels or {}
	-- #3022: the cats caught so far (stats.catsCaught), not the cats in the cafe. A new cafe's starter Tabby made that
	-- count 2 after the first catch, so #2912's "second" line never showed.
	local cats: number? = nil
	local stats = state.stats
	if type(stats) == "table" and type(stats.catsCaught) == "number" then
		-- #3160, #3551 (as shared/SecondCat.progress and done): every cat caught by hand counts and so does the
		-- first bowl cat, but it takes one caught by hand to reach 2
		local tamed = if type(stats.baitsTamed) == "number" then stats.baitsTamed else 0
		local hand = math.max(0, stats.catsCaught - tamed)
		local counted = hand + (if tamed >= 1 then 1 else 0)
		cats = if hand >= 1 then counted else math.min(counted, 1)
	end
	return {
		step = state.tutorialStep or TutorialHints.DONE,
		device = device or "keyboard",
		resting = TutorialHints.resting(state.cats, spots, state.tier or 1),
		bowl = (levels[TutorialHints.BOWL] or 0) >= 1,
		baited = type(state.bait) == "table", -- #3285: the UI's state sends false for an empty bowl
		arrived = type(state.bait) == "table" and state.bait.cat ~= nil,
		cats = cats,
		night = areasOpen == false,
	}
end

function TutorialHints.upgrade(step: number?, levels: { [string]: number }?): string?
	local owned: { [string]: number } = levels or {}
	if step == 3 then
		return TutorialHints.TABLE
	elseif step == 4 and (owned[TutorialHints.BOWL] or 0) < 1 then
		return TutorialHints.BOWL
	end
	return nil
end

-- #3880 (Derek 2026-11-13: "show an arrow to the X of upgrades menu and dim screen after the table and bait bowl
-- upgrade"): the table and the Bait bowl are both bought (step 4 with the bowl owned), so the next thing is outside
-- and an open Upgrades window's X glows, with the tutorial's arrow and spotlight.
function TutorialHints.closeUpgrades(step: number?, levels: { [string]: number }?): boolean
	local owned: { [string]: number } = levels or {}
	return step == 4 and (owned[TutorialHints.BOWL] or 0) >= 1
end

-- #2912 (Nov 10 read: 105 caught a second cat, 93 bought the first table): the strip's Buy button, which buys the
-- step's upgrade in one press with no trip into Upgrades. The words for each upgrade it can buy.
TutorialHints.BUY_TEXT = {
	[TutorialHints.TABLE] = "Buy a table",
	[TutorialHints.BOWL] = "Buy the Bait bowl",
} :: { [string]: string }

export type Offer = { id: string, cost: number, text: string }

-- What the strip's Buy button offers: the step's upgrade (`upgrade`) and its next level's cost from `upgrades` (the
-- catalog's), only while `money` covers it. nil hides the button, so a player short of coins never meets a greyed
-- buy; the Upgrades tile still glows.
function TutorialHints.offer(
	step: number?,
	levels: { [string]: number }?,
	money: number?,
	upgrades: { any }?
): Offer?
	local id = TutorialHints.upgrade(step, levels)
	local text = if id ~= nil then TutorialHints.BUY_TEXT[id] else nil
	if id == nil or text == nil or type(money) ~= "number" or upgrades == nil then
		return nil
	end
	for _, def in upgrades do
		if def.id == id then
			local level = (levels or {})[id] or def.startLevel or 0
			local cost = if type(def.costs) == "table" then def.costs[level + 1] else nil
			if type(cost) ~= "number" or money < cost then
				return nil
			end
			return { id = id, cost = cost, text = text }
		end
	end
	return nil
end

function TutorialHints.line(view: View): string?
	local id = pick(view)
	if id == "second" and view.night == true then
		id = "secondNight"
	end
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
