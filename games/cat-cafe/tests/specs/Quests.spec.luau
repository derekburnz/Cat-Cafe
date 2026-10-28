--!strict
-- shared/Quests.luau and the quest and achievement rows (F73, quests.md section 6): the UTC day and Monday week, the
-- pools and which quest a slot is given, what a quest needs and how far it has come, a save's set repaired, the
-- claim and swap rules, the prizes and what each achievement measures.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Quests = require(Shared.Quests)

	local MONDAY = 1792972800 -- 2026-10-26 00:00 UTC

	local function fresh(): any
		return ProfileSchema.template(1000)
	end

	local function rows(kind: string, pool: string): { any }
		return (Catalog.quests :: any)[kind][pool]
	end

	local function ids(list: { any }): { string }
		local out = {}
		for _, row in list do
			table.insert(out, row.id)
		end
		return out
	end

	local function fixed(value: number): () -> number
		return function()
			return value
		end
	end

	local function seeded(seed: number): () -> number
		local rng = Random.new(seed)
		return function()
			return rng:NextNumber()
		end
	end

	describe("the day and the week", function()
		it("starts a day at 00:00 UTC and a week on Monday 00:00 UTC", function()
			expect(Quests.day(MONDAY)).to.equal(20752)
			expect(Quests.day(MONDAY - 1)).to.equal(20751)
			expect(Quests.dayEndsAt(MONDAY)).to.equal(MONDAY + 86400)
			expect(Quests.dayEndsAt(MONDAY - 1)).to.equal(MONDAY)
			expect(Quests.week(MONDAY)).to.equal(Quests.week(MONDAY + 6 * 86400 + 86399))
			expect(Quests.week(MONDAY - 1)).to.equal(Quests.week(MONDAY) - 1)
			expect(Quests.weekEndsAt(MONDAY)).to.equal(MONDAY + 7 * 86400)
			expect(Quests.weekEndsAt(MONDAY - 1)).to.equal(MONDAY)
			expect(Config.QuestWeekOffsetSeconds).to.equal(4 * 86400) -- 1970-01-05, the first Monday
		end)
	end)

	describe("Catalog.quests and Catalog.achievements (section 6)", function()
		it("has five daily slots and three weekly ones, as Config says", function()
			expect(Quests.DAILY_POOLS :: any).to.deepEqual({ "streets", "streets", "cafe", "extra", "big" })
			expect(Quests.WEEKLY_POOLS :: any).to.deepEqual({ "a", "b", "c" })
			expect(#Quests.pools("daily")).to.equal(Config.QuestDailyCount)
			expect(#Quests.pools("weekly")).to.equal(Config.QuestWeeklyCount)
			expect(Config.QuestDailyCount).to.equal(5)
			expect(Config.QuestWeeklyCount).to.equal(3)
		end)

		it("has the design's rows in each pool", function()
			expect(ids(rows("daily", "streets")) :: any).to.deepEqual({ "d_catch5", "d_perfect10", "d_rescue2", "d_rare1" })
			expect(ids(rows("daily", "cafe")) :: any).to.deepEqual({ "d_coins", "d_tips6", "d_bait1", "d_food2" })
			expect(ids(rows("daily", "extra")) :: any).to.deepEqual({
				"d_spin1",
				"d_tipjar3",
				"d_fish5",
				"d_crate1",
				"d_levelup1",
			})
			expect(ids(rows("daily", "big")) :: any).to.deepEqual({
				"d_rare3",
				"d_catch12",
				"d_rescue5",
				"d_perfect30",
				"d_coinsbig",
			})
			expect(ids(rows("weekly", "a")) :: any).to.deepEqual({ "w_catch60", "w_perfect150", "w_rescue15" })
			expect(ids(rows("weekly", "b")) :: any).to.deepEqual({ "w_coins", "w_bait10", "w_tips60" })
			expect(ids(rows("weekly", "c")) :: any).to.deepEqual({ "w_new2", "w_gold2", "w_daily15", "w_sets3" })
		end)

		it("indexes every row once, counts a counter the save has, and gives every pool a row anyone can do", function()
			local stats = ProfileSchema.template(0).stats :: any
			local seen: { [string]: boolean } = {}
			for _, kind in { "daily", "weekly" } do
				for pool, list in (Catalog.quests :: any)[kind] do
					local open = false
					for _, row in list do
						expect(seen[row.id]).to.equal(nil)
						seen[row.id] = true
						expect(Catalog.getQuest(row.id)).to.equal(row)
						expect(Catalog.questPools[row.id]).to.equal(pool)
						expect(#row.text > 0).to.equal(true)
						local known = stats[row.stat] ~= nil or row.stat == "lifetimeCoins" or row.stat == "distinctCats"
						if not known then
							error("quest " .. row.id .. " counts an unknown stat " .. row.stat)
						end
						expect((row.needs ~= nil) ~= (row.needsSeconds ~= nil)).to.equal(true)
						open = open or row.requires == nil
					end
					if not open then
						error(kind .. " pool " .. pool .. " has no row without a requirement")
					end
				end
			end
			expect(Catalog.getQuest("nope")).to.equal(nil)
		end)

		it("has 44 achievements, each measuring something real, with a prize for its size", function()
			expect(#Catalog.achievements).to.equal(44)
			local stats = ProfileSchema.template(0).stats :: any
			local special = {
				lifetimeCoins = true,
				tier = true,
				distinctCats = true,
				goldCats = true,
				mythicalCats = true,
				decorOwned = true,
				topCatLevel = true,
			}
			local seen: { [string]: boolean } = {}
			for _, def in Catalog.achievements do
				expect(seen[def.id]).to.equal(nil)
				seen[def.id] = true
				expect(Catalog.getAchievement(def.id)).to.equal(def)
				expect(#def.name > 0 and #def.text > 0 and def.needs > 0).to.equal(true)
				local upgrade = string.match(def.measure, "^upgrade:(.+)$")
				local known = stats[def.measure] ~= nil
					or special[def.measure] == true
					or (upgrade ~= nil and Catalog.getUpgrade(upgrade) ~= nil)
				if not known then
					error("achievement " .. def.id .. " measures an unknown " .. def.measure)
				end
				expect(Quests.achievementPrize(def)).to.be.ok()
			end
			expect(Catalog.getAchievement("nope")).to.equal(nil)
		end)

		it("pays the design's quest, set and achievement prizes", function()
			expect(Catalog.questPrizes.daily :: any).to.deepEqual({ coins = 200, coinSeconds = 180, fish = 2 })
			expect(Catalog.questPrizes.dailyBig :: any).to.deepEqual({
				coins = 400,
				coinSeconds = 300,
				fish = 4,
				lures = { tuna = 1 },
			})
			expect(Catalog.questPrizes.dailySet :: any).to.deepEqual({
				potions = { big_tip_potion = 1, gold_rush_potion = 1 },
				fish = 10,
				spins = 1,
			})
			expect((Catalog.questPrizes.weeklySet :: any).potions).to.deepEqual({
				big_tip_potion = 3,
				gold_rush_potion = 3,
				quick_bait_potion = 2,
			})
			expect(Quests.prize("daily", 1)).to.equal(Catalog.questPrizes.daily)
			expect(Quests.prize("daily", 4)).to.equal(Catalog.questPrizes.daily)
			expect(Quests.prize("daily", 5)).to.equal(Catalog.questPrizes.dailyBig)
			expect(Quests.prize("weekly", 2)).to.equal(Catalog.questPrizes.weekly)
			expect(Quests.setPrize("daily")).to.equal(Catalog.questPrizes.dailySet)
			expect(Quests.setPrize("weekly")).to.equal(Catalog.questPrizes.weeklySet)
			for _, prize in Catalog.questPrizes :: any do
				for potionId in prize.potions or {} do
					expect(Catalog.getPotion(potionId)).to.be.ok()
				end
				for crateId in prize.crates or {} do
					expect(Catalog.getCrate(crateId)).to.be.ok()
				end
			end
			for _, size in { "S", "M", "L", "XL" } do
				local prize = Catalog.achievementPrizes[size] :: any
				expect(prize).to.be.ok()
				for potionId in prize.potions or {} do
					expect(Catalog.getPotion(potionId)).to.be.ok()
				end
				for crateId in prize.crates or {} do
					expect(Catalog.getCrate(crateId)).to.be.ok()
				end
			end
		end)
	end)

	describe("needs, progress and done", function()
		it("scales a coins quest with the day rate, never under its minimum", function()
			local coins = Catalog.getQuest("d_coins") :: any
			expect(Quests.needsFor(coins, 0)).to.equal(500)
			expect(Quests.needsFor(coins, -5)).to.equal(500)
			expect(Quests.needsFor(coins, 10)).to.equal(6000)
			expect(Quests.needsFor(coins, 10.5)).to.equal(6300)
			expect(Quests.needsFor(Catalog.getQuest("w_coins") :: any, 0)).to.equal(10000)
			expect(Quests.needsFor(Catalog.getQuest("d_catch5") :: any, 1e6)).to.equal(5)
		end)

		it("counts from the counter's value when picked, up to its needs", function()
			local p = fresh()
			p.stats.catsCaught = 7
			local entry = Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0)
			expect(entry :: any).to.deepEqual({ id = "d_catch5", base = 7, needs = 5, claimed = false })
			expect(Quests.progress(p, entry)).to.equal(0)
			p.stats.catsCaught = 10
			expect(Quests.progress(p, entry)).to.equal(3)
			expect(Quests.done(p, entry)).to.equal(false)
			p.stats.catsCaught = 40
			expect(Quests.progress(p, entry)).to.equal(5)
			expect(Quests.done(p, entry)).to.equal(true)
			-- a counter below its base (a rolled-back save) shows 0, never less
			p.stats.catsCaught = 2
			expect(Quests.progress(p, entry)).to.equal(0)
		end)

		it("reads lifetime coins whole and the cats found for distinctCats", function()
			local p = fresh()
			p.lifetimeCoins = 1234.9
			expect(Quests.value(p, "lifetimeCoins")).to.equal(1234)
			local found = 0
			for _ in p.collection do
				found += 1
			end
			expect(Quests.value(p, "distinctCats")).to.equal(found)
			expect(Quests.value(p, "noSuchStat")).to.equal(0)
		end)

		it("never finishes an unknown id", function()
			local p = fresh()
			local entry = { id = "gone", base = 0, needs = 1, claimed = false }
			expect(Quests.progress(p, entry)).to.equal(0)
			expect(Quests.done(p, entry)).to.equal(false)
		end)
	end)

	describe("pick and rollSet", function()
		it("never gives both Streets slots the same counter", function()
			local p = fresh()
			for step = 0, 99 do
				local set = Quests.rollSet(p, "daily", 0, {}, seeded(step))
				local first = Catalog.getQuest(set[1].id) :: any
				local second = Catalog.getQuest(set[2].id) :: any
				expect(first.stat ~= second.stat).to.equal(true)
			end
			-- with d_catch5 in slot 1, slot 2's lowest roll skips catsCaught
			local taken = { Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0) }
			expect((Quests.pick(p, "daily", 2, taken, {}, 0) :: any).id).to.equal("d_perfect10")
		end)

		it("rolls a full set in slot order with no id twice", function()
			local p = fresh()
			for step = 0, 49 do
				for _, kind in { "daily", "weekly" } do
					local pools = Quests.pools(kind :: any)
					local set = Quests.rollSet(p, kind :: any, 0, {}, seeded(step))
					expect(#set).to.equal(#pools)
					local seen: { [string]: boolean } = {}
					for slot, entry in set do
						expect(Catalog.questPools[entry.id]).to.equal(pools[slot])
						expect(seen[entry.id]).to.equal(nil)
						seen[entry.id] = true
						expect(entry.claimed).to.equal(false)
					end
				end
			end
		end)

		it("leaves out the bait bowl quests until the bowl is bought", function()
			local p = fresh()
			p.upgradeLevels.lure_bowl = 0
			local cafe = {}
			for step = 0, 99 do
				local def = Quests.pick(p, "daily", 3, {}, {}, step / 100) :: any
				cafe[def.id] = true
			end
			expect(cafe :: any).to.deepEqual({ d_coins = true, d_tips6 = true })
			p.upgradeLevels.lure_bowl = 1
			expect((Quests.pick(p, "daily", 3, {}, {}, 0.99) :: any).id).to.equal("d_food2")
		end)

		it("offers the crate quest only with a crate banked or the fish for one", function()
			local p = fresh()
			p.goldenFish = 0
			p.crates = {}
			local crate = Catalog.getQuest("d_crate1") :: any
			expect(Quests.eligible(p, crate)).to.equal(false)
			p.goldenFish = Config.CratePrice
			expect(Quests.eligible(p, crate)).to.equal(true)
			p.goldenFish = 0
			p.crates = { classic_crate = 0 }
			expect(Quests.eligible(p, crate)).to.equal(false)
			p.crates = { classic_crate = 1 }
			expect(Quests.eligible(p, crate)).to.equal(true)
		end)

		it("offers New Faces only while two cats are left to find in the open areas", function()
			local p = fresh()
			local newFaces = Catalog.getQuest("w_new2") :: any
			local open = Quests.uncaught(p)
			expect(open >= 2).to.equal(true)
			expect(Quests.eligible(p, newFaces)).to.equal(true)
			local left = open
			for _, def in Catalog.cats do
				local area = Catalog.getArea(def.area)
				if left > 1 and area ~= nil and area.tier <= p.tier and p.collection[def.id] == nil then
					p.collection[def.id] = 1
					left -= 1
				end
			end
			expect(Quests.uncaught(p)).to.equal(1)
			expect(Quests.eligible(p, newFaces)).to.equal(false)
		end)

		it("keeps away from yesterday's quests unless nothing else is left", function()
			local p = fresh()
			local avoid = { d_catch5 = true }
			expect((Quests.pick(p, "daily", 1, {}, avoid, 0) :: any).id).to.equal("d_perfect10")
			local all = { d_catch5 = true, d_perfect10 = true, d_rescue2 = true, d_rare1 = true }
			expect((Quests.pick(p, "daily", 1, {}, all, 0) :: any).id).to.equal("d_catch5")
			local set = Quests.rollSet(p, "daily", 0, { d_catch5 = true, d_perfect10 = true }, fixed(0))
			expect(set[1].id).to.equal("d_rescue2")
			expect(set[2].id).to.equal("d_rare1")
		end)

		it("has nothing for a slot past the set", function()
			expect(Quests.pick(fresh(), "weekly", 4, {}, {}, 0)).to.equal(nil)
		end)
	end)

	describe("repair (a save's set)", function()
		it("leaves a good set alone", function()
			local p = fresh()
			p.quests.daily = Quests.rollSet(p, "daily", 0, {}, seeded(1))
			local before = table.clone(p.quests.daily)
			expect(Quests.repair(p, "daily", 0, seeded(2))).to.equal(false)
			expect(p.quests.daily :: any).to.deepEqual(before)
		end)

		it("gives an unknown or misplaced id a fresh pick from its slot's pool, and fills missing slots", function()
			local p = fresh()
			p.quests.daily = {
				{ id = "d_catch5", base = 0, needs = 5, claimed = true },
				{ id = "removed_quest", base = 0, needs = 3, claimed = false },
				{ id = "w_catch60", base = 0, needs = 60, claimed = false },
			}
			expect(Quests.repair(p, "daily", 0, fixed(0))).to.equal(true)
			local daily = p.quests.daily
			expect(#daily).to.equal(5)
			expect(daily[1] :: any).to.deepEqual({ id = "d_catch5", base = 0, needs = 5, claimed = true })
			expect(daily[2].id).to.equal("d_perfect10") -- not catsCaught again
			for slot, entry in daily do
				expect(Catalog.questPools[entry.id]).to.equal(Quests.DAILY_POOLS[slot])
			end
		end)

		it("drops slots past the set", function()
			local p = fresh()
			local set = Quests.rollSet(p, "weekly", 0, {}, seeded(3))
			table.insert(set, { id = "w_catch60", base = 0, needs = 60, claimed = false })
			p.quests.weekly = set
			expect(Quests.repair(p, "weekly", 0, fixed(0))).to.equal(true)
			expect(#p.quests.weekly).to.equal(3)
		end)
	end)

	describe("claiming and swapping", function()
		it("claims only a finished, unclaimed quest", function()
			local p = fresh()
			p.quests.daily = Quests.rollSet(p, "daily", 0, {}, fixed(0))
			p.quests.daily[1] = Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0)
			expect(Quests.claimBlocker(p, "daily", 6)).to.equal("No such quest")
			expect(Quests.claimBlocker(p, "daily", 1)).to.equal("Not finished yet")
			p.stats.catsCaught += 5
			expect(Quests.claimBlocker(p, "daily", 1)).to.equal(nil)
			p.quests.daily[1].claimed = true
			expect(Quests.claimBlocker(p, "daily", 1)).to.equal("Already claimed")
		end)

		it("swaps one unfinished quest a day and one a week", function()
			local p = fresh()
			p.quests.daily = Quests.rollSet(p, "daily", 0, {}, fixed(0))
			p.quests.weekly = Quests.rollSet(p, "weekly", 0, {}, fixed(0))
			p.quests.daily[1] = Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0)
			expect(Quests.rerollBlocker(p, "daily", 1)).to.equal(nil)
			expect(Quests.rerollBlocker(p, "daily", 9)).to.equal("No such quest")
			p.stats.catsCaught += 5
			expect(Quests.rerollBlocker(p, "daily", 1)).to.equal("That quest is done")
			p.quests.dailyReroll = true
			expect(Quests.rerollBlocker(p, "daily", 2)).to.equal("You've used today's free swap")
			expect(Quests.rerollBlocker(p, "weekly", 1)).to.equal(nil)
			p.quests.weeklyReroll = true
			expect(Quests.rerollBlocker(p, "weekly", 1)).to.equal("You've used this week's free swap")
		end)

		it("swaps in a different quest, never the one it replaces", function()
			local p = fresh()
			p.quests.daily = Quests.rollSet(p, "daily", 0, {}, fixed(0))
			local old = p.quests.daily[1].id
			for step = 0, 99 do
				local def = Quests.pick(p, "daily", 1, p.quests.daily, {}, step / 100) :: any
				expect(def.id ~= old).to.equal(true)
				expect(def.stat ~= (Catalog.getQuest(p.quests.daily[2].id) :: any).stat).to.equal(true)
			end
		end)

		it("counts the set prize only when every slot of a full set is claimed", function()
			local function entries(n: number, claimed: boolean): { any }
				local out = {}
				for _ = 1, n do
					table.insert(out, { id = "d_catch5", base = 0, needs = 1, claimed = claimed })
				end
				return out
			end
			expect(Quests.allClaimed(entries(5, true), 5)).to.equal(true)
			expect(Quests.allClaimed(entries(4, true), 5)).to.equal(false)
			local list = entries(5, true)
			list[3].claimed = false
			expect(Quests.allClaimed(list, 5)).to.equal(false)
		end)
	end)

	describe("achievements", function()
		it("measures tier, upgrades, gold and Mythical cats found, decor owned and the top cat level", function()
			local p = fresh()
			p.tier = 3
			p.upgradeLevels.net = 2
			p.goldCollection = { a = 1, b = 2 }
			p.decorOwned = { lamp = true, rug = false, plant = true }
			p.lifetimeCoins = 99.5
			p.stats.rescues = 4
			expect(Quests.measure(p, "tier")).to.equal(3)
			expect(Quests.measure(p, "upgrade:net")).to.equal(2)
			expect(Quests.measure(p, "goldCats")).to.equal(2)
			expect(Quests.measure(p, "decorOwned")).to.equal(2)
			expect(Quests.measure(p, "lifetimeCoins")).to.equal(99)
			expect(Quests.measure(p, "rescues")).to.equal(4)
			local mythical = 0
			for _, def in Catalog.cats do
				if def.rarity == "Mythical" and mythical < 2 then
					p.collection[def.id] = 1
					mythical += 1
				end
			end
			expect(Quests.measure(p, "mythicalCats")).to.equal(mythical)
			local top = 0
			for _, instance in p.cats do
				instance.level = 7
				top = 7
			end
			expect(Quests.measure(p, "topCatLevel")).to.equal(top)
		end)

		it("claims a met achievement once", function()
			local p = fresh()
			local def: any = nil
			for _, row in Catalog.achievements do
				if row.measure == "rescues" then
					def = row
					break
				end
			end
			expect(Quests.achievementBlocker(p, "nope")).to.equal("Unknown")
			expect(Quests.achievementBlocker(p, def.id)).to.equal("Not there yet")
			p.stats.rescues = def.needs * 3
			expect(Quests.achievementProgress(p, def)).to.equal(def.needs)
			expect(Quests.achievementBlocker(p, def.id)).to.equal(nil)
			p.achievements[def.id] = true
			expect(Quests.achievementBlocker(p, def.id)).to.equal("Already claimed")
		end)

		it("lists every achievement's progress and claim for the window", function()
			local p = fresh()
			local first = Catalog.achievements[1]
			p.achievements[first.id] = true
			local view = Quests.achievementsView(p)
			local n = 0
			for id, row in view do
				n += 1
				expect(row.claimed).to.equal(id == first.id)
				expect(row.progress <= (Catalog.getAchievement(id) :: any).needs).to.equal(true)
			end
			expect(n).to.equal(44)
		end)
	end)

	describe("view", function()
		it("sends each quest's text, progress and needs with the resets and the swap and set flags", function()
			local p = fresh()
			p.quests.daily = Quests.rollSet(p, "daily", 0, {}, fixed(0))
			p.quests.weekly = Quests.rollSet(p, "weekly", 0, {}, fixed(0))
			p.quests.daily[1] = Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0)
			p.stats.catsCaught += 2
			p.quests.dailyReroll = true
			local view = Quests.view(p, MONDAY + 60)
			expect(view.daily[1] :: any).to.deepEqual({
				id = "d_catch5",
				text = "Catch 5 cats",
				progress = 2,
				needs = 5,
				claimed = false,
			})
			expect(#view.daily).to.equal(5)
			expect(#view.weekly).to.equal(3)
			expect(view.dailyResetsAt).to.equal(MONDAY + 86400)
			expect(view.weeklyResetsAt).to.equal(MONDAY + 7 * 86400)
			expect(view.dailyRerollUsed).to.equal(true)
			expect(view.weeklyRerollUsed).to.equal(false)
			expect(view.dailySetClaimed).to.equal(false)
		end)
	end)
end
