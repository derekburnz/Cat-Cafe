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
	-- #2718 refresh (11-14 11:50 UTC, 59 merges since #3927): the onboarding fixes Derek OK'd 02:37 UTC (#4097, #4098),
	-- the Relic Museum's new inside (#4138), the Rummage Bin minigame fix (#4128), the pop-up cards (#4092) and the
	-- phone fixes (#4151, #4152, #3990). Still behind switches (rare customers, friend joins, Today's Deal, gold tone):
	-- rows when they open.
	-- Tonight's refresh (Derek 2026-11-14 17:41 UTC: "update whats new board prior to tonights update"), reaching every
	-- server with the 22:00 UTC restart: the new-kind first bait cat (#4199), spawn pop-ups one at a time (#4228), the
	-- new codes (#4242) and the admin events after each update restart (#4195). Robux items get no row.
	{
		id = "first_bait_new",
		date = "2026-11-14",
		icon = "cat",
		text = "First bait cat is always new",
	},
	{
		id = "spawn_popups",
		date = "2026-11-14",
		icon = "fix",
		text = "Spawn pop-ups one at a time",
	},
	{
		id = "codes_nov14",
		date = "2026-11-14",
		icon = "new",
		text = "Four new codes to redeem",
	},
	{
		id = "admin_events",
		date = "2026-11-14",
		icon = "new",
		text = "Admin events after updates",
	},
	-- #4189 (Derek 2026-11-14 14:55 UTC: "add text that earlier tiers made easier")
	{
		id = "tiers_easier",
		date = "2026-11-14",
		icon = "faster",
		text = "Tiers 2 to 7 made easier",
	},
	{
		id = "free_bait_bowl",
		date = "2026-11-14",
		icon = "new",
		text = "Start with a free Bait bowl",
	},
	{
		id = "tier2_sooner",
		date = "2026-11-14",
		icon = "faster",
		text = "Tier 2 opens sooner",
	},
	{
		id = "museum_halls",
		date = "2026-11-14",
		icon = "look",
		text = "Relic Museum: hall tabs",
	},
	{
		id = "rummage_walk",
		date = "2026-11-14",
		icon = "fix",
		text = "Rummage Bin waits for you",
	},
	{
		id = "popup_cards",
		date = "2026-11-14",
		icon = "look",
		text = "Easier to see pop-up cards",
	},
	{
		id = "phone_tips",
		date = "2026-11-14",
		icon = "fix",
		text = "Clearer tips on phones",
	},
	-- #3927 refresh (11-14 02:50 UTC): live since the Friday rows. The Cats menu's new top bar (#4028) and turning the
	-- camera through a trait roll (#4016); the station menus' one look went on with the 15:30 UTC update (#3558).
	-- Behind switches or tiers still (Snowy Mountain, the late stations, the Secret trait): rows when they open.
	{
		id = "cats_menu_bar",
		date = "2026-11-14",
		icon = "look",
		text = "Cats menu: search and sort",
	},
	{
		id = "pool_camera",
		date = "2026-11-14",
		icon = "new",
		text = "Turn the camera at the Pool",
	},
	{
		id = "station_menus",
		date = "2026-11-13",
		icon = "look",
		text = "One new look for every menu",
	},
	-- Friday 2026-11-13 22:00 UTC update (#3523): the switches turned on after the restart. The two player ideas carry
	-- their IdeaCredits_v1 ids (added 22:05 UTC with idea-credits.yml add-player at place version 632).
	{
		id = "speed_shoes",
		date = "2026-11-13",
		icon = "new",
		text = "New Speed Shoes",
	},
	{
		id = "secret_cats",
		date = "2026-11-13",
		icon = "cat",
		text = "Secret cats are out there",
		creditId = "c14",
	},
	{
		id = "pet_a_cat",
		date = "2026-11-13",
		icon = "new",
		text = "Pet the cats in your cafe",
		creditId = "c15",
	},
	{
		id = "picnic_treats",
		date = "2026-11-13",
		icon = "new",
		text = "Picnic Treats: pick 1 of 3",
	},
	{
		id = "index_to_every_cat",
		date = "2026-11-13",
		icon = "new",
		text = "Index rewards up to 70 cats",
	},
	{
		id = "backpack_colours",
		date = "2026-11-13",
		icon = "look",
		text = "Pick your backpack colour",
	},
	-- #2718 refresh (11-13 14:20 UTC, Model-Agent): live changes since #3817 (about 37 merges). Lighter models and
	-- 256 px pictures for phones (#3791, #3809, #3812, #3831, #3832, #3833), menus built after start-up (#3722),
	-- Mouse Dash windows and clock (#3853), the Mystic Pool's Legendary and Mythic roll scene (#3849) and its pointer
	-- (#3822), short-phone fits (#3518, #3848, #3816). Switches still off (picnicTreats, returnGift, fxLite,
	-- traitBundles, Friday's) get their rows when they go on.
	{
		id = "lighter_on_phones",
		date = "2026-11-13",
		icon = "faster",
		text = "Smoother on phones",
	},
	{
		id = "faster_game_start",
		date = "2026-11-13",
		icon = "faster",
		text = "Faster game start",
	},
	{
		id = "mouse_dash_longer",
		date = "2026-11-13",
		icon = "fix",
		text = "Mouse Dash: easier, longer",
	},
	{
		id = "big_trait_roll_scene",
		date = "2026-11-13",
		icon = "look",
		text = "Big trait rolls get a scene",
	},
	{
		id = "mystic_pool_glow",
		date = "2026-11-13",
		icon = "look",
		text = "Glow points to Mystic Pool",
	},
	{
		id = "fits_small_phones",
		date = "2026-11-13",
		icon = "fix",
		text = "Fits small phones better",
	},
	-- #2718 refresh (11-13 05:30 UTC, Growth-Agent): live changes since #3778 that the board did not name. Start with a
	-- table (#3679, new servers from about 04:00 UTC), catch reach on touch (touchCatchReach on 03:34 UTC), Park gate
	-- paw trail (parkGateTrail on 03:37 UTC), bright intro Skip (#3795). Friday rows (Speed Shoes, Secret cats, pet a
	-- cat, station menus) go in with their switches, not here.
	{
		id = "start_with_a_table",
		date = "2026-11-13",
		icon = "faster",
		text = "Cafe starts with a table",
	},
	{
		id = "touch_catch_reach",
		date = "2026-11-13",
		icon = "fix",
		text = "Easier catches on phones",
	},
	{
		id = "park_gate_trail",
		date = "2026-11-13",
		icon = "look",
		text = "Paw trail to the Park gate",
	},
	{
		id = "intro_skip_button",
		date = "2026-11-13",
		icon = "fix",
		text = "Brighter Skip in the intro",
	},
	-- #2718 refresh (11-13 00:30 UTC): the 02:30 UTC restart of 2026-11-13 and what went live since #3434. Merge with
	-- that publish. Take out "epic_trait_tier" if #3719 is not on main at the publish.
	{
		id = "mystic_pool_at_spawn",
		date = "2026-11-13",
		icon = "new",
		text = "Mystic Pool now at spawn",
	},
	{
		id = "epic_trait_tier",
		date = "2026-11-13",
		icon = "new",
		text = "New Epic trait tier",
	},
	{
		id = "rarer_traits_more_often",
		date = "2026-11-13",
		icon = "new",
		text = "Rare traits come up more",
	},
	{
		id = "mouse_dash_menu_clock",
		date = "2026-11-13",
		icon = "look",
		text = "Mouse Dash: new menu, clock",
	},
	{
		id = "trade_shows_traits",
		date = "2026-11-13",
		icon = "look",
		text = "Trades show cat traits",
	},
	-- #2718 (Design-Agent, 11-13 01:46 UTC): two changes the board did not name yet. The pick a cat menu (#3749, no
	-- switch, merged 11-13 01:15 UTC) and resting in your cafe (afkCafe, on live since 11-12 15:41 UTC).
	{
		id = "mystic_pool_pick_cat",
		date = "2026-11-13",
		icon = "look",
		text = "Mystic Pool: pick your cat",
	},
	{
		id = "rest_in_cafe_double_pay",
		date = "2026-11-12",
		icon = "new",
		text = "Rest in your cafe: 2x pay",
	},
	-- #3420, #3424: the Thursday 2026-11-12 launch (22:00 UTC). Merge this only with the launch publish, and only
	-- the rows whose feature is switched on at the launch.
	{
		id = "mystic_pool_traits",
		date = "2026-11-12",
		icon = "new",
		text = "Mystic Pool: cat traits",
	},
	{
		id = "mouse_dash",
		date = "2026-11-12",
		icon = "new",
		text = "New Arcade game: Mouse Dash",
	},
	-- #3457: the launch's party and gift rows were taken out on 2026-11-13 once both had ended (Review-QA's smoke
	-- check); rows for timed events come out when the event ends, so the board never promises what is over.
	{
		id = "rich_money_bags",
		date = "2026-11-12",
		icon = "new",
		text = "Rich customers leave bags",
	},
	-- #3462: on at the launch (the `cartTier6` switch goes on right after the restart); take this row out if it does not
	{
		id = "day_cart_top_shelf",
		date = "2026-11-12",
		icon = "new",
		text = "Day Cart: Tier 6 top shelf",
	},
	-- #3448: take this row out if the bigger circles are not on main at the launch
	{
		id = "bigger_station_circles",
		date = "2026-11-12",
		icon = "look",
		text = "Bigger station circles",
	},
	-- #2718 refresh (11-12 09:10): player-facing changes since #3369, 148 merges, that are on without a switch. The
	-- launch's own rows are #3434's and go above these. The top 10 join line (#3466) was a player's idea, credited
	-- since 2026-11-13 (Derek; the credit row c13 was added with the idea-credits workflow).
	{
		id = "top_ten_hello",
		date = "2026-11-12",
		icon = "new",
		text = "Top 10 players get a hello",
		creditId = "c13",
	},
	{
		id = "spa_sort_toggle",
		date = "2026-11-12",
		icon = "look",
		text = "Spa: sort cats by rarity",
	},
	{
		id = "rummage_loot_card",
		date = "2026-11-12",
		icon = "look",
		text = "Rummage Bin shows your loot",
	},
	{
		id = "town_square_tidy",
		date = "2026-11-12",
		icon = "look",
		text = "Tidier Town Square",
	},
	{
		id = "camp_circles_clear",
		date = "2026-11-12",
		icon = "look",
		text = "Clear paths to camp stations",
	},
	{
		id = "new_player_shield_15",
		date = "2026-11-12",
		icon = "new",
		text = "New player shield: 15 min",
	},
	{
		id = "cannon_landing_steady",
		date = "2026-11-12",
		icon = "fix",
		text = "Steadier cannon landing",
	},
	{
		id = "button_taps_kept",
		date = "2026-11-12",
		icon = "fix",
		text = "Fewer missed button taps",
	},
	-- #2718 refresh (11-11 21:00): player-facing changes since #3259, 67 merges; no new player ideas
	{
		id = "swift_paws_five",
		date = "2026-11-11",
		icon = "faster",
		text = "Swift Paws: 5 speed levels",
	},
	{
		id = "arcade_free_daily",
		date = "2026-11-11",
		icon = "new",
		text = "Free Arcade game every day",
	},
	{
		id = "arcade_leaderboard",
		date = "2026-11-11",
		icon = "new",
		text = "Cat Arcade leaderboard",
	},
	{
		id = "titles_bag_tab",
		date = "2026-11-11",
		icon = "new",
		text = "Titles tab in your Bag",
	},
	{
		id = "shorter_nights",
		date = "2026-11-11",
		icon = "faster",
		text = "Shorter nights",
	},
	{
		id = "tackle_shield_new",
		date = "2026-11-11",
		icon = "new",
		text = "New players can't be tackled",
	},
	{
		id = "stray_calls_over",
		date = "2026-11-11",
		icon = "cat",
		text = "Strays call you over",
	},
	{
		id = "station_reveal_show",
		date = "2026-11-11",
		icon = "look",
		text = "Station reveal with confetti",
	},
	{
		id = "first_catches_easier",
		date = "2026-11-11",
		icon = "fix",
		text = "Easier first catches",
	},
	{
		id = "tutorial_one_tap_buy",
		date = "2026-11-11",
		icon = "faster",
		text = "Tutorial: one-tap Buy",
	},
	{
		id = "decor_unlocked",
		date = "2026-11-11",
		icon = "fix",
		text = "Decor arrives unlocked",
	},
	{
		id = "ruins_waterfall_mist",
		date = "2026-11-11",
		icon = "look",
		text = "Ruins waterfall and mist",
	},
	-- #2718 refresh (11-11 04:00): player-facing changes since #3220, 27 merges; no new player ideas
	{
		id = "rummage_bin",
		date = "2026-11-11",
		icon = "new",
		text = "Rummage Bin in the Alleyway",
	},
	{
		id = "saturday_gift",
		date = "2026-11-11",
		icon = "new",
		text = "Saturday update gifts",
	},
	{
		id = "hidden_nooks",
		date = "2026-11-11",
		icon = "new",
		text = "Hidden nooks in wild areas",
	},
	{
		id = "ruins_desert_detail",
		date = "2026-11-11",
		icon = "look",
		text = "More Ruins and Desert detail",
	},
	{
		id = "second_stray_paw",
		date = "2026-11-11",
		icon = "fix",
		text = "Easier to find a second cat",
	},
	{
		id = "night_market_alert",
		date = "2026-11-11",
		icon = "look",
		text = "Night Market ! at nightfall",
	},
	{
		id = "decor_lantern_gem",
		date = "2026-11-11",
		icon = "look",
		text = "Bench lantern and gem move",
	},
	{
		id = "rainbow_paint_door",
		date = "2026-11-11",
		icon = "fix",
		text = "Rainbow paint skips the door",
	},
	{
		id = "catch_card_net",
		date = "2026-11-11",
		icon = "fix",
		text = "Catch card names net catches",
	},
	{
		id = "cannon_menus_open",
		date = "2026-11-11",
		icon = "fix",
		text = "Cannon menus stay open",
	},
	{
		id = "park_cannon_camp",
		date = "2026-11-11",
		icon = "fix",
		text = "Park cannon lands in camp",
	},
	-- #3062 + #3067: the Cat Arcade, the same player's idea as Swift Paws (the same credit)
	{
		id = "cat_arcade",
		date = "2026-11-11",
		icon = "new",
		text = "Cat Arcade in Town Square",
		creditId = "c12",
	},
	-- #3217 refresh (11-11): player-facing changes since #3043; Swift Paws was its_cuzu098's idea
	{
		id = "swift_paws_perk",
		date = "2026-11-11",
		icon = "new",
		text = "Swift Paws walk speed perk",
		creditId = "c12",
	},
	{
		id = "tutorial_spotlight",
		date = "2026-11-11",
		icon = "look",
		text = "Clearer tutorial arrow",
	},
	{
		id = "tutorial_click_through",
		date = "2026-11-11",
		icon = "faster",
		text = "Click through the tutorial",
	},
	{
		id = "fewer_new_badges",
		date = "2026-11-11",
		icon = "fix",
		text = "Fewer New! pop-ups",
	},
	{
		id = "first_rescues_easier",
		date = "2026-11-11",
		icon = "fix",
		text = "First rescues are easier",
	},
	{
		id = "quick_use_and_buy",
		date = "2026-11-11",
		icon = "faster",
		text = "Faster Use and buy presses",
	},
	{
		id = "day_clock_top_pc",
		date = "2026-11-11",
		icon = "look",
		text = "Day clock at the top on PC",
	},
	{
		id = "sky_brighter",
		date = "2026-11-11",
		icon = "look",
		text = "Brighter sky day and night",
	},
	{
		id = "camps_no_drop_in",
		date = "2026-11-11",
		icon = "fix",
		text = "Camps load in without drops",
	},
	-- #2718 refresh (11-10 16:40): player-facing changes since #2977, 37 merges; no player ideas
	{
		id = "town_square_grew",
		date = "2026-11-10",
		icon = "look",
		text = "Town Square grew again",
	},
	{ id = "drop_buttons_small", date = "2026-11-10", icon = "fix", text = "Smaller Drop buttons" },
	{
		id = "catch_result_flash",
		date = "2026-11-10",
		icon = "look",
		text = "Snappier catch result",
	},
	{
		id = "backpack_heads_big",
		date = "2026-11-10",
		icon = "look",
		text = "Bigger cats in your Backpack",
	},
	{
		id = "refill_best_food",
		date = "2026-11-10",
		icon = "faster",
		text = "Refill uses your best food",
	},
	{
		id = "mythical_decor_shine",
		date = "2026-11-10",
		icon = "look",
		text = "Mythical decor shines more",
	},
	{
		id = "trade_log_more",
		date = "2026-11-10",
		icon = "new",
		text = "Trade log shows more items",
	},
	{
		id = "spa_cats_float",
		date = "2026-11-10",
		icon = "look",
		text = "Spa cats float when ready",
	},
	{
		id = "controller_fixes_2",
		date = "2026-11-10",
		icon = "fix",
		text = "More controller fixes",
	},
	-- #2718 refresh (11-10 12:30): player-facing changes since #2939, 30 merges; no player ideas
	-- #3011 (Derek2 11-10: "buff how often night market stocks good items and amount")
	{
		id = "night_market_stock",
		date = "2026-11-10",
		icon = "new",
		text = "More food at Night Market",
	},
	{ id = "trade_decor", date = "2026-11-10", icon = "new", text = "Trade decor with friends" },
	{ id = "first_bait_cut", date = "2026-11-10", icon = "look", text = "Watch your bait cat eat" },
	{
		id = "park_first_hint",
		date = "2026-11-10",
		icon = "faster",
		text = "Hints lead you to the Park",
	},
	{
		id = "second_cat_pointer",
		date = "2026-11-10",
		icon = "faster",
		text = "Arrow to your second cat",
	},
	{ id = "return_goals", date = "2026-11-10", icon = "new", text = "Next goals when you return" },
	{
		id = "first_catch_pulse",
		date = "2026-11-10",
		icon = "look",
		text = "Gold pulse on first catch",
	},
	{ id = "cat_sold_sound", date = "2026-11-10", icon = "look", text = "Sound when a cat sells" },
	{ id = "gamepad_hints", date = "2026-11-10", icon = "fix", text = "Controller button hints" },
	{ id = "intro_ground", date = "2026-11-10", icon = "fix", text = "Intro waits for the ground" },
	{
		id = "whistle_refund",
		date = "2026-11-10",
		icon = "fix",
		text = "Whistle refunded as coins",
	},
	-- #2718 refresh (11-10): player-facing changes since #2890, 26 merges; no player ideas
	{ id = "spa_hourly", date = "2026-11-10", icon = "new", text = "Spa: a level every hour" },
	{
		id = "museum_room_tips",
		date = "2026-11-10",
		icon = "new",
		text = "Museum rooms add 5% tips",
	},
	{
		id = "museum_exhibits",
		date = "2026-11-10",
		icon = "look",
		text = "See your exhibits on show",
	},
	{ id = "spa_pool_cats", date = "2026-11-10", icon = "look", text = "See your cats in the Spa" },
	{ id = "cheaper_ranks", date = "2026-11-10", icon = "faster", text = "Cheaper ranks 3 to 7" },
	{
		id = "first_catch_wait",
		date = "2026-11-10",
		icon = "faster",
		text = "First catch ring waits",
	},
	{
		id = "first_flight_stray",
		date = "2026-11-10",
		icon = "faster",
		text = "First flights land by a cat",
	},
	{
		id = "rare_catch_chat",
		date = "2026-11-10",
		icon = "new",
		text = "Rare catches in the chat",
	},
	{
		id = "caught_stay_unlocked",
		date = "2026-11-10",
		icon = "fix",
		text = "Caught cats stay unlocked",
	},
	{ id = "fewer_asks", date = "2026-11-10", icon = "faster", text = "Fewer pop-up asks" },
	{ id = "day_event_banner", date = "2026-11-10", icon = "look", text = "Day and event banner" },
	{
		id = "desert_blowing_sand",
		date = "2026-11-10",
		icon = "look",
		text = "Sand blows off the dunes",
	},
	-- #2872, #2874 (v477): menus, prompts and drops on a gamepad
	{ id = "controller_play", date = "2026-11-10", icon = "new", text = "Play with a controller" },
	-- #2718 refresh (11-09 night): player-facing changes since #2704, 99 merges; no player ideas
	{ id = "cat_makeovers", date = "2026-11-09", icon = "cat", text = "Cat makeovers for 16 cats" },
	{
		id = "spa_and_museum",
		date = "2026-11-09",
		icon = "new",
		text = "Oasis Spa and Relic Museum",
	},
	{
		id = "townsfolk_cats",
		date = "2026-11-09",
		icon = "cat",
		text = "Townsfolk cats in the camps",
	},
	{
		id = "playtime_gifts",
		date = "2026-11-09",
		icon = "new",
		text = "Playtime gifts as you play",
	},
	{ id = "invite_fish", date = "2026-11-09", icon = "new", text = "Golden fish for invites" },
	{
		id = "quicker_first_bait",
		date = "2026-11-09",
		icon = "faster",
		text = "Quicker first bait",
	},
	{
		id = "easier_rescues",
		date = "2026-11-09",
		icon = "faster",
		text = "Easier rescues near start",
	},
	{
		id = "desert_ruins_remade",
		date = "2026-11-09",
		icon = "look",
		text = "Desert and Ruins remade",
	},
	{
		id = "roomier_town_square",
		date = "2026-11-09",
		icon = "look",
		text = "Roomier Town Square",
	},
	{ id = "wear_backpack", date = "2026-11-09", icon = "look", text = "Wear your Backpack" },
	-- Derek2 (11-09): "update the whats new every 20-50 minor changes" (#2718): the
	-- player-facing changes since the 11-08 rows, 163 merges; no player ideas came in through feedback this time
	{
		id = "desert_ruins",
		date = "2026-11-09",
		icon = "new",
		text = "Desert and Ruins areas open",
	},
	{ id = "twenty_new_cats", date = "2026-11-09", icon = "cat", text = "20 new cats to catch" },
	{
		id = "cannon_locked_areas",
		date = "2026-11-09",
		icon = "look",
		text = "Cannon shows locked areas",
	},
	{ id = "net_reach", date = "2026-11-09", icon = "faster", text = "Net reaches a bit further" },
	{
		id = "quicker_tutorial",
		date = "2026-11-09",
		icon = "faster",
		text = "Shorter, quicker tutorial",
	},
	{ id = "mystery_market", date = "2026-11-09", icon = "new", text = "Juniper's Mystery Market" },
	{
		id = "backpack_two_cats",
		date = "2026-11-09",
		icon = "new",
		text = "Backpack carries 2 cats",
	},
	{ id = "trade_anywhere", date = "2026-11-09", icon = "new", text = "Trade from anywhere" },
	{ id = "gift_wraps", date = "2026-11-09", icon = "new", text = "Rare and Super gift wraps" },
	{
		id = "day_cart_buy_all",
		date = "2026-11-09",
		icon = "faster",
		text = "Buy all at the Day Cart",
	},
	{
		id = "rare_rescue_easier",
		date = "2026-11-09",
		icon = "faster",
		text = "Easier rare cat rescues",
	},
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
