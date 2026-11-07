--!strict
-- Equip best: the placement of owned cats on open role slots that earns the most. Pure, no Roblox services.
--
-- Each cat is worth rating x 1.5 in a slot of its favorite role and rating x 1 elsewhere, so this is a weighted
-- assignment problem (slots on one side, cats on the other). Greedy by rating is wrong when a slightly weaker
-- cat is the only one that loves a free slot, so the Hungarian algorithm is used instead. The matrix is at most
-- 10 slots by N cats, which is far too small to matter for cost. A tiny bonus for staying on the current spot
-- means ties never shuffle cats around the cafe for no gain.
-- #1955 (auto-equip.md): Auto Equip runs the same plan with some cats held where they are (`planKeeping`): a locked cat
-- already working, a cat the player placed or rested by hand in the last Config.AutoEquipHoldSeconds, and a cat on
-- offer in a trade (`held`). A held working cat keeps its slot; a held resting cat stays resting.
-- #2050 (the greeter "teleport", Animation-Engineer 2026-11-07): Auto Equip's plan is also sticky. A cat already on a
-- slot counts AUTO_STAY more there, so a level up that makes another cat a hair better doesn't move cats (each move
-- rebuilds the cat's model). Only a real gain moves anyone; the manual Equip Best button still plans exactly.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local EquipBest = {}

export type Plan = {
	placements: { [string]: string }, -- uid -> spotId; any owned uid missing here rests in the cat room
	baseRate: number, -- sum of cat x slot values before the cafe and tier multipliers
	spotsOpen: number,
	catsPlaced: number,
}

local STAY_BONUS = 1e-6 -- below any real difference in value; only breaks exact ties
EquipBest.AUTO_STAY = 0.05 -- #2050: Auto Equip moves a working cat only for a cat worth over 5% more in that plan
local INF = math.huge

-- Value of one cat in one slot for an owner at `tier`: rating x favorite role multiplier. 0 for an unknown cat.
function EquipBest.value(instance: Types.CatInstance, spot: Types.SpotDef, tier: number?): number
	local def = Catalog.getCat(instance.catId)
	if def == nil then
		return 0
	end
	local favorite = if def.favoriteRole == spot.spotType then Config.FavoriteMultiplier else 1
	return CatStats.rating(instance, tier) * favorite
end

-- Hungarian algorithm (minimising), rows 1..n, columns 1..m with n <= m. cost[i][j] is a number.
-- Returns assignment[i] = j. Standard O(n^2 m) potential method.
local function hungarian(cost: { { number } }, n: number, m: number): { number }
	local u: { number } = table.create(n + 1, 0)
	local v: { number } = table.create(m + 1, 0)
	local p: { number } = table.create(m + 1, 0) -- p[j] = row matched to column j (0 = none); index 0 used
	local way: { number } = table.create(m + 1, 0)
	for i = 0, n do
		u[i] = 0
	end
	for j = 0, m do
		v[j] = 0
		p[j] = 0
		way[j] = 0
	end

	for i = 1, n do
		p[0] = i
		local j0 = 0
		local minv: { number } = {}
		local used: { boolean } = {}
		for j = 0, m do
			minv[j] = INF
			used[j] = false
		end
		repeat
			used[j0] = true
			local i0 = p[j0]
			local delta = INF
			local j1 = 0
			for j = 1, m do
				if not used[j] then
					local cur = cost[i0][j] - u[i0] - v[j]
					if cur < minv[j] then
						minv[j] = cur
						way[j] = j0
					end
					if minv[j] < delta then
						delta = minv[j]
						j1 = j
					end
				end
			end
			for j = 0, m do
				if used[j] then
					u[p[j]] += delta
					v[j] -= delta
				else
					minv[j] -= delta
				end
			end
			j0 = j1
		until p[j0] == 0
		repeat
			local j1 = way[j0]
			p[j0] = p[j1]
			j0 = j1
		until j0 == 0
	end

	local assignment: { number } = table.create(n, 0)
	for j = 1, m do
		if p[j] ~= 0 then
			assignment[p[j]] = j
		end
	end
	return assignment
end

-- Open spots in catalog order.
function EquipBest.openSpots(profile: Types.PlayerProfile): { Types.SpotDef }
	local open: { Types.SpotDef } = {}
	for _, spot in Catalog.allSpots do -- #1624: the pass-only slots too
		if Economy.spotIsOpen(profile, spot.id) then
			table.insert(open, spot)
		end
	end
	return open
end

-- Owned cats in a stable order (best first) so the result never depends on hash iteration order.
local function orderedCats(profile: Types.PlayerProfile): { Types.CatInstance }
	local cats: { Types.CatInstance } = {}
	for _, instance in profile.cats do
		table.insert(cats, instance)
	end
	table.sort(cats, CatStats.betterFor(profile.tier))
	return cats
end

