--!strict
-- Analytics (feature F16, growth analytics-plan.md): the onboarding_v6, first_hour_v3 and catch_attempt funnels (only
-- these since #2444; the intro, grand_opening and bait_cycle funnels are no longer sent, their custom events stay),
-- the feedback_v1 funnel (#2681: the slide-in faces ask, a face, a chip),
-- coin sources and sinks, tier and area Index progression and the custom events, sent through AnalyticsService.
-- Server only; Roblox records nothing from Studio or a client. What only the client knows (its device, a screen it
-- opened or a tutorial card it showed) arrives through TelemetryReport, allowlisted and limited to 40 a
-- minute; nothing it sends pays anything.
-- Every Log call is wrapped in pcall: telemetry must never throw into gameplay. In Studio the last LOG_SIZE events
-- are also kept in memory for QA (`recent`, Debug.telemetry).
-- Custom fields are positional (CustomField01 to 03); the plan names each position. Values are short enum-like
-- strings, never a player's name, a cat's given name or chat, because Roblox folds a field past 8,000 distinct
-- values into "Other".
-- Tips are never an event per second: the cafe's income is counted from lifetimeCoins (CafeService settles it on
-- every sync) and logged as one Source at least once a minute, before every Sink and when the player leaves.
-- #1888 (release tests once ads run): each session keeps where the join came from (JoinSource, an ad's launch data),
-- sent with session_start, the joined step and the Store funnel's first step; the Store is a funnel of its own
-- (StoreFunnel); every Robux spend logs robux_purchase. A player in owner test mode (OwnerTest) logs nothing, so the
-- owner's own testing never reaches the funnels.

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArcadeFunnel = require(ReplicatedStorage.Shared.ArcadeFunnel)
local CafePass = require(ReplicatedStorage.Shared.CafePass)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Catching = require(ReplicatedStorage.Shared.Catching)
local Clock = require(ReplicatedStorage.Shared.Clock)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventGate = require(script.Parent.Parent.Util.EventGate)
local FeedbackFunnel = require(ReplicatedStorage.Shared.FeedbackFunnel)
local FieldText = require(script.Parent.Parent.Util.FieldText)
local FirstFive = require(ReplicatedStorage.Shared.FirstFive)
local GrandOpening = require(ReplicatedStorage.Shared.GrandOpening)
local Guard = require(script.Parent.Parent.Util.Guard)
local IntroModeService = require(script.Parent.IntroModeService)
local IntroSplit = require(ReplicatedStorage.Shared.IntroSplit)
local JoinSource = require(ReplicatedStorage.Shared.JoinSource)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local MemoryWatch = require(ReplicatedStorage.Shared.MemoryWatch)
local Net = require(script.Parent.Net)
local NetPing = require(ReplicatedStorage.Shared.NetPing)
local NewKind = require(ReplicatedStorage.Shared.NewKind)
local NightPass = require(ReplicatedStorage.Shared.NightPass)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local PassService = require(script.Parent.PassService)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local PlaytimeGifts = require(ReplicatedStorage.Shared.PlaytimeGifts)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local RarityFunnel = require(ReplicatedStorage.Shared.RarityFunnel)
local ReturnGoals = require(ReplicatedStorage.Shared.ReturnGoals)
local ReturnHook = require(ReplicatedStorage.Shared.ReturnHook)
local SessionFeedback = require(ReplicatedStorage.Shared.SessionFeedback)
local StationOpens = require(ReplicatedStorage.Shared.StationOpens)
local StepGaps = require(ReplicatedStorage.Shared.StepGaps)
local StoreFunnel = require(ReplicatedStorage.Shared.StoreFunnel)
local Types = require(ReplicatedStorage.Shared.Types)
local UpgradePace = require(ReplicatedStorage.Shared.UpgradePace)

type Profile = Types.PlayerProfile

-- analytics-plan section 5: Roblox's transaction type names where they fit, plus Promo for codes
export type TransactionType = "Gameplay" | "Onboarding" | "Shop" | "TimedReward" | "Promo"

-- analytics-plan section 6 with data-model section 16's v0.4 and v0.5 renames (shove for bump). Names never change
-- once shipped; the launch-phase events (codes, Daily Treat, requests) come with their features.
export type CustomEvent =
	"rank_up"
	| "session_end"
	-- #2996 (retention-ideas.md 5e): an upgrade level bought, value the seconds since the previous buy this session
	-- (else since the join); fields: "1", "2", "3", "4" or "5+" (the account's nth buy), the upgrade id, the new level
	| "upgrade_bought"
	| "offline_claim"
	| "dealer_buy"
	-- F94 (rewards-and-shops.md section 6): a Fresh Catch buy, value the golden fish spent; the row id, tier
	| "fresh_catch_buy"
	-- #1052 (corner-shop.md section 4): a Corner Shop buy, value the coins spent; the row id, tier
	| "corner_shop_buy"
	-- #1181 (corner-shop-v2.md section 4): a food fed from the Bag, value its XP; the food id
	| "cat_fed"
	| "rich_tip"
	-- #2798: a Cozy Cafe bag collected, value today's bags so far; what it held ("coins", "coins+lure", "coins+fish",
	-- "coins+lure+fish")
	| "cozy_bag"
	-- #3573 (shared/AfkCafe): a rest in the player's own cafe starts (value 1; field: "doubled" or "party"), ends
	-- (value: its seconds) and what the cafe paid during it (value: coins)
	| "bin_roll" -- #3608: the Rummage Bin chose a prize before the bar (value 1; fields: row id, "roll" or "fixed")
	| "net_ping" -- #3661 (shared/NetPing): a session's ping in ms, once (fields: device, band)
	| "intro_group" -- #3666 (shared/IntroSplit): a new save joined the intro test (value 1; field: its group)
	| "cat_pet" -- #3651 (shared/Pet): a cat was petted (value 1; field: first, same or moved)
	| "yard_pick" -- #3614: a Yard Sale lucky pick landed (value 1; fields: crate id, tier)
	| "afk_start"
	| "afk_end"
	| "afk_pay"
	| "afk_rejoin" -- #3602: a resting player was sent back into the game ahead of the idle disconnect (value 1)
	-- #2792: a new account's first rich customer, Mystery Visitor or Cat Collector: the kind ("rich", "mystery",
	-- "collector") and "arrived" (value the account's seconds of play), or how it ended, "claimed" or "missed" (value
	-- its seconds at the cafe)
	| "first_visit"
	-- #2797 (retention-ideas.md 5d): the invite card's buttons, value the account's minutes played; "shown", "invite"
	-- or "notnow"
	| "invite_card"
	-- #2797: an invited new player's progress, value 1; "linked" (joined through an invite on a fresh save),
	-- "joiner_paid" (their first catch), "inviter_sent" (the inviter's reward sent), "inviter_paid", "inviter_capped"
	-- (InviteDailyMax reached today) or "inviter_repeat" (that joiner paid this inviter before)
	| "invite_join"
	| "cat_sold"
	| "cat_renamed"
	| "autopress_flag"
	| "cat_caught"
	| "catch_circles" -- value the Perfect rings; rarity, net level, result (#2913: a miss is missed_early, missed_late or missed_none)
	-- #1884 (catch-rework.md 7d): a net catch's end, value the rings judged; purrfect, great, nice or bolt, rarity, mood
	| "catch_finish"
	| "rescue_attempt"
	| "rescue_refill" -- #3049: a starter trap refilled for a first-timer; fields: area, players waiting
	| "bait_rolled"
	| "bait_resolved"
	| "gold_found"
	| "rainbow_found" -- F99 (rainbow-coat.md section 5): rarity, net, bait or rescue, first of the cat yes or no
	| "rally_step" -- F101 (rescue-rally.md section 5): value the players in the server; the step (25, 50, 100), lap, paid
	| "rally_points" -- F101: value a player's points this Rally on this server, at its end or their leave; laps paid
	-- #3062: a Cat Arcade game's end, value its points; circles, milestones paid (comma list or "none"), win or not
	| "arcade_run"
	-- #3296: a Mouse Dash game's end, value its points; hearts lost, seconds, free or paid, and how it ended (hearts,
	-- win, quit)
	| "mouse_dash_run"
	| "arcade_quit" -- #3378: a game left early, value the circles hit; free or paid
	| "arcade_blocked" -- #3378: Start refused, value 1; the reason (closed, loading, running, busy, no_fish)
	| "arcade_board_top" -- #3378: a new best that stands in the leaderboard's top, value its place
	| "title_set" -- #3378: a title (chat tag) picked in the Bag's Titles tab, value 1; the title id or "off"
	-- #3378: tackles the join shield (#3342) stopped on this server in the last minute, value the count; logged on
	-- the last such tackler
	| "tackle_shield"
	-- #3378: the waiting second-cat stray called the player over (#3022), value the call's number this visit; "yes"
	-- when a catch started within STRAY_CALL_SECONDS of it, else "no"
	| "stray_call"
	| "camp_extra" -- F100 (camp-extras.md section 4): value the fills taken or 1; the extra, what was taken, tier
	| "cafe_pass_claim" -- #1645: value 1; the track, the level and the season
	| "cafe_pass_bought" -- #1626: value 1; the season whose paid track was bought
	| "grant_failed" -- #2127: value 1; the product, the step that threw, and "retry" (nothing paid) or "kept"
	| "shove"
	| "drop_outcome"
	-- #3145: a Drop press the server refused, value 1, with why: "none" (the server holds no cat: the player's
	-- screen had drifted), "no_home" or "no_body" (the night's refusal is not counted)
	| "drop_refused"
	| "left_after_shove"
	| "left_after_restart_warning" -- #2720: value the seconds since the last restart warning; warnings seen, its seconds left
	| "slots_full"
	| "role_favorite"
	| "travel"
	| "tutorial_step"
	| "ui_opened"
	| "tip_jar"
	| "index_reward"
	| "spin"
	| "crate_opened"
	| "mystery_buy" -- #2565: value fish before; item, week slot, tier
	| "fishstore_buy" -- #4055: value fish before; FishStore key, tier
	| "bag_colours" -- #3699: a Backpack colour pick saved, value 1; the main id, the trim id
	| "code_redeemed"
	| "intro_cutscene" -- F72: "finished" or "skipped", version:shot ("2:4"), "first" or "replay"
	| "intro_skip" -- #3773: a first play skipped; value the whole seconds watched; version:shot, device
	| "return_gift_paid" -- #3772 (shared/ReturnGift): the welcome back gift paid; value the UTC days since the first day
	| "potion_used" -- F64: potion id, tier
	| "mystery_gift" -- F64: "opened" or "missed", kind:id ("potion:tip_potion", "spin"), tier; the value is the count
	| "collector_visit" -- F63: "arrived", "traded", "declined", "timeout" or "withdrawn", catId:variant, offer value
	| "quest_claimed" -- F73: kind ("daily" or "weekly"), quest id, slot ("<slot> auto" when a reset paid it)
	| "quest_set" -- F73: kind, when the last quest of a full set is claimed and the set prize paid
	| "achievement_claimed" -- F73: achievement id, size
	| "daily_treat" -- F70: the day stamped (1 to 7)
	-- Derek's 10-31 research notes: where early players stop. On leaving before Tier 2: the furthest onboarding step,
	-- the tutorial step ("intro" while the intro has never finished) and where they were; the value is the session's
	-- seconds
	| "quit_point"
	-- F84 (hometown-cannon.md section 7): a Cat Cannon flight, from cannon id to destination; a carried cat checked
	-- in at a camp, the value its seconds carried, with area, rarity and times knocked loose
	| "cannon_launch"
	| "camp_checkin"
	-- F95 (economy-ladder.md section 7): on a returning join, the value the minutes away; tier, the minutes offline
	-- pays for (inside the cap) and "long_nap" or "free"
	| "offline_return"
	-- F93 (catch-rework.md section 5): net swings rolled up per player (review S99), value the swings since the last
	-- roll up; "hit", "miss_near" or "miss_empty", net level, device
	| "net_swing"
	-- #2910: walk-up station opens rolled up per player like net_swing, value the opens since the last roll up; the
	-- window (shared/StationOpens.WINDOWS), "ring" or "prompt", device
	| "station_open"
	-- F97 (notes-10-28-to-10-30.md section 7): a sunrise wave with no Epic or rarer stray rerolled its last one; area,
	-- the rarity it got. A server event, logged under the first loaded player
	| "wave_rare"
	-- #3470: Secret cats. secret_spawn (value 1; area or "bowl", wild, bait or rescue), secret_caught (value the
	-- tackles it took on the way home; catch, bait or rescue, coat) and secret_lost (value 1; area, despawn or tackle)
	| "secret_spawn"
	| "secret_caught"
	| "secret_lost"
	-- F87 (easy-start.md section 5): a new player leaving (their first UTC day of play, or tutorialStep below 5), value
	-- the session's seconds; the furthest onboarding step, the session's bounce window, device. From the client: a
	-- stuck nudge (tutorialStep, kind: pulse, help_shown or show_me) and where the intro was played from (tile, help)
	| "new_player_left"
	-- #2562 (Derek2: "see if lots of people leave during night time"): on leaving, value the session's seconds; the
	-- clock's phase (day, dusk or night), which third of it (Clock.leavePhase) and the tier with first or return
	| "left_in_phase"
	-- #2774 (the 2 to 5 minute drop): a net or rescue catch checked in from an area, value 1; the area id, the rarity
	| "cat_caught_area"
	-- #2774: a pre-Tier 2 player left, value the seconds played; the furthest onboarding step, where (cafe, an area id
	-- or none), "carry" or "empty" with " bait" or " nobait"
	| "quit_state"
	-- #2774: the account's first bait resolved, value the seconds from food in to resolve; lure, rarity, tame or let go
	| "first_bait_wait"
	-- #2774: an onboarding step reached, value the account's seconds of play then; the step name
	| "step_time"
	-- #3530 (shared/StepGaps): the later step of a gap reached, value the seconds since its first step (0 when not
	-- known); the gap, the bucket (under_15s, 15_60s, 60_120s, over_120s, earlier_visit or no_start)
	| "step_gap"
	-- #3530: beside quit_state, value the session's seconds; kinds of cat ("0" to "5"), coins as a share of Tier 2's
	-- cost (under_25, 25_50, 50_75, 75_plus), ready or not_ready (Tier 2's needs met: rank_up_ready_quit)
	| "quit_have"
	-- #3098 (shared/FirstFive, below Tier 2): a step became possible, value the account's seconds of play; the step
	-- (table_afford, bowl_afford, second_stray_up), kind (coins or stray), device
	| "step_ready"
	-- #3098: no new onboarding step for a bucket's seconds, value those seconds; the awaited step, the bucket (30, 60,
	-- 120), the last stuck nudge shown (pulse, help_shown, show_me or none)
	| "step_stall"
	-- #3098: beside quit_state, value the session's seconds; the furthest step, "<idle bucket> <screen>" (one field,
	-- e.g. "5-15 upgrades"), afford (yes, no or na)
	| "quit_snapshot"
	-- #3098 P2: once a session about 150 s in, value the client's fps; ping bucket, memory bucket, device
	| "health_check"
	-- #3743 (shared/MemoryWatch): the client's total memory at 5, 15, 30 and 60 minutes into a session, value the
	-- MB; device, the mark ("m5"), growth since the session's first mark (MemoryWatch.growthBucket)
	| "client_memory"
	-- #3743: at the 5 and 30 minute marks, the MB under one of Roblox's memory groups; the group, the mark, device
	| "client_memory_tag"
	-- #3098 P2: a join within an hour of the last leave, value the minutes away; furthest step, minutes bucket,
	-- session number bucket
	| "quick_return"
	-- #3098 P2: beside quit_snapshot, value the session's seconds; cats working, table level, cats owned
	| "quit_cafe"
	-- #3098 P1b: beside quit_state, value the session's seconds; the scene (FirstFive.SCENES), device, seconds bucket
	| "quit_scene"
	-- #3098 P1b: the session's first intro shot, value the seconds since the join; device, "intro", bucket
	| "first_scene"
	-- #2774: the account's first bait cat came, value the seconds from food in; where the player was then
	| "first_bait_arrived"
	-- #2651 part 4 (late-stations.md section 3): a cat into the Oasis Spa or collected from it, value 1; the level band
	-- ("1-9", "10-19" and so on) before the soak
	| "spa_put"
	| "spa_collect"
	-- a copy given to the Relic Museum, value 1; its rarity and coat. A room finished, value the rooms done; its area
	| "museum_donate"
	| "museum_room"
	| "museum_fill" -- #3130: an Auto fill, value the copies given; its area
	-- #3050: a Rummage Bin win, value 1; the prize row (tuna, fish, salmon, potion, crate, golden), the win's number
	-- on the account ("1" to "10", 10 for any later one). The first win also logs step_time "first_bin"
	| "bin_play"
	| "stuck_nudge"
	| "event_rsvp" -- #2766
	| "screen_short" -- #2913: the viewport's short side once a session, SCREEN_SHORTS
	| "intro_choice"
	-- F87 (TipService): a context tip shown (tip id, skipped yes or no), once per id until ClearTips;
	-- a feedback face (love, ok or no; the chip or none; tier), FeedbackSessionLimit a session
	| "tip_shown"
	-- #3430: the Mystic Pool's first walk-up cutscene ended; value the seconds seen; watched or skipped
	| "mystic_intro"
	| "ask_shown" -- F96: value 1; kind (notify, favorite, like or F92's invite), the session number
	| "feedback"
	-- #2681: with each feedback answer, value 1: the face, the furthest clean funnel step (onboarding_v7, #3695), the account's minutes
	-- played (FeedbackFunnel.minutesBucket)
	| "feedback_ctx"
	-- #2681: with each feedback answer, value 1: the face, the device, "<place version>:<err|ok>" (whether this
	-- session's client logged an error before it)
	| "feedback_env"
	-- #3272: the once-a-day session ask (shared/SessionFeedback), one answer a UTC day, value 1 each: the answer (love,
	-- ok, no or skipped), the device and the session length bucket; the answer, the furthest clean funnel step (onboarding_v7, #3695) and
	-- the cats owned bucket; the answer, the screen open and the build ("<place version>:<err|ok>")
	| "session_feedback"
	-- #3196 (trait-station.md section 7): a trait rolled, value its rarity rank (1 Common to 5 Mythic): the trait id
	-- (its rarity comes with it), how it was paid (free, token, fish), and "first", "reroll_new" or "reroll_old" (which
	-- was kept; a re-roll logs at its choice). Three fields, the most a custom event carries
	| "trait_roll"
	-- #3196: Trait Tokens gained, value how many: the source (station, spin, daily_treat, quest, lost_found, code)
	| "trait_token"
	| "session_feedback_ctx"
	| "session_feedback_where"
	-- #2681: the like ask ("Having fun? A thumbs up") shown, value 1; tier, minutes played bucket, device
	| "like_ask_shown"
	-- #2694: how a slide-in faces ask ended, at most one per ask shown, value 1: answered, closed or ignored; early or
	-- late (the client's report); minutes played bucket
	| "feedback_ask_end"
	-- #2692: a beginner's night pass let a cannon flight go at night, once a session, value 1; the destination, the
	-- clock's phase
	| "night_pass_used"
	-- F96 (starter-cat.md section 4): the free Bellhop Cat taken home; the gate it passed, "task" or "group"
	| "starter_cat"
	| "shop_cat" -- #1447: a shop-only cat given on its pass (catId)
	-- F91 (front-lawn.md section 5): a lawn piece or path or fence style bought, value 1, once per id ever (moves log
	-- nothing, review S119); its id, tier. The coins it cost are the economy sink "lawn"
	| "lawn_placed"
	| "lawn_drop" -- #3222: a drop-only Golden lawn piece from a freed cat (id, tier)
	-- F92 (playing-together.md 6): on leave, the minutes with at least one pal on the server (how the first pal was
	-- linked: friend, invite, follow or private; tier)
	| "pal_time"
	-- F92 (playing-together.md 6): a rescue attempt a helper joined, as it ends (rarity, freed yes or no, pals yes or
	-- no); the helper's tip is the economy source helper_tip
	| "team_rescue"
	-- F88 (luck-and-rare-moments.md 1f): a bait or crate roll with Luck above x1 (value the Luck; roll kind, rarity
	-- won, tier) and a Lucky Day's sunrise (value the players in the server; the area of a Mythical, or none)
	| "luck_used"
	| "lucky_day"
	-- #1572 (luck-and-rare-moments.md 1h): a pity cat's end in this server (value the slot; area, kind, and secured,
	-- lost (another server's catch came first), gone (caught elsewhere) or expired (night came first))
	| "pity_cat"
	-- F89 (luck-and-rare-moments.md 2d): a big pull; rarity, gold yes or no, catch, bait or rescue
	| "rare_secured"
	-- F102 (trading.md section 6): a trade swapped, for each player in it; value the cats that moved, fields the cats
	-- given, the cats got and the best rarity got. Never who
	| "trade_done"
	-- #1273 (easy-start.md section 5): for a new player, a mark at 30 s, 60 s, 2, 5 and 10 minutes into the session,
	-- value the seconds; the furthest onboarding step, the screen open, device
	| "session_30s"
	| "session_60s"
	| "session_2m"
	| "session_5m"
	| "session_10m"
	-- #1273: the first catch, value the catch attempts it took (one is a first try); how it came (net or rescue)
	| "first_catch_tries"
	-- #1273: the first window a player opens (first_window_opened), value 1; the screen
	| "first_window"
	-- #1273: the Tutorial tile's red X, value 1, once a session; tutorialStep
	| "tutorial_closed"
	-- #2915: the first Park landing's hint, value 1, each kind once a session; toast or ring (PARK_HINTS)
	| "park_first_hint"
	-- #3554: the walk to a first Park catch, value 1, each once a session; the tier (PARK_TRAIL)
	| "park_gate_trail_shown"
	| "park_entered_first"
	| "park_first_catch"
	-- #3556: once a session each, value 1: first time near a free stray, and the first in-reach glow; the device,
	-- the tier (CATCH_REACH)
	| "stray_near_first"
	-- #3555: the first rank up's walk-through. rank_up_ready_first (value 1) and rank_up_pressed_first (value the
	-- seconds from ready to the rank up) from RankSpotService, once a session; shown and closed from the client
	-- (RANK_SPOT), value 1, once a session each; the device
	| "rank_up_ready_first"
	| "rank_up_pressed_first"
	| "rank_up_spotlight_shown"
	| "rank_up_spotlight_closed"
	| "catch_prompt_shown_first"
	-- #2946: the first bait's cutscene ended, value 1, once a session; shown, skipped or none (CUT_OUTCOMES)
	| "first_bait_cutscene"
	-- #1888: each join, value 1; where it came from (JoinSource), "new" or "returning", tier
	| "session_start"
	-- #3073: each Store visit (the store_v1 opened step's), value 1; the join source (JoinSource), tier, device.
	-- A custom event can be broken down by its fields, which a funnel step can't, so the Store reads ad vs organic.
	| "store_opened"
	-- #1888: a pass or product bought, value the Robux spent; its sku (StoreFunnel), the days since the first join,
	-- "first" for the account's first spend here or "repeat"
	| "robux_purchase"
	-- #1888: Roblox's purchase prompt closed without buying, value 1; the sku, tier
	| "store_cancelled"
	-- #1888: every fifth Cafe Pass level, value the level; the season, the paid track ("paid" or "free"), tier
	| "cafe_pass_level"
	-- #1888: a Jukebox track picked (#1875), value 1; the track id or "default"
	| "jukebox_pick"
	-- #1920: the session recap card shown, once a session, value the minutes played this session; the Grand Opening
	-- milestones done (0 to 8), tier and (#2123) the Tomorrow line's kind (bait, treat or quests; shared/ReturnHook)
	| "session_recap"
	-- #1920: the session recap card closed, once a session, value the whole seconds it was open (0 to 30)
	| "session_recap_close"
	-- #2123 (first-hour.md 6a): a returning player's welcome back card named a reason to be back, value 1; the kind
	-- (bait, treat or quests; shared/ReturnHook)
	| "welcome_back_hook"
	-- #2916: a next goal shown (shared/ReturnGoals), value its progress in percent (0 for "away"); the kind, where
	-- ("recap" or "join") and the Tier it is for ("none" for "away")
	| "return_goal_shown"
	-- #2916: a goal shown this session or at the join was met, value the whole minutes since it was shown; the same
	-- fields as return_goal_shown
	| "return_goal_done"
	-- #1919: the goal card's "Find N more cats" nudge opened the Index, value 1; the area id it pointed at or "none"
	| "index_hint_tap"
	-- #1936 (release.md section 3): a purchase prompt the client's store guard refused, value 1; where it came from
	-- (bait, store or cafePass), why (no_tap: no tap in the last 2 seconds; busy: during a catch, rescue or cutscene),
	-- tier
	| "store_guard_blocked"
	-- #2486 (live-events.md section 7): a player in a running Cafe Event (joined during it, or in the server as it
	-- started), value 1; the event id, the Experience Event id the join came through ("" for none), the join source
	| "event_join"
	-- #2486: the coins a Cafe Event's money added for one player, at the event's end or their leave; the event id, tier
	| "event_money"
	-- #2486: a Cafe Event shower cat, value its number in the event; the event id, area, kind, and spawned, secured,
	-- lost (another server's catch won), gone or expired
	| "event_shower"
	-- #2486: a Cafe Event's reward paid for a secure (or to everyone at an early end); the event id, and "first" for
	-- the account's first event reward (the badge's), else "again"
	| "event_reward"
	-- #1947 (like-prompts.md section 3): a like or favourite card's button, once per card a session, value 1; the gift
	-- ("like" or "fav") and the button (like, favourite or close). A card paid (Source like_gift or fav_gift) with no
	-- report is "none". #2791: the server logs each gift ladder step as it pays, value the account's minutes played; the
	-- step ("m2", "m4", "m6", "like", "m15", "m20", "fav") and "paid"
	| "playtime_gift"
	| "update_gift" -- #2997: the Saturday update gift paid, value 1; its id
	-- #1934 (release.md section 1): a Roblox badge awarded, value the account's minutes played; the badge key, "live"
	-- (earned this session) or "catchup" (earned before, awarded on join)
	| "badge_awarded"

-- One catch_attempt funnel (analytics-plan 4.1): a GUID per attempt and its fields rarity, method, area. The caller
-- keeps it with the stray, the rescue attempt and then the carry.
export type CatchFunnel = { id: string, values: { string } }

export type LogEntry = {
	at: number,
	userId: number,
	kind: string,
	name: string,
	value: number,
	fields: { string },
}

local Telemetry = {}

local CURRENCY = "coins"
local FISH_CURRENCY = "golden_fish" -- F52
local FLUSH_SECONDS = 60
-- Net swings are counted and logged as one net_swing event per result, net level and device this often and on leave:
-- one event per swing would spend the server's analytics budget (120 + 20 per player a minute) at 75 a minute per
-- hunter (review S99).
local SWING_FLUSH_SECONDS = 300
local LOG_SIZE = 200
local DAY_SECONDS = 86400
local LEFT_AFTER_SHOVE_SECONDS = 120
local LEFT_AFTER_RESTART_WARNING_SECONDS = 120 -- #2720
local REPORTS = {
	"device",
	"ui_opened",
	"intro_choice",
	"stuck_nudge",
	"step",
	"screen",
	"tutorial_closed",
	"store_opened", -- #1888: the Store opened, from StoreFunnel.SOURCES
	"new_kind_trail", -- #3529: the five cats trail showed or was followed (shared/NewKind.REPORTS)
	"stray_call", -- #3378: the waiting stray's call played for this player; the value is the call's number (1 to 4)
	"store_tab", -- #1888: a Store tab shown, StoreFunnel.TABS
	"store_buy", -- #1888: a buy button pressed, the pass or product id
	"session_recap", -- #1920: the recap card is on screen (value true)
	"session_recap_close", -- #1920: the recap card closed, the whole seconds it was open (0 to 30)
	"index_hint_tap", -- #1919: the goal card's hint opened the Index, a Catalog area id or "none"
	"store_guard_blocked", -- #1936: a purchase prompt the guard refused, "<source>:<reason>"
	"playtime_gift", -- #1947: a gift card's button, "<like|fav>:<like|favourite|close>"
	"client_error", -- #2681: the client logged its first error line this session (value true)
	"feedback_outcome", -- #2694: how a slide-in faces ask ended, "<answered|closed|ignored>:<early|late>"
	"event_rsvp", -- #2766: the update Event's Notify Me ask, RSVP_KINDS
	"screen_short", -- #2913: the viewport's short side in px, SCREEN_SHORTS, once a session
	"park_first_hint", -- #2915: the first Park landing's hint shown, PARK_HINTS
	"park_trail", -- #3554: the walk to a first Park catch: shown, entered or caught (PARK_TRAIL)
	"rank_spot", -- #3555: the rank up walk-through shown or closed (RANK_SPOT)
	"catch_reach", -- #3556: first time near a stray, first in-reach glow: near or shown (CATCH_REACH)
	"first_bait_cutscene", -- #2946: how the first bait's cutscene ended, CUT_OUTCOMES
	"health_mem", -- #3098: the client's total memory in MB (0 to FirstFive.MEMORY_MAX), sent just before health_fps
	"health_fps", -- #3098: the client's frames a second (0 to FirstFive.FPS_MAX), once a session (health_check)
	"mem_total", -- #3743: the client's total memory at a mark (MemoryWatch.encode), once a mark a session
	"mem_tag", -- #3743: the memory under one group at a mark (MemoryWatch.encode), once a mark and group a session
	"intro_shot", -- #3098 P1b: an intro shot started, 1 to FirstFive.INTRO_SHOTS (quit_scene; the first logs first_scene)
}
local DEVICES = { "phone", "tablet", "pc", "console" }
-- F87 (easy-start.md section 5): the client's reports with fixed values. A stuck nudge logs once per tutorialStep and
-- kind a session (the hint pulses every 40 s while it waits); an intro choice at most INTRO_CHOICES times a session.
local INTRO_FROM = { "tile", "help" }
local NUDGE_KINDS = { "pulse", "help_shown", "show_me" }
-- #2766: the update Event's ask: shown, its two buttons, what Roblox's Notify Me prompt answered, or that it failed;
-- each logs once a session
local RSVP_KINDS = { "shown", "remind", "later", "going", "not_going", "none", "failed" }
-- #2913: the screen's short side in px, bucketed by the client, to read the phone catch circles by size
local SCREEN_SHORTS = { "lt400", "400_600", "gt600" }
local INTRO_CHOICES = 5
-- #2915: the first Park landing's toast, and the soft ring on the nearest stray after 90 s with no Park catch; each
-- once a session
local PARK_HINTS = { "toast", "ring" }
-- #3555: the client's rank_spot report to the event it logs (shared/RankSpot)
local RANK_SPOT: { [string]: CustomEvent } = {
	shown = "rank_up_spotlight_shown",
	closed = "rank_up_spotlight_closed",
}
-- #3556: the client's catch_reach report to the event it logs (shared/TouchReach)
local CATCH_REACH: { [string]: CustomEvent } = {
	near = "stray_near_first",
	shown = "catch_prompt_shown_first",
}
-- #3554: the client's park_trail report to the event it logs (UI/Components/ParkTrailLogic)
local PARK_TRAIL: { [string]: CustomEvent } = {
	shown = "park_gate_trail_shown",
	entered = "park_entered_first",
	caught = "park_first_catch",
}
-- #2946: the first bait's cutscene played to the end, was tapped through, or could not play (Reduce Motion, a busy
-- camera, no cat in time); once a session
local CUT_OUTCOMES = { "shown", "skipped", "none" }
local RECAP_CLOSE_MAX = 30 -- #1920: session_recap_close's seconds, 0 to this
local INDEX_HINT_TAPS = 10 -- #1919: index_hint_tap events logged at most this many times a session
local FIRST_MOVE_STUDS = 8 -- first_move: this far across the ground from where the character was first seen
local WATCH_SECONDS = 1 -- how often first_move and rank_up_ready are looked for
local SCREEN_NAME_MAX = 32 -- a screen report longer than this is dropped; one not in SCREENS reads "other"
-- the UI's ScreenName (screenOpened) to the ui_opened field value
local SCREENS: { [string]: string } = {
	Upgrades = "upgrades",
	Decor = "decor",
	Collection = "collection",
	RankUp = "rank_up",
	Areas = "areas",
	Bait = "bait",
	Dealer = "dealer",
}
-- #1888: more screens for ui_opened only (first_window_opened keeps v3's meaning, the windows above)
local MORE_SCREENS: { [string]: string } = {
	Cats = "cats",
	Store = "store",
	Quests = "quests",
	Potions = "potions",
	Spin = "spin",
	Market = "market",
	Codes = "codes",
	DailyTreat = "daily_treat",
	Trade = "trade",
	TipJar = "tip_jar",
	Cannon = "cannon",
	YardSale = "yard_sale",
	Settings = "settings",
}
-- progressionPathName "tier", levelName by tier (analytics-plan section 7)
local TIER_NAMES = { "corner", "cozy", "busy", "famous", "grand", "sunstone", "wonder" }
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

type Session = {
	accounted: number, -- lifetimeCoins already logged, as tips or as a Source of its own
	joinedAt: number,
	lastUpgradeAt: number?, -- #2996: os.time() of this session's last upgrade buy
	caughtAtJoin: number,
	device: string?, -- from the client's one device report
	joinLogged: boolean,
	returnedNextDay: boolean,
	waitingForRole: { [string]: CatchFunnel }, -- checked-in cats whose funnel waits for step 4 (uid -> funnel)
	knockedAt: number?, -- os.clock() of the last shove that knocked this player's cat loose
	knockedRarity: string?,
	restartWarnedAt: number?, -- #2720: os.clock() of the last restart warning this player was shown
	restartWarnedLeft: number, -- #2720: the seconds to the restart that warning said
	restartWarnings: number, -- #2720: restart warnings shown this session
	swings: { [string]: { count: number, values: { string } } }, -- net swings not logged yet, by their fields
	stationOpens: { [string]: { count: number, values: { string } } }, -- #2910: station opens not logged yet
	arcade: ArcadeFunnel.State, -- #3378: how far arcade_v1 got today
	strayCall: number?, -- #3378: the number of the stray call still waiting for its catch start
	strayCalls: number, -- #3378: stray calls counted this session
	origin: Vector3?, -- F87: where the character's root was first seen this session, for first_move
	nudges: { [string]: boolean }, -- F87: stuck_nudge already logged this session, by "<tutorialStep>:<kind>"
	introChoices: number, -- F87: intro_choice events logged this session
	screen: string, -- #1273: the screen open as last reported (a SCREENS value, "other" or "none")
	uiOpened: { [string]: boolean }, -- ui_opened logged this session, by screen, so a flood logs each once (review)
	tutorialClosed: boolean, -- #1273: tutorial_closed logged this session
	parkHints: { [string]: boolean }, -- #2915: park_first_hint logged this session, by kind
	parkTrail: { [string]: boolean }, -- #3554: park_trail logged this session, by kind
	catchReach: { [string]: boolean }, -- #3556: catch_reach logged this session, by kind
	rankSpot: { [string]: boolean }, -- #3555: rank_spot logged this session, by kind
	firstBaitCut: boolean, -- #2946: first_bait_cutscene logged this session
	source: string, -- #1888: where the join came from (JoinSource.parse of the launch data)
	joinEvent: string, -- #2486: the Experience Event id the join came through (GameJoinContext.EventId), "" for none
	store: StoreVisit?, -- #1888: the Store visit open now, for the Store funnel
	storeVisits: number, -- #1888: Store funnels started this session (StoreFunnel.VISITS_MAX)
	recapShown: boolean, -- #1920: session_recap logged this session
	recapClosed: boolean, -- #1920: session_recap_close logged this session
	goals: { ShownGoal }, -- #2916: next goals shown this session (recap) or at the join, until each is met
	indexHintTaps: number, -- #1919: index_hint_tap events logged this session (INDEX_HINT_TAPS)
	guardBlocks: number, -- #1936: store_guard_blocked events logged this session (StoreFunnel.GUARD_BLOCKS_MAX)
	giftButtons: { [string]: boolean }, -- #1947: playtime_gift logged this session, by gift kind
	clientError: boolean, -- #2681: the client reported an error line this session (client_error)
	feedbackRun: string?, -- #2681: the feedback_v1 run of a slide-in ask shown and not answered yet
	feedbackAsks: number, -- #2681: feedback_v1 runs started this session (FeedbackFunnel.ASKS_PER_SESSION)
	feedbackEnds: number, -- #2694: feedback_ask_end events logged this session, never more than feedbackAsks
	-- #3098 (shared/FirstFive): step_ready logged this session by step; the awaited step's index, os.clock() since
	-- it was the furthest, its stall buckets logged and the last stuck nudge for it; the last activity and position;
	-- the screen open as quit_snapshot names it
	readyLogged: { [string]: boolean },
	stallStep: number,
	stallSince: number,
	stallLogged: { [number]: boolean },
	lastNudge: string,
	activeAt: number,
	lastAt: Vector3?,
	snapScreen: string,
	healthMem: string?, -- #3098 P2: the memory bucket the client reported, for health_check
	healthLogged: boolean, -- #3098 P2: health_check logged this session
	memLogged: { [number]: boolean }, -- #3743: mem_total marks and mem_tag indexes logged this session
	memFirst: number?, -- #3743: the MB at the session's first logged mark
	introShot: number, -- #3098 P1b: the furthest intro shot the client reported this session (0 none)
	stepClock: { [string]: number }, -- #3530: os.clock() when a step_gap step was reached this session
	areasCaught: { [string]: boolean }?, -- #3695: the areas with a catch, for the clean funnel (nil until joined is logged)
	rarityStep: number?, -- #3876: rarity_v1 steps logged this session (nil until joined is logged)
}

-- #2916: one next goal shown: where ("recap" or "join") and os.time() it was shown
type ShownGoal = { goal: Types.ReturnGoalView, mode: string, at: number }

-- #1888: one Store visit, a funnel session of StoreFunnel's: its id, the furthest step logged and the sku pressed.
-- #2914: `landing` is the tab the visit opened on (its first store_tab report), which tab_viewed doesn't count.
type StoreVisit = { id: string, step: number, sku: string?, landing: string? }

local sessions: { [Player]: Session } = {}
local studio = RunService:IsStudio()
local log: { LogEntry } = {}

-- Bucket helpers: the plan's ranges as short strings ------------------------------------------------------

local function bucket(n: number, edges: { number }, labels: { string }): string
	for i, edge in edges do
		if n <= edge then
			return labels[i]
		end
	end
	return labels[#labels]
end

local function catsWorking(profile: Profile): string
	local n = 0
	for _, instance in profile.cats do
		if instance.spotId ~= nil then
			n += 1
		end
	end
	return bucket(n, { 0, 1, 3, 6 }, { "0", "1", "2-3", "4-6", "7+" })
end

local function catsDistinct(profile: Profile): string
	return bucket(
		ProfileSchema.collectionCount(profile),
		{ 4, 11, 19, 29 },
		{ "1-4", "5-11", "12-19", "20-29", "30+" }
	)
end

local function tierText(profile: Profile): string
	return tostring(Economy.tier(profile))
end

-- Sending ----------------------------------------------------------------------------------------------------

-- FieldText.clean: Roblox drops a field that holds , " ' or / ("Event field CustomField02 is invalid")
local function customFields(values: { string }): { [string]: any }?
	if #values == 0 then
		return nil
	end
	local fields: { [string]: any } = {}
	for i, value in values do
		if i > #FIELD_KEYS then
			break
		end
		fields[FIELD_KEYS[i]] = FieldText.clean(value)
	end
	return fields
end

local function remember(
	player: Player,
	kind: string,
	name: string,
	value: number,
	values: { string }
)
	if not studio then
		return
	end
	table.insert(log, {
		at = os.time(),
		userId = player.UserId,
		kind = kind,
		name = name,
		value = value,
		fields = values,
	})
	if #log > LOG_SIZE then
		table.remove(log, 1)
	end
end

-- #1888: a player in owner test mode (OwnerTest.ATTRIBUTE, set by the server) is left out of every event.
local function excluded(player: Player): boolean
	return player:GetAttribute(OwnerTest.ATTRIBUTE) == true
end

local function deliver(kind: string, fn: () -> ())
	local ok, err = pcall(function()
		fn()
		return nil :: any
	end)
	if not ok then
		warn(string.format("[Telemetry] %s not logged: %s", kind, tostring(err)))
	end
end

-- Every Log call passes this budget first (EventGate): over budget, the event waits its turn instead of being refused
-- by Roblox ("You have sent too many events").
local gate = EventGate.new(os.clock())

local function send(player: Player, kind: string, fn: () -> ())
	if excluded(player) then
		return
	end
	local item = { kind = kind, fn = fn }
	if gate:offer(item, os.clock(), #Players:GetPlayers()) then
		deliver(kind, fn)
	end
end

local droppedWarnAt = -math.huge

local function flushGate()
	local now = os.clock()
	for _, item in gate:due(now, #Players:GetPlayers()) do
		deliver(item.kind, item.fn)
	end
	-- one line a minute at most, so a full queue doesn't flood the console
	if gate.dropped > 0 and now - droppedWarnAt >= 60 then
		droppedWarnAt = now
		warn(
			string.format(
				"[Telemetry] %d events dropped: the analytics queue is full",
				gate:takeDropped()
			)
		)
	end
end

local function logEconomy(
	player: Player,
	profile: Profile,
	isSource: boolean,
	amount: number,
	balance: number,
	transactionType: TransactionType,
	sku: string,
	currency: string?
)
	if amount <= 0 then
		return
	end
	local flow = if isSource
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local values = { tierText(profile), ClockService.phase(), catsWorking(profile) }
	local ending = math.max(0, math.floor(balance))
	local kind = if isSource then "source" else "sink"
	remember(player, if currency ~= nil then kind .. " " .. currency else kind, sku, amount, values)
	send(player, "economy " .. sku, function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency or CURRENCY,
			amount,
			ending,
			transactionType,
			sku,
			customFields(values)
		)
	end)
end

-- Logs the tips settled since the last log as one Source. `pending` is a credit (negative) or spend (positive)
-- already applied to the wallet whose own event comes next, so the tips event's endingBalance is the wallet
-- before it.
local function flushTips(player: Player, profile: Profile, pending: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	local tips = math.floor(profile.lifetimeCoins - session.accounted)
	if tips < 1 then
		return
	end
	session.accounted += tips
	-- #1273: the cafe's first tips (a cat in a role serving customers), when the watch missed them between syncs
	if Onboarding.reached(profile.telemetry, "first_role_assigned") then
		Telemetry.onboarding(player, profile, "first_customer_served")
	end
	-- F92: the pal bonus's share of it goes out as its own source, pal_bonus
	local pal = math.clamp(math.floor(Economy.takePalEarned(profile)), 0, tips)
	if tips - pal >= 1 then
		logEconomy(
			player,
			profile,
			true,
			tips - pal,
			profile.coins + pending - pal,
			"Gameplay",
			"tips"
		)
	end
	if pal >= 1 then
		logEconomy(player, profile, true, pal, profile.coins + pending, "Gameplay", "pal_bonus")
	end
end

-- Public API ---------------------------------------------------------------------------------------------------

-- One onboarding step (analytics-plan section 3). Logged at once when it is the next step, along with any later
-- steps already reached; held in profile.telemetry otherwise (Onboarding.reach). `values` go with this step only.
-- #1273 (easy-start.md section 5): the funnel goes out as Onboarding.FUNNEL with the player's user id as its one funnel
-- session, since LogOnboardingFunnelStepEvent has no name to keep it apart from the earlier funnels. v3 replaced
-- onboarding_v2 outright (Derek 2026-11-04), and v4 (#1888, 45 steps) replaces v3. #3695: the ledger is no longer sent
-- to Roblox; the clean funnel onboarding_v7 (logClean) is.
-- #3022: a listener hears each step as it is reached (CatService starts the second cat's waiting stray at
-- first_customer_served), after the step is logged. A listener that errors is logged and the rest still run.
local stepListeners: { (player: Player, name: string) -> () } = {}
function Telemetry.onStep(listener: (player: Player, name: string) -> ())
	table.insert(stepListeners, listener)
end

-- #3666: a step's fields with the intro test's group as custom field 3, for a save that is in the test.
local function grouped(profile: Profile, fields: { string }): { string }
	return IntroSplit.fields(profile.telemetry.introGroup, fields)
end

-- #3666 (shared/IntroSplit): a new save joins the intro test once, before its first sync and its first funnel step,
-- and intro_group is logged. Checked once per player per session, so the switch going on mid session moves nobody.
-- Called by onLoaded here and by CafeService ahead of a sync, whichever comes first.
-- The session's answer to "does the intro play itself" is fixed here too (Review-QA on #3667): a later switch on
-- must not start the scene mid play for a save grouped earlier.
local introChecked: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Telemetry.introJoin(player: Player, profile: Profile)
	if introChecked[player] ~= nil then
		return
	end
	local on = LiveFlagService.on(IntroSplit.FLAG)
	local state = profile.telemetry
	-- #4001: a new save takes its arm from a Creator Hub Experiment's introMode when there is one (a short wait for
	-- the config read, new saves only), else the older split by account number
	local mode: string? = nil
	if IntroSplit.joins(true, profile.stats.sessions, profile.introSeen, state.introGroup) then
		mode = IntroSplit.fromMode(IntroModeService.get(player))
		if introChecked[player] ~= nil then
			return -- another caller decided while this one waited
		end
	end
	local test = IntroSplit.fromMode(IntroModeService.studioMode()) -- Studio only (IntroModeService.studioMode)
	if test ~= nil then
		mode = test
	end
	local joins = test ~= nil
		or IntroSplit.joins(
			on or mode ~= nil,
			profile.stats.sessions,
			profile.introSeen,
			state.introGroup
		)
	local group = if joins then mode or IntroSplit.group(player.UserId) else state.introGroup
	introChecked[player] = IntroSplit.plays(group, on, Config.IntroAutoPlay)
	if joins then
		state.introGroup = group
		Telemetry.custom(player, IntroSplit.EVENT :: any, 1, { group :: string })
	end
end

-- #3666: whether the intro plays itself for this player this session (IntroSplit.plays as the session began).
function Telemetry.introPlays(player: Player, profile: Profile): boolean
	Telemetry.introJoin(player, profile)
	return introChecked[player] == true
end

-- #4001: whether this save's intro is the short one (its group is the Experiment's "short" arm).
function Telemetry.introShort(profile: Profile): boolean
	-- compared here, not through an IntroSplit helper: one more function there trips the test VM fault in
	-- IndexRewardsShared.spec (tools/cloudcheck/README.md)
	return profile.telemetry.introGroup == IntroSplit.SHORT
end

-- #3695: the clean funnel onboarding_v7 (Onboarding.CLEAN_STEPS), one run per player with the user id as its
-- session: every clean step done since the last one logged, read off the ledger, the cafe's tier and the areas with
-- a catch. Called after every ledger step, every rank up and every catch in an area.
-- The areas the save has a cat from (a spare cat counts by its old area too), added to `areas`.
local function saveAreas(profile: Profile, areas: { [string]: boolean })
	for catId in profile.collection do
		local def = Catalog.getCat(catId)
		if def ~= nil then
			areas[def.area] = true
			if def.incomeArea ~= nil then
				areas[def.incomeArea] = true
			end
		end
	end
end

local function logClean(player: Player, profile: Profile)
	local session = sessions[player]
	local state = profile.telemetry
	local logged = state.cleanStep or 0
	if logged >= Onboarding.CLEAN_COUNT then
		return
	end
	local areas: { [string]: boolean } = if session ~= nil and session.areasCaught ~= nil
		then session.areasCaught
		else {}
	if logged >= Onboarding.CLEAN_TUTORIAL then
		-- past the tutorial the next steps can be an area's: a cat from bait or a rescue never passes caughtIn, so
		-- the save is read again (Review-QA on #3697)
		saveAreas(profile, areas)
	end
	local facts: Onboarding.CleanFacts = { tier = Economy.tier(profile), areas = areas }
	for _, step in Onboarding.cleanDue(state, logged, facts) do
		state.cleanStep = step
		local name = Onboarding.CLEAN_STEPS[step]
		local fields = grouped(profile, {}) -- #3666
		remember(player, "funnel", Onboarding.CLEAN_FUNNEL .. " " .. name, step, fields)
		send(player, "funnel " .. Onboarding.CLEAN_FUNNEL, function()
			AnalyticsService:LogFunnelStepEvent(
				player,
				Onboarding.CLEAN_FUNNEL,
				tostring(player.UserId),
				step,
				name,
				customFields(fields)
			)
		end)
	end
end

-- #3695: a cat caught in `area` (CatService, as the catch is won), for the clean funnel's area steps.
function Telemetry.caughtIn(player: Player, profile: Profile, area: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	local areas = session.areasCaught
	if areas == nil then
		return -- joined is not logged yet: logJoined reads the save's areas, and the cat joins them at check-in
	end
	if areas[area] ~= true then
		areas[area] = true
		logClean(player, profile)
	end
end

function Telemetry.onboarding(
	player: Player,
	profile: Profile,
	stepName: Onboarding.StepName,
	values: { string }?
)
	-- #3530: the gaps that end here, read before the step moves anything
	local session = sessions[player]
	local fresh = not Onboarding.reached(profile.telemetry, stepName)
	local gaps: { { gap: StepGaps.Gap, startReached: boolean } } = {}
	if fresh then
		for _, gap in StepGaps.endingAt(stepName) do
			table.insert(gaps, {
				gap = gap,
				startReached = Onboarding.reached(
					profile.telemetry,
					gap.from :: Onboarding.StepName
				),
			})
		end
	end
	local reach = Onboarding.reachDetail(profile.telemetry, stepName)
	-- #3530: a step put on hold is timed now, when it happened (first_bait_resolved used to wait for the rescue
	-- steps in front of it and read as a 172 second bait wait); it is not timed again when the funnel lets it go
	for _, name in reach.held do
		Telemetry.stepTime(player, profile, name)
	end
	for _, name in reach.log do
		local step = Onboarding.index(name)
		local fields = grouped(profile, if name == stepName and values ~= nil then values else {})
		-- #3695: the ledger is kept and listened to as before, but no longer sent to Roblox as a funnel: the clean
		-- funnel (logClean, below) is what goes out, and Roblox drops every funnel past ten a day
		remember(player, "onboarding", name, step, fields)
		-- #2774 (Derek2: "setup funnels"): when in the account's play the step came, once per step
		if not reach.released[name] then
			Telemetry.stepTime(player, profile, name)
		end
		for _, listener in stepListeners do
			local ok, err = pcall(function()
				listener(player, name)
			end)
			if not ok then
				warn("[Telemetry] step listener: " .. tostring(err))
			end
		end
	end
	if fresh and session ~= nil then
		local now = os.clock()
		for _, entry in gaps do
			local seconds, bucket =
				StepGaps.measure(entry.startReached, session.stepClock[entry.gap.from], now)
			Telemetry.custom(player, "step_gap", seconds, { entry.gap.name, bucket })
		end
		if StepGaps.marks(stepName) then
			session.stepClock[stepName] = now
		end
	end
	if #reach.log > 0 or #reach.held > 0 then
		logClean(player, profile) -- #3695
	end
end

-- #2774: a step_time event, value the seconds of play on the account when `name` came. Onboarding steps log theirs
-- above; #3022's three second cat steps (shared/SecondCat.STEPS) come through here from CatService.
function Telemetry.stepTime(player: Player, profile: Profile, name: string)
	Telemetry.custom(player, "step_time", math.floor(PlayTime.seconds(player, profile)), { name })
end

-- #2996: call right after an upgrade's level went up. Logs how long after the previous buy it came, so the first
-- three buys' spacing can be read per day (shared/UpgradePace).
function Telemetry.upgradeBought(player: Player, profile: Profile, upgradeId: string, level: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	local now = os.time()
	local gap = UpgradePace.gap(now, session.lastUpgradeAt, session.joinedAt)
	session.lastUpgradeAt = now
	Telemetry.custom(
		player,
		"upgrade_bought",
		gap,
		{ UpgradePace.nth(UpgradePace.bought(profile.upgradeLevels)), upgradeId, tostring(level) }
	)
end

-- Call right after Economy.credit(profile, amount) for anything that is not cafe income (section 5).
function Telemetry.source(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	local session = sessions[player]
	if session ~= nil then
		session.accounted += amount -- the credit raised lifetimeCoins; it is not tips
	end
	flushTips(player, profile, -amount)
	logEconomy(player, profile, true, amount, profile.coins, transactionType, sku)
end

-- Call right after a successful Economy.trySpend(profile, amount).
function Telemetry.sink(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	flushTips(player, profile, amount)
	logEconomy(player, profile, false, amount, profile.coins, transactionType, sku)
end

-- Golden fish (F52): their own currency, golden_fish, never mixed into the coin flush. Call right after
-- GoldenFish.credit. Sources: first_catch, repeat_catch, rank_up, index_reward, spin_wheel, tip_jar, code.
function Telemetry.fishSource(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	logEconomy(
		player,
		profile,
		true,
		amount,
		profile.goldenFish,
		transactionType,
		sku,
		FISH_CURRENCY
	)
end

-- Call right after a successful GoldenFish.trySpend. Sinks: crate, lure, perk.
function Telemetry.fishSink(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	logEconomy(
		player,
		profile,
		false,
		amount,
		profile.goldenFish,
		transactionType,
		sku,
		FISH_CURRENCY
	)
end

-- #2486: where this player's join came from (JoinSource) and the Experience Event id it came through ("" for none).
function Telemetry.joinOf(player: Player): (string, string)
	local session = sessions[player]
	if session == nil then
		return JoinSource.ORGANIC, ""
	end
	return session.source, session.joinEvent
end

function Telemetry.custom(player: Player, name: CustomEvent, value: number, values: { string }?)
	local fields = values or {}
	if studio and #fields > #FIELD_KEYS then
		-- Roblox takes three custom fields; customFields drops the rest without a word (Review-QA on #3413)
		warn(
			string.format(
				"[Telemetry] %s has %d fields, only the first %d are sent",
				name,
				#fields,
				#FIELD_KEYS
			)
		)
	end
	remember(player, "custom", name, value, fields)
	send(player, "custom " .. name, function()
		AnalyticsService:LogCustomEvent(player, name, value, customFields(fields))
	end)
end

-- Logs the net swings counted since the last roll up, one net_swing event per result, net level and device.
local function flushSwings(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	-- #2910: the station opens roll up on the same beat
	local opens = session.stationOpens
	session.stationOpens = {}
	for _, entry in opens do
		Telemetry.custom(player, "station_open", entry.count, entry.values)
	end
	if next(session.swings) == nil then
		return
	end
	local swings = session.swings
	session.swings = {}
	for _, entry in swings do
		Telemetry.custom(player, "net_swing", entry.count, entry.values)
	end
end

-- #2910: one walk-up station open (`window`, `how` "ring" or "prompt", checked by the caller), counted for the next
-- roll up with the device.
function Telemetry.stationOpen(player: Player, window: string, how: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	local values = { window, how, session.device or "unknown" }
	local key = table.concat(values, "|")
	local entry = session.stationOpens[key]
	if entry == nil then
		session.stationOpens[key] = { count = 1, values = values }
	else
		entry.count += 1
	end
end

-- Counts one net swing (F93): `result` is NetSwing.result's "hit", "miss_near" or "miss_empty". Logged rolled up
-- every SWING_FLUSH_SECONDS and on leave (review S99).
function Telemetry.netSwing(player: Player, result: string, netLevel: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	local values = { result, tostring(netLevel), session.device or "unknown" }
	local key = table.concat(values, "|")
	local entry = session.swings[key]
	if entry == nil then
		session.swings[key] = { count = 1, values = values }
	else
		entry.count += 1
	end
end

local function funnelStep(
	player: Player,
	funnel: string,
	sessionId: string,
	step: number,
	stepName: string,
	values: { string }
)
	remember(player, "funnel", funnel .. " " .. stepName, step, values)
	send(player, "funnel " .. funnel, function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			funnel,
			sessionId,
			step,
			stepName,
			customFields(values)
		)
	end)
end

-- #3378: stray_call. The client reports each call of its own waiting stray (TelemetryReport "stray_call"); a catch
-- that starts within STRAY_CALL_SECONDS answers it "yes", otherwise it is logged "no" when the time is up.
local STRAY_CALL_SECONDS = 10
local STRAY_CALLS_MOST = 8 -- a session; the client calls 4 times a stray at most

local function strayCalled(player: Player, number: number)
	local session = sessions[player]
	if session == nil or session.strayCall ~= nil or session.strayCalls >= STRAY_CALLS_MOST then
		return
	end
	session.strayCalls += 1
	session.strayCall = number
	task.delay(STRAY_CALL_SECONDS, function()
		if sessions[player] == session and session.strayCall == number then
			session.strayCall = nil
			Telemetry.custom(player, "stray_call", number, { "no" })
		end
	end)
end

local function strayCallAnswered(player: Player)
	local session = sessions[player]
	local number = if session ~= nil then session.strayCall else nil
	if session ~= nil and number ~= nil then
		session.strayCall = nil
		Telemetry.custom(player, "stray_call", number, { "yes" })
	end
end

-- catch_attempt step 1 (F93, catch-rework.md section 5): a net swing landed on a stray. `method` is net, rescue or
-- net_dropped (a knocked-loose cat).
function Telemetry.swingHit(
	player: Player,
	rarity: string,
	method: string,
	area: string
): CatchFunnel
	local funnel = { id = HttpService:GenerateGUID(false), values = { rarity, method, area } }
	funnelStep(player, "catch_attempt", funnel.id, 1, "swing_hit", funnel.values)
	strayCallAnswered(player) -- #3378
	return funnel
end

-- Step 2: the circles went out after that swing, or RescueBegin sent the challenge. A rescue has no swing, so with no
-- `funnel` this opens one and logs step 1 with it: the hold on the trap is where a rescue reaches its cat.
function Telemetry.catchEngaged(
	player: Player,
	rarity: string,
	method: string,
	area: string,
	funnel: CatchFunnel?
): CatchFunnel
	local current = funnel or Telemetry.swingHit(player, rarity, method, area)
	funnelStep(player, "catch_attempt", current.id, 2, "engaged", current.values)
	return current
end

-- Step 3: the cat is in the player's arms.
-- A Grand Opening milestone paid (called after the mark). #2444: its own grand_opening funnel (#1893) is no longer
-- sent; onboarding_v5's first_goal_done and grand_opening_done carry it (#2391).
function Telemetry.grandOpening(player: Player, profile: Profile, n: number)
	if GrandOpening.STEPS[n] == nil then
		return
	end
	Telemetry.onboarding(player, profile, "first_goal_done")
	if GrandOpening.doneCount(profile.grandOpening) >= GrandOpening.COUNT then
		Telemetry.onboarding(player, profile, "grand_opening_done")
	end
end

-- #3695: the playtime_v1 funnel (Onboarding.PLAYTIME_STEPS), one run per player with the user id as its session:
-- joined, moved (the ledger's first_move), then every mark the account's play time has reached since the last one
-- logged. It replaces first_hour_v3 (#2391, #3308), which is no longer sent.
local function logFirstHour(player: Player, profile: Profile)
	local state = profile.telemetry
	local logged = state.playtimeStep or 0
	if logged >= Onboarding.PLAYTIME_COUNT then
		return
	end
	local moved = Onboarding.reached(state, "first_move")
	for _, step in Onboarding.playtimeDue(logged, PlayTime.seconds(player, profile), moved) do
		state.playtimeStep = step
		local name = Onboarding.PLAYTIME_STEPS[step]
		local fields = grouped(profile, {}) -- #3666
		remember(player, "funnel", Onboarding.PLAYTIME_FUNNEL .. " " .. name, step, fields)
		send(player, "funnel " .. Onboarding.PLAYTIME_FUNNEL, function()
			AnalyticsService:LogFunnelStepEvent(
				player,
				Onboarding.PLAYTIME_FUNNEL,
				tostring(player.UserId),
				step,
				name,
				customFields(fields)
			)
		end)
	end
end

-- #3876: the rarity_v1 funnel (shared/RarityFunnel), one run per player with the user id as its session: every step
-- up to the best rarity in the save's Index not yet logged this session. A new session logs its steps again, which
-- the report counts once a player (FunnelUserTotalCount); no save field is needed. Only with the `secretCats` switch.
local function logRarity(player: Player, profile: Profile)
	local session = sessions[player]
	if
		session == nil
		or session.rarityStep == nil
		or not LiveFlagService.on(Catching.SECRET_FLAG)
	then
		return
	end
	local logged = session.rarityStep :: number
	if logged >= #RarityFunnel.STEPS then
		return
	end
	for _, step in RarityFunnel.due(logged, RarityFunnel.best(profile.collection)) do
		session.rarityStep = step
		local name = RarityFunnel.STEPS[step]
		local fields = grouped(profile, {}) -- #3666
		remember(player, "funnel", RarityFunnel.NAME .. " " .. name, step, fields)
		send(player, "funnel " .. RarityFunnel.NAME, function()
			AnalyticsService:LogFunnelStepEvent(
				player,
				RarityFunnel.NAME,
				tostring(player.UserId),
				step,
				name,
				customFields(fields)
			)
		end)
	end
end

-- #2796 (retention-ideas.md 5c): the pity_v1 funnel, one run per player per pity cat (`key`, the cat's claim key):
-- 1 pity_seen (the player came within PITY_SEEN_STUDS of it), 2 pity_catch_started, 3 pity_caught (the claim won).
-- Fields: the kind (Legendary or Mythical), the area and the player's minutes played on the account as a band.
-- Counts only, never who. Spawns are pity_cat's "spawned".
Telemetry.PITY_FUNNEL = "pity_v1"
Telemetry.PITY_STEPS = { "pity_seen", "pity_catch_started", "pity_caught" }

local function minutesBand(seconds: number): string
	local minutes = seconds / 60
	if minutes < 10 then
		return "0-10"
	elseif minutes < 30 then
		return "10-30"
	elseif minutes < 60 then
		return "30-60"
	elseif minutes < 180 then
		return "60-180"
	end
	return "180+"
end

function Telemetry.pityStep(
	player: Player,
	profile: Profile,
	key: string,
	step: number,
	kind: string,
	area: string
)
	local name = Telemetry.PITY_STEPS[step]
	if name == nil then
		return
	end
	funnelStep(
		player,
		Telemetry.PITY_FUNNEL,
		key .. ":" .. tostring(player.UserId),
		step,
		name,
		{ kind, area, minutesBand(PlayTime.seconds(player, profile)) }
	)
end

-- #3378: arcade_v1 (shared/ArcadeFunnel), one run per player per UTC day. `step` is one of ArcadeFunnel's; `free`
-- says whether the game is (or, before a game, would be) the day's free one. Returns nothing; an owner in test mode
-- logs nothing (send).
function Telemetry.arcadeStep(player: Player, profile: Profile, step: number, free: boolean)
	local session = sessions[player]
	if session == nil then
		return
	end
	local day = math.floor(os.time() / 86400)
	local due = ArcadeFunnel.due(session.arcade, day, step)
	if #due == 0 then
		return
	end
	local values = {
		if free then "free" else "paid",
		session.device or "unknown",
		minutesBand(PlayTime.seconds(player, profile)),
	}
	local key = ArcadeFunnel.key(day, player.UserId)
	for _, s in due do
		funnelStep(player, ArcadeFunnel.NAME, key, s, ArcadeFunnel.STEPS[s], values)
	end
end

-- #3378: a game started. Logs arcade_started, and arcade_played_again for a second game that day (`freeUsed`: the
-- day's free game was already used before this one, from the arcade save).
function Telemetry.arcadeStarted(player: Player, profile: Profile, free: boolean, freeUsed: boolean)
	local session = sessions[player]
	if session == nil then
		return
	end
	local again = ArcadeFunnel.started(session.arcade, math.floor(os.time() / 86400), freeUsed)
	Telemetry.arcadeStep(player, profile, ArcadeFunnel.STARTED, free)
	if again then
		Telemetry.arcadeStep(player, profile, ArcadeFunnel.PLAYED_AGAIN, free)
	end
end

-- #3378: hears every counted station open (window, as StationOpens.WINDOWS), after it is counted.
local stationListeners: { (player: Player, window: string) -> () } = {}
function Telemetry.onStationOpen(listener: (player: Player, window: string) -> ())
	table.insert(stationListeners, listener)
end

function Telemetry.catchCaught(player: Player, funnel: CatchFunnel)
	funnelStep(player, "catch_attempt", funnel.id, 3, "caught", funnel.values)
end

-- Step 4, and step 5 at once when the cat went straight to a role; otherwise step 5 waits for PlaceCat or Equip
-- best to give that uid a role (`catWorking`).
function Telemetry.catchCheckedIn(
	player: Player,
	funnel: CatchFunnel,
	uid: string,
	working: boolean
)
	funnelStep(player, "catch_attempt", funnel.id, 4, "checked_in", funnel.values)
	-- #2774: cat_caught has no field left for the area (values: rarity, method, area)
	local area = funnel.values[3]
	if type(area) == "string" and area ~= "" then
		Telemetry.custom(player, "cat_caught_area", 1, { area, funnel.values[1] or "unknown" })
	end
	if working then
		funnelStep(player, "catch_attempt", funnel.id, 5, "working", funnel.values)
		return
	end
	local session = sessions[player]
	if session ~= nil then
		session.waitingForRole[uid] = funnel
	end
end

function Telemetry.catWorking(player: Player, uid: string)
	local session = sessions[player]
	local funnel = if session ~= nil then session.waitingForRole[uid] else nil
	if session == nil or funnel == nil then
		return
	end
	session.waitingForRole[uid] = nil
	funnelStep(player, "catch_attempt", funnel.id, 5, "working", funnel.values)
end

-- A shove knocked this player's cat loose: if they leave within LEFT_AFTER_SHOVE_SECONDS, left_after_shove fires.
function Telemetry.knockedLoose(player: Player, rarity: string)
	local session = sessions[player]
	if session ~= nil then
		session.knockedAt = os.clock()
		session.knockedRarity = rarity
	end
end

-- #2720: a restart warning `secondsLeft` before the restart was shown to this player: if they leave within
-- LEFT_AFTER_RESTART_WARNING_SECONDS, left_after_restart_warning fires (does the warning drive players out?).
function Telemetry.restartWarned(player: Player, secondsLeft: number)
	local session = sessions[player]
	if session ~= nil then
		session.restartWarnedAt = os.clock()
		session.restartWarnedLeft = math.max(0, math.ceil(secondsLeft))
		session.restartWarnings += 1
	end
end

local function areaIndex(player: Player, profile: Profile, complete: boolean, areaId: string)
	local area = Catalog.getArea(areaId)
	if area == nil then
		return
	end
	local values = { catsDistinct(profile) }
	remember(
		player,
		if complete then "progress_complete" else "progress_start",
		"area_index",
		area.tier,
		values
	)
	send(player, "progression area_index", function()
		if complete then
			AnalyticsService:LogProgressionCompleteEvent(
				player,
				"area_index",
				area.tier,
				areaId,
				customFields(values)
			)
		else
			AnalyticsService:LogProgressionStartEvent(
				player,
				"area_index",
				area.tier,
				areaId,
				customFields(values)
			)
		end
	end)
end

-- After a new cat joins the collection: area_index completes when every catalog cat of its area is in the Index. A
-- spare cat (data-model 3d) has no area page.
-- #2916: the next goals the player was shown, logged once per kind and place a session and watched until met.
function Telemetry.goalsShown(
	player: Player,
	goals: { Types.ReturnGoalView },
	mode: "recap" | "join"
)
	local session = sessions[player]
	if session == nil then
		return
	end
	for _, goal in goals do
		local seen = false
		for _, shown in session.goals do
			if shown.goal.kind == goal.kind and shown.mode == mode then
				seen = true
				break
			end
		end
		if seen or table.find(ReturnGoals.KINDS, goal.kind) == nil then
			continue
		end
		local need = goal.need or 0
		local percent = if need > 0
			then math.clamp(math.floor((goal.have or 0) / need * 100), 0, 100)
			else 0
		Telemetry.custom(
			player,
			"return_goal_shown",
			percent,
			{ goal.kind, mode, if goal.tier ~= nil then tostring(goal.tier) else "none" }
		)
		local entry: ShownGoal = { goal = goal, mode = mode :: string, at = os.time() }
		table.insert(session.goals, entry)
	end
end

-- #2916: return_goal_done for every watched goal `profile` meets now (a new cat, a rank up).
local function goalsCheck(player: Player, profile: Profile)
	local session = sessions[player]
	if session == nil or #session.goals == 0 then
		return
	end
	for index = #session.goals, 1, -1 do
		local shown = session.goals[index]
		if ReturnGoals.done(shown.goal, profile) then
			table.remove(session.goals, index)
			Telemetry.custom(
				player,
				"return_goal_done",
				math.floor(math.max(0, os.time() - shown.at) / 60),
				{
					shown.goal.kind,
					shown.mode,
					if shown.goal.tier ~= nil then tostring(shown.goal.tier) else "none",
				}
			)
		end
	end
end

function Telemetry.collected(player: Player, profile: Profile, def: Types.CatDef)
	goalsCheck(player, profile) -- #2916
	logRarity(player, profile) -- #3876
	if def.area == "spare" or def.area == "secret" then
		return -- #3470: a Secret cat is on no area's Index page
	end
	for _, other in Catalog.cats do
		if other.area == def.area and profile.collection[other.id] == nil then
			return
		end
	end
	areaIndex(player, profile, true, def.area)
end

local function progression(player: Player, profile: Profile, complete: boolean, tier: number)
	local values = { catsDistinct(profile) }
	local levelName = TIER_NAMES[tier] or tostring(tier)
	remember(
		player,
		if complete then "progress_complete" else "progress_start",
		"tier",
		tier,
		values
	)
	send(player, "progression tier", function()
		if complete then
			AnalyticsService:LogProgressionCompleteEvent(
				player,
				"tier",
				tier,
				levelName,
				customFields(values)
			)
		else
			AnalyticsService:LogProgressionStartEvent(
				player,
				"tier",
				tier,
				levelName,
				customFields(values)
			)
		end
	end)
end

-- After RankUp has set profile.tier (and logged its Sink): the progression pair, rank_up with lifetime minutes
-- played, and the tier onboarding steps.
function Telemetry.rankedUp(player: Player, profile: Profile)
	local tier = Economy.tier(profile)
	goalsCheck(player, profile) -- #2916
	progression(player, profile, true, tier - 1)
	progression(player, profile, false, tier)
	local tierDef = Catalog.getTier(tier)
	if tierDef ~= nil then
		areaIndex(player, profile, false, tierDef.area)
	end
	local session = sessions[player]
	local seconds = profile.stats.playtimeSeconds
		+ (if session ~= nil then math.max(0, os.time() - session.joinedAt) else 0)
	Telemetry.custom(player, "rank_up", math.floor(seconds / 60), { tostring(tier) })
	if tier == 2 then
		-- RankUp is pressed on the Rank Up card with the needs met: tier_2 implies both steps before it (F87)
		Telemetry.onboarding(player, profile, "tier_2")
	elseif tier == 3 then
		Telemetry.onboarding(player, profile, "tier_3")
	elseif tier == 4 then
		Telemetry.onboarding(player, profile, "tier_4") -- #1888
	end
	logClean(player, profile) -- #3695: the tier steps (Tier 5 to 7 have no ledger step)
end

-- #1888: Cafe Pass XP added (Payout's passXp), the level `before` and `after` it: first_pass_xp, pass_level_5, and
-- cafe_pass_level at every fifth level crossed.
function Telemetry.passXp(player: Player, profile: Profile, before: number, after: number)
	Telemetry.onboarding(player, profile, "first_pass_xp")
	if after >= 5 then
		Telemetry.onboarding(player, profile, "pass_level_5")
	end
	for level = before + 1, after do
		if level % 5 == 0 then
			Telemetry.custom(player, "cafe_pass_level", level, {
				tostring(profile.pass.season),
				if profile.pass.paidSeason == profile.pass.season then "paid" else "free",
				tierText(profile),
			})
		end
	end
end

-- #1888: the days since the account's first join, "0" on its first day, "30+" past a month, "unknown" when the first
-- day is not known.
local function dayText(profile: Profile): string
	local first = profile.telemetry.firstDay
	if first <= 0 then
		return "unknown"
	end
	local days = math.max(0, os.time() // DAY_SECONDS - first)
	return if days >= 30 then "30+" else tostring(days)
end

-- #1888: one step of the Store funnel for the visit open now, once each and only forward.
local function storeStep(player: Player, name: string, values: { string })
	local session = sessions[player]
	local visit = if session ~= nil then session.store else nil
	local step = StoreFunnel.index(name)
	if visit == nil or step <= visit.step then
		return
	end
	visit.step = step
	funnelStep(player, StoreFunnel.NAME, visit.id, step, name, values)
end

-- #2914: the store_v1 prompt_closed step, for the sku this visit's buy button pressed only (a bait or Cafe Pass
-- prompt outside the Store isn't this visit's).
local function promptClosed(player: Player, sku: string, result: "bought" | "cancelled")
	local session = sessions[player]
	local visit = if session ~= nil then session.store else nil
	if visit ~= nil and visit.sku == sku then
		storeStep(player, "prompt_closed", { sku, result })
	end
end

-- #1888: whether the player has spent Robux here before this purchase: a product receipt on the save (`receipts`
-- counts this one when it is a product), or a pass of ours other than `passId` owned.
local function spentBefore(
	player: Player,
	profile: Profile,
	receipts: number,
	passId: number?
): boolean
	if #profile.receipts > receipts then
		return true
	end
	for _, id in StoreFunnel.passIds() do
		if id ~= passId and PassService.owns(player, id) then
			return true
		end
	end
	return false
end

-- #1888: a pass or product bought, `robux` the price paid (0 when Roblox did not say): robux_purchase, the Store
-- funnel's completed step and, on the account's first spend, first_robux_purchase.
function Telemetry.robuxPurchase(
	player: Player,
	profile: Profile,
	sku: string,
	robux: number,
	first: boolean
)
	Telemetry.custom(
		player,
		"robux_purchase",
		math.max(0, math.floor(robux)),
		{ sku, dayText(profile), if first then "first" else "repeat" }
	)
	promptClosed(player, sku, "bought") -- a receipt can come before the prompt says it closed
	storeStep(player, "completed", { sku, tostring(math.floor(robux)) })
	Telemetry.onboarding(player, profile, "first_robux_purchase")
end

-- #1888: ProductService's newly granted receipt (already recorded on the save), `robux` its CurrencySpent.
function Telemetry.productBought(
	player: Player,
	profile: Profile,
	productId: number,
	robux: unknown
)
	local sku = StoreFunnel.productSku(productId) or "product_other"
	local paid = if type(robux) == "number" then robux else 0
	Telemetry.robuxPurchase(player, profile, sku, paid, not spentBefore(player, profile, 1, nil))
end

-- #1888: Roblox's own prices, looked up once per server (yields; nil when the lookup fails).
local prices: { [string]: number } = {}
local function priceOf(kind: "pass" | "product", id: number): number?
	local key = kind .. tostring(id)
	if prices[key] ~= nil then
		return prices[key]
	end
	local ok, info = pcall(function(): any
		return MarketplaceService:GetProductInfo(
			id,
			if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		)
	end)
	local price = if ok and type(info) == "table" then info.PriceInRobux else nil
	if type(price) == "number" then
		prices[key] = price
		return price
	end
	return nil
end

-- #2131: a pass prompt that said bought, by player and pass id: whether it was the account's first spend, kept until
-- PassService.purchased confirms it with Roblox (a faked flag never logs a purchase).
local pendingPasses: { [Player]: { [number]: boolean } } = {} -- cleared with the session

-- #1888: a game pass prompt closed (PromptGamePassPurchaseFinished on the server): bought, or store_cancelled.
local function onPassPrompt(player: Player, passId: unknown, purchased: unknown)
	local sku = StoreFunnel.passSku(passId)
	local profile = DataService.get(player)
	if sku == nil or profile == nil then
		return
	end
	if purchased ~= true then
		Telemetry.custom(player, "store_cancelled", 1, { sku, tierText(profile) })
		promptClosed(player, sku, "cancelled")
		return
	end
	promptClosed(player, sku, "bought")
	-- now, before PassService's check marks the pass owned; robux_purchase waits for that check (#2131)
	local pending = pendingPasses[player] or {}
	pendingPasses[player] = pending
	pending[passId :: number] = not spentBefore(player, profile, 0, passId :: number)
end

-- #2131: PassService confirmed a bought pass with Roblox: robux_purchase now.
local function onPassConfirmed(player: Player, passId: number)
	local pending = pendingPasses[player]
	local first = if pending ~= nil then pending[passId] else nil
	if first == nil then
		return
	end
	pending[passId] = nil
	local sku = StoreFunnel.passSku(passId)
	local current = DataService.get(player)
	if sku == nil or current == nil then
		return
	end
	task.spawn(function()
		local price = priceOf("pass", passId) or 0 -- yields (GetProductInfo)
		Telemetry.robuxPurchase(player, current, sku, price, first)
	end)
end

-- #1888: a product prompt closed without buying is store_cancelled (a bought one is ProductService's receipt).
-- #2914: either way it is store_v1's prompt_closed.
local function onProductPrompt(userId: unknown, productId: unknown, purchased: unknown)
	if type(userId) ~= "number" then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	local sku = StoreFunnel.productSku(productId)
	local profile = if player ~= nil then DataService.get(player) else nil
	if player == nil or sku == nil or profile == nil then
		return
	end
	if purchased == true then
		promptClosed(player, sku, "bought")
	else
		Telemetry.custom(player, "store_cancelled", 1, { sku, tierText(profile) })
		promptClosed(player, sku, "cancelled")
	end
end

-- The device this player's client reported this session ("phone", "tablet", "pc" or "console"), or nil before it
-- has (bug reports carry it).
function Telemetry.device(player: Player): string?
	local session = sessions[player]
	return if session ~= nil then session.device else nil
end

-- #2681: the slide-in feedback faces shown (TipSeen feedback_ask): opens a feedback_v1 run, at most
-- FeedbackFunnel.ASKS_PER_SESSION a session, which the next answer this session goes on.
function Telemetry.feedbackAsked(player: Player, profile: Profile)
	local session = sessions[player]
	if session == nil or session.feedbackAsks >= FeedbackFunnel.ASKS_PER_SESSION then
		return
	end
	session.feedbackAsks += 1
	local run = HttpService:GenerateGUID(false)
	session.feedbackRun = run
	funnelStep(player, FeedbackFunnel.NAME, run, FeedbackFunnel.index("ask_shown"), "ask_shown", {
		tierText(profile),
		FeedbackFunnel.minutesBucket(PlayTime.seconds(player, profile)),
		Onboarding.cleanFurthest(profile.telemetry),
	})
end

-- #3272: the once-a-day session ask's answer (TipService checked it): who answered, as three events of three fields.
function Telemetry.sessionFeedback(player: Player, profile: Profile, answer: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	local cats = 0
	for _ in profile.cats do
		cats += 1
	end
	local length = SessionFeedback.sessionBucket(os.time() - session.joinedAt)
	Telemetry.custom(player, "session_feedback", 1, { answer, session.device or "unknown", length })
	Telemetry.custom(
		player,
		"session_feedback_ctx",
		1,
		{ answer, Onboarding.cleanFurthest(profile.telemetry), SessionFeedback.catsBucket(cats) }
	)
	Telemetry.custom(player, "session_feedback_where", 1, {
		answer,
		session.screen,
		FeedbackFunnel.build(game.PlaceVersion, session.clientError),
	})
end

-- #2681: one feedback answer (TipService took it and logged `feedback`): where the player was, and the open
-- feedback_v1 run's face and chip steps. An answer from the Feedback button with no ask open logs no run.
function Telemetry.feedbackAnswered(player: Player, profile: Profile, face: string, chip: string?)
	local session = sessions[player]
	if session == nil then
		return
	end
	local minutes = FeedbackFunnel.minutesBucket(PlayTime.seconds(player, profile))
	Telemetry.custom(
		player,
		"feedback_ctx",
		1,
		{ face, Onboarding.cleanFurthest(profile.telemetry), minutes }
	)
	Telemetry.custom(player, "feedback_env", 1, {
		face,
		session.device or "unknown",
		FeedbackFunnel.build(game.PlaceVersion, session.clientError),
	})
	local run = session.feedbackRun
	if run == nil then
		return
	end
	session.feedbackRun = nil
	funnelStep(
		player,
		FeedbackFunnel.NAME,
		run,
		FeedbackFunnel.index("face_picked"),
		"face_picked",
		{ face, minutes }
	)
	if chip ~= nil then
		funnelStep(
			player,
			FeedbackFunnel.NAME,
			run,
			FeedbackFunnel.index("chip_picked"),
			"chip_picked",
			{ face, chip }
		)
	end
end

-- #2681: the like ask shown (TipService's ask_shown for like_ask), to line up with Creator Hub's daily votes.
function Telemetry.likeAskShown(player: Player, profile: Profile)
	local session = sessions[player]
	Telemetry.custom(player, "like_ask_shown", 1, {
		tierText(profile),
		FeedbackFunnel.minutesBucket(PlayTime.seconds(player, profile)),
		if session ~= nil then session.device or "unknown" else "unknown",
	})
end

-- The last LOG_SIZE events, oldest first (Studio only; empty on a live server).
function Telemetry.recent(count: number?): { LogEntry }
	local first = math.max(1, #log - (count or #log) + 1)
	local out: { LogEntry } = {}
	for i = first, #log do
		table.insert(out, log[i])
	end
	return out
end

-- Join and leave --------------------------------------------------------------------------------------------------

-- joined goes out as the profile loads (#1273: loaded carries the device now), then returned_next_day and the
-- steps the save already shows, so a save is never stuck behind a step it passed silently (QA S72).
local function logJoined(player: Player)
	local session = sessions[player]
	local profile = DataService.get(player)
	if session == nil or profile == nil or session.joinLogged then
		return
	end
	session.joinLogged = true
	-- #3695: the areas the save has a cat from (a spare cat counts by its old area), before the first step logs
	local parkCats = 0
	for catId in profile.collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and (def.area == "park" or def.incomeArea == "park") then
			parkCats += 1
		end
	end
	local areasCaught: { [string]: boolean } = {}
	saveAreas(profile, areasCaught)
	session.areasCaught = areasCaught
	Telemetry.onboarding(player, profile, "joined", { session.source })
	logFirstHour(player, profile)
	session.rarityStep = 0 -- #3876
	logRarity(player, profile)
	if session.returnedNextDay then
		Telemetry.onboarding(player, profile, "returned_next_day")
	end
	local shown = Onboarding.fromSave({
		catsCaught = profile.stats.catsCaught,
		distinctCats = Economy.distinctCats(profile),
		tables = Economy.level(profile, "tables"),
		bowl = Economy.level(profile, "lure_bowl"),
		tier = Economy.tier(profile),
		parkCats = parkCats,
		starterCat = profile.starterCatClaimed,
		passXp = profile.pass.xp,
		passClaims = #profile.pass.claimedFree + #profile.pass.claimedPaid,
		passLevel = CafePass.levelOf(profile.pass.xp),
		spent = spentBefore(player, profile, 0, nil),
		goalsDone = GrandOpening.doneCount(profile.grandOpening),
	})
	for _, name in shown do
		Telemetry.onboarding(player, profile, name :: Onboarding.StepName)
	end
end

-- A new player (#1273, F87): their first UTC day of play, or still in the first loop (Onboarding.isNewPlayer).
local function isNewPlayer(profile: Profile, now: number): boolean
	return Onboarding.isNewPlayer(profile.tutorialStep, profile.telemetry.firstDay, now)
end

-- The three fields of the time markers and the leave events: the furthest step logged, the screen open, and `third`.
local function whereInFunnel(profile: Profile, session: Session, third: string): { string }
	return { Onboarding.cleanFurthest(profile.telemetry), session.screen, third }
end

-- What the client reports (TelemetryReport), analytics only: every name and value is allowlisted or range checked,
-- the remote is limited to 40 a minute (Net), and nothing here pays, unlocks or saves anything but telemetry. A
-- funnel step a client sends is reached by itself (Onboarding.CLIENT_STEPS) and logs once per player.
local function onReport(player: Player, rawName: unknown, rawValue: unknown)
	local name = Guard.oneOf(rawName, REPORTS)
	local session = sessions[player]
	local profile = DataService.get(player)
	if name == nil or session == nil or profile == nil then
		return
	end
	session.activeAt = os.clock() -- #3098: a report counts as activity for quit_snapshot's idle
	if name == "device" then
		local device = Guard.oneOf(rawValue, DEVICES)
		if device ~= nil and session.device == nil then
			session.device = device
			Telemetry.onboarding(player, profile, "loaded", { device })
		end
	elseif name == "intro_choice" then
		local from = Guard.oneOf(rawValue, INTRO_FROM)
		if from ~= nil and session.introChoices < INTRO_CHOICES then
			session.introChoices += 1
			Telemetry.custom(player, "intro_choice", 1, { from })
		end
	elseif name == "new_kind_trail" then
		-- #3529: once a session each, as step_time, and only with the switch on
		local step = if type(rawValue) == "string" then NewKind.REPORTS[rawValue] else nil
		if
			step ~= nil
			and LiveFlagService.on(NewKind.FLAG)
			and not session.nudges["new_kind:" .. step]
		then
			session.nudges["new_kind:" .. step] = true
			Telemetry.stepTime(player, profile, step)
		end
	elseif name == "stray_call" then
		local number = Guard.int(rawValue, 1, 4) -- #3378
		if number ~= nil then
			strayCalled(player, number)
		end
	elseif name == "stuck_nudge" then
		local kind = Guard.oneOf(rawValue, NUDGE_KINDS)
		if kind ~= nil then
			local step = tostring(profile.tutorialStep)
			local key = step .. ":" .. kind
			session.lastNudge = kind -- #3098: step_stall's hint
			if not session.nudges[key] then
				session.nudges[key] = true
				Telemetry.custom(player, "stuck_nudge", 1, { step, kind })
			end
		end
	elseif name == "event_rsvp" then
		local kind = Guard.oneOf(rawValue, RSVP_KINDS)
		if kind ~= nil and not session.nudges["rsvp:" .. kind] then
			session.nudges["rsvp:" .. kind] = true -- the stuck nudges' once-a-session set, keyed apart
			Telemetry.custom(player, "event_rsvp", 1, { kind })
		end
	elseif name == "intro_shot" then
		-- #3098 P1b: kept for quit_scene; the session's first shot 1 logs first_scene (join to the cutscene)
		if
			type(rawValue) == "number"
			and rawValue == math.floor(rawValue)
			and rawValue >= 1
			and rawValue <= FirstFive.INTRO_SHOTS
		then
			local shot = rawValue :: number
			-- only the first play's shot 1: a replay from the Tutorial tile later (introSeen) would time minutes, not
			-- the load (Gameplay-Engineer)
			local first = session.introShot == 0 and shot == 1 and not profile.introSeen
			session.introShot = math.max(session.introShot, shot)
			if first and Economy.tier(profile) < 2 then
				local waited = math.max(0, os.time() - session.joinedAt)
				Telemetry.custom(player, "first_scene", waited, {
					session.device or "unknown",
					"intro",
					FirstFive.firstSceneBucket(waited),
				})
			end
		end
	elseif name == "mem_total" then
		-- #3743: once a mark a session, and not before the mark's minute (less a minute for the two clocks)
		local mark, mb = MemoryWatch.decode(rawValue)
		local minutes = if mark ~= nil then MemoryWatch.MARKS[mark] else nil
		if
			mark ~= nil
			and mb ~= nil
			and minutes ~= nil
			and not session.memLogged[mark]
			and os.time() - session.joinedAt >= minutes * 60 - 60
		then
			session.memLogged[mark] = true
			Telemetry.custom(player, "client_memory", mb, {
				session.device or "unknown",
				"m" .. tostring(minutes),
				MemoryWatch.growthBucket(session.memFirst, mb),
			})
			if session.memFirst == nil then
				session.memFirst = mb
			end
		end
	elseif name == "mem_tag" then
		local index, mb = MemoryWatch.decode(rawValue)
		local mark: number?, tag: number? = nil, nil
		if index ~= nil then
			mark, tag = MemoryWatch.tagOf(index)
		end
		-- only beside a total this session already logged for that mark
		if
			index ~= nil
			and mb ~= nil
			and mark ~= nil
			and tag ~= nil
			and session.memLogged[mark]
			and not session.memLogged[1000 + index]
		then
			session.memLogged[1000 + index] = true
			Telemetry.custom(player, "client_memory_tag", mb, {
				MemoryWatch.TAGS[tag],
				"m" .. tostring(MemoryWatch.MARKS[mark]),
				session.device or "unknown",
			})
		end
	elseif name == "health_mem" then
		-- #3098 P2: kept for the health_check that follows; below Tier 2 only, like the other first-five events
		if
			type(rawValue) == "number"
			and rawValue == rawValue
			and rawValue >= 0
			and rawValue <= FirstFive.MEMORY_MAX
		then
			session.healthMem = FirstFive.memoryBucket(rawValue :: number)
		end
	elseif name == "health_fps" then
		if
			type(rawValue) == "number"
			and rawValue == rawValue
			and rawValue >= 0
			and rawValue <= FirstFive.FPS_MAX
			and not session.healthLogged
			and Economy.tier(profile) < 2
		then
			session.healthLogged = true
			Telemetry.custom(player, "health_check", math.floor(rawValue :: number), {
				FirstFive.pingBucket(player:GetNetworkPing() * 1000),
				session.healthMem or "unknown",
				session.device or "unknown",
			})
		end
	elseif name == "screen_short" then
		local size = Guard.oneOf(rawValue, SCREEN_SHORTS)
		if size ~= nil and not session.nudges.screen_short then
			session.nudges.screen_short = true -- once a session, in the stuck nudges' set
			Telemetry.custom(player, "screen_short", 1, { size })
		end
	elseif name == "step" then
		-- a tutorial card or the catch card on screen (Onboarding.REPORTABLE)
		local step = Guard.oneOf(rawValue, Onboarding.REPORTABLE)
		if step ~= nil then
			Telemetry.onboarding(player, profile, step :: Onboarding.StepName)
		end
	elseif name == "screen" then
		-- the screen open now, "none" when it closed; kept for the time markers and the leave events
		if type(rawValue) == "string" and #(rawValue :: string) <= SCREEN_NAME_MAX then
			local raw = rawValue :: string
			session.screen = if raw == "none" then "none" else SCREENS[raw] or "other"
			session.snapScreen = FirstFive.snapScreen(raw) -- #3098
		end
	elseif name == "tutorial_closed" then
		if not session.tutorialClosed then
			session.tutorialClosed = true
			Telemetry.custom(player, "tutorial_closed", 1, { tostring(profile.tutorialStep) })
		end
	elseif name == "park_first_hint" then
		local kind = Guard.oneOf(rawValue, PARK_HINTS)
		if kind ~= nil and not session.parkHints[kind] then
			session.parkHints[kind] = true
			Telemetry.custom(player, "park_first_hint", 1, { kind })
		end
	elseif name == "park_trail" then
		local kind = Guard.oneOf(rawValue, { "shown", "entered", "caught" })
		local event = if kind ~= nil then PARK_TRAIL[kind] else nil
		if kind ~= nil and event ~= nil and not session.parkTrail[kind] and profile.tier >= 2 then
			session.parkTrail[kind] = true
			Telemetry.custom(player, (event :: any) :: CustomEvent, 1, { tierText(profile) })
		end
	elseif name == "rank_spot" then
		local kind = Guard.oneOf(rawValue, { "shown", "closed" })
		local event = if kind ~= nil then RANK_SPOT[kind] else nil
		-- only a player the server said may see it (the attribute RankSpotService sets), or one who just had it
		if
			kind ~= nil
			and event ~= nil
			and not session.rankSpot[kind]
			and (player:GetAttribute("RankSpotlight") == true or session.rankSpot.shown)
		then
			session.rankSpot[kind] = true
			Telemetry.custom(
				player,
				(event :: any) :: CustomEvent,
				1,
				{ session.device or "unknown" }
			)
		end
	elseif name == "catch_reach" then
		local kind = Guard.oneOf(rawValue, { "near", "shown" })
		local event = if kind ~= nil then CATCH_REACH[kind] else nil
		if kind ~= nil and event ~= nil and not session.catchReach[kind] then
			session.catchReach[kind] = true
			Telemetry.custom(
				player,
				(event :: any) :: CustomEvent,
				1,
				{ session.device or "unknown", tierText(profile) }
			)
		end
	elseif name == "first_bait_cutscene" then
		local outcome = Guard.oneOf(rawValue, CUT_OUTCOMES)
		if outcome ~= nil and not session.firstBaitCut then
			session.firstBaitCut = true
			Telemetry.custom(player, "first_bait_cutscene", 1, { outcome })
		end
	elseif name == "store_opened" then
		-- #1888: a new Store funnel session for each visit, up to StoreFunnel.VISITS_MAX a session
		local from = Guard.oneOf(rawValue, StoreFunnel.SOURCES)
		if from ~= nil and session.storeVisits < StoreFunnel.VISITS_MAX then
			session.storeVisits += 1
			session.store = { id = HttpService:GenerateGUID(false), step = 0, sku = nil }
			storeStep(player, "opened", { from, tierText(profile), session.source })
			Telemetry.custom(
				player,
				"store_opened",
				1,
				{ session.source, tierText(profile), session.device or "unknown" }
			)
			Telemetry.onboarding(player, profile, "first_store_open")
		end
	elseif name == "store_tab" then
		-- #2914: the first tab of a visit is the one it opened on; tab_viewed is the next one the player picks
		local tab = Guard.oneOf(rawValue, StoreFunnel.TABS)
		local visit = session.store
		if tab ~= nil and visit ~= nil then
			if visit.landing == nil then
				visit.landing = tab
			elseif tab ~= visit.landing then
				storeStep(player, "tab_viewed", { tab, "picked" })
			end
		end
	elseif name == "store_guard_blocked" then
		local source, reason = StoreFunnel.guardBlock(rawValue)
		if
			source ~= nil
			and reason ~= nil
			and session.guardBlocks < StoreFunnel.GUARD_BLOCKS_MAX
		then
			session.guardBlocks += 1
			Telemetry.custom(
				player,
				"store_guard_blocked",
				1,
				{ source, reason, tierText(profile) }
			)
		end
	elseif name == "store_buy" then
		local passSku = StoreFunnel.passSku(rawValue)
		local sku = passSku or StoreFunnel.productSku(rawValue)
		local visit = session.store
		if sku ~= nil and visit ~= nil and visit.step < StoreFunnel.index("buy_pressed") then
			visit.sku = sku
			local kind: "pass" | "product" = if passSku ~= nil then "pass" else "product"
			-- #2914: a buy on the tab the Store opened on still looked past the first screen
			storeStep(player, "tab_viewed", { visit.landing or "unknown", "landing" })
			task.spawn(function()
				local price = priceOf(kind, rawValue :: number)
				storeStep(
					player,
					"buy_pressed",
					{ sku, if price ~= nil then tostring(price) else "unknown" }
				)
			end)
		end
	elseif name == "session_recap" then
		-- #1920: once a session; the minutes come from the server's own join time, not the client
		if rawValue == true and not session.recapShown then
			session.recapShown = true
			local minutes = math.floor(math.max(0, os.time() - session.joinedAt) / 60)
			local tomorrow = ReturnHook.pick(profile, os.time(), "recap")
			Telemetry.custom(player, "session_recap", minutes, {
				tostring(GrandOpening.doneCount(profile.grandOpening)),
				tierText(profile),
				if tomorrow ~= nil then tomorrow.kind else "none",
			})
			Telemetry.goalsShown(player, ReturnGoals.pick(profile, os.time()), "recap") -- #2916
		end
	elseif name == "session_recap_close" then
		-- whole seconds; the client may send a fraction, and a long stay counts as RECAP_CLOSE_MAX
		local raw = if type(rawValue) == "number" and rawValue == rawValue
			then rawValue :: number
			else nil
		local seconds = if raw ~= nil then math.clamp(math.floor(raw), 0, RECAP_CLOSE_MAX) else nil
		if seconds ~= nil and session.recapShown and not session.recapClosed then
			session.recapClosed = true
			Telemetry.custom(player, "session_recap_close", seconds)
		end
	elseif name == "index_hint_tap" then
		-- #1919: a Catalog area id or "none" (no open area has cats left to find)
		local area = if rawValue == "none"
			then "none"
			elseif type(rawValue) == "string" and Catalog.getArea(rawValue) ~= nil then rawValue
			else nil
		if area ~= nil and session.indexHintTaps < INDEX_HINT_TAPS then
			session.indexHintTaps += 1
			Telemetry.custom(player, "index_hint_tap", 1, { area })
		end
	elseif name == "client_error" then
		if rawValue == true then
			session.clientError = true
		end
	elseif name == "feedback_outcome" then
		local outcome, kind = FeedbackFunnel.outcome(rawValue)
		if outcome ~= nil and kind ~= nil and session.feedbackEnds < session.feedbackAsks then
			session.feedbackEnds += 1
			Telemetry.custom(player, "feedback_ask_end", 1, {
				outcome,
				kind,
				FeedbackFunnel.minutesBucket(PlayTime.seconds(player, profile)),
			})
		end
	elseif name == "playtime_gift" then
		local kind, button = PlaytimeGifts.report(rawValue)
		if kind ~= nil and button ~= nil and not session.giftButtons[kind] then
			session.giftButtons[kind] = true
			Telemetry.custom(player, "playtime_gift", 1, { kind, button })
		end
	else
		local raw = if type(rawValue) == "string" then rawValue else nil
		local screen = if raw ~= nil then SCREENS[raw] else nil
		local more = if raw ~= nil then MORE_SCREENS[raw] else nil
		if screen == nil and more ~= nil and not session.uiOpened[more] then
			session.uiOpened[more] = true
			Telemetry.custom(player, "ui_opened", 1, { more }) -- #1888: not a window for first_window_opened
		end
		if screen ~= nil and not session.uiOpened[screen] then
			session.uiOpened[screen] = true
			Telemetry.custom(player, "ui_opened", 1, { screen })
			if not Onboarding.reached(profile.telemetry, "first_window_opened") then
				Telemetry.custom(player, "first_window", 1, { screen })
				Telemetry.onboarding(player, profile, "first_window_opened", { screen })
			end
			if screen == "rank_up" and Economy.tier(profile) == 1 then
				Telemetry.onboarding(player, profile, "rank_up_card_seen") -- Tier 2's needs showing (F87)
			end
		end
	end
end

-- #1273: a new player's time markers (Onboarding.MARKERS), each logged if this session is still the one that
-- started them.
local function startMarkers(player: Player, session: Session)
	for _, marker in Onboarding.MARKERS do
		task.delay(marker.seconds, function()
			local profile = DataService.get(player)
			if sessions[player] ~= session or profile == nil then
				return
			end
			Telemetry.custom(
				player,
				marker.name :: CustomEvent,
				marker.seconds,
				whereInFunnel(profile, session, session.device or "unknown")
			)
		end)
	end
end

local function onLoaded(player: Player, profile: Profile)
	Telemetry.introJoin(player, profile) -- #3666: before any funnel step of this session
	local now = os.time()
	local firstSession = profile.stats.sessions <= 1
	local session: Session = {
		accounted = profile.lifetimeCoins,
		joinedAt = now,
		caughtAtJoin = profile.stats.catsCaught,
		device = nil,
		joinLogged = false,
		-- lastSeen is still the end of the previous session here (DataService sets it on leave)
		returnedNextDay = not firstSession
			and math.floor(profile.lastSeen / DAY_SECONDS) < math.floor(now / DAY_SECONDS),
		waitingForRole = {},
		knockedAt = nil,
		knockedRarity = nil,
		restartWarnedAt = nil,
		restartWarnedLeft = 0,
		restartWarnings = 0,
		swings = {},
		stationOpens = {},
		arcade = ArcadeFunnel.fresh(),
		strayCall = nil,
		strayCalls = 0,
		origin = nil,
		nudges = {},
		introChoices = 0,
		screen = "none",
		uiOpened = {},
		tutorialClosed = false,
		parkHints = {},
		parkTrail = {},
		catchReach = {},
		rankSpot = {},
		firstBaitCut = false,
		source = JoinSource.ORGANIC,
		joinEvent = "",
		store = nil,
		storeVisits = 0,
		recapShown = false,
		recapClosed = false,
		goals = {},
		indexHintTaps = 0,
		guardBlocks = 0,
		giftButtons = {},
		clientError = false,
		feedbackRun = nil,
		feedbackAsks = 0,
		feedbackEnds = 0,
		readyLogged = {},
		stepClock = {},
		stallStep = profile.telemetry.onboardingStep,
		stallSince = os.clock(),
		stallLogged = {},
		lastNudge = "none",
		activeAt = os.clock(),
		lastAt = nil,
		snapScreen = "none",
		healthMem = nil,
		healthLogged = false,
		memLogged = {},
		memFirst = nil,
		introShot = 0,
	}
	-- #1888: the launch data of the link this join came through (an ad's ad_<tag>)
	local ok, joinData = pcall(function(): any
		return player:GetJoinData()
	end)
	if ok and type(joinData) == "table" then
		session.source = JoinSource.parse(joinData.LaunchData)
		-- #2486: a join from an Experience Event's page carries its id; only digits are kept, as anything a link
		-- carries could be pasted
		local context = joinData.GameJoinContext
		local eventId = if type(context) == "table" then context.EventId else nil
		local text = if type(eventId) == "string" or type(eventId) == "number"
			then tostring(eventId)
			else ""
		if #text <= 24 and string.match(text, "^%d+$") ~= nil then
			session.joinEvent = text
		end
	end
	sessions[player] = session
	-- #3661: this session's ping, once, after the join has settled
	task.delay(NetPing.SAMPLE_SECONDS, function()
		if sessions[player] ~= session or player.Parent == nil then
			return
		end
		local ok, seconds = pcall(function()
			return player:GetNetworkPing()
		end)
		if not ok or type(seconds) ~= "number" or seconds ~= seconds then
			return -- no reading: logged as nothing, so a failure never reads as a slow connection
		end
		local ms = NetPing.ms(seconds)
		Telemetry.custom(player, "net_ping", ms, { session.device or "unknown", NetPing.band(ms) })
	end)
	if profile.stats.sessions > 1 then
		-- #2916: the welcome back card's next goals (CafeService sends the same pick)
		Telemetry.goalsShown(player, ReturnGoals.pick(profile, os.time()), "join")
	end
	Telemetry.custom(
		player,
		"session_start",
		1,
		{ session.source, if firstSession then "new" else "returning", tierText(profile) }
	)
	-- #3098 P2: a beginner back within the hour, so the leave read counts only the players truly lost
	local away = now - profile.lastSeen
	if
		not firstSession
		and profile.lastSeen > 0
		and away >= 0
		and away < FirstFive.QUICK_RETURN_SECONDS
		and Economy.tier(profile) < 2
	then
		local minutes = math.floor(away / 60)
		Telemetry.custom(player, "quick_return", minutes, {
			Onboarding.cleanFurthest(profile.telemetry),
			FirstFive.awayBucket(minutes),
			FirstFive.sessionBucket(profile.stats.sessions),
		})
	end
	if firstSession then
		-- the template's coins never pass through Economy.credit, so they are not in lifetimeCoins
		logEconomy(
			player,
			profile,
			true,
			Config.StartCoins,
			profile.coins,
			"Onboarding",
			"start_coins"
		)
		progression(player, profile, false, Economy.tier(profile))
		areaIndex(player, profile, false, "alley")
	else
		local _, paidSeconds = DataService.peekPendingOffline(player)
		Telemetry.custom(
			player,
			"offline_return",
			math.floor(math.max(0, now - profile.lastSeen) / 60),
			{
				tostring(Economy.tier(profile)),
				tostring(math.floor(paidSeconds / 60)),
				if Economy.passes(profile).longNap then "long_nap" else "free",
			}
		)
	end
	logJoined(player)
	if isNewPlayer(profile, now) then
		startMarkers(player, session)
	end
end

local CAFE_REACH = 32 -- studs from the player's own plot's pivot that count as at the cafe for quit_point

-- Where the player's character stands as they leave, for quit_point: "cafe" by their own cafe, an area id on an
-- area's floor, "town" anywhere else, "none" with no character.
local function whereOf(player: Player): string
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return "none"
	end
	local at = (root :: BasePart).Position
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			local pivot = (plot :: Model):GetPivot().Position
			if Vector3.new(at.X - pivot.X, 0, at.Z - pivot.Z).Magnitude <= CAFE_REACH then
				return "cafe"
			end
		end
	end
	for id, spec in Layout.areas do
		local rects = spec.rects
		if rects ~= nil then
			-- a rects area's bounding box takes in the town between its floors, so test the floors themselves
			for _, r in rects do
				if
					at.X >= math.min(r.x1, r.x2)
					and at.X <= math.max(r.x1, r.x2)
					and at.Z >= math.min(r.z1, r.z2)
					and at.Z <= math.max(r.z1, r.z2)
				then
					return id
				end
			end
		else
			local c = spec.center
			if
				math.abs(at.X - c.x) <= spec.halfWidth
				and math.abs(at.Z - c.z) <= spec.halfDepth
			then
				return id
			end
		end
	end
	return "town"
end

-- #2774: the account's first bait cat came `seconds` after the food went in; where the player was (cafe, an area id or
-- none), to see whether the cannon trip has them away when it lands.
function Telemetry.firstBaitArrived(player: Player, seconds: number)
	Telemetry.custom(
		player,
		"first_bait_arrived",
		math.max(0, math.floor(seconds)),
		{ whereOf(player) }
	)
end

-- Runs after the other services' leave work (Telemetry starts last), so a carried cat saved on leave or a rich tip
-- paid on leave has logged its own Source first.
local function onRelease(player: Player, profile: Profile)
	local session = sessions[player]
	if session == nil then
		return
	end
	logJoined(player) -- a player who leaves within DEVICE_WAIT_SECONDS still joined
	local now = os.time()
	Economy.settle(profile, now, ClockService.epoch())
	flushTips(player, profile, 0)
	-- unclaimed offline earnings are credited as the profile saves (DataService.finalize)
	local unclaimed = DataService.peekPendingOffline(player)
	if unclaimed > 0 then
		logEconomy(
			player,
			profile,
			true,
			unclaimed,
			profile.coins + unclaimed,
			"TimedReward",
			"offline"
		)
	end
	local knockedAt = session.knockedAt
	if knockedAt ~= nil and os.clock() - knockedAt <= LEFT_AFTER_SHOVE_SECONDS then
		Telemetry.custom(player, "left_after_shove", 1, {
			session.knockedRarity or "unknown",
			if os.clock() - knockedAt < 30 then "under_30" else "30-120",
		})
	end
	local warnedAt = session.restartWarnedAt
	if warnedAt ~= nil and os.clock() - warnedAt <= LEFT_AFTER_RESTART_WARNING_SECONDS then
		Telemetry.custom(player, "left_after_restart_warning", math.floor(os.clock() - warnedAt), {
			tostring(session.restartWarnings),
			tostring(session.restartWarnedLeft),
			tierText(profile),
		})
	end
	flushSwings(player)
	local caught = profile.stats.catsCaught - session.caughtAtJoin
	-- #2562: night is NightLengthSeconds of every DayLength + NightLength (about 18%); a share of these well over that
	-- at night means night drives players off
	local phase, third = Clock.leavePhase(
		ClockService.phase(),
		ClockService.phaseEndsAt() - Workspace:GetServerTimeNow()
	)
	Telemetry.custom(player, "left_in_phase", math.max(0, now - session.joinedAt), {
		phase,
		third,
		"T"
			.. tierText(profile)
			.. (if profile.stats.sessions <= 1 then "_first" else "_return")
			-- #3035: "_nc" while night catching was open to them, so one read splits switch on from off
			.. (
				if NightPass.firstOf(profile, LiveFlagService.on(NightPass.FLAG))
					then NightPass.LEFT_SUFFIX
					else ""
			),
	})
	Telemetry.custom(player, "session_end", math.max(0, now - session.joinedAt), {
		bucket(caught, { 0, 2, 5 }, { "0", "1-2", "3-5", "6+" }),
		tierText(profile),
		session.device or "unknown",
	})
	-- F87: a new player leaving, in Roblox's bounce windows (easy-start.md section 5); #1273: with the furthest step
	-- logged and the screen open as they left, the value the seconds in game
	local played = math.max(0, now - session.joinedAt)
	if isNewPlayer(profile, now) then
		Telemetry.custom(
			player,
			"new_player_left",
			played,
			whereInFunnel(
				profile,
				session,
				bucket(played, { 60, 180, 600 }, { "0-60s", "61-180s", "3-10m", "10m+" })
			)
		)
	end
	if Economy.tier(profile) < 2 then
		local where = whereOf(player)
		Telemetry.custom(player, "quit_point", played, whereInFunnel(profile, session, where))
		-- #2774: what a leaving beginner was doing
		local character = player.Character
		local carrying = character ~= nil and character:GetAttribute("CarryingCatId") ~= nil
		local baiting = profile.bait ~= nil or profile.bait2 ~= nil
		Telemetry.custom(player, "quit_state", played, {
			Onboarding.cleanFurthest(profile.telemetry),
			where,
			(if carrying then "carry" else "empty") .. (if baiting then " bait" else " nobait"),
		})
		-- #3530: what they had: short of cats or short of money, and whether they could have ranked up
		local tier2 = Catalog.getTier(2)
		Telemetry.custom(
			player,
			"quit_have",
			played,
			StepGaps.quitFields(
				Economy.rankUpCatCount(profile.collection),
				profile.coins,
				if tier2 ~= nil then tier2.cost else 0,
				Economy.rankUpBlocker(profile) == nil
			)
		)
		-- #3098: how idle they were, the screen open, and whether the coins covered the next onboarding buy
		local buy = FirstFive.nextBuy(profile.telemetry)
		-- #3098 P1b: the exact scene they left in
		Telemetry.custom(player, "quit_scene", played, {
			FirstFive.scene({
				loaded = session.device ~= nil,
				introSeen = profile.introSeen,
				introShot = session.introShot,
				launching = character ~= nil and character:GetAttribute("Launching") == true,
				carrying = carrying,
				furthest = Onboarding.cleanFurthest(profile.telemetry),
				where = where,
			}),
			session.device or "unknown",
			FirstFive.secondsBucket(played),
		})
		-- #3098 P2: the cafe they left behind
		local working = 0
		local owned = 0
		for _, instance in profile.cats do
			owned += 1
			if instance.spotId ~= nil then
				working += 1
			end
		end
		Telemetry.custom(
			player,
			"quit_cafe",
			played,
			FirstFive.cafeFields(working, Economy.level(profile, "tables"), owned)
		)
		Telemetry.custom(player, "quit_snapshot", played, {
			Onboarding.cleanFurthest(profile.telemetry),
			FirstFive.idleBucket(os.clock() - session.activeAt) .. " " .. session.snapScreen,
			FirstFive.afford(
				buy,
				profile.coins,
				if buy ~= nil then Economy.nextUpgradeCost(profile, buy) else nil
			),
		})
	end
	sessions[player] = nil
	pendingPasses[player] = nil
end

-- #3098: whether a free stray (not locked by a catch) stands within FirstFive.STRAY_NEAR studs of `at`.
local function strayNear(at: Vector3): boolean
	for _, model in CollectionService:GetTagged("Stray") do
		if model:IsA("Model") and (model:GetAttribute("LockedBy") or 0) == 0 then
			local pivot = (model :: Model):GetPivot().Position
			if (pivot - at).Magnitude <= FirstFive.STRAY_NEAR then
				return true
			end
		end
	end
	return false
end

-- #3098 (shared/FirstFive): activity, step_ready and step_stall for an account below Tier 2, each watch tick.
local function watchFirstFive(player: Player, session: Session, profile: Profile)
	local root = if player.Character ~= nil
		then player.Character:FindFirstChild("HumanoidRootPart")
		else nil
	local at: Vector3? = if root ~= nil and root:IsA("BasePart")
		then (root :: BasePart).Position
		else nil
	local last = session.lastAt
	if at ~= nil and (last == nil or (at - last).Magnitude >= FirstFive.MOVE_STUDS) then
		session.lastAt = at
		session.activeAt = os.clock()
	end
	if Economy.tier(profile) >= 2 then
		return
	end
	local state = profile.telemetry
	local device = session.device or "unknown"
	local function ready(step: string, kind: string)
		if not session.readyLogged[step] then
			session.readyLogged[step] = true
			Telemetry.custom(
				player,
				"step_ready",
				math.floor(PlayTime.seconds(player, profile)),
				{ step, kind, device }
			)
		end
	end
	local buy = FirstFive.nextBuy(state)
	if buy ~= nil then
		local cost = Economy.nextUpgradeCost(profile, buy)
		if cost ~= nil and profile.coins >= cost then
			ready(if buy == "tables" then "table_afford" else "bowl_afford", "coins")
		end
	end
	if
		FirstFive.secondCatDue(state)
		and not session.readyLogged.second_stray_up
		and at ~= nil
		and strayNear(at)
	then
		ready("second_stray_up", "stray")
	end
	-- step_stall: the clock restarts whenever the furthest step moves on
	if state.onboardingStep ~= session.stallStep then
		session.stallStep = state.onboardingStep
		session.stallSince = os.clock()
		session.stallLogged = {}
		session.lastNudge = "none"
	end
	local awaited = FirstFive.awaited(state.onboardingStep)
	if awaited == nil or PlayTime.seconds(player, profile) > FirstFive.STALL_WINDOW then
		return
	end
	for _, edge in FirstFive.newStalls(os.clock() - session.stallSince, session.stallLogged) do
		session.stallLogged[edge] = true
		Telemetry.custom(player, "step_stall", edge, { awaited, tostring(edge), session.lastNudge })
	end
end

-- F87: the onboarding steps nothing else announces. first_move once the character has gone FIRST_MOVE_STUDS across
-- the ground from where it was first seen this session; first_customer_served (#1273) once a cafe with a cat in a role
-- has earned its first tips; rank_up_ready once a Tier 1 cafe meets Tier 2's needs (Economy.rankUpBlocker), which
-- coins earned in the background can do between syncs.
local function watchOnboarding(player: Player, session: Session)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if session.joinLogged then
		logFirstHour(player, profile)
		logRarity(player, profile) -- #3876: a cat from a trade or a switch turned on mid session
	end
	watchFirstFive(player, session, profile)
	if not Onboarding.reached(profile.telemetry, "first_move") then
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			local at = (root :: BasePart).Position
			local origin = session.origin
			if origin == nil then
				session.origin = at
			elseif
				Vector3.new(at.X - origin.X, 0, at.Z - origin.Z).Magnitude >= FIRST_MOVE_STUDS
			then
				Telemetry.onboarding(player, profile, "first_move")
			end
		end
	end
	-- #1273: the cafe's first tips, settled into lifetimeCoins by CafeService's sync and not logged as a Source yet
	if
		not Onboarding.reached(profile.telemetry, "first_customer_served")
		and Onboarding.reached(profile.telemetry, "first_role_assigned")
		and profile.lifetimeCoins - session.accounted >= 1
	then
		Telemetry.onboarding(player, profile, "first_customer_served")
	end
	if
		Economy.tier(profile) == 1
		and not Onboarding.reached(profile.telemetry, "rank_up_ready")
		and Economy.rankUpBlocker(profile) == nil
	then
		Telemetry.onboarding(player, profile, "rank_up_ready")
	end
end

function Telemetry.start()
	DataService.onLoaded:Connect(onLoaded)
	DataService.beforeRelease(onRelease)
	Net.on("TelemetryReport", onReport)
	-- #2910: StationOpened(window, how) from WalkUpController, a count only
	Net.on("StationOpened", function(player: Player, window: unknown, how: unknown)
		if StationOpens.valid(window, how) then
			Telemetry.stationOpen(player, window :: string, how :: string)
			for _, listener in stationListeners do
				local ok, err = pcall(function()
					listener(player, window :: string)
				end)
				if not ok then
					warn("[Telemetry] a station open listener failed: " .. tostring(err))
				end
			end
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPrompt)
	PassService.purchased:Connect(onPassConfirmed)
	MarketplaceService.PromptProductPurchaseFinished:Connect(onProductPrompt)
	task.spawn(function()
		while true do
			task.wait(EventGate.FLUSH_SECONDS)
			flushGate()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			for player in sessions do
				local profile = DataService.get(player)
				if profile ~= nil then
					flushTips(player, profile, 0)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SWING_FLUSH_SECONDS)
			for player in sessions do
				flushSwings(player)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(WATCH_SECONDS)
			for player, session in sessions do
				watchOnboarding(player, session)
			end
		end
	end)
end

return Telemetry
