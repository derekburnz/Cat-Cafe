--!strict
-- The one list of RemoteEvents (data-model section 15). The server creates them in ReplicatedStorage.Remotes;
-- the client waits for them. Every client -> server call is validated and rate limited in server/Services/Net.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

-- Client -> server: (args) and what the server checks.
Remotes.ClientToServer = {
	"SwingNet", -- ()  F93 (catch-rework.md section 1): not carrying, in a catch or rescue, flying or in a camp; one per
	-- NetSwingCooldown, 3 a second at most. Judged NetSmackDelay later from the root and its facing: the nearest free
	-- stray in reach starts its catch (CatchSchedule) or, Dropped, is picked up; a miss makes nearby strays hop
	"CatchPress", -- (strayId: string, index: number)  no time is sent: the server stamps the press on arrival
	"RescueBegin", -- (rescueSpotId: string)  trap holds a stuck cat, unlocked, past its retry waits, in range, not carrying
	"RescuePress", -- (rescueSpotId: string)  no time is sent: the server stamps the press and judges the marker
	"RescueCancel", -- (rescueSpotId: string)  Give up: ends the attempt as a fail; a helper's only ends their help
	"RescueHelp", -- (rescueSpotId: string)  F92 Team Rescue: join someone else's running bar as its one helper; within
	-- TeamRescueRangeStuds, not carrying, the trap locked to another player with no helper yet. Answered with
	-- RescueChallenge (helper = true) or a GrabResult refusal; the helper's presses are RescuePress
	"CheckIn", -- ()  carrying and within CheckInRangeStuds of own plot Door
	"DropCat", -- ()  carrying, areas open: puts the cat down to walk back to where it was caught (F67)
	"PlaceCat", -- (uid: string, spotId: string)
	"UnplaceCat", -- (uid: string)
	"EquipBest", -- ()  places owned cats on open spots for the highest rate (shared/EquipBest.plan)
	"UnequipAll", -- ()  rests every working cat in the cat room (shared/EquipBest.restAll)
	"SellCat", -- (uid: string)  not the last cat, not locked (F62)
	"LockCat", -- (uid: string, locked: boolean)  F62: owns uid; a locked cat cannot be sold or traded
	"BuyUpgrade", -- (upgradeId: string)
	"BuyDecor", -- (decorId: string)
	"RankUp", -- ()  next tier's cost, different cats and rarity (Economy.rankUpBlocker); spends and raises the tier
	"ToggleDecor", -- (decorId: string, placed: boolean)
	"EquipBestDecor", -- ()  puts out the best owned decor for the most money (shared/DecorBest), the rest away
	"ResetSave", -- ()  testers only (Player attribute Tester): a fresh save at the next join, then a kick
	"BuyLure", -- (lureId: string)
	"UseLure", -- (lureId: string)  bowl bought and empty, food in stock; from anywhere (2026-10-28)
	"ResolveBait", -- (choice: "tame" | "letgo")  the bowl's cat has arrived; from anywhere (2026-10-28)
	"ClaimOffline", -- ()
	"TutorialAdvance", -- (step: number)
	"RequestSync", -- ()  asks for a full ProfileSync (client UI just loaded)
	"Travel", -- (destination: string)  "home" (a cloud hop from a wild area) or "cannon" (the front of the nearest
	-- Cat Cannon, F84); not while carrying, mid catch or rescue, or in a flight
	"LaunchCannon", -- (cannonId: string, destination: string)  F84 (hometown-cannon.md section 7): `town` or a camp's
	-- area id within CannonRangeStuds; `town` or another area with a camp, the area opened by the caller's tier, open
	-- and not in the dusk warning; not carrying, no lock, not flying or tackled down, off CannonCooldownSeconds;
	-- 1 a second. Answered with CannonLaunch
	"BuyDealerFood", -- (lureId: string, night: number)  night, near the cart, a dealer food, `night` the server's
	-- current night count (F94; was the 5 minute window: a buy sent as the cart leaves is refused, S42), fewer bought
	-- tonight than its amount
	"BuyFreshCatch", -- (itemId: string, window: number)  F94 (rewards-and-shops.md section 6): day, within
	-- FishMarketRange of a FishMarket station, a Catalog.freshCatch row, `window` the current one, fewer bought this
	-- window than its amount, enough golden fish; 2 a second; answered with FreshCatchStock, bought or refused
	"Tackle", -- ()  v0.11 F74 (data-model section 10c, shared/Shove): in an unlocked catching area, areas open, not
	-- carrying, no lock, off TackleCooldownSeconds; lunges and hits the first player in reach who could be shoved
	"ClaimRichTip", -- ()  own plot has an unexpired rich tip, within RichTipRangeStuds of its RichTipAnchor
	"RenameCat", -- (uid: string, name: string)  owns uid; CatName.validate; RenameCooldownSeconds; the filter passes
	"TelemetryReport", -- (name: string, value: string)  analytics only, allowlisted: device once, ui_opened (F16)
	"SetSetting", -- (key: string, value: boolean | number)  a key of shared/Settings: a switch takes a boolean, a
	-- volume a number clamped to 0 to 1; saved in profile.settings, answered by ProfileSync
	"ClaimTipJar", -- (step: number)  integer 1 to #Catalog.tipJar, unclaimed this session, its minutes reached (F47)
	"ClaimIndexReward", -- (areaId: string, milestoneId: string)  known prize, unclaimed, the area's count met (F48)
	"SpinWheel", -- ()  within SpinStationRange of a SpinWheel station, a free or banked spin, SpinCooldownSeconds (F49)
	"OpenCrate", -- (crateId: string)  within FishMarketRange of a FishMarket, the crate's zone unlocked, a banked
	-- crate (used first) or its price in golden fish, CrateOpenCooldownSeconds between opens (F53, shared/Crates)
	"BuyFishItem", -- (itemId: string)  within FishMarketRange of a FishMarket, a lure or perk row of Catalog.fishShop,
	-- below its max level, its cost in golden fish (F53); answered with a toast and a ProfileSync
	"RedeemCode", -- (text: string)  within CodesCatRange of a CodesCat, at most 40 bytes, trimmed and lowercased to 1
	-- to CodeMaxLength letters and digits, a known active code not yet redeemed (F65, shared/Codes); 1 per 2 s, locked
	-- CodeLockSeconds after CodeWrongLimit wrong codes; answered with CodeResult
	"ClaimStarterCat", -- ()  F96 (starter-cat.md section 4): within StarterCatRangeStuds of a BellhopStand, the
	-- Bellhop Cat not yet claimed, and the first goals done (GroupId 0) or the player in GroupId; 1 per 2 s, answered
	-- with StarterCatResult
	"IntroDone", -- (shot: number, replay: boolean)  integer 0 to 10: 0 when the intro cutscene played to the end, else
	-- the shot showing at Skip (F72, shared/Intro); 1 a second. The first non-replay call sets introSeen
	"UsePotion", -- (potionId: string)  F64: a known potion in the bag whose minutes fit under PotionMaxMinutes with
	-- the time it has left, else a "Full" toast and nothing used; answered with a ProfileSync
	"OpenMysteryGift", -- ()  F64: a gift waits on the caller's own plot, within MysteryRangeStuds of its
	-- MysteryGiftAnchor (the GiftPrompt's hold does the same); answered with MysteryGiftResult
	"AnswerCollector", -- (accept: boolean)  F63: a live Cat Collector visit on the caller's own plot, within
	-- CollectorRangeStuds of him; on accept the cat he asks for is still owned, resting, unlocked and not the
	-- caller's last cat, else a toast says why and he waits on. A trade or No thanks ends the visit (CollectorOffer "")
	"ClaimQuest", -- (kind: "daily" | "weekly", slot: number)  F73: slot 1 to QuestDailyCount or QuestWeeklyCount,
	-- finished and unclaimed; pays it and, when it is the set's last, the set prize; answered with QuestResult
	"RerollQuest", -- (kind: "daily" | "weekly", slot: number)  F73: the day's or week's free swap unused, the quest
	-- neither finished nor claimed; another eligible quest from the same pool, counting from now
	"ClaimAchievement", -- (achievementId: string)  F73: a known achievement, met and unclaimed; answered with
	-- QuestResult
	"ClaimAll", -- (what: string)  shared/ClaimAll.KINDS: "daily", "weekly" or "achievements" (the Quests window),
	-- "index" (every Index page) or "tipjar"; pays every one ready as its single Claim would, one toast and one sync
	-- (and QuestResult for quests, TipJarState for the Tip Jar); nothing ready answers "Nothing to claim yet"
	"ClaimDailyTreat", -- ()  F70: a Daily Treat stamp due (a later UTC day than the last claim); pays the next day
	-- of the card and answers with ProfileSync (`dailyTreat`)
	"ReportBug", -- (text: string, kind: string?, clientErrors: { string }?)  shared/BugReport: 3 to 500 bytes of
	-- UTF-8 text; kind "bug", "stuck" or "idea"; up to 3 error lines; 1 per 20 s, 10 a player and 200 a server
	"TipSeen", -- (id: string, skipped: boolean?)  F87 (easy-start.md section 6): a shared/Tips id or one of its
	-- asks, 1 a second. A tip goes in tipsSeen (logged once as tip_shown, skipped true when a camera cut was skipped);
	-- F96: an ask this session sent (notify_ask, favorite_ask, like_ask) goes in tipsSeen and logs ask_shown (the
	-- notification ask's first showing only sets notifyAskAt; skipped true: Roblox would not prompt), feedback_ask
	-- sets feedbackAsked, stuck_help sets stuckHelpShown for the current tutorialStep
	"ClearTips", -- ()  F87: Settings' "Show tips again"; forgets tipsSeen but the asks; 1 per 10 s; ProfileSync
	"SendFeedback", -- (face: string, chip: string?)  F87 (section 4): face in Tips.FACES, chip nil or in Tips.CHIPS;
	-- 1 per 10 s and FeedbackSessionLimit (5) a session; logs `feedback` and sets feedbackAsked. Text goes by ReportBug
	"CollectCampExtra", -- (extraId: string)  F100 (camp-extras.md section 4): "picnic", "pond" or "lostFound", the
	-- player's tier opens its area, within CampExtraRangeStuds (and a little slack) of its PromptAnchor, something held;
	-- takes it all; 1 a second, answered with CampExtraResult and CampExtrasState
	"BuyYardSale", -- (crateId: string)  F100: within reach of the Yard Sale (Tier 3), one of today's two crates
	-- (CampExtras.yardStock) not yet bought today, YardSaleCratePrice golden fish; banked for the Market; 1 a second
}

-- Server -> client.
Remotes.ServerToClient = {
	"ProfileSync", -- (state: Types.PlayerState)  full state; the client merges
	"CatCaught", -- (catId: string, isNew: boolean, variant: string)  variant "base", "gold" or "rainbow" (F99), for the
	-- Cat found card's coat
	"OfflineEarnings", -- (amount: number, seconds: number)
	"Toast", -- (text: string, kind: "info" | "good" | "warn")
	"Announce", -- (text: string, rarity: Types.Rarity?)  fired to everyone; rarity on a rare catch. F89: a Legendary
	-- or Mythical check-in shout-out at most once a minute a player (RareMomentService)
	"SecuredRare", -- (userId: number, catId: string, rarity: Types.Rarity, gold: boolean, variant: string)  F89
	-- (luck-and-rare-moments.md 2a): a Legendary, a Mythical or a gold Epic or better (and, F99, every rainbow cat)
	-- checked in or tamed, to everyone: the owner's big pull card and the hop, spin, shockwave and stings; the first
	-- Epic a player ever secures goes to that player alone for the small card. The toast is the Announce above
	"RainbowSpawned", -- (areaId: string, catId: string, strayId: string, toast: boolean)  F99 (rainbow-coat.md
	-- section 2): a rainbow stray spawned, to everyone for its beam (the stray model is named strayId in the Strays
	-- folder, Variant "rainbow") and a nearby shimmer; toast is true at most once every RainbowSpawnToastSeconds per
	-- server, for "A Rainbow Tabby is out in the Woods!" (Catching.rainbowSpawnText)
	"FoundRareDecor", -- (userId: number, decorId: string)  F89 (2b): a Mythical crate piece, to everyone for the
	-- toast ("Sam found the Mythical Midnight Sky!", RareMoments.decorText), at most once a minute a player
	"PalArrived", -- (joinerUserId: number, palUserId: number, palArea: string?)  F92 (playing-together.md section 5),
	-- to everyone: a player who joined through a pal's invite or by following them now stands at that pal's front
	-- door, for the wave from both characters; palArea is the catching area the pal is in (nil in town or a cafe),
	-- for the joiner's "Sam is in the Park" marker
	"LeaderboardSync", -- (data: Types.LeaderboardSync)  F98 (leaderboards.md section 5): every list's top 50 with names
	-- and crowns and this player's own line, on join, after each refresh and after the player's own write
	"PalsChanged", -- (userIds: { number })  F92 (playing-together.md 1): this player's pals on the server, every time
	-- one comes or goes, for the HUD chip's headshots and "+10% with pals"; none sent while a player has never had one
	"GrabResult", -- (id: string, ok: boolean, reason: string, retry: boolean)  id is a rescueSpotId; retry keeps the
	-- prompt open. Since F93 a stray has no prompt: a swing's refusal is a toast and its outcome CatchResult.
	"NetSwung", -- (userId: number, hit: boolean)  F93: a swing landed, to the swinger and every client within 150 studs,
	-- for the smack, the bounce on a miss and the whoosh; hit is true when it started a catch or a pick up
	"CatchSchedule", -- (strayId: string, circles: { Types.CatchCircle }, windows: Types.CatchWindows)
	"CatchResult", -- (strayId: string, grades: { Types.CircleGrade }, success: boolean, charmGain: number,
	-- retryAt: number?)  grades up to and including the first Miss; after a miss the stray sprints off and anyone may
	-- try again (v0.5). retryAt (server time, miss only) is when this player may try that stray again (F57: 3, 6
	-- then 10 s after it stops, by their miss streak).
	"RescueChallenge", -- (rescueSpotId: string, challenge: Types.RescueChallenge)  the bar, or a tree's falling cat
	"RescueResult", -- (rescueSpotId: string, hits: number, pawsLeft: number, done: boolean, success: boolean,
	-- bar: Types.RescueBar)  after every judged press, when a zone runs out (F93) and when the attempt ends; `bar` is
	-- how the marker runs and which zone to hit from now. Refusals of RescueBegin come as GrabResult. F92: a Team
	-- Rescue helper gets these too (a done one that is not a success when they stop helping), and `bar.endsAt` is the
	-- deadline, TeamRescueExtraSeconds later once a helper joins
	"TeamRescue", -- (rescueSpotId: string, rescuerUserId: number, helperUserId: number, position: Vector3,
	-- coins: number)  F92: a helped rescue freed its cat, to the rescuer and the helper for the "Team Rescue!" pop;
	-- coins is the helper's tip this player got (0 for the rescuer, and on the TeamRescueTipCooldown)
	"TravelResult", -- (destination: string, ok: boolean, reason: string?)  answers every Travel the limiter lets through
	"CannonLaunch", -- (destination: string, launchAt: number?)  F84: the caller's flight began at launchAt (server
	-- time) and lands at the destination's pad CannonLaunchSeconds later; launchAt nil when the launch was refused
	-- (the server's toast says why)
	"CampCheckIn", -- (userId: number, campId: string)  F84: fired to everyone in the frame a carrier walks into a
	-- camp, before the carried cat is removed, so each client hops its copy into the camp's basket
	"PlotOpened", -- (position: Vector3, plotIndex: number)  fired to everyone when a For Rent plot gets an owner
	"DealerStock", -- (stock: Types.DealerStock?)  this player's amounts and buys of each food tonight (F94: one stock
	-- per server per night, `night` its count), nil by day; after every buy
	"FreshCatchStock", -- (stock: Types.FreshCatchStock?)  F94: this player's Fresh Catch amounts and buys by day,
	-- nil at night ("Back at sunrise"); at sunrise, at each new window, on join and after every BuyFreshCatch
	"ShopAlert", -- (itemId: string)  F94: a Gold Rush Potion or the cheap Classic Crate is on the Fresh Catch shelf
	-- and this player has the golden fish for it; at most once a window per player, only with settings.shopAlerts on
	-- (none until shared/Settings saves the key, review S100)
	"TipJarState", -- (state: Types.TipJarState)  when the profile loads and after every claim (F47)
	"ShowTip", -- (id: string)  F87 (easy-start.md section 3): a server-side context tip's moment came (shared/Tips:
	-- `due` from the save and the clock, or its event, or F96's `dueAsk`, one ask a session); at most once a session
	-- per id until TipSeen. The client queues and times it, then answers TipSeen
	"SpinResult", -- (slice: number, amount: number)  the slice a SpinWheel landed on and its coins or foods; 0, 0
	-- when refused (F49)
	"CrateResult", -- (crateId: string, decorId: string, duplicate: boolean, refund: number)  the piece an OpenCrate
	-- gave (its rarity and kind are on its DecorDef) and the golden fish a duplicate paid back; decorId "" when refused
	"StarterCatResult", -- (ok: boolean, reason: string?)  F96: the answer to ClaimStarterCat; ok plays the happy hop,
	-- a refusal's reason is the stand card's line ("Finish your first goals to take me home")
	"CodeResult", -- (ok: boolean, message: string, prize: Types.IndexPrize?)  the answer to RedeemCode: the code box's
	-- answer line and, when ok, the prize pictures (F65)
	"ShoveResult", -- (outcome: "shove" | "loose" | "held" | "miss" | "refused", shoverUserId: number,
	-- targetUserId: number, position: Vector3?, direction: Vector3?)  a tackle that hits goes to everyone; the target's
	-- client pushes its own character ShoveKnockbackStuds along direction. "miss" (v0.11 F74: the window ended with no
	-- hit, targetUserId 0, position the tackler's, direction the lunge's) and "refused" (no position) go to the
	-- tackler alone
	"CatchBurst", -- (direction: Vector3)  the getaway (v0.8 F55): a player beside a catch or rescue that just
	-- succeeded; their client pushes its own character CatchBurstStuds along direction (flat, unit). Not a shove
	"MysteryGiftResult", -- (kind: "potion" | "lure" | "fish" | "spin", id: string?, count: number)  F64: what the
	-- owner's opened Mystery gift held, for the gift card and the ribbon pop
	"CollectorOffer", -- (catUid: string, offer: Types.CollectorOffer?, endsAt: number, traded: boolean?)  F63: the
	-- owner's Cat Collector card: the cat he wants, his offer (a Catalog.collectorOffers row; the zone crate is the
	-- cat's area's) and the server time he leaves. catUid "" ends the visit, `traded` true when it ended in a trade
	"QuestResult", -- (paid: { string })  F73: what a quest, a set or an achievement claim paid ("+$300", "2 spins"),
	-- after the server's toast with the same words, for the Quests window's own claim effect
	"CampExtrasState", -- (state: Types.CampExtrasState)  F100: each camp extra's open, held, nextAt and the Yard
	-- Sale's stock today, on join and whenever it changes (a fill, a new UTC day, a rank up, a collect or a buy)
	"RallyState", -- (state: Types.RallyState)  F101: the server's Rescue Rally bar and this player's part in it, on
	-- join, at each step, lap, start and end, and at most every Config.RallyStateSeconds while points come in
	"RallyPoint", -- (userId: number, amount: number)  F101: to every client for each score in the Rally, for the pops
	"CampExtraResult", -- (extraId: string, ok: boolean, paid: { string }, prize: Types.IndexPrize?)  F100: the
	-- answer to CollectCampExtra or BuyYardSale; paid is what it gave in Payout's words ("2 Money Potion", "+14 golden
	-- fish", "1 Park Crate") and prize the same for the pictures, nil when refused (the server's toast says why)
	"CatLevelUp", -- (uid: string, level: number)  one of this player's cats reached `level` (v0.12 F75): the toast,
	-- the level up chime and, from the model's Level attribute, the sparkle; once per settle that raises it
}

function Remotes.folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if existing ~= nil then
		return existing :: Folder
	end
	return ReplicatedStorage:WaitForChild(Remotes.FolderName) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return Remotes.folder():WaitForChild(name) :: RemoteEvent
end

return Remotes
