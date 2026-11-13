--!strict
-- #3700 (Derek 2026-11-12: "make the picking the cat menu better and make sure to add rarity/level sorting"): the
-- order, the filters and the row words of a "pick a cat" list, shared by every menu that has one (cat-picker.md).
-- Used first by the Mystic Pool. Pure: no instances.
--   SORTS, sorted(cats, sort, flipped)   Money (the default since #3874), Rarity, Level or Name; `flipped` turns it
--   MENU_SORTS, menuSort(sort)           Money, Level, Rarity: the Filter pop-up's sorts (#3874)
--   FILTERS, match(cat, query, filter)   All, Resting, Working, No trait, Has trait, with the search words
--   matchShown(cat, query, shown)        #3940: several Show chips at once (Working and No trait on top of each other)
--   toggleShown, anyShown                a chip press ("All" turns every chip off) and whether any chip is on
--   packShown, unpackShown               the chips that are on as the catPickShow setting ("Working,No trait")
--   rarity(cat), coatTag(cat)            "Mythical" and "GOLD" / "RAINBOW" for the row's tags
--   line(cat, rate)                      "Lv 37 · Working · +$410/s"
--   count(shown)                         "42 cats", "1 cat", "0 cats match"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any

local CatPickLogic = {}

CatPickLogic.SORTS = { "Rarity", "Level", "Money", "Name" }
-- #3874 (Derek 2026-11-13: "Make the default sort by money"): Rarity before
CatPickLogic.DEFAULT_SORT = "Money"
-- #3874 (Derek 2026-11-13: "just sort by level/rarity/money(s)", then "a search bar and a filter menu"): the sorts
-- and filters in the Filter pop-up
CatPickLogic.MENU_SORTS = { "Money", "Level", "Rarity" }
CatPickLogic.MENU_FILTERS = { "All", "Working", "Resting", "No trait", "Has trait" }

-- `sort` when the Filter pop-up has it, else the default (a remembered Name sort from before #3874).
function CatPickLogic.menuSort(sort: string?): string
	for _, name in CatPickLogic.MENU_SORTS do
		if name == sort then
			return name
		end
	end
	return CatPickLogic.DEFAULT_SORT
end
CatPickLogic.FILTERS = { "All", "Resting", "Working", "No trait", "Has trait" }

local COAT_RANK: { [string]: number } = { rainbow = 2, gold = 1 }

local function def(cat: any): any
	return Catalog.getCat(cat.catId)
end

local function number(value: any): number
	return if type(value) == "number" then value else 0
end

local function hasTrait(cat: any): boolean
	return type(cat.trait) == "table" and type(cat.trait.id) == "string"
end

local function breed(cat: any): string
	local found = def(cat)
	return if found ~= nil and type(found.name) == "string" then found.name else tostring(cat.catId)
end

local function coatWord(cat: any): string
	if cat.variant == "rainbow" then
		return "Rainbow "
	end
	return if cat.variant == "gold" then "Gold " else ""
end

-- The row's first line: the cat's own name, else its coat and breed.
function CatPickLogic.title(cat: any): string
	if type(cat.name) == "string" and cat.name ~= "" then
		return cat.name
	end
	return coatWord(cat) .. breed(cat)
end

-- The cat's rarity word ("Mythical"), "Common" when its kind is not known.
function CatPickLogic.rarity(cat: any): string
	local found = def(cat)
	return if found ~= nil and type(found.rarity) == "string" then found.rarity else "Common"
end

-- "GOLD" or "RAINBOW" for a coat, nil for a plain cat.
function CatPickLogic.coatTag(cat: any): string?
	if cat.variant == "rainbow" then
		return "RAINBOW"
	end
	return if cat.variant == "gold" then "GOLD" else nil
end

-- "Lv 37 · Working · +$410/s"; `rate` is the cat's pay as the caller words it (Format.rate), left out when nil.
function CatPickLogic.line(cat: any, rate: string?): string
	local job = if cat.spotId ~= nil then "Working" else "Resting"
	local words = string.format("Lv %d · %s", math.max(1, math.floor(number(cat.level))), job)
	return if rate ~= nil then words .. " · " .. rate else words
end

function CatPickLogic.sort(value: unknown): string
	if type(value) == "string" then
		for _, name in CatPickLogic.SORTS do
			if string.lower(name) == string.lower(value) then
				return name
			end
		end
	end
	return CatPickLogic.DEFAULT_SORT
end

-- The cats in `sort` order, best first (A to Z for Name); `flipped` turns that round. The uid settles what is left,
-- so the order never flickers between two builds.
--   Rarity  highest rarity, then rainbow before gold before plain, then level, then name
--   Level   highest level, then rarity, then name
--   Money   highest pay a second, then rarity, then name
--   Name    A to Z
function CatPickLogic.sorted(cats: { [string]: any }?, sort: string?, flipped: boolean?): { any }
	local out: { any } = {}
	if cats == nil then
		return out
	end
	local ranks: { [string]: number } = {}
	local names: { [string]: string } = {}
	for _, cat in cats do
		if type(cat) == "table" and type(cat.uid) == "string" then
			table.insert(out, cat)
			ranks[cat.uid] = number(Catalog.rarityRank[CatPickLogic.rarity(cat)])
			names[cat.uid] = string.lower(CatPickLogic.title(cat))
		end
	end
	local by = CatPickLogic.sort(sort)
	-- the keys in order, each larger first; the name and uid come after and are never flipped apart from Name
	local function keys(cat: any): (number, number, number)
		local rank, level = ranks[cat.uid], number(cat.level)
		if by == "Level" then
			return level, rank, 0
		elseif by == "Money" then
			return number(cat.rating), rank, 0
		elseif by == "Name" then
			return 0, 0, 0
		end
		return rank, COAT_RANK[cat.variant] or 0, level
	end
	local turn = flipped == true
	table.sort(out, function(a: any, b: any): boolean
		local a1, a2, a3 = keys(a)
		local b1, b2, b3 = keys(b)
		if a1 ~= b1 then
			return (a1 > b1) ~= turn
		end
		if a2 ~= b2 then
			return (a2 > b2) ~= turn
		end
		if a3 ~= b3 then
			return (a3 > b3) ~= turn
		end
		if names[a.uid] ~= names[b.uid] then
			return (names[a.uid] < names[b.uid]) ~= (turn and by == "Name")
		end
		return a.uid < b.uid
	end)
	return out
end

-- #3940 (Derek 2026-11-13: "make the buttons in mystic be able to have multiple filters toggled on like working/no
-- trait on top of eachother"): the Show chips in two groups. A cat shows when, in every group with a chip on, it fits
-- one of the chips that are on. So Working with No trait lists working cats with no trait, and Working with Resting
-- lists every cat. All is no chip on.
CatPickLogic.SHOW_GROUPS = { { "Working", "Resting" }, { "No trait", "Has trait" } }
CatPickLogic.SHOW_CHIPS = { "Working", "Resting", "No trait", "Has trait" } -- the order packShown writes them in

export type Shown = { [string]: boolean }

local function fits(cat: any, chip: string): boolean
	if chip == "Working" then
		return cat.spotId ~= nil
	elseif chip == "Resting" then
		return cat.spotId == nil
	elseif chip == "No trait" then
		return not hasTrait(cat)
	elseif chip == "Has trait" then
		return hasTrait(cat)
	end
	return true
end

local function words(cat: any, query: string?): boolean
	local typed = string.lower(string.match(query or "", "^%s*(.-)%s*$") or "")
	if typed == "" then
		return true
	end
	local own = if type(cat.name) == "string" then cat.name else ""
	local hay = string.lower(own .. " " .. coatWord(cat) .. breed(cat))
	return string.find(hay, typed, 1, true) ~= nil
end

-- Whether a cat shows under the search words and one filter chip. The words are found in the cat's own name, its
-- coat or its breed, any case.
function CatPickLogic.match(cat: any, query: string?, filter: string?): boolean
	if filter ~= nil and filter ~= "All" and not fits(cat, filter) then
		return false
	end
	return words(cat, query)
end

function CatPickLogic.matchShown(cat: any, query: string?, shown: Shown?): boolean
	if shown ~= nil then
		for _, group in CatPickLogic.SHOW_GROUPS do
			local any, fit = false, false
			for _, chip in group do
				if shown[chip] then
					any = true
					fit = fit or fits(cat, chip)
				end
			end
			if any and not fit then
				return false
			end
		end
	end
	return words(cat, query)
end

-- A press on a Show chip: All turns every chip off, any other chip turns itself on or off. A new table.
function CatPickLogic.toggleShown(shown: Shown?, chip: string): Shown
	local out: Shown = {}
	if chip == "All" or table.find(CatPickLogic.SHOW_CHIPS, chip) == nil then
		return out
	end
	for _, name in CatPickLogic.SHOW_CHIPS do
		local on = shown ~= nil and shown[name] == true
		if name == chip then
			on = not on
		end
		if on then
			out[name] = true
		end
	end
	return out
end

function CatPickLogic.anyShown(shown: Shown?): boolean
	if shown ~= nil then
		for _, name in CatPickLogic.SHOW_CHIPS do
			if shown[name] then
				return true
			end
		end
	end
	return false
end

-- The chips that are on as the catPickShow setting: their names in SHOW_CHIPS order, joined by commas ("" for All).
function CatPickLogic.packShown(shown: Shown?): string
	local on: { string } = {}
	for _, name in CatPickLogic.SHOW_CHIPS do
		if shown ~= nil and shown[name] then
			table.insert(on, name)
		end
	end
	return table.concat(on, ",")
end

-- The setting back to chips; names it does not know are dropped, so an odd value reads as All.
function CatPickLogic.unpackShown(text: unknown): Shown
	local out: Shown = {}
	if type(text) == "string" then
		for name in string.gmatch(text, "[^,]+") do
			if table.find(CatPickLogic.SHOW_CHIPS, name) ~= nil then
				out[name] = true
			end
		end
	end
	return out
end

-- The count beside the chips.
function CatPickLogic.count(shown: number): string
	if shown <= 0 then
		return "0 cats match"
	end
	return if shown == 1 then "1 cat" else string.format("%d cats", shown)
end

return CatPickLogic
