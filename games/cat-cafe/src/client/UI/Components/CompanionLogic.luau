--!strict
-- #5296: the Companion picker's pure part, kept apart from the screen so specs need no UI (Components/CompanionPicker).
--   CompanionLogic.order(cats, catById) -> { Types.CatInstance }   best first
--   CompanionLogic.better(cats, catById, uid) -> { string }            uids that beat the companion `uid` (#5457)
--   CompanionLogic.fresh(better, seen) -> boolean                       one of them not seen yet (#5457)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)

local Follower = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Follower")) :: any

local CompanionLogic = {}

-- Best first: the higher Money, then Luck, then level, then the newest caught; ties by uid so the order holds.
function CompanionLogic.order(
	cats: { [string]: Types.CatInstance }?,
	catById: { [string]: Types.CatDef }
): { Types.CatInstance }
	local list: { Types.CatInstance } = {}
	local all: { [string]: Types.CatInstance } = cats or {}
	for _, cat in all do
		if type(cat) == "table" and catById[cat.catId] ~= nil then
			table.insert(list, cat)
		end
	end
	local function score(cat: Types.CatInstance): (number, number)
		local def = catById[cat.catId]
		local rarity = if def then def.rarity else nil
		return Follower.catAmount(cat, rarity, "money"), Follower.catAmount(cat, rarity, "luck") -- #5303
	end
	table.sort(list, function(a: Types.CatInstance, b: Types.CatInstance): boolean
		local am, al = score(a)
		local bm, bl = score(b)
		if am ~= bm then
			return am > bm
		elseif al ~= bl then
			return al > bl
		elseif (a.level or 1) ~= (b.level or 1) then
			return (a.level or 1) > (b.level or 1)
		elseif (a.caughtAt or 0) ~= (b.caughtAt or 0) then
			return (a.caughtAt or 0) > (b.caughtAt or 0)
		end
		return a.uid < b.uid
	end)
	return list
end

-- #5457 (Derek 2026-11-19: "show an exclamation mark on cat companion if you have a new companion option that is
-- better"): the uids of the cats that would give more than the companion `uid` (none following: every cat), by the
-- picker's own order: more Money, or the same Money and more Luck.
function CompanionLogic.better(
	cats: { [string]: Types.CatInstance }?,
	catById: { [string]: Types.CatDef },
	uid: string?
): { string }
	local all: { [string]: Types.CatInstance } = cats or {}
	local function score(cat: Types.CatInstance?): (number, number)
		if cat == nil then
			return -1, -1
		end
		local def = catById[cat.catId]
		local rarity = if def then def.rarity else nil
		return Follower.catAmount(cat, rarity, "money"), Follower.catAmount(cat, rarity, "luck")
	end
	local nowMoney, nowLuck = score(if uid ~= nil and uid ~= "" then all[uid] else nil)
	local out: { string } = {}
	for key, cat in all do
		if type(cat) == "table" and catById[cat.catId] ~= nil and key ~= uid then
			local money, luck = score(cat)
			if money > nowMoney or (money == nowMoney and luck > nowLuck) then
				table.insert(out, key)
			end
		end
	end
	table.sort(out)
	return out
end

-- #5457: whether one of `better` has not been seen yet. Opening the picker marks them all seen, so the mark clears
-- even when the player keeps the cat they have (some keep one for its look); a newer better cat brings it back.
function CompanionLogic.fresh(better: { string }, seen: { [string]: boolean }): boolean
	for _, uid in better do
		if not seen[uid] then
			return true
		end
	end
	return false
end

return CompanionLogic
