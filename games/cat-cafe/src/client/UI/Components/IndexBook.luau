--!strict
-- The Index's pages as one scroll (Derek's Set 4 answer, 2026-11-01: "sorted into a normal and gold tab and a
-- cleaner ui for navigating ... just swap between normal/gold and scroll through area's very simply showing rarity
-- and what hasn't been found with a black filling"). The Cats tab and the Gold tab each list every area in tier
-- order, its cats rarest last. The spare cats (F78) have no page (Derek 2026-10-28: "No need for a spare part of
-- the index has no use").
--   found(state, tab)                    which cats count as found on the tab: met or owned, or found in gold
--   sections(catalog, state, tab)        the areas to scroll through, each with its cats and counts
--   count(section)                       the line beside an area's name: "7 / 10", "Complete!" or "Tier 3"
--   reward(views, track)                 the area's reward button: "ready" with how many, "next", "done" or "none"
--   first(sections)                      the area the Index opens on: the first open one with cats still to find
-- Pure: no Theme, so the cloud spec runner can load it.

local CatVariant = require(script.Parent.CatVariant)
local IndexRewards = require(script.Parent.IndexRewards)
local Types = require(script.Parent.Parent.Types)

export type Tab = "normal" | "gold"

export type Section = {
	id: string, -- an area id
	name: string,
	tier: number,
	locked: boolean, -- the player's tier has not opened the area and nothing in it is found yet
	have: number,
	total: number,
	cats: { Types.CatDef }, -- rarest last, catalog order within a rarity
}

export type Reward = {
	state: "ready" | "next" | "done" | "none",
	ready: number, -- rewards waiting to be claimed on this track
	need: number?, -- what the next one needs, while state is "next"
	toGo: number?,
}

local IndexBook = {}

IndexBook.FALLBACK_AREA = "alley"
IndexBook.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

local SPARE = IndexRewards.SPARE_AREA

local function rank(rarity: string): number
	return table.find(IndexBook.RARITIES, rarity) or 1
end

-- "Neighbourhood" from "neighbourhood" for an area the catalog does not list.
local function titled(id: string): string
	return id:sub(1, 1):upper() .. id:sub(2)
end

function IndexBook.found(state: Types.PlayerState, tab: Tab): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if tab == "gold" then
		for catId in CatVariant.collection(state) do
			out[catId] = true
		end
		return out
	end
	for catId in state.catsOwned do
		out[catId] = true
	end
	local collection: { [string]: number } = state.collection or {}
	for catId in collection do
		out[catId] = true
	end
	return out
end

function IndexBook.sections(catalog: Types.Catalog, state: Types.PlayerState, tab: Tab): { Section }
	local found = IndexBook.found(state, tab)
	local list: { Section } = {}
	local byId: { [string]: Section } = {}
	local function add(id: string, name: string, tier: number)
		local section: Section = {
			id = id,
			name = name,
			tier = tier,
			locked = false,
			have = 0,
			total = 0,
			cats = {},
		}
		table.insert(list, section)
		byId[id] = section
	end
	local areas: { Types.AreaDef } = catalog.areas or {}
	local ordered = table.clone(areas)
	table.sort(ordered, function(a: Types.AreaDef, b: Types.AreaDef): boolean
		return a.tier < b.tier
	end)
	for _, area in ordered do
		add(area.id, area.name, area.tier)
	end
	local order: { [string]: number } = {}
	for index, def in catalog.cats do
		order[def.id] = index
		local areaId: string = def.area or IndexBook.FALLBACK_AREA
		if areaId == SPARE then
			continue
		elseif not byId[areaId] then
			add(areaId, titled(areaId), 0)
		end
		local section = byId[areaId]
		table.insert(section.cats, def)
		section.total += 1
		if found[def.id] then
			section.have += 1
		end
	end
	for _, section in list do
		table.sort(section.cats, function(a: Types.CatDef, b: Types.CatDef): boolean
			local ra, rb = rank(a.rarity), rank(b.rarity)
			if ra ~= rb then
				return ra < rb
			end
			return order[a.id] < order[b.id]
		end)
		section.locked = state.tier < section.tier and section.have == 0
	end
	return list
end

function IndexBook.count(section: Section): string
	if section.locked then
		return "Tier " .. tostring(section.tier)
	elseif section.total > 0 and section.have >= section.total then
		return "Complete!"
	end
	return ("%d / %d"):format(section.have, section.total)
end

-- The area's rewards on one track: how many wait to be claimed, else what the next one needs.
function IndexBook.reward(views: { IndexRewards.View }, track: IndexRewards.Track): Reward
	local ready = 0
	local next: IndexRewards.View? = nil
	local any = false
	for _, view in views do
		if IndexRewards.track(view.milestone) ~= track then
			continue
		end
		any = true
		if view.state == "ready" then
			ready += 1
		elseif view.state == "locked" and next == nil then
			next = view
		end
	end
	if ready > 0 then
		return { state = "ready", ready = ready }
	elseif next then
		return {
			state = "next",
			ready = 0,
			need = IndexRewards.need(next.milestone),
			toGo = IndexRewards.toGo(next),
		}
	end
	return { state = if any then "done" else "none", ready = 0 }
end

function IndexBook.first(sections: { Section }): string?
	for _, section in sections do
		if not section.locked and section.have < section.total then
			return section.id
		end
	end
	local head = sections[1]
	return if head then head.id else nil
end

return IndexBook
