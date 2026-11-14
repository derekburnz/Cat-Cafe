--!strict
-- The Grand Opening roadmap (#1893, first-hour.md section 1): eight first-hour milestones as a strip under the goal
-- card, "Grand Opening 3/8" over eight dots, that opens in place into a short list. The server checks and pays each
-- milestone; this only reads what ProfileSync says is done. Pure, so the cloud specs check it.
--   STEPS                                 the eight milestones' card text and reward, in order
--   view(state) -> View?                  what the strip shows, or nil while it is hidden: before the first catch
--                                         (tutorialStep 2, #2795), once finished, and for an account that never had it
--   toast(n) -> string                    "Grand Opening 4/8: Tier 2! +5 golden fish"
--   BANNER                                the banner after step 8

local RoadmapLogic = {}

export type Step = { text: string, short: string, reward: string, doneText: string? }
export type Row = { n: number, text: string, reward: string, done: boolean, next: boolean }
export type View = { count: number, total: number, rows: { Row }, title: string }

-- #2795: the tutorialStep the strip shows from, the first catch (shared GrandOpening.SHOW_FROM_STEP; it was the
-- tutorial's end, 5)
RoadmapLogic.SHOW_FROM = 2
RoadmapLogic.TUTORIAL_DONE = 5 -- tutorialStep at the tutorial's end (easy-start.md; RecapLogic waits for it)
RoadmapLogic.TITLE = "Grand Opening"
-- the banner's 72 px title fits a small phone at 14 letters, so the spec's "Your cafe's Grand Opening!" is the line
RoadmapLogic.BANNER = "Grand Opening!"
RoadmapLogic.BANNER_LINE = "Your cafe's Grand Opening! +30 golden fish"

-- first-hour.md 1a: the card text, the toast's short words and the reward (#2795: the server's prizes since #2237)
RoadmapLogic.STEPS = {
	-- #3660: a new save starts with its first table, so the row never asks for it once it is done
	{
		text = "Open your first table",
		short = "First table!",
		reward = "+3 golden fish",
		doneText = "Your first table is open",
	},
	{ text = "Your first bait cat", short = "First bait cat!", reward = "+3 golden fish" },
	{ text = "Three different cats", short = "Three cats!", reward = "+1 spin" }, -- #4188: Tier 2's need (4 for #4098)
	{ text = "Rank up to Tier 2", short = "Tier 2!", reward = "+5 golden fish" },
	{ text = "Catch a cat in the Park", short = "A Park cat!", reward = "+1 Swift Potion" },
	{ text = "A full Tier 2 cafe", short = "Full cafe!", reward = "+1 spin" },
	{ text = "Twelve different cats", short = "Twelve cats!", reward = "+5 golden fish" },
	{
		text = "Grand Opening! Rank up to Tier 3",
		short = "Grand Opening!",
		reward = "+30 golden fish, a crate and a tag",
	},
} :: { Step }

-- What ProfileSync sends: grandOpening = { done = { [n] = true }, finished = true? } (first-hour.md 1c)
local function doneOf(raw: unknown): ({ [number]: boolean }, boolean)
	local done: { [number]: boolean } = {}
	if type(raw) ~= "table" then
		return done, false
	end
	local list = (raw :: any).done
	if type(list) == "table" then
		for key, value in list do
			local n = tonumber(key)
			if n ~= nil and value == true then
				done[n] = true
			end
		end
	end
	return done, (raw :: any).finished == true
end

function RoadmapLogic.view(state: { [string]: any }): View?
	local raw = state.grandOpening
	if raw == nil then
		return nil -- the server sends it only to accounts that get the roadmap (not Tier 3 and up when it shipped)
	end
	if (state.tutorialStep or RoadmapLogic.SHOW_FROM) < RoadmapLogic.SHOW_FROM then
		return nil
	end
	local done, finished = doneOf(raw)
	if finished then
		return nil
	end
	local total = #RoadmapLogic.STEPS
	local count = 0
	local rows: { Row } = {}
	local nextFound = false
	for n, step in RoadmapLogic.STEPS do
		local isDone = done[n] == true
		if isDone then
			count += 1
		end
		local isNext = not isDone and not nextFound
		if isNext then
			nextFound = true
		end
		table.insert(rows, {
			n = n,
			text = if isDone and step.doneText ~= nil then step.doneText else step.text,
			reward = step.reward,
			done = isDone,
			next = isNext,
		})
	end
	return {
		count = count,
		total = total,
		rows = rows,
		title = ("%s %d/%d"):format(RoadmapLogic.TITLE, count, total),
	}
end

function RoadmapLogic.toast(n: number): string
	local step = RoadmapLogic.STEPS[n]
	if step == nil then
		return RoadmapLogic.TITLE
	end
	return ("%s %d/%d: %s %s"):format(
		RoadmapLogic.TITLE,
		n,
		#RoadmapLogic.STEPS,
		step.short,
		step.reward
	)
end

return RoadmapLogic
