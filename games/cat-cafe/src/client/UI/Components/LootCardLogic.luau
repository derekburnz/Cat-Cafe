--!strict
-- The Rummage Bin's loot card (#3464, Derek 2026-11-12: "show the loot obtained from rummage also"): what the card
-- lists for a win. The server sends the whole win as a list of items (Types.RummageWin.items, each a kind, an id and
-- a count); the card draws exactly that and never works out a prize of its own.
--   TITLE, SECONDS               "You found:" and how long the card stays
--   rows(win) -> { Row }         one row per item: its kind and id for the picture, its name and "x2" or "+10"
--   gold(win) -> boolean         the gold frame: a win that holds a golden crate
-- Pure, so the cloud spec runner checks it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

local LootCardLogic = {}

LootCardLogic.TITLE = "You found:"
LootCardLogic.SECONDS = 4
LootCardLogic.MAX_ROWS = 4
LootCardLogic.ROW_GAP_SECONDS = 0.15 -- the rows land one after the other

export type Row = { kind: string, id: string?, name: string, amount: string }

local KINDS: { [string]: boolean } = { lure = true, crate = true, potion = true, fish = true }

local function nameOf(kind: string, id: string?): string?
	if kind == "fish" then
		return "Golden fish"
	elseif id == nil then
		return nil
	elseif kind == "lure" then
		local lure = Catalog.getLure(id)
		return if lure ~= nil then lure.name else nil
	elseif kind == "crate" then
		local crate = Catalog.getCrate(id)
		return if crate ~= nil then crate.name else nil
	elseif kind == "potion" then
		local potion = Catalog.getPotion(id)
		return if potion ~= nil then potion.name else nil
	end
	return nil
end

-- The rows for a win as the server sent it. Anything that is not a known item with a whole count of 1 or more is
-- left out, so a damaged message draws nothing wrong.
function LootCardLogic.rows(win: unknown): { Row }
	local rows: { Row } = {}
	if type(win) ~= "table" then
		return rows
	end
	local items = (win :: any).items
	if type(items) ~= "table" then
		return rows
	end
	for _, item in items :: { any } do
		if #rows >= LootCardLogic.MAX_ROWS then
			break
		end
		if type(item) ~= "table" then
			continue
		end
		local kind, id, count = item.kind, item.id, item.count
		if type(kind) ~= "string" or not KINDS[kind] then
			continue
		end
		if type(count) ~= "number" or count ~= count or count < 1 then
			continue
		end
		local name = nameOf(kind, if type(id) == "string" then id else nil)
		if name == nil then
			continue
		end
		local whole = math.floor(count)
		table.insert(rows, {
			kind = kind,
			id = if type(id) == "string" then id else nil,
			name = name,
			amount = if kind == "fish"
				then string.format("+%d", whole)
				else string.format("x%d", whole),
		})
	end
	return rows
end

function LootCardLogic.gold(win: unknown): boolean
	for _, row in LootCardLogic.rows(win) do
		if
			row.kind == "crate"
			and row.id ~= nil
			and string.find(row.id, "golden", 1, true) ~= nil
		then
			return true
		end
	end
	return false
end

return LootCardLogic
