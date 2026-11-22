--!strict
-- Growth Nov 22 (custom-event-names-with-data.md): 49 of Telemetry's 254 custom event names have never had data in
-- Creator Hub, while others sent from the same function do (Roblox refuses some names, cause not pinned down). With
-- the eventFold switch on, Telemetry.custom sends the important dark ones under a name that records, the old name's
-- meaning in field 1. Pure, so the cloud specs check it.
--   FLAG                      the switch (LiveFlags eventFold, off by default)
--   fold(name, value, fields) -> (name, fields)   the name and fields to send: the host and its fields for a folded
--                             name, else the same name and fields. The value is never changed.
--
-- The hosts and their field 1 (Growth filters the host by field 1 to read the old event):
--   picnic_cat_caught         picnic_started   "cat_<n>" (value n), rarity, cat id
--   start_cannon              free_start       "cannon_town" or "cannon_camp" (value seconds), lit_walk or picker
--   hood_welcome              tier3_trip       "welcome_shown" or "welcome_caught", rarity
--   days_played               daily_gift       "days_<n>" (value n), cat or prize, device
--   return_card               daily_gift       "return_<line>" (value hours away), ready, device
--   quick_return              daily_gift       "quick_<away bucket>" (value minutes away), furthest step, sessions
--   rank_up_spotlight_closed  rank_up_spotlight_shown   device, "closed" (shown has only device)
--   snowglobe_catch           camp_extra       "snowglobe", "catch", rarity (value Snowflakes given)
--   gift_buy                  camp_extra       "gift_stall", item id, tier (value Snowflakes before)

local EventFold = {}

EventFold.FLAG = "eventFold"

type Fields = { string }
type Folder = (value: number, fields: Fields) -> (string, Fields)

local function at(fields: Fields, i: number): string
	return fields[i] or "unknown"
end

local function whole(value: number): string
	return if value == value then tostring(math.max(0, math.floor(value))) else "0"
end

local FOLDS: { [string]: Folder } = {
	picnic_cat_caught = function(value, fields)
		return "picnic_started", { "cat_" .. whole(value), at(fields, 1), at(fields, 2) }
	end,
	start_cannon = function(_, fields)
		return "free_start", { "cannon_" .. at(fields, 1), at(fields, 2) }
	end,
	hood_welcome = function(_, fields)
		return "tier3_trip", { "welcome_" .. at(fields, 1), at(fields, 2) }
	end,
	days_played = function(value, fields)
		return "daily_gift", { "days_" .. whole(value), at(fields, 1), at(fields, 2) }
	end,
	return_card = function(_, fields)
		return "daily_gift", { "return_" .. at(fields, 3), at(fields, 1), at(fields, 2) }
	end,
	quick_return = function(_, fields)
		return "daily_gift", { "quick_" .. at(fields, 2), at(fields, 1), at(fields, 3) }
	end,
	rank_up_spotlight_closed = function(_, fields)
		return "rank_up_spotlight_shown", { at(fields, 1), "closed" }
	end,
	snowglobe_catch = function(_, fields)
		return "camp_extra", { "snowglobe", "catch", at(fields, 1) }
	end,
	gift_buy = function(_, fields)
		return "camp_extra", { "gift_stall", at(fields, 1), at(fields, 2) }
	end,
}

function EventFold.folds(name: string): boolean
	return FOLDS[name] ~= nil
end

function EventFold.fold(name: string, value: number, fields: Fields): (string, Fields)
	local folder = FOLDS[name]
	if folder == nil then
		return name, fields
	end
	return folder(value, fields)
end

return EventFold
