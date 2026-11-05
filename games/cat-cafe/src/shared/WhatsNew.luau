--!strict
-- "What's new" on the Thank You board (#1216, idea-credits.md section 7): the latest updates, newest first. The board's
-- WhatsNewPanel (UI-Engineer's Screens/ThanksBoard) reads this module on the client and shows the first SHOWN rows.
-- Whoever opens a publish PR adds one row at the top: one line per update, not per PR (section 7b).
--   id        unique, snake_case
--   date      YYYY-MM-DD, UTC; rows never go back in time
--   icon      one of ICONS: new (a place, shop or feature), cat, look (art, UI or decor), faster, fix
--   text      at most TEXT_MAX characters, sentence case, no full stop, no hype, no prices, never a Robux item
--   creditId  optional: the credit's short id in IdeaCredits_v1 (c1, c2 ...) when the update came from a player's
--             idea; never a user id or a name, since the repo is public
-- WhatsNew.spec checks every rule, so a bad row fails the gate.

local WhatsNew = {}

export type Icon = "new" | "cat" | "look" | "faster" | "fix"
export type Row = { id: string, date: string, icon: Icon, text: string, creditId: string? }

WhatsNew.ICONS = table.freeze({ "new", "cat", "look", "faster", "fix" })
WhatsNew.TEXT_MAX = 28
WhatsNew.SHOWN = 5

WhatsNew.rows = table.freeze({
	{ id = "cat_food_bag", date = "2026-11-05", icon = "new", text = "Bag with cat food to feed" },
	{
		id = "corner_shop_sizes",
		date = "2026-11-05",
		icon = "new",
		text = "Corner Shop sizes and tiers",
	},
	{
		id = "cannon_aim",
		date = "2026-11-04",
		icon = "faster",
		text = "Cannons fly straight to pads",
	},
	{ id = "wall_art", date = "2026-11-04", icon = "look", text = "Wall art off the back window" },
	{ id = "thanks_board", date = "2026-11-04", icon = "new", text = "Thank You board in town" },
} :: { Row })
for _, row in WhatsNew.rows do
	table.freeze(row)
end

-- The rows the board shows: the newest SHOWN, or all of them when there are fewer (it never pads).
function WhatsNew.latest(): { Row }
	return table.move(WhatsNew.rows, 1, math.min(WhatsNew.SHOWN, #WhatsNew.rows), 1, {})
end

-- "Nov 4" for "2026-11-04" (UTC month and day, never "2 days ago"); "" for a malformed date.
local MONTHS =
	{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function WhatsNew.shortDate(date: string): string
	local month, day = string.match(date, "^%d%d%d%d%-(%d%d)%-(%d%d)$")
	local m, d = tonumber(month), tonumber(day)
	if m == nil or d == nil or MONTHS[m] == nil then
		return ""
	end
	return string.format("%s %d", MONTHS[m], d)
end

return WhatsNew
