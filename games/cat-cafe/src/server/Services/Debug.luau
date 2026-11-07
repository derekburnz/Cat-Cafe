--!strict
-- Studio-only hooks for automated playtests (QA request, docs/decisions.md). Every function errors outside Studio.
-- From the command bar (Server view) or Studio MCP execute_luau while playing, go through the bridge that
-- Main.server.luau sets up, never require this module directly: a direct require gets a fresh copy whose
-- services never started ("profile not loaded", a clock nobody runs).
--   local D = game.ServerStorage.CatCafeDebug
--   D:Invoke("setCoins", nil, 5000)   -- nil means the first player in the server
--   D:Invoke("setFish", nil, 300)      -- 300 golden fish in the wallet (F52)
--   D:Invoke("setPhase", "night")
--   D:Invoke("baitReady")              -- the bowl's cat arrives now
--   D:Invoke("baitReady", nil, "rainbow")   -- ... in a rainbow coat ("gold" or "base" too; QA A25, F99)
--   D:Invoke("baitReady", nil, nil, 2)      -- the second bowl's cat arrives now (#1161)
--   D:Invoke("secondBowl", nil, true)  -- act as if you own the Second Bait Bowl pass this session (false: as if not)
--   D:Invoke("richTip", nil, 20)       -- a rich customer's tip at your cafe, gone unpaid in 20 s
--   D:Invoke("tipPiles", nil, 6)       -- 6 tip piles on your cafe's tables now, whatever the clock (F61)
--   D:Invoke("knockLoose")             -- your carried cat drops as a knocked-loose stray (stand in an area)
--   D:Invoke("tackle", "Player1", "loose")  -- a real Tackle press with every check, the roll forced (F74)
--   D:Invoke("telemetry", 20)          -- the last 20 analytics events, oldest first
--   D:Invoke("renameCat", nil, "Mochi")              -- RenameCat on your first working cat (or a uid as 4th arg)
--   D:Invoke("tipJar", nil, 30)        -- the Tip Jar's session is 30 minutes older: steps 1 to 6 unlock now
--   D:Invoke("fillIndex", nil, "alley", nil, true)     -- every Alleyway cat in your Index, gold too (F48)
--   D:Invoke("fillIndex", nil, "alley", 5, "rainbow")  -- five Alleyway cats in your Index, rainbow coats too (F99)
--   D:Invoke("spawnStray", "tabby", "park", "rainbow")  -- a rainbow Tabby stray in the Park (F99; true for gold)
--   D:Invoke("nextCoat", "rainbow")    -- the next stray a wave or refill spawns is rainbow (F99; nil clears it)
--   D:Invoke("spins", nil, 3, true)    -- 3 banked spins and today's free spin due again, no cooldown (F49)
--   D:Invoke("spinSlice", nil, 4)      -- your next spin lands on slice 4 (F94, QA S63; nil goes back to random)
--   D:Invoke("dailyTreat", nil, 6)     -- the Daily Treat card at 6 stamps and a stamp due now: Claim pays day 7 (F70)
--   D:Invoke("giveCrate", nil, "alley_crate", 5)   -- 5 banked Alleyway Crates the Market opens for free (F53)
--   D:Invoke("campExtras", nil, 7 * 3600)   -- 7 hours away for the camp extras: the pond full, one picnic (F100)
--   D:Invoke("rally", nil, "force", true)    -- a Rescue Rally now (F101; false stops it, nil goes back to Config)
--   D:Invoke("rally", nil, "points", 20)     -- 20 check-ins' points for you through the steps and prizes (F101)
--   D:Invoke("rally", nil, "laps", 4)        -- your laps paid this weekend; returns the Rally's line either way
--   D:Invoke("tutorialStep", nil, 4)     -- sets the tutorial step (0 to 5) and syncs; then 5 for the X's pulse
--   D:Invoke("tackleLesson")             -- forgets the Tackle tip was seen and sends it now (the tackling lesson)
--   D:Invoke("giveFood", nil, "small_cat_snack", 5) -- cat food for the Bag's feed menu
--   D:Invoke("recapNow")                -- the "Your cafe so far" recap card now
--   D:Invoke("rescuePress", nil, "hit")   -- a bar press on your running rescue that hits ("miss" misses), judged
--                                      -- like a real one; returns "hit hits=2/6 paws=3 stage=bar"
--   D:Invoke("restartNotice", 300)     -- the restart countdown's 5 minute warning to everyone; returns its text
--   D:Invoke("rareCatchElsewhere", "Sam caught a Legendary Maine Coon!", "Legendary") -- #2203: a chat line as if
--                                      -- another server sent it; returns the line, or nil when held back
--   D:Invoke("tradeMinTier", 0)        -- trading from Tier 0 in this server (F102; nil goes back to the flag or Config)
--   D:Invoke("trading", false)         -- the trading kill switch off in this server, as CatCafe_Flags would (F102)
--   D:Invoke("flag", "codes", false)   -- a live switch (codes or rally) off in this server, as CatCafe_Flags would (#2119)
--   D:Invoke("freshCatch")             -- forget this window's Fresh Catch buys and heads up; returns the stock (F94)
--   D:Invoke("seedCafe", nil, 5, 12, { extraSlot = true, grandCafe = true })  -- Tier 5, 12 cats, slots filled (#2050)
--   D:Invoke("levelCat", nil, "<uid>", 1)    -- that cat one level up, as play would (Auto Equip may re-plan) (#2050)
--   D:Invoke("placeCat", nil, "<uid>", "greeter_1")   -- PlaceCat as the client sends it; unplaceCat too (#2050)
--   D:Invoke("autoEquipNow", nil, true)  -- Auto Equip runs now, the hand holds ended first (true); returns its state
--   D:Invoke("equipValues", nil, "<uid>")  -- that cat's value on each open slot against the cat working there (#2050)
--   D:Invoke("pitySpawn")              -- the sooner pity timer's cat spawns now; returns "<kind> <seq>: in <area>" (#2099)
--   D:Invoke("cancelMinigames")       -- ends your rescue (Give up), your help on one, and your running catches
--   D:Invoke("codes")                  -- forget your redeemed codes and the wrong-code lock (F65)
--   D:Invoke("givePotion", nil, "tip_potion", 3)    -- 3 Tip Potions in the bag (F64; nil id gives each potion)
--   D:Invoke("potionLeft", nil, "tip_potion", 30)   -- the running Tip Potion has 30 s left (0 ends it)
--   D:Invoke("mystery", nil, "potion")  -- a Mystery Visitor sits down at your cafe now, its gift of that kind (F64)
--   D:Invoke("collector", nil, nil, 1)  -- the Cat Collector at your counter now, his value roll at its best (F63)
--   D:Invoke("intro")                  -- the intro plays again on your next respawn or rejoin, as for a new player (F72)
--   D:Invoke("tips")                   -- forget every context tip, the feedback ask and the help cards (F87)
--   D:Invoke("bugReports", 50)         -- today's newest 50 bug reports (UTC), oldest first; needs API access on
--   D:Invoke("bugReports", 10, nil, true)  -- the newest 10 sent from Studio playtests today (keys s_ not r_)
--   D:Invoke("leaderboardHide", 123)   -- hide user id 123 from every leaderboard (live store with API access; F98)
--   D:Invoke("leaderboardHide", 123, true)  -- show them again
--   D:Invoke("leaderboards")           -- why the boards read what they do: writes on/off, hidden list, per list the
--                                         value now, last write and read, rows read and shown, rank (#941)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Bait = require(ReplicatedStorage.Shared.Bait)
local BugReportService = require(script.Parent.BugReportService)
local CafeService = require(script.Parent.CafeService)
local CampExtraService = require(script.Parent.CampExtraService)
local CatService = require(script.Parent.CatService)
local CatStats = require(ReplicatedStorage.Shared.CatStats)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Clock = require(ReplicatedStorage.Shared.Clock)
local ClockService = require(script.Parent.ClockService)
local CodeService = require(script.Parent.CodeService)
local CollectorService = require(script.Parent.CollectorService)
local Config = require(ReplicatedStorage.Shared.Config)
local DailyTreat = require(ReplicatedStorage.Shared.DailyTreat)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EquipBest = require(ReplicatedStorage.Shared.EquipBest)
local FishMarketService = require(script.Parent.FishMarketService)
local FreshCatch = require(ReplicatedStorage.Shared.FreshCatch)
local GlobalCatchService = require(script.Parent.GlobalCatchService)
local Layout = require(script.Parent.Parent.World.Layout)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LiveFlagService = require(script.Parent.LiveFlagService)
local MysteryService = require(script.Parent.MysteryService)
local NameService = require(script.Parent.NameService)
local Net = require(script.Parent.Net)
local PityService = require(script.Parent.PityService)
local Potions = require(ReplicatedStorage.Shared.Potions)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local QuestService = require(script.Parent.QuestService)
local RallyService = require(script.Parent.RallyService)
local RescueService = require(script.Parent.RescueService)
local RestartNoticeService = require(script.Parent.RestartNoticeService)
local RichTipService = require(script.Parent.RichTipService)
local SessionRecapService = require(script.Parent.SessionRecapService)
local Shove = require(ReplicatedStorage.Shared.Shove)
local ShoveService = require(script.Parent.ShoveService)
local Spin = require(ReplicatedStorage.Shared.Spin)
local SpinService = require(script.Parent.SpinService)
local StarterCatService = require(script.Parent.StarterCatService)
local Telemetry = require(script.Parent.Telemetry)
local TipJarService = require(script.Parent.TipJarService)
local TipPileService = require(script.Parent.TipPileService)
local TipService = require(script.Parent.TipService)
local TradeService = require(script.Parent.TradeService)
local Types = require(ReplicatedStorage.Shared.Types)

local Debug = {}

local function guard()
	if not RunService:IsStudio() then
		error("[Debug] only available in Studio")
	end
end

local function profileOf(player: Player): Types.PlayerProfile
	guard()
	local profile = DataService.get(player)
	assert(profile ~= nil, "profile not loaded for " .. player.Name)
	return profile
end

local function resolve(player: Player | number | string | nil): Player
	if typeof(player) == "Instance" then
		return player :: Player
	end
	if type(player) == "number" then
		local found = Players:GetPlayerByUserId(player)
		assert(found ~= nil, "no player with that user id")
		return found :: Player
	end
	if type(player) == "string" then
		local found = Players:FindFirstChild(player)
		assert(found ~= nil and found:IsA("Player"), "no player named " .. player)
		return found :: Player
	end
	local first = Players:GetPlayers()[1]
	assert(first ~= nil, "no players in the server")
	return first
end

-- Authoritative state as the server sees it (settled first).
function Debug.snapshot(player: (Player | number | string)?): Types.PlayerState
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time(), ClockService.epoch())
	return CafeService.buildState(p, profile)
end

function Debug.setCoins(player: (Player | number | string)?, coins: number)
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time(), ClockService.epoch())
	profile.coins = coins
	CafeService.sync(p)
end

-- Sets the golden fish in the wallet (F52); lifetimeGoldenFish never drops below it. Returns the new count.
function Debug.setFish(player: (Player | number | string)?, fish: number): number
	local p = resolve(player)
	local profile = profileOf(p)
	profile.goldenFish = math.max(0, math.floor(fish))
	profile.lifetimeGoldenFish = math.max(profile.lifetimeGoldenFish, profile.goldenFish)
	CafeService.sync(p)
	return profile.goldenFish
end

-- Pretend the player has been away: rewinds lastTick so the next settle credits `seconds` of income.
function Debug.setLastTick(player: (Player | number | string)?, secondsAgo: number)
	local p = resolve(player)
	local profile = profileOf(p)
	profile.lastTick = os.time() - secondsAgo
	CafeService.sync(p)
end

-- Wipes the profile back to the starting state (in memory; saved on leave like any other change).
function Debug.resetProfile(player: (Player | number | string)?)
	local p = resolve(player)
	local profile = profileOf(p)
	local fresh = ProfileSchema.template(os.time())
	for key, value in fresh :: any do
		(profile :: any)[key] = value
	end
	for key in profile :: any do
		if (fresh :: any)[key] == nil then
			(profile :: any)[key] = nil
		end
	end
	CafeService.refreshPlot(p)
	CafeService.sync(p)
end

-- #2099 (QA): the sooner pity timer's cat now, as if its time had come (PityService.debugSpawn).
function Debug.pitySpawn(): string
	guard()
	return PityService.debugSpawn()
end

-- One line for the cafe: "tier T, N cats, working: uid=spot uid=spot ..." in slot order (#2050).
local function cafeLine(profile: Types.PlayerProfile): string
	local count, working = 0, {}
	for _ in profile.cats do
		count += 1
	end
	for _, spot in Catalog.allSpots do -- the pass-only waiter_4 and waiter_5 too
		local cat = Economy.catOnSpot(profile, spot.id)
		if cat ~= nil then
			table.insert(
				working,
				string.format("%s=%s(L%d)", cat.uid, spot.id, CatStats.level(cat))
			)
		end
	end
	return string.format(
		"tier %d, %d cats, working: %s",
		profile.tier,
		count,
		table.concat(working, " ")
	)
end

-- #2050 (Desktop-Tester's greeter repro on a test save): the tier (1 to 5, as setTier), Extra Slot and Grand Cafe for
-- this session when `options` says so (as secondBowl does, no purchase), `catCount` new cats (0 to 60, in catalogue
-- order) given as a check-in would (Auto Equip runs as in play), and then every open slot still empty takes a
-- resting cat through PlaceCat's own steps. Those fills are the seed's, not the player's, so their hand holds end and
-- Auto Equip runs once (when on), as after a join. Returns cafeLine, whose uids levelCat and unplaceCat take.
function Debug.seedCafe(
	player: (Player | number | string)?,
	tier: number,
	catCount: number?,
	options: unknown
): string
	guard()
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time(), ClockService.epoch())
	profile.tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Catalog.maxTier)
	local opts: { [string]: any } = if type(options) == "table" then options :: any else {}
	local passes = table.clone(Economy.passes(profile))
	if opts.extraSlot == true then
		passes.slots = math.max(passes.slots, 1)
	end
	if opts.grandCafe == true then
		passes.grand = true
	end
	Economy.setPasses(profile, passes)
	for index = 1, math.clamp(math.floor(tonumber(catCount) or 0), 0, 60) do
		local def = Catalog.cats[(index - 1) % #Catalog.cats + 1]
		CafeService.addCaughtCat(p, def, false)
	end
	for _, spot in Catalog.allSpots do -- the pass-only waiter_4 and waiter_5 too
		if Economy.spotIsOpen(profile, spot.id) and Economy.catOnSpot(profile, spot.id) == nil then
			local resting: { string } = {}
			for uid, cat in profile.cats do
				if cat.spotId == nil then
					table.insert(resting, uid)
				end
			end
			table.sort(resting)
			if resting[1] == nil then
				break
			end
			CafeService.debugPlace(p, resting[1], spot.id)
		end
	end
	CafeService.debugAutoEquip(p, true, true)
	CafeService.refreshPlot(p)
	CafeService.sync(p)
	return cafeLine(profile)
end

-- #2050: cat `uid` up `levels` levels (default 1) as its XP would take it; the sync sends CatLevelUp and asks Auto
-- Equip to re-plan, as in play. Earnings settle first, so working cats can also level from the XP they earned since
-- the last settle, as they would at any sync. Returns "<uid> L<before> -> L<after>; " then cafeLine.
function Debug.levelCat(player: (Player | number | string)?, uid: string, levels: number?): string
	guard()
	local p = resolve(player)
	local profile = profileOf(p)
	local cat = profile.cats[uid]
	assert(cat ~= nil, "no cat with that uid")
	Economy.settle(profile, os.time(), ClockService.epoch())
	local before = CatStats.level(cat)
	for _ = 1, math.clamp(math.floor(tonumber(levels) or 1), 1, Config.CatMaxLevel) do
		CatStats.addXp(cat, math.max(1, CatStats.xpToNext(CatStats.level(cat)) - CatStats.xp(cat)))
	end
	local after = CatStats.level(cat)
	CafeService.refreshPlot(p)
	CafeService.sync(p)
	return string.format("%s L%d -> L%d; %s", uid, before, after, cafeLine(profile))
end

-- #2050: PlaceCat(uid, spotId) as the client sends it, every check included. Returns cafeLine, after
-- "refused: <why>; " when PlaceCat would refuse (the player sees the same as a toast).
function Debug.placeCat(player: (Player | number | string)?, uid: string, spotId: string): string
	guard()
	local p = resolve(player)
	local profile = profileOf(p)
	local cat = profile.cats[uid]
	local spot = Catalog.getSpot(spotId)
	local holder = if spot ~= nil then Economy.catOnSpot(profile, spotId) else nil
	local why = if cat == nil
		then "no cat with that uid"
		elseif spot == nil then "no slot " .. tostring(spotId)
		elseif not Economy.spotIsOpen(profile, spotId) then spotId
			.. " is not open at this tier and these passes"
		elseif holder ~= nil then spotId .. " already has " .. holder.uid
		elseif cat.spotId ~= nil then "the cat is on "
			.. tostring(cat.spotId)
			.. "; unplaceCat it first"
		else nil
	if why ~= nil then
		return "refused: " .. why .. "; " .. cafeLine(profile)
	end
	CafeService.debugPlace(p, uid, spotId)
	return cafeLine(profile)
end

-- #2050: Auto Equip's state and a run now. With `clearHolds` the hand placements' holds (AutoEquipHoldSeconds) end
-- first; the run skips the rate limit and does nothing with settings.autoEquip off. Returns "autoEquip on|off, <n>
-- held, <m> moved; " then cafeLine. An emptied slot waits for the next run: resting a cat by hand is not a trigger.
function Debug.autoEquipNow(player: (Player | number | string)?, clearHolds: boolean?): string
	guard()
	local p = resolve(player)
	local on, held, moved = CafeService.debugAutoEquip(p, clearHolds == true, true)
	return string.format(
		"autoEquip %s, %d held, %d moved; %s",
		if on then "on" else "off",
		held,
		moved,
		cafeLine(profileOf(p))
	)
end

-- #2050: why Auto Equip does or doesn't put cat `uid` to work. For each open slot: the cat working there and its
-- value (EquipBest.value: rating x 1.5 on its favorite role), then this cat's value there and the gain in percent.
-- Auto Equip takes a swap only when the whole plan gains (EquipBest.AUTO_STAY, 5%), and never moves a locked
-- working cat ("locked") or one placed by hand in the last AutoEquipHoldSeconds.
function Debug.equipValues(player: (Player | number | string)?, uid: string): string
	guard()
	local profile = profileOf(resolve(player))
	local cat = profile.cats[uid]
	assert(cat ~= nil, "no cat with that uid")
	local lines = {
		string.format(
			"%s %s L%d rating %.2f %s",
			uid,
			cat.catId,
			CatStats.level(cat),
			CatStats.rating(cat, profile.tier),
			if cat.spotId ~= nil then "on " .. tostring(cat.spotId) else "resting"
		),
	}
	for _, spot in EquipBest.openSpots(profile) do
		local mine = EquipBest.value(cat, spot, profile.tier)
		local holder = Economy.catOnSpot(profile, spot.id)
		if holder == nil then
			table.insert(lines, string.format("%s: empty vs %.2f", spot.id, mine))
		else
			local theirs = EquipBest.value(holder, spot, profile.tier)
			table.insert(
				lines,
				string.format(
					"%s: %s%s L%d %.2f vs %.2f (%+d%%)",
					spot.id,
					holder.uid,
					if holder.locked == true then " locked" else "",
					CatStats.level(holder),
					theirs,
					mine,
					if theirs > 0 then math.floor((mine / theirs - 1) * 100 + 0.5) else 0
				)
			)
		end
	end
	return table.concat(lines, "; ")
end

-- #2050: UnplaceCat(uid) as the client sends it. Returns cafeLine.
function Debug.unplaceCat(player: (Player | number | string)?, uid: string): string
	guard()
	local p = resolve(player)
	CafeService.debugUnplace(p, uid)
	return cafeLine(profileOf(p))
end

-- Sets the cafe tier (1 to 5) without RankUp's checks or cost, for testing areas, slots, caps and expansions.
function Debug.setTier(player: (Player | number | string)?, tier: number)
	local p = resolve(player)
	local profile = profileOf(p)
	Economy.settle(profile, os.time(), ClockService.epoch())
	profile.tier = math.clamp(math.floor(tier), 1, Catalog.maxTier)
	CafeService.refreshPlot(p)
	CafeService.sync(p)
end

-- Adds `count` of a food (shop or dealer) to the player's lures.
function Debug.giveLure(player: (Player | number | string)?, lureId: string, count: number?)
	local p = resolve(player)
	local profile = profileOf(p)
	assert(Catalog.getLure(lureId) ~= nil, "unknown lure " .. lureId)
	profile.lures[lureId] = (profile.lures[lureId] or 0) + math.max(1, math.floor(count or 1))
	CafeService.sync(p)
end

-- Adds `count` (default 1) of a cat food (Catalog.catFood: small_cat_snack, cat_snack, big_cat_snack) to the Bag,
-- for the feed menu (#2234). Returns how many the player now holds.
function Debug.giveFood(player: (Player | number | string)?, foodId: string, count: number?): number
	guard()
	local p = resolve(player)
	local profile = profileOf(p)
	assert(Catalog.getCatFood(foodId) ~= nil, "unknown cat food " .. tostring(foodId))
	profile.catFood[foodId] = (profile.catFood[foodId] or 0) + math.max(1, math.floor(count or 1))
	CafeService.sync(p)
	return profile.catFood[foodId]
end

-- Sends the "Your cafe so far" session recap card now (#1920, #2243). Returns whether it went out.
function Debug.recapNow(player: (Player | number | string)?): boolean
	guard()
	return SessionRecapService.debugSendNow(resolve(player))
end

-- Ages this session's Tip Jar by `minutes` so its steps unlock now (F47). Returns the session minutes played.
function Debug.tipJar(player: (Player | number | string)?, minutes: number): number
	return TipJarService.debugAge(resolve(player), minutes)
end

-- Sets the banked spins and, with `freeDue`, makes today's free spin due again (F49). Returns the spins available.
function Debug.spins(player: (Player | number | string)?, banked: number, freeDue: boolean?): number
	local p = resolve(player)
	return SpinService.debugSet(p, profileOf(p), banked, freeDue == true)
end

-- Makes the player's next spin land on `slice` (1 to 6), or random again with nil (F94, QA S63). Bank a spin with
-- Debug.spins first. Returns the slice set.
function Debug.spinSlice(player: (Player | number | string)?, slice: number?): number?
	guard()
	local p = resolve(player)
	return SpinService.debugForceSlice(p, if slice ~= nil then math.floor(slice) else nil)
end

-- Sets the Daily Treat card to `stamp` stamps (0 to 7) with a stamp due now, as if the last claim was yesterday
-- (F70). Returns the day the next Claim pays.
function Debug.dailyTreat(player: (Player | number | string)?, stamp: number): number
	local p = resolve(player)
	local profile = profileOf(p)
	profile.dailyTreat.stamp = math.clamp(math.floor(stamp), 0, DailyTreat.DAYS)
	profile.dailyTreat.lastDay = math.max(Spin.day(os.time()) - 1, 0)
	CafeService.sync(p)
	return DailyTreat.nextDay(profile.dailyTreat)
end

-- Sets the player's banked crates of `crateId` to `count` (default 1) and clears the Market cooldown (F53). Walk
-- to the Golden Fish Market to open them; a banked crate costs no fish.
function Debug.giveCrate(player: (Player | number | string)?, crateId: string, count: number?)
	local p = resolve(player)
	FishMarketService.debugGive(p, profileOf(p), crateId, count or 1)
end

-- F100 (camp-extras.md section 5, check 2): every camp extra's clock `seconds` (default 7 hours) into the past, as if
-- the player had been away that long (a UTC day for each 86400 s on the Lost and Found and the Yard Sale). Returns
-- "picnic=1 yardSale=2 pond=24 lostFound=0" (what each holds; shut extras show 0).
function Debug.campExtras(player: (Player | number | string)?, seconds: number?): string
	local p = resolve(player)
	local state: any = CampExtraService.debugAway(p, profileOf(p), seconds or 7 * 3600)
	local parts: { string } = {}
	for _, id in { "picnic", "yardSale", "pond", "lostFound" } do
		table.insert(parts, string.format("%s=%d", id, state[id].held))
	end
	return table.concat(parts, " ")
end

-- F101 (rescue-rally.md section 6): `action` "force" (value true, false or nil for Config.RallyForce), "points" (value
-- check-ins scored for the player) or "laps" (value the laps paid this weekend); returns the Rally as this player
-- sees it, "active=true lap=1 points=20/90 mine=20 lapsPaid=1 lapsDone=false".
-- The restart countdown's warning for `seconds` (0 to 600) to every player, as a MessagingService message would
-- bring it. Returns the text, or nil for seconds the server would ignore.
function Debug.restartNotice(seconds: unknown): string?
	guard()
	return RestartNoticeService.debugNotice(seconds)
end

-- Sets the tutorial step (0 to 5) and syncs, so the HUD sees a step change as the tutorial would make it (the X's
-- pulse on the sync from below 5 to 5, #2212). TutorialAdvance takes only the next step, once a second.
function Debug.tutorialStep(player: (Player | number | string)?, step: number): number
	guard()
	local p = resolve(player)
	local profile = profileOf(p)
	profile.tutorialStep = math.clamp(math.floor(step), 0, 5)
	CafeService.sync(p)
	return profile.tutorialStep
end

-- Forgets the Tackle tip was seen and sends it now, as the first check-in after the newcomer shield does, so the
-- client plays the tackling lesson again (#2198, #2201). Returns whether it went out.
function Debug.tackleLesson(player: (Player | number | string)?): boolean
	guard()
	return TipService.debugResend(resolve(player), "tackle")
end

-- A rescue bar press for `player` that hits or misses on purpose (`kind` "hit" or "miss"), for testers who cannot time
-- one by hand (RescueService.debugPress).
function Debug.rescuePress(player: (Player | number | string)?, kind: string?): string
	guard()
	return RescueService.debugPress(resolve(player), if kind == "miss" then "miss" else "hit")
end

-- #2203: a rare-catch line as if another server published it, through the same checks and show gate.
function Debug.rareCatchElsewhere(text: unknown, rarity: unknown): string?
	guard()
	return GlobalCatchService.debugReceive({ t = text, r = rarity, j = "debug" })
end

-- F102 (trading.md section 2): this server's minimum tier to trade; returns the one now in force.
function Debug.tradeMinTier(tier: unknown): number
	guard()
	return TradeService.debugMinTier(
		if type(tier) == "number" then math.max(0, math.floor(tier)) else nil
	)
end

-- F102 (section 4): the kill switch in this server (true or nil on, false off); returns whether trading is on.
function Debug.trading(on: unknown): boolean
	guard()
	return TradeService.debugTrading(if type(on) == "boolean" then on else nil)
end

-- #2119: live switch `key` ("codes" or "rally") in this server (true on, false off, nil back to CatCafe_Flags);
-- returns whether it is on.
function Debug.flag(key: unknown, on: unknown): boolean
	guard()
	assert(type(key) == "string", "flag needs a switch name")
	return LiveFlagService.debugSet(key, if type(on) == "boolean" then on else nil)
end

function Debug.rally(player: (Player | number | string)?, action: string?, value: any): string
	local p = resolve(player)
	if action == "force" then
		RallyService.debugForce(if type(value) == "boolean" then value else nil)
	elseif action == "points" then
		RallyService.debugPoints(p, tonumber(value) or 1)
	elseif action == "laps" then
		RallyService.debugLaps(p, profileOf(p), tonumber(value) or 0)
	end
	return RallyService.debugSummary(p)
end

-- Forgets the player's Fresh Catch buys and heads up (F94, QA S63), so the shelf sells this window's stock again and
-- the alert can come again. Returns the window and its stock, "<window>: <itemId>=<amount> ..." in shelf order.
function Debug.freshCatch(player: (Player | number | string)?): string
	local profile = profileOf(resolve(player))
	profile.freshCatch = FreshCatch.fresh()
	local window = FreshCatch.window(os.time())
	local parts: { string } = {}
	for _, item in FreshCatch.stock(window) do
		table.insert(parts, string.format("%s=%d", item.itemId, item.amount))
	end
	return string.format("%d: %s", window, table.concat(parts, " "))
end

-- Puts `count` (default 1) of a potion in the bag, or of every potion when `potionId` is nil (F64).
function Debug.givePotion(player: (Player | number | string)?, potionId: string?, count: number?)
	local p = resolve(player)
	local profile = profileOf(p)
	for _, def in Catalog.potions do
		if potionId == nil or def.id == potionId then
			profile.potions[def.id] = (profile.potions[def.id] or 0) + (count or 1)
		end
	end
	CafeService.sync(p)
end

-- Sets a potion's time left to `seconds` of play (0 ends it within a second), to see an expiry without the wait.
-- Returns the time left before.
function Debug.potionLeft(
	player: (Player | number | string)?,
	potionId: string,
	seconds: number
): number
	local p = resolve(player)
	local profile = profileOf(p)
	assert(Catalog.getPotion(potionId) ~= nil, "unknown potion " .. tostring(potionId))
	local now = os.time()
	Economy.settle(profile, now, ClockService.epoch())
	local before = Potions.left(profile, potionId, now)
	if seconds > 0 then
		profile.buffs[potionId] = seconds
	else
		profile.buffs[potionId] = nil
	end
	CafeService.sync(p)
	return before
end

-- A Mystery Visitor sits down at the player's cafe now, its gift of `kind` ("potion", "lure", "fish" or "spin")
-- when given (F64). Returns the gift's kind and id, or "" without a cafe or a table.
function Debug.mystery(player: (Player | number | string)?, kind: string?): string
	local gift = MysteryService.debugArrive(resolve(player), kind)
	return if gift ~= nil
		then string.format("%s %s x%d", gift.kind, gift.id or "", gift.count)
		else ""
end

-- The Cat Collector arrives at the player's cafe now, whatever the clock and the roll (F63): asking for the cat `uid`
-- when given (resting and unlocked), else his own pick, with his value roll forced to `valueRoll` (0 for his lowest
-- offer for that cat, 1 for his best) when given. Returns "<uid> <value>", or "" without a cafe or an askable cat.
function Debug.collector(
	player: (Player | number | string)?,
	uid: string?,
	valueRoll: number?
): string
	local catUid, offer = CollectorService.debugArrive(resolve(player), uid, valueRoll)
	return if catUid ~= nil and offer ~= nil
		then string.format("%s %d", catUid, offer.value)
		else ""
end

-- Starts a new quest day and week for the player now (F73), paying the old sets' finished quests first. Returns the
-- new daily ids, then " | ", then the weekly ids.
function Debug.quests(player: (Player | number | string)?): string
	local daily, weekly = QuestService.debugRenew(resolve(player))
	return table.concat(daily, " ") .. " | " .. table.concat(weekly, " ")
end

-- Marks the intro unseen, so the next respawn lands inside the back door and the next join plays it (F72). Reset
-- the character (or rejoin) to see it; the Tutorial tile replays it without this. Returns the old value.
function Debug.intro(player: (Player | number | string)?): boolean
	local p = resolve(player)
	local profile = profileOf(p)
	local was = profile.introSeen
	profile.introSeen = false
	CafeService.sync(p)
	return was
end

-- Forgets the player's context tips, like ask, feedback ask and "Need a hand?" cards, and which tips went out this
-- session, so each shows again (F87, QA S72). Returns how many tips were forgotten.
function Debug.tips(player: (Player | number | string)?): number
	local p = resolve(player)
	return TipService.debugReset(p, profileOf(p))
end

-- Forgets the player's Bellhop Cat claim and sends their Bellhop Cats away, so the stand can be claimed again (F96,
-- starter-cat.md section 5). Returns how many cats were removed.
function Debug.starterCat(player: (Player | number | string)?): number
	local p = resolve(player)
	return StarterCatService.debugReset(p, profileOf(p))
end

-- Forgets the player's redeemed codes and clears the wrong-code lock, so `playtest` can be redeemed again (F65).
-- Returns how many codes were forgotten.
function Debug.codes(player: (Player | number | string)?): number
	local p = resolve(player)
	return CodeService.debugReset(p, profileOf(p))
end

-- The newest `count` (default 20) bug reports of UTC day `day` ("YYYYMMDD", default today), oldest first, printed
-- one line each and returned: the testers' reports, or with `studio` true the ones sent from Studio playtests.
-- Reads the BugReports_v1 DataStore, so Studio's API access must be on.
function Debug.bugReports(count: number?, day: string?, studio: boolean?): { string }
	guard()
	local lines = BugReportService.debugList(count, day, studio)
	for _, line in lines do
		print("[BugReport] " .. line)
	end
	return lines
end

-- Brings the cat at the bait bowl now instead of after LureWaitSeconds (F28). Errors when the bowl is empty.
-- `coat` ("gold", "rainbow" or "base") replaces the coat rolled when the food went in, the way nextCoat forces a
-- stray's, so a test sees and hears a gold or rainbow arrival (QA A25, F99); nil keeps the roll. Returns the rolled
-- cat id, so a test can check what the card shows.
function Debug.baitReady(player: (Player | number | string)?, coat: string?, bowl: number?): string
	local p = resolve(player)
	local profile = profileOf(p)
	assert(bowl == nil or bowl == 1 or bowl == 2, "the bowl is 1 or 2")
	local bait = Bait.stateOf(profile, bowl or 1)
	assert(bait ~= nil, "the bait bowl is empty")
	if coat ~= nil then
		assert(
			coat == "gold" or coat == "rainbow" or coat == "base",
			"the coat is gold, rainbow or base"
		)
		bait.variant = coat
	end
	bait.placedAt = os.time() - Config.LureWaitSeconds
	bait.readyAt = os.time()
	CafeService.refreshPlot(p)
	CafeService.sync(p)
	return bait.catId
end

-- #1161: the Second Bait Bowl pass on (true) or off (false) for this session, as a purchase would set it, without
-- buying it. Returns the bowl's state ("on" or "offer").
function Debug.secondBowl(player: (Player | number | string)?, owned: boolean): string
	local p = resolve(player)
	local profile = profileOf(p)
	local passes = table.clone(Economy.passes(profile))
	passes.secondBowl = if owned then true else nil
	Economy.setPasses(profile, passes)
	CafeService.refreshPlot(p)
	CafeService.sync(p)
	return CafeService.secondBowl(p, profile)
end

-- Opens a rich tip at the player's cafe now, whatever the clock and the roll (F31). `staySeconds` shortens the wait
-- before it pays itself (RichTipStaySeconds by default). Returns the amount.
function Debug.richTip(player: (Player | number | string)?, staySeconds: number?): number
	guard()
	return RichTipService.debugOpen(resolve(player), staySeconds)
end

-- Puts `count` tip piles (1 by default) on the player's cafe tables now, whatever the clock, up to TipPilesMax
-- (F61). Returns how many wait.
function Debug.tipPiles(player: (Player | number | string)?, count: number?): number
	guard()
	return TipPileService.debugAdd(resolve(player), count)
end

-- Pretends the player rejoined after `secondsAgo` away: sets the unclaimed offline earnings to what that gap
-- pays at the current day rate and shows the popup. Returns the amount.
function Debug.setLastSeen(player: (Player | number | string)?, secondsAgo: number): number
	local p = resolve(player)
	profileOf(p)
	local amount = DataService.debugSetAway(p, math.max(0, secondsAgo))
	local pending, seconds = DataService.peekPendingOffline(p)
	if pending > 0 then
		Net.fire(p, "OfflineEarnings", pending, seconds)
	end
	return amount
end

-- Marks the in-memory profile as written by a newer version, so it saves that way on leave and the next join hits
-- the newer-save guard (kicked, data untouched). The dev profile then stays unloadable: clear it from the command
-- bar with game:GetService("DataStoreService"):GetDataStore("CatCafeProfiles_dev"):RemoveAsync("p_" .. userId).
function Debug.setSaveVersion(player: (Player | number | string)?, version: number)
	local p = resolve(player)
	local profile = profileOf(p)
	profile.version = math.floor(version)
end

-- Gives the player a cat as if checked in (skips the alley). `rescued` true marks it as rescued.
function Debug.giveCat(
	player: (Player | number | string)?,
	catId: string,
	rescued: boolean?
): Types.CatInstance
	local p = resolve(player)
	profileOf(p)
	local def = Catalog.getCat(catId)
	assert(def ~= nil, "unknown cat id " .. catId)
	local instance = CafeService.addCaughtCat(
		p,
		def :: Types.CatDef,
		true,
		nil,
		nil,
		if rescued then "rescue" else nil
	)
	return instance
end

-- Fills the Index page of `areaId` (F48): the first `count` of its cats (all of them when nil) go into the
-- collection, and into the gold collection too when `gold` is true (the rainbow one when it is "rainbow", F99),
-- without giving any cats. Returns the page's count.
function Debug.fillIndex(
	player: (Player | number | string)?,
	areaId: string,
	count: number?,
	gold: (boolean | string)?
): number
	local p = resolve(player)
	local profile = profileOf(p)
	assert(Catalog.getArea(areaId) ~= nil, "unknown area " .. areaId)
	local added = 0
	for _, def in Catalog.cats do
		if def.area == areaId and (count == nil or added < count) then
			added += 1
			profile.collection[def.id] = profile.collection[def.id] or os.time()
			if gold == "rainbow" then
				profile.rainbowCollection[def.id] = profile.rainbowCollection[def.id] or os.time()
			elseif gold then
				profile.goldCollection[def.id] = profile.goldCollection[def.id] or os.time()
			end
		end
	end
	CafeService.sync(p)
	return added
end

function Debug.setUpgrade(player: (Player | number | string)?, upgradeId: string, level: number)
	local p = resolve(player)
	local profile = profileOf(p)
	local def = Catalog.getUpgrade(upgradeId)
	assert(def ~= nil, "unknown upgrade " .. upgradeId)
	profile.upgradeLevels[upgradeId] =
		math.clamp(level, (def :: Types.UpgradeDef).startLevel, (def :: Types.UpgradeDef).maxLevel)
	CafeService.refreshPlot(p)
	CafeService.sync(p)
end

-- Spawns a stray of the given cat in an area (any Catalog.areas id, "alley" by default), gold when `coat` is true
-- or "gold", rainbow when it is "rainbow" (F99). Returns its StrayId.
function Debug.spawnStray(catId: string, areaId: string?, coat: (boolean | string)?): string
	guard()
	return CatService.debugSpawnStray(catId, areaId or "alley", coat)
end

-- F99 (rainbow-coat.md section 6, check 1): the next stray a wave or a refill spawns gets `coat` ("gold" or
-- "rainbow"), with its beam and the server's toast; nil clears it.
function Debug.nextCoat(coat: string?)
	guard()
	CatService.debugNextCoat(coat)
end

-- Drops the player's carried cat where they stand as a shove would, whatever the grace or immunity: a Dropped stray
-- anyone picks up with the hold (v0.8 F56). Stand in a catching area. Returns the new StrayId.
function Debug.knockLoose(player: (Player | number | string)?): string
	guard()
	return CatService.debugKnockLoose(resolve(player))
end

-- `player` presses Tackle with every section 10c check (v0.11 F74): face someone within the 12 stud lunge first, in a
-- catching area. `outcome` "loose" or "held" forces the roll on a carrier that can be knocked loose; nil rolls
-- BumpChance (1.0 since v0.8 F56, so always loose). The server cannot move a client-owned character, so the lunge
-- itself only plays from the real button.
function Debug.tackle(player: (Player | number | string)?, outcome: string?)
	guard()
	assert(
		outcome == nil or outcome == "loose" or outcome == "held",
		"outcome is loose, held or nil"
	)
	local forced: Shove.KnockResult? = if outcome == "loose"
		then "loose"
		elseif outcome == "held" then "held"
		else nil
	ShoveService.debugTackle(resolve(player), forced)
end

-- RenameCat as if the player sent it, with every check and the real filter (F33). `uid` defaults to a working cat,
-- else any cat. Returns the uid.
function Debug.renameCat(player: (Player | number | string)?, name: string, uid: string?): string
	local who = resolve(player)
	local profile = profileOf(who)
	local chosen = uid
	if chosen == nil then
		for catUid, instance in profile.cats do
			if chosen == nil or instance.spotId ~= nil then
				chosen = catUid
			end
			if instance.spotId ~= nil then
				break
			end
		end
	end
	assert(chosen ~= nil, "no cat to rename")
	NameService.debugRename(who, chosen :: string, name)
	return chosen :: string
end

-- Moves the player's character onto an area's first spawn point, past its gate whatever their tier, so a
-- playtest can check that a locked area refuses catches (F23).
function Debug.teleport(player: (Player | number | string)?, areaId: string)
	guard()
	local spec = Layout.areas[areaId]
	assert(spec ~= nil, "no area " .. tostring(areaId))
	local character = resolve(player).Character
	assert(character ~= nil, "no character")
	local point = spec.spawnPoints[1]
	character:PivotTo(CFrame.new(point.x + 3, spec.floorY + 4, point.z))
end

-- Jumps the server clock to the start of "day" or "night" at full length. Night closes the areas at once (every
-- stray and trap clears, everyone in an area goes home); day brings the sunrise wave and fills the traps.
function Debug.setPhase(phase: Types.ClockPhase)
	guard()
	assert(phase == "day" or phase == "night", "phase is day or night")
	ClockService.debugSetPhase(phase)
end

-- F98: adds a user id to the leaderboards' hidden list (or takes it off with `show`), in the live DataStore when
-- Studio has API access; the next refresh drops them from every list. Returns how many are hidden.
function Debug.leaderboardHide(userId: number, show: boolean?): number
	guard()
	assert(type(userId) == "number" and userId > 0, "a user id")
	return LeaderboardService.debugHide(userId, show)
end

-- #941: LeaderboardService.debugState for `player` (nil means the first player), for an empty or odd board.
function Debug.leaderboards(player: Player | number | string | nil): { [string]: any }
	guard()
	return LeaderboardService.debugState(resolve(player))
end

-- F88 (review N311): jumps the clock into the night before the next Lucky Day, `lead` seconds before its sunrise
-- (LuckyDayWarnSeconds + 5 when none is given, so the warning, the banner and the x2 wave all play). Returns that
-- Lucky Day's number.
function Debug.toLuckyDay(lead: number?): number
	guard()
	local day = Clock.nextLuckyDay(ClockService.day())
	local before =
		math.clamp(lead or (Config.LuckyDayWarnSeconds + 5), 1, Config.NightLengthSeconds)
	ClockService.debugSetTime(Clock.sunriseOf(day) - before)
	return day
end

-- The clock as the server sees it: phase, server time it ends at, and seconds left.
function Debug.clock(): { phase: Types.ClockPhase, endsAt: number, secondsLeft: number }
	guard()
	local endsAt = ClockService.phaseEndsAt()
	return {
		phase = ClockService.phase(),
		endsAt = endsAt,
		secondsLeft = endsAt - Workspace:GetServerTimeNow(),
	}
end

-- Puts a stuck cat at a rescue trap ("rescue_alley_1" when none is given; the park's trees are rescue_park_1 and
-- rescue_park_2). `coat` forces the hidden roll: true or "gold" for gold, "rainbow" for rainbow (F99). Returns the
-- rescueSpotId.
function Debug.spawnStuckCat(
	catId: string,
	rescueSpotId: string?,
	coat: (boolean | string)?
): string
	guard()
	return RescueService.debugSpawnStuck(catId, rescueSpotId, coat)
end

-- Laptop-Tester (2026-11-07): ends the player's rescue (as Give up) or their help on someone's, and any catch they
-- have running (a Miss), so a tester stuck in a minigame can carry on. Returns what the server had, such as
-- "rescue: none, catches ended: 0": with both empty, a rescue or catch screen still up is the client's alone.
function Debug.cancelMinigames(player: (Player | number | string)?): string
	guard()
	local p = resolve(player)
	local rescue = RescueService.debugCancel(p)
	local catches = CatService.debugEndCatch(p)
	return string.format("rescue: %s, catches ended: %d", rescue, catches)
end

-- Number of strays in an area and of stuck cats across all rescue traps.
function Debug.counts(areaId: string?): { strays: number, stuck: number }
	guard()
	return { strays = CatService.strayCount(areaId or "alley"), stuck = RescueService.stuckCount() }
end

function Debug.dataSaves(): boolean
	guard()
	return DataService.saves()
end

-- The last `count` analytics events this server logged (all of them, 200 at most, when nil), oldest first, one line
-- each: "onboarding first_catch 3", "sink tables 100 [1, day, 1]". Studio sends nothing to Roblox, so this is the
-- place to check the funnel order (F16).
function Debug.telemetry(count: number?): { string }
	guard()
	local lines: { string } = {}
	for _, entry in Telemetry.recent(count) do
		local fields = if #entry.fields > 0
			then " [" .. table.concat(entry.fields, ", ") .. "]"
			else ""
		table.insert(
			lines,
			string.format(
				"%d %s %s %s%s",
				entry.userId,
				entry.kind,
				entry.name,
				tostring(entry.value),
				fields
			)
		)
	end
	return lines
end

-- The player's onboarding funnel state: the last step logged and the steps held back until it catches up.
function Debug.onboarding(player: (Player | number | string)?): { step: number, held: { string } }
	guard()
	local profile = profileOf(resolve(player))
	local held: { string } = {}
	for key in profile.telemetry.achieved do
		table.insert(held, key)
	end
	table.sort(held, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return { step = profile.telemetry.onboardingStep, held = held }
end

return Debug
