--!strict
-- #5505 part 1 (Design-Agent's come-back-tomorrow-spec.md section 3, Derek 2026-11-19: "away money and daily reward
-- milestones", "focus on updates to help with funnel drop offs and retention"): the total UTC days an account has
-- played, never a streak and never lost, with six milestone gifts, behind the switch `awayPromise`
-- (LiveFlags.OFF_BY_DEFAULT). The cats are picked by rule, never rolled: the given rarity from the player's newest
-- area, a kind they don't own first, else the first of that rarity there. Nothing is random and nothing is for Robux.
-- Saved as profile.daysPlayed = { count, last, paid } (paid: the highest milestone day paid). An existing save starts
-- at 1 on its next join. No VERSION bump: an older server dropping it can only count a day again from 0, so the
-- switch goes on only after a restart Derek calls. Pure but for Catalog.
--   MILESTONES                                  the six gifts, by day count
--   sanitize(raw) -> State?                     a save's field made safe
--   note(state?, day) -> (State, boolean)       count `day` if it is a new one (true when it counted)
--   due(state) -> Milestone?                    the next milestone reached and not yet paid
--   next(state) -> Milestone?                   the next milestone still ahead, for the board's row
--   pickCat(rarity, tier, collection) -> string?  the cat id a cat milestone gives

local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

local DaysPlayed = {}

DaysPlayed.FLAG = "awayPromise"
DaysPlayed.DAY_SECONDS = 86400
DaysPlayed.EVENT = "days_played" -- value the day number; fields the milestone's kind, device

export type State = { count: number, last: number, paid: number }
export type Milestone = { days: number, prize: Types.IndexPrize?, cat: string? }

local MILESTONES: { Milestone } = {
	{ days = 2, prize = { fish = 100, spins = 3 } },
	{ days = 3, cat = "Rare" },
	{ days = 5, prize = { crates = { classic_golden_crate = 1 }, potions = { lucky_potion = 1 } } },
	{ days = 7, cat = "Epic" },
	{ days = 14, prize = { fish = 500, crates = { classic_golden_crate = 2 } } },
	{ days = 30, cat = "Legendary" },
}
table.freeze(MILESTONES)
DaysPlayed.MILESTONES = MILESTONES

function DaysPlayed.day(now: number): number
	return math.floor(now / DaysPlayed.DAY_SECONDS)
end

local function whole(raw: unknown): number?
	if type(raw) == "number" and raw == raw and raw > -math.huge and raw < math.huge then
		return math.floor(raw)
	end
	return nil
end

function DaysPlayed.sanitize(raw: unknown): State?
	if type(raw) ~= "table" then
		return nil
	end
	local count = whole((raw :: any).count)
	local last = whole((raw :: any).last)
	if count == nil or last == nil then
		return nil
	end
	return {
		count = math.clamp(count, 0, 100000),
		last = last,
		paid = math.clamp(whole((raw :: any).paid) or 0, 0, 100000),
	}
end

function DaysPlayed.note(state: State?, day: number): (State, boolean)
	if state == nil then
		return { count = 1, last = day, paid = 0 }, true
	end
	if day > state.last then
		state.count += 1
		state.last = day
		return state, true
	end
	return state, false
end

function DaysPlayed.due(state: State): Milestone?
	for _, milestone in MILESTONES do
		if milestone.days > state.paid and state.count >= milestone.days then
			return milestone
		end
	end
	return nil
end

function DaysPlayed.next(state: State): Milestone?
	for _, milestone in MILESTONES do
		if milestone.days > state.paid and milestone.days > state.count then
			return milestone
		end
	end
	return nil
end

-- The area a player at `tier` opened last: the highest tier area at or below it.
function DaysPlayed.newestArea(tier: number): string?
	local best: Types.AreaDef? = nil
	for _, area in Catalog.areas do
		if area.tier <= tier and (best == nil or area.tier > (best :: Types.AreaDef).tier) then
			best = area
		end
	end
	return if best ~= nil then best.id else nil
end

-- The cat a cat milestone gives: `rarity` from the newest area, a kind not in `collection` first, else the first of
-- that rarity there; with none of that rarity in the newest area, the next area down. Never an exclusive cat.
function DaysPlayed.pickCat(rarity: string, tier: number, collection: { [string]: any }): string?
	local step = math.floor(tier)
	while step >= 1 do
		local areaId = DaysPlayed.newestArea(step)
		local first: string? = nil
		for _, def in Catalog.cats do
			if def.area == areaId and def.rarity == rarity and def.exclusive ~= true then
				if collection[def.id] == nil then
					return def.id
				end
				first = first or def.id
			end
		end
		if first ~= nil then
			return first
		end
		step -= 1
	end
	return nil
end

return DaysPlayed
