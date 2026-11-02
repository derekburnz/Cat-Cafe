--!strict
-- shared/Leaderboards against leaderboards.md (F98): what each board ranks as whole numbers, the week, the Money
-- figure without potions, the stores' names, the rows a read makes (hidden players out, ranks closed up, top 50) and
-- the crown.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Leaderboards = require(Shared.Leaderboards)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Quests = require(Shared.Quests)
	local Types = require(Shared.Types)

	-- A Monday 00:00 UTC (a quest week's start) plus a day and a bit.
	local MONDAY = Quests.weekEndsAt(1800000000) - 604800
	local NOW = MONDAY + 90000

	local function profile(): Types.PlayerProfile
		return ProfileSchema.template(NOW)
	end

	local function catsOf(exclusive: boolean, count: number): { string }
		local ids: { string } = {}
		for _, def in Catalog.cats do
			if (def.exclusive == true) == exclusive and #ids < count then
				table.insert(ids, def.id)
			end
		end
		return ids
	end

	describe("the values", function()
		it("counts Index entries as cats found plus gold coats, never exclusive cats", function()
			local p = profile()
			p.collection = {}
			p.goldCollection = {}
			local normal = catsOf(false, 3)
			for _, id in normal do
				p.collection[id] = NOW
			end
			p.goldCollection[normal[1]] = NOW
			for _, id in catsOf(true, 2) do
				p.collection[id] = NOW
				p.goldCollection[id] = NOW
			end
			p.collection.not_a_cat = NOW
			expect(Leaderboards.indexEntries(p)).to.equal(4)
			expect(Leaderboards.values(p, NOW, NOW).index).to.equal(4)
		end)

		it("counts minutes played, the session so far included, all time and this week", function()
			local p = profile()
			p.stats.playtimeSeconds = 3600
			p.stats.weekPlay = { week = Leaderboards.week(NOW), seconds = 600 }
			local values = Leaderboards.values(p, NOW - 150, NOW)
			expect(values.playtime).to.equal(62) -- (3600 + 150) / 60, rounded down
			expect(values.playtime_week).to.equal(12) -- (600 + 150) / 60
			-- last week's saved time is not this week's; a session from last week counts from Monday
			p.stats.weekPlay = { week = Leaderboards.week(NOW) - 1, seconds = 99999 }
			local spanning = Leaderboards.values(p, MONDAY - 600, MONDAY + 300)
			expect(spanning.playtime_week).to.equal(5)
		end)

		it("folds a session's time this week into weekPlay at its end", function()
			local p = profile()
			Leaderboards.foldWeekPlay(p, NOW - 120, NOW)
			expect(p.stats.weekPlay.week).to.equal(Leaderboards.week(NOW))
			expect(p.stats.weekPlay.seconds).to.equal(120)
			Leaderboards.foldWeekPlay(p, NOW + 1000, NOW + 1300)
			expect(p.stats.weekPlay.seconds).to.equal(420)
			-- a session across Monday 00:00 starts the new week with its time since then
			local q = profile()
			q.stats.weekPlay = { week = Leaderboards.week(MONDAY) - 1, seconds = 5000 }
			Leaderboards.foldWeekPlay(q, MONDAY - 1000, MONDAY + 60)
			expect(q.stats.weekPlay.week).to.equal(Leaderboards.week(MONDAY))
			expect(q.stats.weekPlay.seconds).to.equal(60)
		end)
	end)

	describe("the Money figure", function()
		it("is the cafe's rate with the pal bonus, never a potion", function()
			local p = profile()
			local base = Economy.incomePerSecond(p)
			expect(base > 0).to.equal(true)
			expect(Leaderboards.moneyRate(p)).to.be.near(base, 1e-9)
			p.buffs[Potions.TIP] = 600
			expect(Leaderboards.moneyRate(p)).to.be.near(base, 1e-9)
			Economy.setPals(p, 1)
			expect(Leaderboards.moneyRate(p)).to.be.near(base * (1 + Config.PalTipBonus), 1e-9)
			Economy.setPals(p, 0)
		end)

		it("keeps the best rate all time and this week, and starts the week over", function()
			local p = profile()
			Leaderboards.noteRate(p, 12.4, NOW)
			Leaderboards.noteRate(p, 8, NOW)
			expect(p.stats.bestRate).to.equal(12.4)
			expect(p.stats.weekBestRate.rate).to.equal(12.4)
			expect(Leaderboards.values(p, NOW, NOW).money).to.equal(12)
			local nextWeek = NOW + 604800
			Leaderboards.noteRate(p, 3, nextWeek)
			expect(p.stats.bestRate).to.equal(12.4)
			expect(p.stats.weekBestRate :: any).to.deepEqual({
				week = Leaderboards.week(nextWeek),
				rate = 3,
			})
			local values = Leaderboards.values(p, nextWeek, nextWeek)
			expect(values.money).to.equal(12)
			expect(values.money_week).to.equal(3)
			-- a week with no rate noted yet reads 0
			expect(Leaderboards.values(p, nextWeek + 604800, nextWeek + 604800).money_week).to.equal(
				0
			)
		end)

		it("ignores a bad rate and clamps a huge one to LeaderboardRateMax", function()
			local p = profile()
			for _, bad in { 0, -5, 0 / 0 } do
				Leaderboards.noteRate(p, bad, NOW)
			end
			expect(p.stats.bestRate).to.equal(0)
			Leaderboards.noteRate(p, 1e12, NOW)
			expect(Leaderboards.values(p, NOW, NOW).money).to.equal(Config.LeaderboardRateMax)
			expect(Config.LeaderboardRateMax).to.equal(10000000)
		end)
	end)

	describe("the stores", function()
		it("are named per board, the weekly ones per week", function()
			expect(Leaderboards.storeName("index", 7)).to.equal("CatCafe_LB_Index")
			expect(Leaderboards.storeName("playtime", 7)).to.equal("CatCafe_LB_Playtime")
			expect(Leaderboards.storeName("money", 7)).to.equal("CatCafe_LB_Money")
			expect(Leaderboards.storeName("playtime_week", 2913)).to.equal(
				"CatCafe_LB_Playtime_W2913"
			)
			expect(Leaderboards.storeName("money_week", 2913)).to.equal("CatCafe_LB_Money_W2913")
			expect(#Leaderboards.LISTS).to.equal(5)
		end)

		it("start the week on Monday 00:00 UTC, the weekly quests' week", function()
			expect(Leaderboards.week(MONDAY)).to.equal(Quests.week(MONDAY))
			expect(Leaderboards.week(MONDAY - 1)).to.equal(Leaderboards.week(MONDAY) - 1)
			expect(Leaderboards.weekStartsAt(NOW)).to.equal(MONDAY)
			-- 1970-01-05 was a Monday: every week start is a Monday at midnight
			expect((MONDAY - 4 * 86400) % 604800).to.equal(0)
		end)
	end)

	describe("the rows", function()
		local function name(userId: number): string
			return "P" .. userId
		end

		it(
			"rank what the store sent, dropping hidden players and bad keys and closing the ranks up",
			function()
				local entries = {
					{ key = "11", value = 900 },
					{ key = "22", value = 800 },
					{ key = "bad", value = 700 },
					{ key = "33", value = 600 },
					{ key = "0", value = 500 },
					{ key = "44", value = "x" },
					{ key = "55", value = 400 },
				}
				local rows = Leaderboards.rows(entries, { [22] = true }, name)
				expect(#rows).to.equal(3)
				expect(rows[1] :: any).to.deepEqual({
					rank = 1,
					userId = 11,
					name = "P11",
					value = 900,
					crown = false,
				})
				expect(rows[2].userId).to.equal(33)
				expect(rows[2].rank).to.equal(2)
				expect(rows[3].userId).to.equal(55)
				expect(Leaderboards.rankOf(rows, 55)).to.equal(3)
				expect(Leaderboards.rankOf(rows, 22)).to.equal(nil)
			end
		)

		it("keep the top LeaderboardSize only", function()
			local entries = {}
			for i = 1, 60 do
				table.insert(entries, { key = tostring(i), value = 100 - i })
			end
			local rows = Leaderboards.rows(entries, {}, name)
			expect(#rows).to.equal(Config.LeaderboardSize)
			expect(rows[50].userId).to.equal(50)
		end)

		it("crown the all-time top 10 of any board, never a weekly list", function()
			local function list(first: number, count: number): { Types.LeaderboardRow }
				local entries = {}
				for i = 0, count - 1 do
					table.insert(entries, { key = tostring(first + i), value = 1000 - i })
				end
				return Leaderboards.rows(entries, {}, name)
			end
			local lists: { [Leaderboards.List]: { Types.LeaderboardRow } } = {
				index = list(1, 12),
				money = list(100, 3),
				playtime_week = list(500, 3),
			}
			expect(Leaderboards.crowned(lists, 1)).to.equal(true)
			expect(Leaderboards.crowned(lists, 10)).to.equal(true)
			expect(Leaderboards.crowned(lists, 11)).to.equal(false)
			expect(Leaderboards.crowned(lists, 102)).to.equal(true)
			expect(Leaderboards.crowned(lists, 500)).to.equal(false)
			expect(Config.LeaderboardCrownRank).to.equal(10)
		end)
	end)

	describe("Leaderboards edges (QA)", function()
		-- An OrderedDataStore keeps whole numbers only, so a NaN, a negative, an infinity or a fraction would make the
		-- write throw and the player drop off every board.
		it("makes every list a whole number from 0 for any save the game could load, money at most RateMax", function()
			local junk: { any } = { 0 / 0, -5, math.huge, -math.huge, 1e300, 12.75, "60", true, {} }
			local week = Leaderboards.week(NOW)
			local saves: { any } = {}
			for _, value in junk do
				table.insert(saves, {
					stats = {
						playtimeSeconds = value,
						bestRate = value,
						weekPlay = { week = week, seconds = value },
						weekBestRate = { week = week, rate = value },
					},
				})
				table.insert(saves, {
					stats = {
						weekPlay = { week = value, seconds = 600 },
						weekBestRate = value,
					},
				})
			end
			table.insert(saves, { stats = "not a table" })
			table.insert(saves, {})
			for n, raw in saves do
				local p = ProfileSchema.migrate(raw, NOW)
				for _, joinedAt in { NOW, NOW - 3600, MONDAY - 600, NOW + 300, 0 } do
					for _, now in { NOW, MONDAY - 1, MONDAY, MONDAY + 1 } do
						for list, value in Leaderboards.values(p, joinedAt, now) do
							local where = string.format(
								"save %d, joined %d, now %d: %s %s",
								n,
								joinedAt,
								now,
								list,
								tostring(value)
							)
							local ok = value == value and value >= 0 and value < math.huge and value % 1 == 0
							expect(ok or error(where)).to.equal(true)
							if list == "money" or list == "money_week" then
								expect(value <= Config.LeaderboardRateMax or error(where)).to.equal(true)
							end
						end
					end
				end
			end
		end)

		it("never lowers a best Money figure, and starts each week from its own first rate", function()
			local p = profile()
			local week = Leaderboards.week(NOW)
			local best, weekBest = 0, 0
			for _, step in
				{
					{ rate = 40, at = NOW },
					{ rate = 0 / 0, at = NOW },
					{ rate = -10, at = NOW },
					{ rate = 25, at = NOW },
					{ rate = 90, at = NOW + 60 },
					{ rate = 0, at = NOW + 120 },
					{ rate = 0 / 0, at = MONDAY + 604800 }, -- a bad rate never starts a week
					{ rate = 30, at = MONDAY + 604800 }, -- next week: its own best starts at 30
					{ rate = 20, at = MONDAY + 604800 + 60 },
				}
			do
				Leaderboards.noteRate(p, step.rate, step.at)
				local rate = step.rate
				if rate == rate and rate > 0 then
					best = math.max(best, rate)
					if Leaderboards.week(step.at) ~= week then
						week = Leaderboards.week(step.at)
						weekBest = rate
					else
						weekBest = math.max(weekBest, rate)
					end
				end
				expect(p.stats.bestRate).to.equal(best)
				expect(p.stats.weekBestRate.week).to.equal(week)
				expect(p.stats.weekBestRate.rate).to.equal(weekBest)
			end
			expect(p.stats.bestRate).to.equal(90)
			expect(p.stats.weekBestRate.rate).to.equal(30)
		end)
	end)
end
