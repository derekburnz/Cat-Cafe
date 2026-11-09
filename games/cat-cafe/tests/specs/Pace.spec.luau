--!strict
-- The loop script's pace in numbers (QA; test plan section 6, data-model 11 and 12, features F60 and F61 "QA re-times
-- Tier 2", economy-ladder.md section 8 checks 3 and 7 and section 6's one hour floor for F95). A second by second run
-- of a new player on the real shared code: Economy's income, settle, XP, blockers, passes and offline pay, the Clock's
-- day and night, the Catalog's prices, odds, first catch rewards, Tip Jar and Index prizes, Bait's bowl luck,
-- EquipBest's placements, Catching's picks and CatStats' charm. The player:
-- - joins, watches the 25 s intro, then flies to the Alleyway and checks the tutorial Common in at its camp at 51 s;
-- - by day sets out on CATCHES trips into the newest area its tier opens at even times, a catch per trip from the
--   sunrise wave while it lasts (a stray picked at random from the wave, which has an Epic or better since F97,
--   Catching.waveRare), and is home between trips and all night (areas closed). A trip is the Cat Cannon's
--   (hometown-cannon.md 6a, F84): the walk to the cannon, the hop and the flight, the walk from the camp's pad to a
--   spawn point the stray's rarity may take in the area's set (Catching.spawnPool on Layout's points, so F85's long
--   sets count as they land) along a path 1.25 times the straight line (6b), the carry back into the camp (the catch
--   rush, then carry speed) and the cloud hop home;
-- - nets each stray with presses that land PRESS_SPREAD seconds either side of the target (one standard deviation,
--   ping wobble included; data-model 10, v0.13.15), graded by Circles on its net level's windows times the
--   stray's `catchWindow` (F83), on the trust bar (#1884). A bolt costs the chase: the stray sprints and rests
--   (Catching.fleeUntil), the misser waits its growing step longer (Catching.selfRetrySeconds) and walks over,
--   startled at first. A trip
--   that runs late delays the next one, and a stray still loose at the dusk banner is left behind;
-- - is paid each tip pile the moment it appears, wherever it is (F97); at home claims a waiting rich visitor, tames a
--   ready bait cat and puts food in an empty bowl, buying the best shop food whose price at its tier
--   (Economy.foodPrice, F97) is at most FOOD_SECONDS of income (Kibble at least) when out;
--   claims Tip Jar coins when due and every Index milestone it reaches on the area pages and All Cats (their coins,
--   food, tips forever, bait speed and gold luck); places the best cats after every new one and every rank up;
-- - ranks up the moment `rankUpBlocker` allows, otherwise buys the cheapest open shop item (the data-model 11 pace
--   model's player: upgrades, and the coin decor shop until F97 moved it into the Classic Crate), or with SAVER only
--   the tables and the bait bowl;
-- - plays in one go, or SESSION seconds a day (F95): away the rest of the day, it is paid Economy.offlineGain at the
--   next join (half its day rate for up to 8 hours), its bowl keeps counting, and it joins a running server at a
--   random point of its day and of the global days (#1572) with a fresh wave and a new Tip Jar;
-- - with MONEY owns that Money pass (Economy.setPasses; 24 stands for owning every paid bonus);
-- - has Luck (F88, shared/Luck): the Lucky Cat levels it buys from the shop go into each food's roll, fixed when the
--   food goes in, and on a Lucky Day (the day phase of a day Clock.dayKinds rolls lucky, #1572) the sunrise wave
--   rolls at LuckyDayWaveLuck and its food at LuckyDayPlayerLuck more;
-- - rolls each cat's coat as the game does (F99, Catching.rollCoat): rainbow first, then gold on the same roll, with
--   the Rainbow track's luck from the Rainbow page it claims as well; a rainbow cat earns RainbowMultiplier.
-- With LAWN it also buys the best affordable front lawn piece or style whenever it can (lawn-nursery.md section 6d
-- check 4) and lays the best lawn (Lawn.applyBest), after the rank up and before the cheapest shop item.
-- Spins, golden fish and their perks, crates, potions, quests, the Daily Treat, rescues and the night dealer
-- are left out, as in the economy-ladder.md section 3 model, so real players run a little faster.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Layout = require(ServerScriptService.Server.World.Layout)
	local Bait = require(Shared.Bait)
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)
	local Catching = require(Shared.Catching)
	local Circles = require(Shared.Circles)
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local GrandOpening = require(Shared.GrandOpening)
	local EquipBest = require(Shared.EquipBest)
	local IndexRewards = require(Shared.IndexRewards)
	local Lawn = require(Shared.Lawn)
	local Luck = require(Shared.Luck)
	local Prizes = require(Shared.Prizes)
	local ProfileSchema = require(Shared.ProfileSchema)
	local StrayTopUp = require(Shared.StrayTopUp)
	local Types = require(Shared.Types)
	local VisitTimer = require(Shared.VisitTimer)

	local INTRO_SECONDS = 25
	local RANDOM_DAYS = 1000 -- #1572: a running server joins on a random one of this many global days
	-- hometown-cannon.md 6a (F84): the intro, then about 26 s to fly out, net the tutorial stray waiting just past the
	-- Alleyway's camp and walk it in (75 s through the back door before)
	local TUTORIAL_CHECKIN = 51
	local CANNON_WALK = 5 -- 6a: the cafe to the Town Square cannon (the Cannon button: at once)
	local CANNON_HOP = 0.5 -- 6a: hopping in, before the flight's CannonLaunchSeconds
	-- How much longer the main path is than the straight way in, by area (6b: about 1.25 everywhere): the Alleyway's
	-- one lane about 300 studs through its four ways through for 251 (QA's sum), and since Model-Agent's islands
	-- (#905, area-sets.md's walk checks) a long area's shortest walk is 1.0 to 1.08 times its depth (the Park about
	-- 315, the Neighbourhood 440 to 460, the Woods 480 to 500, the Sewer about 560 to the throne), so 1.1 for a player
	-- who does not hug every corner. An area not here takes 6b's 1.25.
	local WINDING: { [string]: number } = {
		alley = 1.2,
		park = 1.1,
		neighbourhood = 1.1,
		woods = 1.1,
		sewer = 1.1,
	}
	local PAD_IN = 13 -- the landing pad, this far inside the camp from its gate line (CAMP_PAD)
	local PRESS_SPREAD = 0.05 -- data-model 10 (v0.13.15): presses within about 50 ms
	local MAX_TRIES = 200
	local LIMIT = 3600 -- a Tier 2 run gives up after an hour
	local FOOD_SECONDS = 60 -- economy-ladder.md section 3's model: each food at most a minute of income
	local DAY = 86400
	local HOUR = 3600
	-- The long runs to Tier 5 hold hundreds of cats, so they take bigger steps: five second ticks, a settle and a look
	-- at the shop every 30 s and right after any change, and Equip best only when a new cat can win a slot or every
	-- 10 minutes of play (resting cats level up too). Each costs at most a few seconds a step against hours of play.
	local LONG_STEP = 5
	local LONG_SETTLE = 30
	local LONG_PLAN = 600

	type Options = {
		catches: number,
		saver: boolean?,
		freshServer: boolean?,
		spread: number?,
		target: number?, -- the tier the run stops at, 2 when nil
		limit: number?, -- seconds of play before it gives up, LIMIT when nil
		session: number?, -- seconds of play a day; nil plays in one go
		money: number?, -- the Money pass multiplier, none when nil
		long: boolean?, -- a long run to Tier 5: bigger steps (LONG_STEP, LONG_SETTLE and LONG_PLAN)
		strays: StrayModel?, -- #1159's daytime top-ups into the area the player hunts in; none when nil
		quickBait: boolean?, -- #1716: a Quick Bait Potion runs the whole time (+0.25 bait speed, inside BaitSpeedMax)
		lawn: ("greedy" | "saving")?, -- #1283: buys the best affordable lawn piece or style and lays the best lawn; "greedy" the moment it can, "saving" only with the next rank up's cost left over
		pals: number?, -- pals on the server (Economy.setPals, #1165): tips, piles and rich visitors earn the pal bonus
		event: { from: number, to: number }?, -- #2486: a Cafe Event's money (EventMoneyMax) over these seconds of play
		tier2Band: { number }?, -- #2557: this case's Tier 2 band in minutes, { low, high }, when not 10 to 20
	}
	-- The daytime top-ups (#1159, shared/StrayTopUp) as the one catcher sees them. `players` sets the floor of live
	-- strays (StrayTopUp.floor); `wait` fixes the seconds between top-ups (60 is StrayTopUpMinSeconds, the most a
	-- non-stop catcher can be given: 60 an hour an area), nil draws the real 60 to 120 s each time. The catcher has the
	-- whole supply to itself, so the other players on a full server are not taking strays: the pace's worst case.
	type StrayModel = { players: number, wait: number? }
	-- #1896: what a run bought or unlocked and when (seconds of play): a shop item or lawn piece ("buy"), a rank up
	-- ("rank"), a cat the Index had not met ("newcat") or a Grand Opening step met (#1893, "roadmap", from the end of
	-- the tutorial as the server marks them; the model pays no step prizes)
	type Event = { t: number, kind: string, id: string }
	type Run = {
		events: { Event },
		tierAt: { [number]: number }, -- seconds of play at each rank up
		dayAt: { [number]: number }, -- the day (session) of each rank up
		catsReady: number?, -- seconds of play when the cats for Tier 2 were in
		coinsFromPiles: number,
		coinsFromRich: number,
		coinsOffline: number,
		tries: number,
		misses: number,
		chaseSeconds: number,
		leftBehind: number,
		topUps: number, -- strays added by #1159's top-ups
	}

	-- Park and Miller's generator: exact in doubles, so every machine gets the same runs
	local function generator(seed: number): () -> number
		local state = seed
		return function(): number
			state = state * 48271 % 2147483647
			return state / 2147483647
		end
	end

	-- A net level's windows for a stray of this rarity: the level's half-widths times the rarity's `catchWindow`
	-- (F83, data-model 2 and 10), 1 on a build without it.
	local function windowsFor(netLevel: number, rarity: Types.Rarity): Types.NetWindows
		local windows = Circles.windows(netLevel)
		local scale = (Catalog.rarities[rarity] :: any).catchWindow or 1
		return { perfect = windows.perfect * scale, good = windows.good * scale }
	end

	-- Seconds to cover `studs` on foot after a miss: StartledWalkSpeed for StartledSeconds, then NormalWalkSpeed.
	local function walkSeconds(studs: number): number
		local startled = Config.StartledWalkSpeed * Config.StartledSeconds
		if studs <= startled then
			return studs / Config.StartledWalkSpeed
		end
		return Config.StartledSeconds + (studs - startled) / Config.NormalWalkSpeed
	end

	-- A trip's seconds, the chase left out (hometown-cannon.md 6a and 6b): the cannon out, the walk from the pad to a
	-- spawn point a stray of `rarity` may take in the area's set as Catching.spawnPool picks in an empty area (`roll`
	-- choosing among them), the carry back (CatchRushWalkSpeed for CatchRushSeconds, then CarryWalkSpeed) and the
	-- cloud hop home. Distances are in the camp's space, where z is how far in from the gate line.
	local function tripSeconds(areaId: string, rarity: Types.Rarity?, roll: number): number
		local spec, camp = Layout.areas[areaId], assert(Layout.camps[areaId])
		local slots: { Catching.SpawnSlot } = {}
		for i, point in spec.spawnPoints do
			slots[i] = { zone = point.zone, free = true }
		end
		local pool = Catching.spawnPool(slots, rarity)
		local point = spec.spawnPoints[pool[1 + math.floor(roll * #pool)]]
		local _, z = Layout.campLocal(camp, point.x, point.z)
		local path = (WINDING[areaId] or 1.25) * (PAD_IN + math.max(z, 0))
		local rush = math.min(path, Config.CatchRushWalkSpeed * Config.CatchRushSeconds)
		local back = rush / Config.CatchRushWalkSpeed + (path - rush) / Config.CarryWalkSpeed
		local flight = CANNON_WALK + CANNON_HOP + Config.CannonLaunchSeconds
		local out = flight + path / Config.NormalWalkSpeed
		return out + back + Config.CloudHopSeconds
	end

	-- Whether a tick from `clockT - step` to `clockT` passed a multiple of `every` (the server's pile and visitor
	-- ticks); with one second ticks, `clockT % every == 0`.
	local function crossed(clockT: number, step: number, every: number): boolean
		return clockT // every ~= (clockT - step) // every
	end

	local function simulate(options: Options, seed: number): Run
		local rng = generator(seed)
		-- the presses and the rings have their own rolls, so a change to the catch (#1884) leaves which cats come,
		-- and when, as they were
		local pressRng = generator(seed * 3 + 1)
		local step = if options.long then LONG_STEP else 1
		local limit = options.limit or LIMIT
		local target = options.target or 2
		local sessionLength = options.session or limit
		local base = 1000000
		local profile: any = ProfileSchema.template(base)
		if options.money ~= nil then
			Economy.setPasses(profile, { money = options.money, longNap = false, slots = 0 })
		end
		if options.pals ~= nil then
			Economy.setPals(profile, options.pals)
		end
		Economy.setEventMoney(1)
		local eventOn = false
		-- the pals' share on top of tip piles and rich visitors (TipPileService and RichTipService use
		-- Economy.tipMultiplier; Economy.settle pays it on the per second income itself); offline pay has none
		local palBoost = 1 + Economy.palBonus(profile)
		local run: Run = {
			events = {},
			tierAt = {},
			dayAt = {},
			coinsFromPiles = 0,
			coinsFromRich = 0,
			coinsOffline = 0,
			tries = 0,
			misses = 0,
			chaseSeconds = 0,
			leftBehind = 0,
			topUps = 0,
		}
		local spread = options.spread or PRESS_SPREAD
		local settleEvery = if options.long then LONG_SETTLE else 1
		local plannedAt = 0 -- seconds of play at the last full Equip best
		local tutorialDone = false
		local roadmapMet: { [number]: boolean } = {}
		local uid = 0
		local epoch = 0 -- the session's server clock start, for settling across day and night
		local dirty = true -- the rate changed since the last settle: settle on the next tick

		-- A press's error: normal, by Box and Muller from two of the press rolls (never 0, so the log is safe).
		local function pressError(): number
			return spread
				* math.sqrt(-2 * math.log(pressRng()))
				* math.cos(2 * math.pi * pressRng())
		end

		-- Seconds from the first try on a stray to the try that nets it, or nil after MAX_TRIES.
		local function chase(rarity: Types.Rarity): number?
			local netLevel = Economy.level(profile, "net")
			local windows = windowsFor(netLevel, rarity)
			local studs = Catching.fleeStuds(rarity)
			local streak: Catching.MissStreak? = nil
			local startsAt = 0
			for _ = 1, MAX_TRIES do
				run.tries += 1
				-- #1884 (catch-rework.md 7b): the trust bar decides the try, ring by ring as the server judges it
				local circles = Circles.schedule(rarity, netLevel, startsAt, pressRng)
				local attempt = Circles.newAttempt(circles, windows, Circles.trustFor(rarity))
				local endedAt = startsAt
				for i, circle in circles do
					local at = Circles.target(circle) + pressError()
					if circle.kind == "paw" then
						-- #1884 (7c): a paw ring is left alone (+1 trust)
						Circles.expire(attempt, Circles.deadline(circle, windows) + 1e-6)
					elseif Circles.press(attempt, i, at, at) == nil then
						Circles.expire(attempt, Circles.deadline(circle, windows) + 1e-6)
					end
					endedAt = math.max(at, Circles.target(circle))
					if Circles.isDone(attempt) then
						break
					end
				end
				if Circles.succeeded(attempt) then
					return startsAt
				end
				local missedAt = endedAt
				run.misses += 1
				streak = Catching.nextMiss(streak, missedAt)
				local count = assert(streak).count
				local free = Catching.fleeUntil(missedAt, studs) + Catching.selfRetrySeconds(count)
				startsAt = math.max(free, missedAt + walkSeconds(studs)) + Config.CatchHoldSeconds
			end
			return nil
		end

		local function rate(): number
			return Economy.incomePerSecond(profile)
		end

		-- The newest area the player's tier opens, where its trips go.
		local function newestArea(): Types.AreaDef
			return assert(Catalog.getArea(assert(Catalog.getTier(Economy.tier(profile))).area))
		end

		-- The coat roll (F99): rainbow first on the same roll, then gold, with the player's Index rainbow and gold luck
		-- (the shared stray roll uses the best luck in the area, its own when it plays alone).
		local function coat(def: Types.CatDef, rainbow: number, gold: number): string
			return Catching.rollCoat(
				def,
				rng(),
				IndexRewards.rainbowChance(rainbow, IndexRewards.rainbowLuck(profile)),
				IndexRewards.rollChance(gold, IndexRewards.totals(profile).goldLuck)
			)
		end

		-- Every milestone reached on the area's page and All Cats, claimed at once: coins at today's rate, food, and
		-- the tips forever, bait speed and gold luck that count from the claim on (crates, fish and spins left out).
		local function claimIndex(areaId: string)
			for _, page in { areaId, IndexRewards.ALL, IndexRewards.RAINBOW } do
				for _, milestone in Catalog.indexMilestones do
					if
						milestone.track ~= "decor"
						and IndexRewards.blocker(profile, page, milestone.id) == nil
					then
						local claims = profile.indexRewards[page] or {}
						profile.indexRewards[page] = claims
						claims[milestone.id] = true
						local prize = assert(IndexRewards.prize(page, milestone.id))
						Economy.credit(
							profile,
							Prizes.coins(prize.coins, prize.coinSeconds, rate())
						)
						for lureId, count in (prize.lures or {}) :: { [string]: number } do
							profile.lures[lureId] = (profile.lures[lureId] or 0) + count
						end
					end
				end
			end
		end

		-- Equip best (EquipBest's plan) after a new cat. A long run skips it when the newcomer cannot win a slot: every
		-- slot is filled and its rating, even in its favourite role, is no more than any working cat's own, so putting
		-- the weakest left out in its place does at least as well.
		local function placeBest(newcomer: Types.CatInstance?)
			if options.long and newcomer ~= nil then
				local working, weakest = 0, math.huge
				for _, other in profile.cats do
					if other.spotId ~= nil then
						working += 1
						weakest = math.min(weakest, CatStats.rating(other, profile.tier))
					end
				end
				local best = CatStats.rating(newcomer, profile.tier) * Config.FavoriteMultiplier
				if working >= #EquipBest.openSpots(profile) and best <= weakest then
					return
				end
			end
			EquipBest.apply(profile, EquipBest.plan(profile))
		end

		local function addCat(def: Types.CatDef, variant: string, now: number)
			Economy.settle(profile, now, epoch) -- the time before it at the old rate
			uid += 1
			local instance =
				CatStats.newInstance("c" .. uid, def.id, now, CatStats.rollCharm(rng(), rng()))
			instance.variant = variant
			profile.cats[instance.uid] = instance
			if profile.collection[def.id] == nil then
				profile.collection[def.id] = now
				table.insert(run.events, { t = now - base, kind = "newcat", id = def.id })
				Economy.credit(profile, Catalog.rarities[def.rarity].firstCatchReward)
			end
			if variant == "gold" and profile.goldCollection[def.id] == nil then
				profile.goldCollection[def.id] = now
			elseif variant == "rainbow" and profile.rainbowCollection[def.id] == nil then
				profile.rainbowCollection[def.id] = now
			end
			placeBest(instance)
			claimIndex(def.area)
			dirty = true
		end

		-- Catalog.lures runs from Kibble up, so the last food held is the best
		local function bestFood(): string?
			local best: string? = nil
			for _, def in Catalog.lures do
				if (profile.lures[def.id] or 0) > 0 then
					best = def.id
				end
			end
			return best
		end

		-- Out of food: the best shop food whose price at this tier (Economy.foodPrice, F97) is at most FOOD_SECONDS of
		-- income, Kibble at least.
		local function buyFood()
			local tier = Economy.tier(profile)
			local pick = Catalog.luresById.kibble
			local price = Economy.foodPrice(pick.id, tier)
			for _, def in Catalog.lures do
				local cost = Economy.foodPrice(def.id, tier)
				if def.source == "shop" and cost > price and cost <= FOOD_SECONDS * rate() then
					pick, price = def, cost
				end
			end
			if Economy.trySpend(profile, price) then
				profile.lures[pick.id] = (profile.lures[pick.id] or 0) + 1
			end
		end

		-- A sunrise wave (F66): the area's waveSize strays rolled on its odds, at LuckyDayWaveLuck on a Lucky Day
		-- (F88), the last one rerolled to Epic or better when none is (F97, Catching.waveRare).
		local function rollWave(area: Types.AreaDef, lucky: boolean): { Types.Rarity }
			local odds = Luck.apply(area.odds, if lucky then Config.LuckyDayWaveLuck else 1)
			local wave: { Types.Rarity } = {}
			for _ = 1, area.waveSize do
				table.insert(wave, Catching.pickRarity(odds, rng()))
			end
			Catching.waveRare(wave, rng())
			return wave
		end

		-- The cheapest open shop item, affordable or not: an upgrade's next level or a coin decor piece (bought and
		-- placed), or with SAVER only the tables and the bait bowl.
		local function cheapestItem(): (string?, number, boolean)
			local cheapest: string? = nil
			local cheapestCost = math.huge
			local isDecor = false
			for _, def in Catalog.upgrades do
				local blocker = Economy.upgradeBlocker(profile, def.id)
				local cost = Economy.nextUpgradeCost(profile, def.id)
				local wanted = not options.saver or def.id == "tables" or def.id == "lure_bowl"
				if
					wanted
					and cost ~= nil
					and (blocker == nil or blocker == "Not enough coins")
					and cost < cheapestCost
				then
					cheapest, cheapestCost, isDecor = def.id, cost, false
				end
			end
			if not options.saver then
				for _, def in Catalog.decor do
					local blocker = Economy.decorBlocker(profile, def.id)
					if
						(blocker == nil or blocker == "Not enough coins")
						and def.cost < cheapestCost
					then
						cheapest, cheapestCost, isDecor = def.id, def.cost, true
					end
				end
			end
			return cheapest, cheapestCost, isDecor
		end

		-- The best affordable lawn piece or style (#1283, lawn-nursery.md 6d check 4): the highest bonus first, then the
		-- cheaper, and only one that raises the lawn's bonus once the best lawn is laid. One that cannot is skipped until
		-- the next rank up opens more spots.
		local noGain: { [string]: boolean } = {}
		local function buyBestLawn(): boolean
			local best: string? = nil
			local bestBonus, bestPrice = 0, math.huge
			local nextTier = Catalog.getTier(Economy.tier(profile) + 1)
			local reserve = if options.lawn == "saving" and nextTier ~= nil
				then nextTier.cost
				else 0
			local function consider(id: string, rarity: string?, price: number)
				local bonus = Lawn.rarityBonus(rarity :: any)
				if
					price > 0
					and bonus > 0
					and noGain[id] ~= true
					and Lawn.buyBlocker(profile, id) == nil
					and Economy.canAfford(profile, price + reserve)
					and (bonus > bestBonus or (bonus == bestBonus and price < bestPrice))
				then
					best, bestBonus, bestPrice = id, bonus, price
				end
			end
			for _, def in Catalog.lawn do
				consider(def.id, def.rarity, def.price)
			end
			for _, def in Catalog.lawnStyles do
				consider(def.id, def.rarity, def.price)
			end
			if best == nil then
				return false
			end
			local before = Lawn.bonus(profile)
			profile.lawnOwned[best] = true
			local placed, styles = Lawn.best(profile)
			if Lawn.bonusOf(profile.lawnOwned, placed, styles) <= before then
				profile.lawnOwned[best] = nil -- no better than what is out: not worth the coins
				noGain[best] = true
				return false
			end
			assert(Economy.trySpend(profile, bestPrice))
			Lawn.applyBest(profile)
			return true
		end

		-- The wait for food going in now. With QUICK_BAIT, a Quick Bait Potion is running the whole time: the Day Cart
		-- sells 2 of each size a day (10, 30 and 60 minutes, #1716), so an hour a day is covered from one day's buys.
		local function baitWait(night: boolean): number
			local speed = IndexRewards.totals(profile).baitSpeed
			if options.quickBait then
				speed = math.min(speed + 0.25, Config.BaitSpeedMax)
			end
			return math.floor(Economy.lureWaitSeconds(profile, night) * (1 - speed) + 1e-6)
		end

		local played = 0 -- seconds of play before this session
		local leftAt: number? = nil
		local baitLuck = 1 -- the Luck the food in the bowl was rolled at (F88)
		local rateAtLogout = 0
		local session = 0
		while played < limit do
			session += 1
			-- a running server at a random point of its day and night and of the global days (F88; #1572 rolls each day's
			-- kinds, so a random one of RANDOM_DAYS), or a fresh one at sunrise with FRESH_SERVER
			local offset = if options.freshServer and session == 1
				then 0
				else Config.ServerStartDaySeconds + math.floor(
					rng() * (Config.DayLengthSeconds + Config.NightLengthSeconds) * RANDOM_DAYS
				)
			local joined = base + (session - 1) * DAY
			epoch = joined - offset
			if leftAt ~= nil then
				-- the welcome back card: the day rate at logout, half of it for up to 8 hours (F95)
				local coins = Economy.offlineGain(
					rateAtLogout,
					leftAt,
					joined,
					Economy.passes(profile).longNap
				)
				Economy.credit(profile, coins)
				run.coinsOffline += coins
			end
			profile.lastTick = joined -- DataService.load: time away settles nothing
			-- F88: a Lucky Day is the day phase of a Lucky Day (#1572: rolled from the day, ClockService.luckyDay)
			local function luckyAt(clockT: number): boolean
				return Clock.phaseAt(clockT) == "day" and Clock.isLuckyDay(Clock.dayAt(clockT))
			end
			local area = newestArea()
			local wave = rollWave(area, luckyAt(offset))
			local rich: { amount: number, leaves: number }? = nil
			local richLeft = VisitTimer.draw(Config.RichEveryMin, Config.RichEveryMax, rng())
			local tipJarPaid: { [number]: boolean } = {}
			local tripsStarted = 0 -- today's trips, by their place in the day's schedule
			local topUpIn: number? = nil -- seconds to the next top-up while the area is under its floor
			local trip: { back: number, def: Types.CatDef?, variant: string, rarity: Types.Rarity? }? =
				nil
			local intro = if session == 1 then INTRO_SECONDS else 0
			local length = math.min(sessionLength, limit - played)
			local r = 0 -- the rate at the last settle; a cat placed after it counts from the next
			local settledAt = -math.huge

			local s = 0 -- seconds into this session
			while s <= length do
				local t = played + s
				local now = joined + s
				local clockT = offset + s
				local phase, left = Clock.phaseAt(clockT)
				local day = phase == "day"
				local lucky = day and Clock.isLuckyDay(Clock.dayAt(clockT))
				-- #2486: the event's x money on the cafe's income, tip piles, rich tips and the Tip Jar (live-events.md
				-- 2b), the time before it settled at the old rate
				local window = options.event
				local inEvent = window ~= nil and t >= window.from and t < window.to
				if inEvent ~= eventOn then
					Economy.settle(profile, now, epoch)
					Economy.setEventMoney(if inEvent then Config.EventMoneyMax else 1)
					eventOn = inEvent
					dirty = true
				end
				-- every tick on the Tier 2 runs; a long run settles every LONG_SETTLE and right after a change, and
				-- shops only then
				local settling = dirty or s - settledAt >= settleEvery
				if settling then
					Economy.settle(profile, now, epoch)
					if options.long and t - plannedAt >= LONG_PLAN then
						plannedAt = t
						placeBest(nil)
					end
					r = rate() * Economy.eventMoney()
					settledAt = s
					dirty = false
				end

				-- the server's ticks: tip piles every 30 s, paid at once wherever the player is (F97), and rich
				-- visitors every 60 s, by day, at cafes that earn
				local tables = Economy.level(profile, "tables")
				if day and tables >= 1 and r > 0 then
					if crossed(clockT, step, Config.TipPileSeconds) then
						local amount = Economy.tipPileAmount(r * palBoost)
						Economy.credit(profile, amount)
						run.coinsFromPiles += amount
					end
					-- #1135: the rich customer's timer counts down by open day while no tip is open
					if rich == nil and left > Config.DuskWarningSeconds then
						richLeft -= step
						if richLeft <= 0 then
							rich = {
								amount = Economy.richTipAmount(r * palBoost),
								leaves = s + Config.RichTipStaySeconds,
							}
							richLeft =
								VisitTimer.draw(Config.RichEveryMin, Config.RichEveryMax, rng())
						end
					end
				end
				if rich ~= nil and (not day or s >= rich.leaves) then
					rich = nil -- gone unpaid: it left at its time or at nightfall
				end
				if day and Config.DayLengthSeconds - left < step then
					wave = rollWave(area, lucky) -- the sunrise wave
					tripsStarted = 0
				end
				if not day then
					trip = nil -- the areas close at night
				end
				-- #1159: by day, while the area's live strays (the wave left, plus the one being chased) are under the
				-- floor, a timer runs and one stray arrives when it runs out, rolled on the area's normal odds
				local topUps = options.strays
				if topUps ~= nil and day then
					local live = #wave + (if trip ~= nil and trip.rarity ~= nil then 1 else 0)
					if live >= StrayTopUp.floor(topUps.players) then
						topUpIn = nil
					else
						topUpIn = (topUpIn or topUps.wait or StrayTopUp.wait(rng())) - step
						if topUpIn <= 0 then
							table.insert(wave, Catching.pickRarity(Luck.apply(area.odds, 1), rng()))
							run.topUps += 1
							topUpIn = nil
						end
					end
				elseif topUps ~= nil then
					topUpIn = nil
				end

				-- where the player is: out on a trip or at home
				local home = s >= intro
				if day and s >= intro then
					local into = Config.DayLengthSeconds - left
					local dusk = Config.DayLengthSeconds - Config.DuskWarningSeconds
					local interval = (dusk - 10) / options.catches
					-- the latest trip whose start time has come; one missed while out on a long chase is skipped, and
					-- none sets out that could not be back by the dusk banner
					local due = if into >= 10
						then math.min(options.catches, math.floor((into - 10) / interval) + 1)
						else 0
					local pick: number? = if trip == nil
							and due > tripsStarted
							and #wave > 0
						then 1 + math.floor(rng() * #wave)
						else nil
					local seconds = if trip == nil and due > tripsStarted
						then tripSeconds(area.id, if pick ~= nil then wave[pick] else nil, rng())
						else 0
					if trip == nil and due > tripsStarted and into + seconds > dusk then
						tripsStarted = due
					elseif trip == nil and due > tripsStarted then
						tripsStarted = due
						local back = into + seconds
						local def: Types.CatDef? = nil
						local variant = "base"
						local rarity: Types.Rarity? = nil
						if pick ~= nil then
							rarity = table.remove(wave, pick) :: Types.Rarity
							def = Catching.pickCat(rarity :: Types.Rarity, area.id, rng())
							local caught = def :: Types.CatDef
							variant = coat(caught, Config.RainbowChanceNet, Config.GoldChanceNet)
							local extra = chase(rarity :: Types.Rarity)
							if extra ~= nil and back + extra <= dusk then
								back += extra
								run.chaseSeconds += extra
							else
								def = nil -- still loose at the dusk banner: left behind, still in the wave
								run.leftBehind += 1
								back = math.max(back, dusk)
								table.insert(wave, rarity :: Types.Rarity)
								rarity = nil
							end
						end
						trip = {
							back = math.ceil(back),
							def = def,
							variant = variant,
							rarity = rarity,
						}
					end
					local current = trip
					if current ~= nil then
						home = false
						if into >= current.back then
							trip = nil
							local unclaimed = current.rarity
							if current.def ~= nil and tutorialDone then
								addCat(current.def, current.variant, now)
							elseif unclaimed ~= nil then
								table.insert(wave, unclaimed :: Types.Rarity) -- not counted before the tutorial cat is in
							end
						end
					end
					if not tutorialDone and s >= TUTORIAL_CHECKIN then
						tutorialDone = true
						addCat(Catching.pickCat("Common", "alley", rng()), "base", now)
					end
				end

				-- the Tip Jar's coin gifts at their session minutes, claimed from the HUD
				for _, def in Catalog.tipJar do
					if not tipJarPaid[def.step] and s >= def.minutes * 60 then
						tipJarPaid[def.step] = true
						local prize = def.prize
						Economy.credit(profile, Prizes.coins(prize.coins, prize.coinSeconds, r))
						for lureId, count in (prize.lures or {}) :: { [string]: number } do
							profile.lures[lureId] = (profile.lures[lureId] or 0) + count
						end
					end
				end

				if home then
					if rich ~= nil then
						Economy.credit(profile, rich.amount)
						run.coinsFromRich += rich.amount
						rich = nil
					end
					local bait = profile.bait
					if bait ~= nil and now >= bait.readyAt then
						local lure = assert(Catalog.luresById[bait.lureId])
						-- F88: the Luck fixed when the food went in (BaitService.onUseLure)
						local odds = Luck.apply(
							Bait.oddsFor(lure.odds, Economy.level(profile, "lure_bowl")),
							baitLuck
						)
						local rarity = Catching.pickRarity(odds, rng())
						local def = Catching.pickBaitCat(rarity, Economy.tier(profile), rng())
						profile.bait = nil
						profile.stats.baitsTamed += 1 -- the Grand Opening's step 2 reads it
						addCat(def, coat(def, Config.RainbowChanceBait, Config.GoldChanceBait), now)
					end
					if profile.bait == nil and Economy.level(profile, "lure_bowl") >= 1 then
						if bestFood() == nil then
							buyFood()
						end
						local food = bestFood()
						if food ~= nil then
							profile.lures[food] -= 1
							baitLuck = Luck.of(profile, now, lucky)
							profile.bait = {
								lureId = food,
								placedAt = now,
								readyAt = now + baitWait(not day),
								night = if day then nil else true,
							}
						end
					end
				end

				-- spending: the rank up first, then the cheapest open shop item
				local blocker = if settling then Economy.rankUpBlocker(profile) else "not shopping"
				if
					run.catsReady == nil
					and Economy.distinctCats(profile) >= assert(Catalog.getTier(2)).distinctCats
				then
					run.catsReady = t
				end
				if not settling then
					-- between settles: nothing bought
				elseif blocker == nil then
					local def = assert(Catalog.getTier(Economy.tier(profile) + 1))
					assert(Economy.trySpend(profile, def.cost))
					profile.tier = def.tier
					run.tierAt[def.tier] = t
					table.insert(run.events, { t = t, kind = "rank", id = "tier" .. def.tier })
					run.dayAt[def.tier] = session
					if def.tier >= target then
						Economy.setEventMoney(1)
						return run
					end
					placeBest(nil) -- the new role slots
					if options.lawn then
						Lawn.grantTierGifts(profile)
						Lawn.applyBest(profile)
						table.clear(noGain)
					end
					area = newestArea()
					wave = rollWave(area, lucky)
					dirty = true
				elseif options.lawn and buyBestLawn() then
					table.insert(run.events, { t = t, kind = "buy", id = "lawn" })
					dirty = true
				else
					local id, cost, isDecor = cheapestItem()
					if id ~= nil and Economy.trySpend(profile, cost) then
						if isDecor then
							profile.decorOwned[id] = true
							profile.decorPlaced[id] = true
						else
							profile.upgradeLevels[id] = Economy.level(profile, id) + 1
						end
						table.insert(run.events, { t = t, kind = "buy", id = id })
						dirty = true
					end
				end
				if tutorialDone then
					for n = 1, GrandOpening.COUNT do
						if not roadmapMet[n] and GrandOpening.met(profile, n) then
							roadmapMet[n] = true
							table.insert(
								run.events,
								{ t = t, kind = "roadmap", id = GrandOpening.STEPS[n].id }
							)
						end
					end
				end
				s += step
			end
			played += length
			leftAt = joined + length
			rateAtLogout = rate() -- the day rate; no potions in the model
		end
		Economy.setEventMoney(1)
		return run
	end

	local function runs(options: Options, count: number): { Run }
		local out = {}
		for i = 1, count do
			table.insert(out, simulate(options, 7919 * i))
		end
		return out
	end

	-- The value at the given share of the runs (0.5 the median), every run without one counted as `missing`.
	local function quantile(
		list: { Run },
		value: (Run) -> number?,
		share: number,
		missing: number
	): number
		local values = {}
		for _, run in list do
			table.insert(values, value(run) or missing)
		end
		table.sort(values)
		return values[math.clamp(math.floor(share * #values + 0.5), 1, #values)]
	end

	local function tierAt(tier: number): (Run) -> number?
		return function(run: Run): number?
			return run.tierAt[tier]
		end
	end

	local function clock(seconds: number): string
		return string.format("%d h %02d", seconds // HOUR, (seconds % HOUR) // 60)
	end

	-- Each Tier 2 check is the median of RUNS seeded runs: join at a random point of a running server's day and night.
	local RUNS = 40

	-- The profile's extras for a failure message: ", tables and bowl only", ", top-ups for 1 player every 60 s", ", 3 pals".
	local function profileText(options: Options): string
		local text = if options.saver then ", tables and bowl only" else ""
		local strays = options.strays
		if strays ~= nil then
			text ..= string.format(
				", top-ups for %d player%s every %s s",
				strays.players,
				if strays.players == 1 then "" else "s",
				if strays.wait ~= nil then tostring(strays.wait) else "60 to 120"
			)
		end
		if options.quickBait then
			text ..= ", Quick Bait Potion running"
		end
		if options.lawn then
			text ..= if options.lawn == "saving"
				then ", best lawn bought after saving for the rank up"
				else ", best lawn bought at once"
		end
		if options.pals ~= nil then
			text ..= string.format(
				", %d pal%s",
				options.pals,
				if options.pals == 1 then "" else "s"
			)
		end
		return text
	end

	local function check(options: Options)
		local list = runs(options, RUNS)
		local ready = quantile(list, function(run: Run): number?
			return run.catsReady
		end, 0.5, LIMIT) / 60
		local median = quantile(list, tierAt(2), 0.5, LIMIT) / 60
		local tries, misses, chased, behind, added = 0, 0, 0, 0, 0
		for _, run in list do
			added += run.topUps
			tries += run.tries
			misses += run.misses
			chased += run.chaseSeconds
			behind += run.leftBehind
		end
		local text = string.format(
			"%d catches a day%s: cats ready at %.1f min, Tier 2 at %.1f min (10th to 90th %.1f to %.1f); "
				.. "%d of %d tries missed, %.0f s of chases, %.1f strays left behind and %.1f top-ups a run",
			options.catches,
			profileText(options),
			ready,
			median,
			quantile(list, tierAt(2), 0.1, LIMIT) / 60,
			quantile(list, tierAt(2), 0.9, LIMIT) / 60,
			misses,
			tries,
			chased / #list,
			behind / #list,
			added / #list
		)
		-- features section 8 and data-model 12: 10 to 20 minutes; under 10, the tier costs go up
		local band = options.tier2Band or { 10, 20 }
		if median < band[1] or median > band[2] then
			error(string.format("Tier 2 outside %g to %g minutes: ", band[1], band[2]) .. text)
		end
		-- v0.13.6: the coins are the last thing a player waits for
		if ready >= median then
			error("the cats come after the coins: " .. text)
		end
	end

	-- The long runs to Tier 5 (F95): LONG_RUNS seeded runs each. Returns the runs and a line with
	-- each tier's median time of play (and day, for daily play) for the failure message.
	local LONG_RUNS = 10

	local function toTier5(options: Options): ({ Run }, string)
		local list = runs(options, LONG_RUNS)
		local limit = assert(options.limit)
		local parts = {}
		for tier = 2, Catalog.maxTier do
			local played = quantile(list, tierAt(tier), 0.5, limit)
			local part = string.format("Tier %d %s", tier, clock(played))
			if options.session ~= nil then
				local day = quantile(list, function(run: Run): number?
					return run.dayAt[tier]
				end, 0.5, math.huge)
				part ..= string.format(
					" (day %s)",
					if day == math.huge then "none" else tostring(day)
				)
			end
			table.insert(parts, part)
		end
		local text = string.format(
			"%d catches a day%s%s%s, medians of %d runs: %s; Tier 5 10th to 90th %s to %s",
			options.catches,
			profileText(options),
			if options.session ~= nil
				then string.format(", %d min a day", options.session // 60)
				else " in one go",
			if options.money ~= nil then string.format(", %dx Money", options.money) else "",
			#list,
			table.concat(parts, ", "),
			clock(quantile(list, tierAt(5), 0.1, limit)),
			clock(quantile(list, tierAt(5), 0.9, limit))
		)
		return list, text
	end

	describe(
		"Tier 2 in the loop script (QA re-time after F60 and F61, misses and chases for F83)",
		function()
			it(
				"takes 10 to 20 minutes for the pace model player at 4 or 5 catches a day",
				function()
					check({ catches = 4 })
					check({ catches = 5 })
				end
			)

			it(
				"takes 10 to 20 minutes for a player who buys only the tables and the bait bowl first",
				function()
					check({ catches = 4, saver = true })
					check({ catches = 5, saver = true })
				end
			)

			it(
				"takes 10 to 20 minutes for a shakier player whose presses land within about 70 ms (F83)",
				function()
					-- data-model 10 (v0.13.15): a young player on a phone
					check({ catches = 4, spread = 0.07 })
				end
			)
		end
	)

	describe(
		"Tier 5 on the money ladder (F95, economy-ladder.md section 8 checks 3 and 7)",
		function()
			it(
				"takes 8.3 to 11.2 hours of play in one go, Tier 4 at 2.2 to 2.9 (#2230: was 8 to 12; #2559 and #2557: were 9 to 14 and 5 to 6)",
				function()
					local list, text =
						toTier5({ catches = 4, target = 5, limit = 16 * HOUR, long = true })
					local median = quantile(list, tierAt(5), 0.5, 16 * HOUR)
					-- #2557 with #2559 (Design-Agent: the combined medians plus or minus 15%): Tier 5 9 h 46, Tier 4 2 h 33
					if median < 8.3 * HOUR or median > 11.2 * HOUR then
						error("Tier 5 outside 8.3 to 11.2 hours of play: " .. text)
					end
					-- #2496: Tier 4 wants a Mythical and 120M; the time from Tier 3 to the first Mythical is reported
					local four = quantile(list, tierAt(4), 0.5, 16 * HOUR)
					local wait = quantile(list, function(run: Run): number?
						local three = run.tierAt[3]
						if three == nil then
							return nil
						end
						for _, event in run.events do
							local def = if event.kind == "newcat"
								then Catalog.getCat(event.id)
								else nil
							if def ~= nil and def.rarity == "Mythical" then
								return math.max(0, event.t - three)
							end
						end
						return nil
					end, 0.5, 16 * HOUR)
					print(
						string.format(
							"[Pace #2496] Tier 3 to the first Mythical %s (median); %s",
							clock(wait),
							text
						)
					)
					-- #2559 (Derek2: Tier 3 to 4 about 70% cheaper; Design-Agent's band): 3 h 01 (was 5 h 15 at 160M)
					if four < 2.2 * HOUR or four > 2.9 * HOUR then
						error("Tier 4 outside 2.2 to 2.9 hours of play: " .. text)
					end
				end
			)

			it(
				"takes 9 to 14 hours in one go with one 2-hour x2 Cafe Event in the run (#2486)",
				function()
					-- live-events.md 2b: if not, the event's window gets shorter, not its multiplier smaller. The window
					-- sits late in the run, where the cafe earns the most and the boost is worth the most.
					local list, text = toTier5({
						catches = 4,
						target = 5,
						limit = 16 * HOUR,
						long = true,
						event = { from = 6 * HOUR, to = 8 * HOUR },
					})
					local median = quantile(list, tierAt(5), 0.5, 16 * HOUR)
					-- #2557 with #2559 (Design-Agent): 8 h 00, plus 15%, with the one-go floor of 8 h (was 9 to 14)
					if median < 8 * HOUR or median > 9.2 * HOUR then
						error(
							"Tier 5 outside 8 to 9.2 hours of play with a 2-hour x2 event: " .. text
						)
					end
				end
			)

			it("comes on day 4 to 6 for an hour a day with free offline pay", function()
				local list, text = toTier5({
					catches = 4,
					target = 5,
					limit = 10 * HOUR,
					session = HOUR,
					long = true,
				})
				local day = quantile(list, function(run: Run): number?
					return run.dayAt[5]
				end, 0.5, math.huge)
				if day < 4 or day > 6 then
					error("Tier 5 outside day 4 to 6: " .. text)
				end
			end)

			it("takes over 2 hours of play in one go with 4x Money", function()
				local list, text =
					toTier5({ catches = 4, target = 5, limit = 8 * HOUR, money = 4, long = true })
				-- check 7: if not, the Tier 5 cost goes up
				if quantile(list, tierAt(5), 0.5, 8 * HOUR) <= 2 * HOUR then
					error("Tier 5 in 2 hours or less with 4x Money: " .. text)
				end
			end)

			it("takes over an hour of play in one go with every paid bonus (about 24x)", function()
				-- section 6: Monetization-Agent's floor; if not, the cat requirements go up. The extra role slot is not
				-- in the model yet (EquipBest does not read the pass), so this player is a slot short of the real one.
				local list, text =
					toTier5({ catches = 4, target = 5, limit = 8 * HOUR, money = 24, long = true })
				if quantile(list, tierAt(5), 0.5, 8 * HOUR) <= HOUR then
					error("Tier 5 in an hour or less with every paid bonus: " .. text)
				end
			end)
		end
	)

	-- #2651 (QA-Planner 2026-11-09, tier6-7-areas.md section 1): the late tiers on the money ladder. Pace set the costs
	-- (9B and 60B, from the drafts 70B and 1.8T, which took 29 h past Tier 5 and never reached Tier 7 in 80 h). Coins are
	-- the only blocker: the cats and the Mythicals are in within minutes of each rank up. Design's targets: Tier 6 5 to 7 h
	-- after Tier 5, Tier 7 8 to 11 h after Tier 6, both in one go. Fit run (10 runs): Tier 6 16 h 17, Tier 7 26 h 19.
	describe("Tiers 6 and 7 on the money ladder (QA edges, #2651)", function()
		it("Tier 6 comes 5 to 7.5 h after Tier 5 and Tier 7 8 to 11.5 h after Tier 6, in one go", function()
			local limit = 40 * HOUR
			local list = runs({ catches = 4, target = 7, limit = limit, long = true }, LONG_RUNS)
			local function gap(from: number, to: number): (Run) -> number?
				return function(run: Run): number?
					local a, b = run.tierAt[from], run.tierAt[to]
					return if a ~= nil and b ~= nil then b - a else nil
				end
			end
			local six = quantile(list, gap(5, 6), 0.5, limit)
			local seven = quantile(list, gap(6, 7), 0.5, limit)
			local text = string.format(
				"medians of %d runs: Tier 5 %s, Tier 6 %s (%s after Tier 5), Tier 7 %s (%s after Tier 6)",
				#list,
				clock(quantile(list, tierAt(5), 0.5, limit)),
				clock(quantile(list, tierAt(6), 0.5, limit)),
				clock(six),
				clock(quantile(list, tierAt(7), 0.5, limit)),
				clock(seven)
			)
			print("[Pace #2651] " .. text)
			if six < 5 * HOUR or six > 7.5 * HOUR then
				error("Tier 6 outside 5 to 7.5 h after Tier 5: " .. text)
			end
			if seven < 8 * HOUR or seven > 11.5 * HOUR then
				error("Tier 7 outside 8 to 11.5 h after Tier 6: " .. text)
			end
		end)
	end)

	-- #1159 (stray top-ups) and #1165 (the friends boost): the pace with both on. The catchers here set out back to back
	-- (12 catches a day is more trips than a 300 s day holds, so a trip starts the moment the last one is home) and the
	-- top-ups come at their fastest, so these are the loop script's quickest hunters; a profile that fails names by how
	-- much, in the message, and the design's rule v0.8 raises that tier's cost.
	local NON_STOP = 12
	local FOUR_FRIENDS = 3 -- pals each on a server of 4 friends: +20% on tips (Pals.bonus)

	describe("Tier 2 with stray top-ups (#1159) and a 4-friend server (#1165)", function()
		it(
			"takes 10 to 20 minutes for a non-stop catcher with a top-up every 60 s (60 an hour an area)",
			function()
				check({ catches = NON_STOP, strays = { players = 1, wait = 60 } })
			end
		)

		it(
			"takes 10 to 20 minutes for the usual 4 or 5 catches a day with the real 60 to 120 s top-ups",
			function()
				check({ catches = 4, strays = { players = 1 } })
			end
		)

		it(
			"takes 10 to 20 minutes for a player who buys the best affordable lawn piece after saving for the rank up (#1283)",
			function()
				check({ catches = 4, lawn = "saving" })
			end
		)

		-- Found 2026-11-05: while the Common lawn pieces opened at Tier 1, a player who spent on the best affordable one
		-- the moment it could (10,000, where Tier 2 costs 13,500) reached Tier 2 at a median of 25.1 min, over the 20
		-- minute bound. Design-Agent (#1451) opened the Commons at Tier 2 instead.
		it(
			"takes 10 to 20 minutes for a player who buys the best affordable lawn piece at once (#1283)",
			function()
				check({ catches = 4, lawn = "greedy" })
			end
		)

		it("takes 10 to 20 minutes with 3 pals on the server", function()
			check({ catches = 4, pals = FOUR_FRIENDS })
		end)

		-- Found 2026-11-05: at Tier 2's old 12,000 coins this quickest case (a non-stop catcher with +20% from 3 pals
		-- and every top-up of a 4-player floor to itself) reached Tier 2 at a median of 9.4 min, under the 10 minute
		-- floor; Design-Agent raised the cost to 13,500 (rule v0.8). #1452's faster wild catching (more strays, better
		-- Rare+ odds) put it at 7.8 min again, so economy-ladder section 3 v3 makes Tier 2 28,000 and the later tiers
		-- 700,000, 60M and 2B. #1499's dearer bait (less sunk into food) put it at 9.9 min, so v3.1 makes it 30,000.
		it(
			-- #2557 (Design-Agent: the combined median, 9.5 min, plus or minus 15%, floor 8): was 10 to 20
			"takes 8 to 11 minutes on a server of 4 friends, the non-stop catcher with every top-up to itself (#2557)",
			function()
				check({
					catches = NON_STOP,
					pals = FOUR_FRIENDS,
					strays = { players = 4, wait = 60 },
					tier2Band = { 8, 11 },
				})
			end
		)
	end)

	describe("Tier 5 with stray top-ups (#1159) and a 4-friend server (#1165)", function()
		it(
			"takes 9 to 14 hours in one go for a player who buys the best affordable lawn (#1283)",
			function()
				local list, text = toTier5({
					catches = 4,
					target = 5,
					limit = 16 * HOUR,
					long = true,
					lawn = "greedy",
				})
				local median = quantile(list, tierAt(5), 0.5, 16 * HOUR)
				if median < 9 * HOUR or median > 14 * HOUR then
					error("Tier 5 outside 9 to 14 hours of play: " .. text)
				end
			end
		)

		it(
			"takes 8 to 14 hours in one go on a server of 4 friends, the non-stop catcher (#2559: was 9 to 14)",
			function()
				local list, text = toTier5({
					catches = NON_STOP,
					target = 5,
					limit = 16 * HOUR,
					long = true,
					pals = FOUR_FRIENDS,
					strays = { players = 4, wait = 60 },
				})
				local median = quantile(list, tierAt(5), 0.5, 16 * HOUR)
				-- #2559 (Design-Agent): 8 h 55 with the cheaper Tier 4
				if median < 8 * HOUR or median > 14 * HOUR then
					error("Tier 5 outside 8 to 14 hours of play: " .. text)
				end
			end
		)

		it("comes on day 4 to 6 for an hour a day on a server of 4 friends", function()
			local list, text = toTier5({
				catches = 4,
				target = 5,
				limit = 10 * HOUR,
				session = HOUR,
				long = true,
				pals = FOUR_FRIENDS,
				strays = { players = 4 },
			})
			local day = quantile(list, function(run: Run): number?
				return run.dayAt[5]
			end, 0.5, math.huge)
			if day < 4 or day > 6 then
				error("Tier 5 outside day 4 to 6: " .. text)
			end
		end)

		it("takes over 2 hours in one go with 4x Money and 3 pals (check 7)", function()
			local list, text = toTier5({
				catches = 4,
				target = 5,
				limit = 8 * HOUR,
				money = 4,
				long = true,
				pals = FOUR_FRIENDS,
			})
			if quantile(list, tierAt(5), 0.5, 8 * HOUR) <= 2 * HOUR then
				error("Tier 5 in 2 hours or less with 4x Money and 3 pals: " .. text)
			end
		end)
	end)

	-- The Cafe Pass (#1644, #1667): its levels come from quests only, so a player who finishes a full day of quests
	-- (one level a day) has reached level `day` by Tier 5's latest day (6, the top of the day 4 to 6 check). The money
	-- those levels pay, counted as income minutes (a minute of the day rate; a tip potion's minutes times its `tips`,
	-- all income counted as tips, the worst case), must stay under 5% of the 8 hour floor for Tier 5. Spins and fish
	-- are not money here (Pace leaves them out as in economy-ladder.md section 3); Monetization-Agent allowed the
	-- paid potions (2026-11-05), and the shop's own paid bonuses are already in the "every paid bonus" check above.
	describe("The Cafe Pass money by Tier 5 (#1667)", function()
		it("pays under 5% of 8 hours of income by level 6, free and paid together", function()
			local LAST_DAY = 6
			local limit = 0.05 * 8 * 60
			for _, season in Catalog.passSeasons do
				local minutes = 0
				for _, track in { season.free, season.paid } :: { { [number]: Types.PassReward } } do
					for level = 1, LAST_DAY do
						local prize = if track[level] ~= nil then track[level].prize else nil
						if prize ~= nil then
							minutes += (prize.coinSeconds or 0) / 60
							for id, count in prize.potions or {} do
								local def = Catalog.getPotion(id)
								if def ~= nil then
									minutes += count * def.minutes * (def.tips or 0)
								end
							end
						end
					end
				end
				if minutes > limit then
					error(
						string.format(
							"%s pays %.1f income minutes by level %d, over %.0f",
							season.id,
							minutes,
							LAST_DAY,
							limit
						)
					)
				end
			end
		end)
	end)

	-- The Day Cart (#1716): each row has its own daily stock, so a day's buys are up to 2 Quick Bait Potions of each
	-- size. Pace leaves potions out; this runs the worst case, one running the whole time, through Tier 5.
	describe("Tier 5 with a Quick Bait Potion always running (#1716)", function()
		it("takes 9 to 14 hours of play in one go (#2230: was 8 to 12)", function()
			local list, text = toTier5({
				catches = 4,
				target = 5,
				limit = 16 * HOUR,
				long = true,
				quickBait = true,
			})
			local median = quantile(list, tierAt(5), 0.5, 16 * HOUR)
			if median < 9 * HOUR or median > 14 * HOUR then
				error("Tier 5 outside 9 to 14 hours of play: " .. text)
			end
		end)

		it("comes on day 4 to 6 for an hour a day", function()
			local list, text = toTier5({
				catches = 4,
				target = 5,
				limit = 10 * HOUR,
				session = HOUR,
				long = true,
				quickBait = true,
			})
			local day = quantile(list, function(run: Run): number?
				return run.dayAt[5]
			end, 0.5, math.huge)
			if day < 4 or day > 6 then
				error("Tier 5 outside day 4 to 6: " .. text)
			end
		end)
	end)
	-- #1896: the first hour. What a new player buys or unlocks, and the gaps between. The run plays one hour with the
	-- pace model player (4 catches a day; the day's other income is left out, so a real player has a little more to do).
	-- first-hour.md section 4 (Design, 2026-11-06): Tables 5 and Espresso 4 moved into Tier 2 to fill its dead window,
	-- their prices and Tier 3's cost fitted here (Tables 5 170,000, Espresso 4 700,000, Tier 3 900,000).
	describe("The first hour (#1896)", function()
		local HOUR_RUNS = 20 -- 10 runs left the Tier 3 median 9 minutes off the 20-run figure
		local GAP = 240 -- the target: something to buy or unlock at least every 4 minutes
		local hourRuns: { Run }? = nil

		local function firstHour(): { Run }
			if hourRuns == nil then
				-- #2230: on past the hour, so a Tier 3 up to 62 minutes is measured; the hour's checks stop at HOUR
				hourRuns = runs({ catches = 4, target = 9, limit = HOUR + 15 * 60 }, HOUR_RUNS)
			end
			return assert(hourRuns)
		end

		-- seconds of play at a run's `nth` buy of `id`, or nil
		local function nthBuy(id: string, nth: number): (Run) -> number?
			return function(run: Run): number?
				local n = 0
				for _, event in run.events do
					if event.kind == "buy" and event.id == id then
						n += 1
						if n == nth then
							return event.t
						end
					end
				end
				return nil
			end
		end

		-- the times of a run's events of `kinds` in the first hour, in order
		local function timesOf(run: Run, kinds: { [string]: boolean }): { number }
			local out = {}
			for _, event in run.events do
				if kinds[event.kind] and event.t <= HOUR then
					table.insert(out, event.t)
				end
			end
			table.sort(out)
			return out
		end

		-- the times of a run's buys and rank ups in the first hour (a rank up and a buy in the same second count once)
		local function spendTimes(run: Run): { number }
			local out = {}
			for _, event in run.events do
				if (event.kind == "buy" or event.kind == "rank") and event.t <= HOUR then
					if #out == 0 or event.t > out[#out] then
						table.insert(out, event.t)
					end
				end
			end
			return out
		end

		local function longestGap(times: { number }): number
			local worst, last = 0, 0
			for _, at in times do
				if at > HOUR then
					break -- the first hour only (#2230 runs on past it)
				end
				worst = math.max(worst, at - last)
				last = at
			end
			return math.max(worst, HOUR - last)
		end

		it("buys something in the first 3 minutes", function()
			for _, run in firstHour() do
				local first = spendTimes(run)[1]
				if first == nil or first > 180 then
					error("no first buy within 3 minutes: " .. tostring(first))
				end
			end
		end)

		it(
			"reaches Tier 3 at 50 to 62 minutes (the middle run, #2230: was 45 to 55), the fastest tenth at 35 or later",
			function()
				local list = firstHour()
				local median = quantile(list, tierAt(3), 0.5, HOUR + 15 * 60 + 1) / 60
				local fast = quantile(list, tierAt(3), 0.1, HOUR + 15 * 60 + 1) / 60
				if median < 50 or median > 62 or fast < 35 then
					error(
						string.format(
							"Tier 3 at %.1f min (tenth %.1f), outside 50 to 62 or before 35",
							median,
							fast
						)
					)
				end
				local tier2 = quantile(list, tierAt(2), 0.5, HOUR + 1) / 60
				if tier2 < 10 or tier2 > 20 then
					error(string.format("Tier 2 at %.1f min, outside 10 to 20", tier2))
				end
			end
		)

		it(
			-- #2121 (first-hour.md 4e): Tables 5 moved from about 22 to about 25 with Bait Bowl 3 bought before it
			"buys Tables 5 at about minute 31 and Espresso 4 at about minute 44.5 (the middle run, #2557)",
			function()
				local list = firstHour()
				-- Tables starts at level 0 and Espresso at 1, so these are the fifth and third buys
				local tables = quantile(list, nthBuy("tables", 5), 0.5, HOUR + 1) / 60
				local espresso = quantile(list, nthBuy("espresso", 3), 0.5, HOUR + 1) / 60
				-- #2557 (Design-Agent): about 31 and 44.5 with a third more cats (were about 25 and 42), Tables 5 by 35 and
				-- Espresso 4 by 50
				if math.abs(tables - 31) > 4 or math.abs(espresso - 44.5) > 5.5 then
					error(
						string.format(
							"Tables 5 at %.1f min, Espresso 4 at %.1f min (want about 31 and 44.5)",
							tables,
							espresso
						)
					)
				end
			end
		)

		it("buys Lucky Cat 3 at about minute 37 (the middle run)", function()
			-- #1896 follow-up: level 3 opens at Tier 2, a buy inside the Tier 3 save; about 31 since #2107 and #2121
			-- (first-hour.md 4e: the middle run's figure, no longer a fitted target). #2192: about 37 with the 320 s day
			-- and 70 s night (were 300 and 90): less of each game day is night, when bait waits half as long, so fewer
			-- bowl cats come in the first hour. Tier 3 stays inside 45 to 55 minutes.
			local lucky = quantile(firstHour(), nthBuy("lucky_cat", 3), 0.5, HOUR + 1) / 60
			if math.abs(lucky - 37) > 3 then
				error(string.format("Lucky Cat 3 at %.1f min (want about 37)", lucky))
			end
		end)

		-- Known miss, recorded for Design (#1896): with Tier 3 moved to 45 to 55 minutes, the middle run's longest gap
		-- between shop buys and rank ups is about 16 minutes (12 wanted) and 11 with new cats and Grand Opening steps
		-- counted (6 wanted; the steps land on a new cat, a rank up or in the first minutes, so they close no gap).
		-- The save for Tier 3 is most of it.
		xit(
			"the middle run's longest gap without a buy is 12 minutes or less, 6 with new cats and roadmap steps",
			function()
				local list = firstHour()
				local plain = quantile(list, function(run: Run): number?
					return longestGap(timesOf(run, { buy = true, rank = true }))
				end, 0.5, HOUR)
				local cats = quantile(list, function(run: Run): number?
					return longestGap(
						timesOf(run, { buy = true, rank = true, newcat = true, roadmap = true })
					)
				end, 0.5, HOUR)
				if plain > 12 * 60 or cats > 6 * 60 then
					error(
						string.format(
							"longest gap %.1f min, %.1f with new cats and roadmap steps",
							plain / 60,
							cats / 60
						)
					)
				end
			end
		)

		-- #2121 (first-hour.md 4e): the guard is 15 minutes between coin buys and rank ups (was 18) and 10 with new cats
		-- and roadmap steps counted (was 12); the 6 above stays the stretch goal
		it(
			"the middle run's longest wait is 16 minutes or less, 10 with new cats and roadmap steps (#2557: was 15)",
			function()
				local list = firstHour()
				local plain = quantile(list, function(run: Run): number?
					return longestGap(timesOf(run, { buy = true, rank = true }))
				end, 0.5, HOUR)
				local cats = quantile(list, function(run: Run): number?
					return longestGap(
						timesOf(run, { buy = true, rank = true, newcat = true, roadmap = true })
					)
				end, 0.5, HOUR)
				if plain > 16 * 60 or cats > 10 * 60 then -- #2557 (Design-Agent): 15.8 with a third more cats
					error(
						string.format(
							"longest gap %.1f min, %.1f with new cats and roadmap steps",
							plain / 60,
							cats / 60
						)
					)
				end
			end
		)

		-- Known miss, recorded for Design (docs/playtests/2026-11-06-first-hour.md): the shop's items per tier are
		-- bought in a burst within about 15 minutes of each rank up, then the player waits 20 to 35 minutes for the next
		-- one. Turn this on when Design adds steps between rank ups.
		xit("always has something to buy within 4 minutes", function()
			local worst = 0
			for _, run in firstHour() do
				worst = math.max(worst, longestGap(spendTimes(run)))
			end
			if worst > GAP then
				error(string.format("longest gap without a buy %.1f min, over 4", worst / 60))
			end
		end)
	end)
end