-- The best placement of `cats` on `spots` (the cats best first).
-- `stay` (default 0) is how much more a cat counts on the slot it already has (#2050); the plan's baseRate is
-- always the true value.
local function planFor(
	profile: Types.PlayerProfile,
	spots: { Types.SpotDef },
	cats: { Types.CatInstance },
	stay: number?
): Plan
	local keep = 1 + math.max(0, stay or 0)
	local n = #spots
	local placements: { [string]: string } = {}
	if n == 0 or #cats == 0 then
		return { placements = placements, baseRate = 0, spotsOpen = n, catsPlaced = 0 }
	end

	-- Columns: every cat, then enough empty "nobody" columns so every spot can be left empty (n <= m).
	local m = math.max(#cats, n)
	local cost: { { number } } = {}
	for i, spot in spots do
		local row: { number } = table.create(m, 0)
		for j, instance in cats do
			local value = EquipBest.value(instance, spot, profile.tier)
			if value > 0 and instance.spotId == spot.id then
				value = value * keep + STAY_BONUS
			end
			row[j] = -value
		end
		for j = #cats + 1, m do
			row[j] = 0
		end
		cost[i] = row
	end

	local assignment = hungarian(cost, n, m)
	local baseRate = 0
	local placed = 0
	for i, spot in spots do
		local j = assignment[i] -- 0 when the spot stays empty (table.create fills with 0)
		local instance = if j >= 1 then cats[j] else nil
		if instance ~= nil then
			local value = EquipBest.value(instance, spot, profile.tier)
			if value > 0 then
				placements[instance.uid] = spot.id
				baseRate += value
				placed += 1
			end
		end
	end
	return { placements = placements, baseRate = baseRate, spotsOpen = n, catsPlaced = placed }
end

function EquipBest.plan(profile: Types.PlayerProfile): Plan
	return planFor(profile, EquipBest.openSpots(profile), orderedCats(profile))
end

-- #1955: the cats Auto Equip leaves where they are at `now` (os.clock()): a locked cat that is working, a cat placed
-- or rested by hand (`handAt[uid]`, os.clock()) less than AutoEquipHoldSeconds ago, and a cat `offered` in a trade.
function EquipBest.held(
	profile: Types.PlayerProfile,
	now: number,
	handAt: { [string]: number },
	offered: (uid: string) -> boolean
): { [string]: boolean }
	local held: { [string]: boolean } = {}
	for uid, instance in profile.cats do
		local at = handAt[uid]
		if
			(instance.locked == true and instance.spotId ~= nil)
			or (at ~= nil and now - at < Config.AutoEquipHoldSeconds)
			or offered(uid)
		then
			held[uid] = true
		end
	end
	return held
end

-- #1955: Equip Best's plan with the `held` cats kept where they are: a held working cat keeps its open slot (and its
-- value counts), the other cats share the rest of the open slots. `stay` as planFor (Auto Equip passes AUTO_STAY).
function EquipBest.planKeeping(
	profile: Types.PlayerProfile,
	held: { [string]: boolean },
	stay: number?
): Plan
	local kept: { [string]: string } = {}
	local keptRate = 0
	local taken: { [string]: boolean } = {}
	for uid, instance in profile.cats do
		if held[uid] and instance.spotId ~= nil then
			local spot = Catalog.getSpot(instance.spotId :: string)
			if spot ~= nil and Economy.spotIsOpen(profile, spot.id) and not taken[spot.id] then
				kept[uid] = spot.id
				taken[spot.id] = true
				keptRate += EquipBest.value(instance, spot, profile.tier)
			end
		end
	end
	local spots: { Types.SpotDef } = {}
	for _, spot in EquipBest.openSpots(profile) do
		if not taken[spot.id] then
			table.insert(spots, spot)
		end
	end
	local cats: { Types.CatInstance } = {}
	for _, instance in orderedCats(profile) do
		if not held[instance.uid] then
			table.insert(cats, instance)
		end
	end
	local plan = planFor(profile, spots, cats, stay)
	local placed = plan.catsPlaced
	for uid, spotId in kept do
		plan.placements[uid] = spotId
		placed += 1
	end
	return {
		placements = plan.placements,
		baseRate = plan.baseRate + keptRate,
		spotsOpen = #EquipBest.openSpots(profile),
		catsPlaced = placed,
	}
end

-- Writes the plan into the profile. Returns how many cats changed spot (placed, moved or rested).
function EquipBest.apply(profile: Types.PlayerProfile, plan: Plan): number
	local changed = 0
	for uid, instance in profile.cats do
		local target = plan.placements[uid]
		if instance.spotId ~= target then
			instance.spotId = target
			changed += 1
		end
	end
	return changed
end

-- Unequip all: rests every working cat in the cat room. Returns how many cats left a role.
function EquipBest.restAll(profile: Types.PlayerProfile): number
	local rested = 0
	for _, instance in profile.cats do
		if instance.spotId ~= nil then
			instance.spotId = nil
			rested += 1
		end
	end
	return rested
end

-- True when the current placement already earns the plan's rate (nothing to do).
function EquipBest.isOptimal(profile: Types.PlayerProfile, plan: Plan): boolean
	local current = 0
	for _, instance in profile.cats do
		if instance.spotId ~= nil then
			local spot = Catalog.getSpot(instance.spotId :: string)
			if spot ~= nil and Economy.spotIsOpen(profile, spot.id) then
				current += EquipBest.value(instance, spot, profile.tier)
			end
		end
	end
	return current >= plan.baseRate - 1e-9
end

return EquipBest
