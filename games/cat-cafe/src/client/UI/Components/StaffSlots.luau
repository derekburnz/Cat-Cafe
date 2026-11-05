--!strict
-- The Staff tab of Upgrades (2026-10-27, replaces the floating role slot labels): one row per role with its slots
-- in the order they open, so the player sees at a glance what the next tier unlocks.
--   rows(spots, tier, cats, extra?) -> { Row }
--     a slot is "working" when a cat's spotId is on it, "open" when this tier has opened it and no cat works it,
--     "locked" until its tier. Without cats (state.cats not sent) an opened slot counts as open.
--     #1624: `spots` is Catalog.allSpots (opening order: the tier slots, then the pass-only ones) and `extra` is
--     PlayerState.extraSlots (Grand Cafe and the Extra Slot pass). As the server's Catalog.slotIsOpen counts, the
--     first (slots of this tier or below) + extra spots are open, so an extra slot opens the next tier's spot early.
--     A pass-only slot that is still locked is `hidden` (Slot.hidden), never "opens at Tier 6", and stays out of
--     the counts and the summary; the screens hide its square.
--   Row.summary   "2 working · 1 free", then "· next at Tier 3" while a slot is still locked; "Opens at Tier 3"
--                 for a role with no slot open yet; "All 3 working" when nothing is free or locked.
--   initial(name)  the first letter of a cat's name for its slot square, a whole code point (reviewer S55: names
--                  may start with an accent, kana or an emoji), upper-cased when it is ASCII.
-- Pure, no Theme, so the cloud spec runner can load it.

local Types = require(script.Parent.Parent.Types)

local StaffSlots = {}

export type SlotKind = "working" | "open" | "locked"

export type Slot = {
	spotId: string,
	kind: SlotKind,
	tier: number,
	catUid: string?,
	hidden: boolean?, -- #1624: a pass-only slot the player has not opened; its square is not drawn
}

export type Row = {
	role: string,
	name: string,
	slots: { Slot },
	working: number,
	open: number,
	locked: number,
	nextTier: number?,
	summary: string,
}

-- "barista" -> "Barista", as Format.roleName (Format needs Theme, which the cloud spec runner cannot load)
local function roleName(role: string): string
	return role:sub(1, 1):upper() .. role:sub(2)
end

function StaffSlots.initial(name: string): string
	if name == "" then
		return "?"
	end
	local stop = utf8.offset(name, 2)
	local first = if stop then name:sub(1, stop - 1) else name
	return first:upper()
end

function StaffSlots.rows(
	spots: { Types.SpotDef },
	tier: number,
	cats: { [string]: Types.CatInstance }?,
	extra: number?
): { Row }
	-- the open slots are the first `open` of the list, as Catalog.openSlotCount counts them
	local open = 0
	for _, spot in spots do
		if spot.tier <= tier then
			open += 1
		end
	end
	open = math.min(open + math.max(0, math.floor(extra or 0)), #spots)
	local opened: { [string]: boolean } = {}
	for index, spot in spots do
		opened[spot.id] = index <= open
	end

	local workers: { [string]: string } = {}
	if cats ~= nil then
		for uid, cat in cats do
			local spotId = cat.spotId
			if spotId ~= nil then
				workers[spotId] = uid
			end
		end
	end

	local rows: { Row } = {}
	local byRole: { [string]: Row } = {}
	for _, spot in spots do
		local row = byRole[spot.spotType]
		if row == nil then
			local created: Row = {
				role = spot.spotType,
				name = roleName(spot.spotType),
				slots = {},
				working = 0,
				open = 0,
				locked = 0,
				nextTier = nil,
				summary = "",
			}
			byRole[spot.spotType] = created
			table.insert(rows, created)
			row = created
		end
		local catUid = workers[spot.id]
		local kind: SlotKind = if not opened[spot.id]
			then "locked"
			elseif catUid ~= nil then "working"
			else "open"
		local passOnly = (spot :: any).passOnly == true
		table.insert(row.slots, {
			spotId = spot.id,
			kind = kind,
			tier = spot.tier,
			catUid = catUid,
			hidden = if passOnly and kind == "locked" then true else nil,
		})
	end

	for _, row in rows do
		table.sort(row.slots, function(a: Slot, b: Slot): boolean
			return a.tier < b.tier
		end)
		for _, slot in row.slots do
			if slot.kind == "working" then
				row.working += 1
			elseif slot.kind == "open" then
				row.open += 1
			elseif slot.hidden then
				continue
			else
				row.locked += 1
				local soonest = row.nextTier
				if soonest == nil or slot.tier < soonest then
					row.nextTier = slot.tier
				end
			end
		end
		local nextTier = row.nextTier
		if row.working + row.open == 0 and nextTier ~= nil then
			row.summary = ("Opens at Tier %d"):format(nextTier)
		elseif row.open == 0 and nextTier == nil then
			row.summary = ("All %d working"):format(row.working)
		else
			local parts = {}
			if row.working > 0 then
				table.insert(parts, ("%d working"):format(row.working))
			end
			if row.open > 0 then
				table.insert(parts, ("%d free"):format(row.open))
			end
			if nextTier ~= nil then
				table.insert(parts, ("next at Tier %d"):format(nextTier))
			end
			row.summary = table.concat(parts, " · ")
		end
	end
	return rows
end

return StaffSlots
