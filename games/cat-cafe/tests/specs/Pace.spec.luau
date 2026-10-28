--!strict
-- The loop script's Tier 2 in numbers (QA; test plan section 6, data-model 11 and 12, features F60 and F61 "QA
-- re-times Tier 2"). A second by second run of a new player on the real shared code: Economy's income, settle, XP
-- and blockers, the Clock's day and night, the Catalog's prices, odds, first catch rewards, Tip Jar and Index
-- prizes, EquipBest's placements, Catching's picks and CatStats' charm. The player:
-- - joins, watches the 25 s intro, then catches the tutorial Common behind the cafe and checks it in at 75 s;
-- - by day makes CATCHES trips into the Alleyway, each TRIP_SECONDS out and back, a catch per trip while the
--   sunrise wave lasts, and is home between trips and all night (areas closed);
-- - at home collects every tip pile, claims a waiting rich visitor, tames a ready bait cat and puts food in an
--   empty bowl (buying Kibble when out of food); claims Tip Jar coins and the Index `cats3` and `cats6` prizes when
--   due; places the best cats after every new one;
-- - ranks up the moment `rankUpBlocker` allows, otherwise buys the cheapest open shop item it can afford (the
--   data-model 11 pace model's player), or with SAVER only the tables and the bait bowl.
-- Spins, golden fish, crates and rescues are left out, as in the data-model 11 model.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)
	local Catching = require(Shared.Catching)
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local EquipBest = require(Shared.EquipBest)
	local Prizes = require(Shared.Prizes)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local INTRO_SECONDS = 25
	local TUTORIAL_CHECKIN = 75
	local TRIP_SECONDS = 45
	local LIMIT = 3600 -- give up after an hour

	type Options = { catches: number, saver: boolean?, freshServer: boolean? }
	type Run = { tier2: number?, catsReady: number?, coinsFromPiles: number, coinsFromRich: number }

	-- Park and Miller's generator: exact in doubles, so every machine gets the same runs
	local function generator(seed: number): () -> number
		local state = seed
		return function(): number
			state = state * 48271 % 2147483647
			return state / 2147483647
		end
	end

	local function simulate(options: Options, seed: number): Run
		local rng = generator(seed)
		local offset = if options.freshServer
			then 0
			else Config.ServerStartDaySeconds
				+ math.floor(rng() * (Config.DayLengthSeconds + Config.NightLengthSeconds))
		local base = 1000000
		local epoch = base - offset
		local profile: any = ProfileSchema.template(base)
		local alley = assert(Catalog.getArea("alley"))
		local run: Run = { coinsFromPiles = 0, coinsFromRich = 0 }
		local piles: { number } = {}
		local rich: { amount: number, leaves: number }? = nil
		local tutorialDone = false
		local waveLeft = alley.waveSize
		local tipJarPaid: { [number]: boolean } = {}
		local uid = 0

		local function rate(): number
			return Economy.incomePerSecond(profile)
		end

		local function addCat(def: Types.CatDef, variant: string, now: number)
			uid += 1
			local instance = CatStats.newInstance("c" .. uid, def.id, now, CatStats.rollCharm(rng(), rng()))
			instance.variant = variant
			profile.cats[instance.uid] = instance
			if profile.collection[def.id] == nil then
				profile.collection[def.id] = now
				Economy.credit(profile, Catalog.rarities[def.rarity].firstCatchReward)
			end
			EquipBest.apply(profile, EquipBest.plan(profile))
			-- the Alleyway page's first two cards, claimed at once
			local page = profile.indexRewards.alley or {}
			profile.indexRewards.alley = page
			local alleyCats = 0
			for catId in profile.collection do
				local cat = Catalog.getCat(catId)
				if cat ~= nil and cat.area == "alley" then
					alleyCats += 1
				end
			end
			local prizes = assert(Catalog.indexPrizes.alley)
			if alleyCats >= 3 and not page.cats3 then
				page.cats3 = true
				local prize = assert(prizes.cats3)
				Economy.credit(profile, Prizes.coins(prize.coins, prize.coinSeconds, rate()))
			end
			if alleyCats >= 6 and not page.cats6 then
				page.cats6 = true
				for lureId, count in (assert(prizes.cats6).lures or {}) :: { [string]: number } do
					profile.lures[lureId] = (profile.lures[lureId] or 0) + count
				end
			end
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

		for t = 0, LIMIT do
			local now = base + t
			local clockT = offset + t
			local phase, left = Clock.phaseAt(clockT)
			local day = phase == "day"
			Economy.settle(profile, now, epoch)
			local r = rate() -- this second's rate; a cat placed below counts from the next second

			-- the server's ticks: tip piles every 30 s and rich visitors every 60 s, by day, at cafes that earn
			local tables = Economy.level(profile, "tables")
			if day and tables >= 1 and r > 0 then
				if clockT % Config.TipPileSeconds == 0 and #piles < Config.TipPilesMax then
					table.insert(piles, Economy.tipPileAmount(r))
				end
				if
					clockT % Config.RichCheckSeconds == 0
					and rich == nil
					and left > Config.DuskWarningSeconds
					and rng() < Config.RichChance
				then
					rich = { amount = Economy.richTipAmount(r), leaves = t + Config.RichTipStaySeconds }
				end
			end
			if rich ~= nil and (not day or t >= rich.leaves) then
				rich = nil -- gone unpaid: it left at its time or at nightfall
			end
			if day and left == Config.DayLengthSeconds then
				waveLeft = alley.waveSize -- the sunrise wave
			end

			-- where the player is: out on a trip or at home
			local home = t >= INTRO_SECONDS
			if day and t >= INTRO_SECONDS then
				local into = Config.DayLengthSeconds - left
				local interval = (Config.DayLengthSeconds - Config.DuskWarningSeconds - 10) / options.catches
				for k = 1, options.catches do
					local leave = 10 + (k - 1) * interval
					if into >= leave and into < leave + TRIP_SECONDS then
						home = false
					end
					local back = math.floor(leave + TRIP_SECONDS)
					if into == back and tutorialDone and waveLeft > 0 then
						waveLeft -= 1
						local rarity = Catching.pickRarity(alley.odds, rng())
						local def = Catching.pickCat(rarity, "alley", rng())
						addCat(def, if rng() < Config.GoldChanceNet then "gold" else "base", now)
					end
				end
				if not tutorialDone and t >= TUTORIAL_CHECKIN then
					tutorialDone = true
					addCat(Catching.pickCat("Common", "alley", rng()), "base", now)
				end
			end

			-- the Tip Jar's coin gifts at their session minutes, claimed from the HUD
			for _, def in Catalog.tipJar do
				if not tipJarPaid[def.step] and t >= def.minutes * 60 then
					tipJarPaid[def.step] = true
					local prize = def.prize
					Economy.credit(profile, Prizes.coins(prize.coins, prize.coinSeconds, r))
					for lureId, count in (prize.lures or {}) :: { [string]: number } do
						profile.lures[lureId] = (profile.lures[lureId] or 0) + count
					end
				end
			end

			if home then
				local collected = 0
				for _, amount in piles do
					collected += amount
				end
				piles = {}
				if collected > 0 then
					Economy.credit(profile, collected)
					run.coinsFromPiles += collected
				end
				if rich ~= nil then
					Economy.credit(profile, rich.amount)
					run.coinsFromRich += rich.amount
					rich = nil
				end
				local bait = profile.bait
				if bait ~= nil and now >= bait.readyAt then
					local lure = assert(Catalog.luresById[bait.lureId])
					local rarity = Catching.pickRarity(lure.odds, rng())
					local def = Catching.pickBaitCat(rarity, Economy.tier(profile), rng())
					profile.bait = nil
					addCat(def, if rng() < Config.GoldChanceBait then "gold" else "base", now)
				end
				if profile.bait == nil and Economy.level(profile, "lure_bowl") >= 1 then
					if bestFood() == nil and Economy.trySpend(profile, Catalog.luresById.kibble.cost) then
						profile.lures.kibble = (profile.lures.kibble or 0) + 1
					end
					local food = bestFood()
					if food ~= nil then
						profile.lures[food] -= 1
						profile.bait = {
							lureId = food,
							placedAt = now,
							readyAt = now + Economy.baitWaitSeconds(profile, not day),
							night = if day then nil else true,
						}
					end
				end
			end

			-- spending: the rank up first, then the cheapest open shop item
			if run.catsReady == nil and Economy.distinctCats(profile) >= assert(Catalog.getTier(2)).distinctCats then
				run.catsReady = t
			end
			if Economy.rankUpBlocker(profile) == nil then
				run.tier2 = t
				break
			end
			local cheapest: string? = nil
			local cheapestCost = math.huge
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
					cheapest, cheapestCost = def.id, cost
				end
			end
			if cheapest ~= nil and Economy.trySpend(profile, cheapestCost) then
				profile.upgradeLevels[cheapest] = Economy.level(profile, cheapest) + 1
			end
		end
		return run
	end

	local function runs(options: Options, count: number): { Run }
		local out = {}
		for i = 1, count do
			table.insert(out, simulate(options, 7919 * i))
		end
		return out
	end

	-- The minute at the given share of the runs (0.5 the median), every run that never got there counted as LIMIT.
	local function quantile(list: { Run }, field: string, share: number): number
		local values = {}
		for _, run in list do
			table.insert(values, ((run :: any)[field] or LIMIT) / 60)
		end
		table.sort(values)
		return values[math.clamp(math.floor(share * #values + 0.5), 1, #values)]
	end

	-- Each check is the median of RUNS seeded runs: join at a random point of a running server's day and night.
	local RUNS = 40

	local function check(options: Options)
		local list = runs(options, RUNS)
		local ready = quantile(list, "catsReady", 0.5)
		local median = quantile(list, "tier2", 0.5)
		local text = string.format(
			"%d catches a day%s: cats ready at %.1f min, Tier 2 at %.1f min (10th to 90th %.1f to %.1f)",
			options.catches,
			if options.saver then ", tables and bowl only" else "",
			ready,
			median,
			quantile(list, "tier2", 0.1),
			quantile(list, "tier2", 0.9)
		)
		-- features section 8 and data-model 12: 10 to 20 minutes; under 10, the tier costs go up
		if median < 10 or median > 20 then
			error("Tier 2 outside 10 to 20 minutes: " .. text)
		end
		-- v0.13.6: the coins are the last thing a player waits for
		if ready >= median then
			error("the cats come after the coins: " .. text)
		end
	end

	describe("Tier 2 in the loop script (QA re-time after F60 and F61)", function()
		it("takes 10 to 20 minutes for the pace model player at 4 or 5 catches a day", function()
			check({ catches = 4 })
			check({ catches = 5 })
		end)

		it("takes 10 to 20 minutes for a player who buys only the tables and the bait bowl first", function()
			check({ catches = 4, saver = true })
			check({ catches = 5, saver = true })
		end)
	end)
end
