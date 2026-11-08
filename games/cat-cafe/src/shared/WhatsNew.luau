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
--   thanks    optional (Derek2 2026-11-07: "mention of peoples fixes/suggestions ... it can use their roblox names"):
--             the Roblox username of a playtester whose report or suggestion this update came from, only for the
--             playtesters Derek2 has named; the board shows "💡 Thanks to <name>" under it. Never with a creditId.
-- WhatsNew.spec checks every rule, so a bad row fails the gate.

local WhatsNew = {}

export type Icon = "new" | "cat" | "look" | "faster" | "fix"
export type Row = {
	id: string,
	date: string,
	icon: Icon,
	text: string,
	creditId: string?,
	thanks: string?,
}

WhatsNew.ICONS = table.freeze({ "new", "cat", "look", "faster", "fix" })
WhatsNew.TEXT_MAX = 28
WhatsNew.SHOWN = 8 -- #1768 (Derek2: "show more of the whats new stuff"): one compact line each

WhatsNew.rows = table.freeze({
	-- Derek2 (11-08): "update whats new and include mobile support/overhaul" (#2465): the phone overhaul leads
	{ id = "mobile_overhaul", date = "2026-11-08", icon = "new", text = "Mobile support overhaul" },
	{ id = "phone_top_bar", date = "2026-11-08", icon = "look", text = "Phone HUD in the top bar" },
	{
		id = "phone_tap_feed",
		date = "2026-11-08",
		icon = "new",
		text = "Tap to feed cats on phone",
	},
	{ id = "ring_icons", date = "2026-11-08", icon = "look", text = "Walk-up rings show icons" },
	{
		id = "move_after_catch",
		date = "2026-11-08",
		icon = "faster",
		text = "Move right after catches",
	},
	{
		id = "move_after_rescue",
		date = "2026-11-08",
		icon = "faster",
		text = "Move right after rescues",
	},
	{
		id = "fewer_phone_popups",
		date = "2026-11-08",
		icon = "faster",
		text = "Fewer pop-ups on phone",
	},
	{
		id = "trade_unlock_tier",
		date = "2026-11-08",
		icon = "look",
		text = "Trade shows its unlock tier",
	},
	{ id = "phone_tutorial", date = "2026-11-08", icon = "fix", text = "Tutorial fixes on phone" },
	{ id = "bag_backpack", date = "2026-11-08", icon = "look", text = "Bag has a backpack icon" },
	-- Derek2 (11-07): the next changes merged that day (#2244, #2216, #2225, #2252, #2257, #2233, #2260); crispi_255
	-- suggested the Fish Market's "!" (#2214), the rest were Derek's own asks
	{
		id = "legendary_rescue_hits",
		date = "2026-11-07",
		icon = "fix",
		text = "Legendary rescue hits count",
	},
	{
		id = "fish_market_bang",
		date = "2026-11-07",
		icon = "look",
		text = "Fish Market shows a ! alert",
		thanks = "crispi_255",
	},
	{
		id = "rescue_bang",
		date = "2026-11-07",
		icon = "new",
		text = "Red ! on rescues to help",
	},
	{
		id = "skip_spins",
		date = "2026-11-07",
		icon = "faster",
		text = "Skip spins with a tap",
	},
	{
		id = "golden_fish_hover",
		date = "2026-11-07",
		icon = "fix",
		text = "Golden fish no longer hovers",
	},
	{
		id = "rarity_gems_glow",
		date = "2026-11-07",
		icon = "look",
		text = "Rarity gems glow brighter",
	},
	{
		id = "new_cat_tag",
		date = "2026-11-07",
		icon = "look",
		text = "NEW tag on cats not in Index",
	},
	-- Derek2 (11-07): the changes merged since the 11-07 rows, as they ship; a playtester's report or suggestion is
	-- thanked by Roblox username
	{
		id = "recap_readable",
		date = "2026-11-07",
		icon = "look",
		text = "Cafe recap easier to read",
	},
	{
		id = "tutorial_x_glow",
		date = "2026-11-07",
		icon = "look",
		text = "Tutorial X glows when done",
		thanks = "crispi_255",
	},
	{
		id = "popups_fit",
		date = "2026-11-07",
		icon = "fix",
		text = "Pop-ups no longer cut off",
	},
	{
		id = "rescue_miss_reset",
		date = "2026-11-07",
		icon = "fix",
		text = "Rescue misses reset the bar",
		thanks = "crispi_255",
	},
	{
		id = "good_cats_spread",
		date = "2026-11-07",
		icon = "cat",
		text = "Rare cats spread out more",
		thanks = "crispi_255",
	},
	{
		id = "rare_chat",
		date = "2026-11-07",
		icon = "new",
		text = "Rare catches show in chat",
		thanks = "bgdevila",
	},
	{
		id = "cash_steady",
		date = "2026-11-07",
		icon = "fix",
		text = "Cash no longer shoves the 2x",
		thanks = "bgdevila",
	},
	{
		id = "tackle_drops_cat",
		date = "2026-11-07",
		icon = "fix",
		text = "Tackles always drop the cat",
		thanks = "bgdevila",
	},
	{
		id = "longer_days",
		date = "2026-11-07",
		icon = "look",
		text = "Longer days in town",
		thanks = "bgdevila",
	},
	{
		id = "legendary_cards",
		date = "2026-11-07",
		icon = "look",
		text = "Big cards only for Legendary",
		thanks = "bgdevila",
	},
	{
		id = "tackle_lesson",
		date = "2026-11-07",
		icon = "new",
		text = "Learn tackling after a catch",
	},
	{
		id = "feed_list_smooth",
		date = "2026-11-07",
		icon = "faster",
		text = "Bag feed list no longer lags",
		thanks = "cooltyrell",
	},
	{
		id = "tutorial_pace",
		date = "2026-11-07",
		icon = "look",
		text = "Tutorial at your own pace",
	},
	{ id = "day_start", date = "2026-11-07", icon = "fix", text = "New servers start in daytime" },
	{
		id = "jukebox_shuffle",
		date = "2026-11-07",
		icon = "new",
		text = "Shuffle songs on the jukebox",
	},
	-- #2177 (Derek2, 11-07): the player-facing changes published 11-07; the Tail Bow, the +15% outfit cues and the
	-- Cafe Pass window are left off, as rows never name a Robux item
	{ id = "new_intro", date = "2026-11-07", icon = "new", text = "New intro to start your cafe" },
	{
		id = "real_cat_names",
		date = "2026-11-07",
		icon = "cat",
		text = "Cats go by their real names",
	},
	{ id = "cats_walk", date = "2026-11-07", icon = "cat", text = "Cats walk to bed and to work" },
	{ id = "potion_fold", date = "2026-11-07", icon = "look", text = "Fold potion timers away" },
	{
		id = "collector_visits",
		date = "2026-11-07",
		icon = "new",
		text = "Collectors visit more often",
	},
	{ id = "cat_food_bag", date = "2026-11-05", icon = "new", text = "Bag with cat food to feed" },
	{
		id = "corner_shop_sizes",
		date = "2026-11-05",
		icon = "new",
		text = "Corner Shop sizes and tiers",
	},
	-- #1768: what Derek2's 11-05 playtest found live
	{
		id = "golden_rainbow_days",
		date = "2026-11-05",
		icon = "new",
		text = "Golden and Rainbow days",
	},
	{ id = "mystery_gifts", date = "2026-11-05", icon = "new", text = "Mystery gifts around town" },
	{ id = "more_strays", date = "2026-11-05", icon = "cat", text = "More strays to catch" },
	{ id = "night_market", date = "2026-11-05", icon = "new", text = "Night Market cart at night" },
	{
		id = "decor_crate_reel",
		date = "2026-11-05",
		icon = "look",
		text = "Decor crates spin to open",
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
