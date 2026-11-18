--!strict
-- #5296: the Companion picker's pure part, kept apart from the screen so specs need no UI (Components/CompanionPicker).
--   CompanionLogic.order(cats, catById) -> { Types.CatInstance }   best first

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

return CompanionLogic
