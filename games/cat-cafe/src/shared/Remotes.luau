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
	"RescueCancel", -- (rescueSpotId: string)  Give up: ends the attempt as a fail
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
	"BuyLure", -- (lureId: string)
	"UseLure", -- (lureId: string)  bowl bought and empty, food in stock; from anywhere (2026-10-28)
	"ResolveBait", -- (choice: "tame" | "letgo")  the bowl's cat has arrived, within 20 studs of own BaitBowl
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
	"ClaimDailyTreat", -- ()  F70: a Daily Treat stamp due (a later UTC day than the last claim); pays the next day
	-- of the card and answers with ProfileSync (`dailyTreat`)
	"ReportBug", -- (text: string, kind: string?, clientErrors: { string }?)  shared/BugReport: 3 to 500 bytes of
	-- UTF-8 text; kind "bug", "stuck" or "idea"; up to 3 error lines; 1 per 20 s, 10 a player and 200 a server
	"TipSeen", -- (id: string, skipped: boolean?)  F87 (easy-start.md section 6): a shared/Tips id or one of its three
	-- asks, 1 a second. A tip or like_ask goes in tipsSeen (logged once as tip_shown, skipped true when a camera cut
	-- was skipped), feedback_ask sets feedbackAsked, stuck_help sets stuckHelpShown for the current tutorialStep
	"ClearTips", -- ()  F87: Settings' "Show tips again"; forgets tipsSeen but the like ask; 1 per 10 s; ProfileSync
	"SendFeedback", -- (face: string, chip: string?)  F87 (section 4): face in Tips.FACES, chip nil or in Tips.CHIPS;
	-- 1 per 10 s and FeedbackSessionLimit (5) a session; logs `feedback` and sets feedbackAsked. Text goes by ReportBug
}

-- Server -> client.
Remotes.ServerToClient = {
	"ProfileSync", -- (state: Types.PlayerState)  full state; the client merges
	"CatCaught", -- (catId: string, isNew: boolean)
	"OfflineEarnings", -- (amount: number, seconds: number)
	"Toast", -- (text: string, kind: "info" | "good" | "warn")
	"Announce", -- (text: string, rarity: Types.Rarity?)  fired to everyone; rarity on a rare catch
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
	-- how the marker runs and which zone to hit from now. Refusals of RescueBegin come as GrabResult
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
	-- `due` from the save and the clock, or its event); at most once a session per id until TipSeen. The client queues
	-- and times it, then answers TipSeen
	"SpinResult", -- (slice: number, amount: number)  the slice a SpinWheel landed on and its coins or foods; 0, 0
	-- when refused (F49)
	"CrateResult", -- (crateId: string, decorId: string, duplicate: boolean, refund: number)  the piece an OpenCrate
	-- gave (its rarity and kind are on its DecorDef) and the golden fish a duplicate paid back; decorId "" when refused
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
