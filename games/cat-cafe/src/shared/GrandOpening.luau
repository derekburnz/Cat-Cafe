--!strict
-- The Grand Opening roadmap (#1893, first-hour.md section 1): eight first-hour milestones on a strip under the goal
-- card, each paid once the moment it is met, the last one a rank up to Tier 3. Pure: every milestone is read from
-- the profile, so it needs no tracking of its own; GrandOpeningService checks, pays and tells the client.
--   fresh() -> a new account's state
--   sanitize(raw, fromVersion, tier) -> a saved state made whole; a save from before version 41 already at Tier 3
--     or above is finished at once (the first hour is behind it, nothing back-paid)
--   active(profile) -> whether the roadmap shows and pays: from the first catch (tutorialStep 2) until finished
--   met(profile, n) -> whether milestone n's condition holds now
--   due(profile) -> the milestones met and not yet done, lowest first (none while inactive)
--   mark(state, n, played?) -> records milestone n done; the last one finishes the roadmap at `played` seconds
--   plotLook(profile, played) -> the cafe front's Grand Opening model (#1922): the ribbon while the roadmap shows,
--     the bunting for BUNTING_SECONDS of play after it finished, else nil
--   current(state) -> the lowest milestone not done, or nil
--   view(state) -> a copy for ProfileSync

local Catalog = require(script.Parent.Catalog)
local Economy = require(script.Parent.Economy)
local Potions = require(script.Parent.Potions)
local Prizes = require(script.Parent.Prizes)
local Types = require(script.Parent.Types)

local GrandOpening = {}

export type Step = { id: string, name: string, prize: Types.IndexPrize }

-- first-hour.md 1a, in order. The last one's tag is ChatTags' tag_grand_opener (GrandOpening.TAG).
GrandOpening.STEPS = {
	{ id = "first_table", name = "Open your first table", prize = { fish = 3 } }, -- #2237 fish: was 5, 5, 10, 10, 50
	{ id = "first_bait_cat", name = "Your first bait cat", prize = { fish = 3 } },
	-- #4188: Tier 2's need of 3 (4 for #4098; the id stays "five_cats", so saves keep it done)
	{ id = "five_cats", name = "Three different cats", prize = { spins = 1 } },
	{ id = "tier_2", name = "Rank up to Tier 2", prize = { fish = 5 } },
	{
		id = "park_catch",
		name = "Catch a cat in the Park",
		prize = { potions = { [Potions.SWIFT] = 1 } },
	},
	{ id = "full_cafe", name = "A full Tier 2 cafe", prize = { spins = 1 } },
	{ id = "twelve_cats", name = "Twelve different cats", prize = { fish = 5 } },
	{
		id = "grand_opening",
		name = "Grand Opening! Rank up to Tier 3",
		prize = { fish = 30, crates = { [Prizes.HIGHEST] = 1 }, tag = "Grand Opener" },
	},
} :: { Step }
GrandOpening.COUNT = #GrandOpening.STEPS

-- tutorialStep: the strip appears, and pays, from the first catch (#2795, Derek2 11-09 on retention idea 5: "yes"; it was
-- the tutorial's end, 5), so the first table and the first bait cat pay as they happen
GrandOpening.SHOW_FROM_STEP = 2
GrandOpening.FROM_VERSION = 41 -- the save version that brought it
GrandOpening.TAG = "tag_grand_opener" -- the chat tag milestone 8 gives (ChatTags.TAGS)
-- #1922: the cafe front's models (Model-Agent's #1928), placed at the plot pivot
GrandOpening.RIBBON = "CatCafe_Plot_GrandOpeningRibbon"
GrandOpening.BUNTING = "CatCafe_Plot_GrandOpeningBunting"
GrandOpening.BUNTING_SECONDS = 7200 -- seconds of play the bunting stays after the last milestone

function GrandOpening.fresh(): Types.GrandOpeningState
	return { done = {} }
end

function GrandOpening.sanitize(
	raw: unknown,
	fromVersion: number,
	tier: number
): Types.GrandOpeningState
	if fromVersion < GrandOpening.FROM_VERSION then
		if tier >= 3 then
			return { done = {}, finished = true }
		end
		return GrandOpening.fresh()
	end
	local state = GrandOpening.fresh()
	if type(raw) ~= "table" then
		return state
	end
	local done = (raw :: any).done
	if type(done) == "table" then
		for n = 1, GrandOpening.COUNT do
			if done[n] == true then
				state.done[n] = true
			end
		end
	end
	if (raw :: any).finished == true then
		state.finished = true
		local at = (raw :: any).finishedAt
		if type(at) == "number" and at == at and at >= 0 and at < math.huge then
			state.finishedAt = at
		end
	end
	return state
end

function GrandOpening.active(profile: Types.PlayerProfile): boolean
	return profile.grandOpening.finished ~= true
		and profile.tutorialStep >= GrandOpening.SHOW_FROM_STEP
end

-- A cat from the Park in the collection (a spare cat counts by its old area), as the onboarding funnel's
-- first_park_catch reads it.
local function ownsParkCat(profile: Types.PlayerProfile): boolean
	for catId in profile.collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and (def.area == "park" or def.incomeArea == "park") then
			return true
		end
	end
	return false
end

-- Every role slot the tier (and any extra slot) opens has a cat on it, at Tier 2 or above (Design on #1896: Tier 1's
-- few slots fill right after the tutorial, so the step waited for nothing).
local function fullCafe(profile: Types.PlayerProfile): boolean
	if Economy.tier(profile) < 2 then
		return false
	end
	local open = Catalog.openSlotCount(Economy.tier(profile), Economy.extraSlots(profile))
	if open <= 0 then
		return false
	end
	for index, spot in Catalog.allSpots do
		if index > open then
			break
		end
		if Economy.catOnSpot(profile, spot.id) == nil then
			return false
		end
	end
	return true
end

function GrandOpening.met(profile: Types.PlayerProfile, n: number): boolean
	if n == 1 then
		return Economy.level(profile, "tables") >= 1
	elseif n == 2 then
		return profile.stats.baitsTamed + profile.stats.baitsLetGo >= 1
	elseif n == 3 then
		return Economy.distinctCats(profile) >= Catalog.tiers[2].distinctCats -- #4188: 3 (4 for #4098, 5 before)
	elseif n == 4 then
		return Economy.tier(profile) >= 2
	elseif n == 5 then
		return ownsParkCat(profile)
	elseif n == 6 then
		return fullCafe(profile)
	elseif n == 7 then
		return Economy.distinctCats(profile) >= 12 -- Tier 3's own need (Catalog's distinctCats)
	elseif n == 8 then
		return Economy.tier(profile) >= 3
	end
	return false
end

function GrandOpening.due(profile: Types.PlayerProfile): { number }
	local out: { number } = {}
	if not GrandOpening.active(profile) then
		return out
	end
	for n = 1, GrandOpening.COUNT do
		if profile.grandOpening.done[n] ~= true and GrandOpening.met(profile, n) then
			table.insert(out, n)
		end
	end
	return out
end

function GrandOpening.mark(state: Types.GrandOpeningState, n: number, played: number?)
	state.done[n] = true
	if n == GrandOpening.COUNT then
		state.finished = true
		state.finishedAt = played
	end
end

function GrandOpening.plotLook(profile: Types.PlayerProfile, played: number): string?
	if GrandOpening.active(profile) then
		return GrandOpening.RIBBON
	end
	local state = profile.grandOpening
	local at = state.finishedAt
	if state.finished == true and at ~= nil and played - at < GrandOpening.BUNTING_SECONDS then
		return GrandOpening.BUNTING
	end
	return nil
end

function GrandOpening.current(state: Types.GrandOpeningState): number?
	if state.finished == true then
		return nil
	end
	for n = 1, GrandOpening.COUNT do
		if state.done[n] ~= true then
			return n
		end
	end
	return nil
end

-- How many milestones are done (the strip's "Grand Opening 3/8").
function GrandOpening.doneCount(state: Types.GrandOpeningState): number
	local count = 0
	for n = 1, GrandOpening.COUNT do
		if state.done[n] == true then
			count += 1
		end
	end
	return count
end

function GrandOpening.view(state: Types.GrandOpeningState): Types.GrandOpeningState
	return { done = table.clone(state.done), finished = state.finished }
end

return GrandOpening
