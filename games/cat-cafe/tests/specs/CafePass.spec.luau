--!strict
-- CafePass.luau and Catalog.passSeasons (#1645, #1626; cafe-pass.md): the season clock from UTC dates, levels from
-- XP, claims on the free and paid tracks, the season roll paying what was owed, the save made whole, and the policy
-- walk over every paid row (fixed things only, never crates, spins, fish, coins or Lucky Potions).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CafePass = require(Shared.CafePass)
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Trade = require(Shared.Trade)

	local LEVEL = Config.PassXpPerLevel

	local function fail(pattern: string, ...: any)
		error(string.format(pattern, ...), 2)
	end

	describe("the season clock", function()
		it("reads UTC dates", function()
			expect(CafePass.dateToTime("1970-01-01")).to.equal(0)
			expect(CafePass.dateToTime("2026-11-05")).to.equal(1793836800)
			expect(CafePass.dateToTime("2000-03-01")).to.equal(951868800)
			expect(CafePass.dateToTime("2026-13-01")).to.equal(nil)
			expect(CafePass.dateToTime("soon")).to.equal(nil)
			expect(CafePass.dateToTime(5)).to.equal(nil)
		end)

		it("is closed with no date, but runs a preview season 1 in Studio", function()
			local c = Config :: any
			local saved = c.SeasonStarts
			c.SeasonStarts = {}
			expect((CafePass.seasonAt(2000000000))).to.equal(0)
			local season, startsAt, endsAt = CafePass.seasonAt(2000000000, true)
			expect(season).to.equal(1)
			expect(startsAt).to.equal(0)
			expect(endsAt).to.equal(nil)
			c.SeasonStarts = saved
		end)

		it("runs each season from its date to the next, the newest staying open", function()
			local c = Config :: any
			local saved = c.SeasonStarts
			c.SeasonStarts = { "2026-12-15", "2026-11-01" } -- out of order on purpose
			local nov, dec =
				CafePass.dateToTime("2026-11-01") :: number,
				CafePass.dateToTime("2026-12-15") :: number
			expect((CafePass.seasonAt(nov - 1))).to.equal(0)
			local s1, a1, e1 = CafePass.seasonAt(nov + 5)
			expect(s1).to.equal(1)
			expect(a1).to.equal(nov)
			expect(e1).to.equal(dec)
			local s2, _, e2 = CafePass.seasonAt(dec)
			expect(s2).to.equal(2)
			expect(e2).to.equal(nil)
			c.SeasonStarts = saved
		end)

		it("wraps round the season tables, so a later season reruns one", function()
			expect(CafePass.seasonDef(0)).to.equal(nil)
			expect(CafePass.seasonDef(1)).to.equal(Catalog.passSeasons[1])
			expect(CafePass.seasonDef(1 + #Catalog.passSeasons)).to.equal(Catalog.passSeasons[1])
		end)
	end)

	describe("levels and XP", function()
		it("is 30 levels of 800 XP, capped", function()
			expect(CafePass.levelOf(0)).to.equal(0)
			expect(CafePass.levelOf(LEVEL - 1)).to.equal(0)
			expect(CafePass.levelOf(LEVEL)).to.equal(1)
			expect(CafePass.levelOf(10 ^ 9)).to.equal(Config.PassLevels)
			local state = CafePass.fresh(1)
			expect(CafePass.addXp(state, 1, 100)).to.equal(100)
			expect(CafePass.addXp(state, 2, 100)).to.equal(0) -- not on that season yet
			expect(CafePass.addXp(state, 0, 100)).to.equal(0)
			CafePass.addXp(state, 1, 10 ^ 9)
			expect(state.xp).to.equal(CafePass.maxXp())
		end)

		it("pays pass XP on every quest prize as quests.md section 8 says", function()
			expect(Catalog.questPrizes.daily.passXp).to.equal(100)
			expect(Catalog.questPrizes.dailyBig.passXp).to.equal(200)
			expect(Catalog.questPrizes.dailySet.passXp).to.equal(200)
			expect(Catalog.questPrizes.weekly.passXp).to.equal(400)
			expect(Catalog.questPrizes.weeklySet.passXp).to.equal(400)
		end)
	end)

	describe("claims", function()
		it("needs the level, a reward there, the paid track bought, and no claim yet", function()
			local state = CafePass.fresh(1)
			expect(CafePass.claimBlocker(state, 0, "free", 2)).to.equal(
				"The Cafe Pass isn't running right now"
			)
			expect(CafePass.claimBlocker(state, 1, "free", 2)).to.equal("Reach that level first")
			state.xp = 7 * LEVEL
			expect(CafePass.claimBlocker(state, 1, "free", 3)).to.equal("Nothing at that level")
			expect(CafePass.claimBlocker(state, 1, "free", 2)).to.equal(nil)
			expect(CafePass.claimBlocker(state, 1, "paid", 7)).to.equal(
				"That one is on the paid track"
			)
			CafePass.markClaimed(state, "free", 2, 1)
			expect(CafePass.claimBlocker(state, 1, "free", 2)).to.equal("Already claimed")
		end)

		it("unlocks every paid level already reached once bought (QA case 1)", function()
			local state = CafePass.fresh(1)
			state.xp = 7 * LEVEL
			expect(#CafePass.claimable(state, 1)).to.equal(3) -- free 2, 4 and 6
			state.paidSeason = 1
			local ready = CafePass.claimable(state, 1)
			expect(#ready).to.equal(10) -- and paid 1 to 7
			expect(ready[4].track).to.equal("paid")
			expect(ready[4].level).to.equal(1)
		end)

		it("keeps a paid item forever once claimed", function()
			local state = CafePass.fresh(1)
			state.xp = LEVEL
			state.paidSeason = 1
			CafePass.markClaimed(state, "paid", 1, 1)
			expect(state.items.tag_maple).to.equal(true)
		end)
	end)

	describe("buying the paid track (#1626)", function()
		it("unlocks the running season once, only for a save already on it", function()
			local state = CafePass.fresh(0)
			expect(CafePass.buyPaid(state, 0)).to.equal(false)
			expect(CafePass.buyPaid(state, 1)).to.equal(false) -- not rolled onto season 1 yet
			CafePass.roll(state, 1)
			expect(CafePass.buyPaid(state, 1)).to.equal(true)
			expect(state.paidSeason).to.equal(1)
			expect(CafePass.buyPaid(state, 1)).to.equal(false)
			expect(state.paidSeason).to.equal(1)
		end)

		it("opens the paid claims it unlocks", function()
			local state = CafePass.fresh(0)
			CafePass.roll(state, 1)
			CafePass.addXp(state, 1, LEVEL)
			expect(CafePass.claimBlocker(state, 1, "paid", 1)).to.equal(
				"That one is on the paid track"
			)
			CafePass.buyPaid(state, 1)
			expect(CafePass.claimBlocker(state, 1, "paid", 1)).to.equal(nil)
		end)
	end)

	describe("the season roll (QA case 4)", function()
		it(
			"returns the old season's reached, unclaimed rewards, then resets XP and claims",
			function()
				local state = CafePass.fresh(1)
				state.xp = 4 * LEVEL
				state.paidSeason = 1
				CafePass.markClaimed(state, "free", 2, 1)
				CafePass.markClaimed(state, "paid", 1, 1)
				local owed = CafePass.roll(state, 2)
				local keys: { string } = {}
				for _, claim in owed do
					expect(claim.season).to.equal(1)
					table.insert(keys, claim.track .. claim.level)
				end
				expect(keys :: any).to.deepEqual({ "free4", "paid2", "paid3", "paid4" })
				expect(state.season).to.equal(2)
				expect(state.xp).to.equal(0)
				expect(#state.claimedFree + #state.claimedPaid).to.equal(0)
				expect(state.items.tag_maple).to.equal(true)
				expect(#CafePass.roll(state, 2)).to.equal(0)
			end
		)

		it(
			"owes no paid rewards when that season's track was not bought, and nothing from season 0",
			function()
				local state = CafePass.fresh(1)
				state.xp = 2 * LEVEL
				local owed = CafePass.roll(state, 2)
				expect(#owed).to.equal(1)
				expect(owed[1].track).to.equal("free")
				expect(#CafePass.roll(CafePass.fresh(0), 1)).to.equal(0)
			end
		)
	end)

	describe("the save (version 36)", function()
		it("starts at season 0 and makes a saved pass whole", function()
			local profile = ProfileSchema.template(1000)
			expect(profile.pass.season).to.equal(0)
			expect(profile.pass.xp).to.equal(0)
			local clean = CafePass.sanitize({
				season = 1,
				xp = -5,
				paidSeason = 1.5,
				claimedFree = { 2, 2, 31, "x", 4 },
				claimedPaid = "no",
				items = { tag_maple = true, made_up = true },
				tag = "made_up",
			})
			expect(clean.season).to.equal(1)
			expect(clean.xp).to.equal(0)
			expect(clean.paidSeason).to.equal(0)
			expect(clean.claimedFree :: any).to.deepEqual({ 2, 4 })
			expect(clean.claimedPaid :: any).to.deepEqual({})
			expect(clean.items :: any).to.deepEqual({ tag_maple = true })
			expect(clean.tag).to.equal(nil)
			expect(CafePass.sanitize({ tag = "tag_maple" }).tag).to.equal("tag_maple") -- #1626
			expect(CafePass.sanitize({ tag = "off" }).tag).to.equal("off")
			expect(CafePass.sanitize(nil).season).to.equal(0)
		end)
	end)

	describe("the reward tables (cafe-pass.md sections 2 and 3)", function()
		local season = Catalog.passSeasons[1]

		it("has a free reward every second level and a paid one at every level", function()
			for level = 1, Config.PassLevels do
				expect(season.free[level] ~= nil).to.equal(level % 2 == 0)
				expect(season.paid[level]).to.be.ok()
			end
			expect((season.paid[30].item :: any).id).to.equal("maple_muffin")
		end)

		it("puts only fixed things on the paid track (QA case 5, monetization-policy)", function()
			local allowed = { big_tip_potion = true, swift_potion = true, steady_potion = true }
			for level, row in season.paid do
				local prize = row.prize :: any
				if prize ~= nil then
					for key in prize do
						if key ~= "potions" then
							fail("paid level %d pays %s", level, key)
						end
					end
					for potionId in prize.potions do
						if not allowed[potionId] then
							fail("paid level %d pays %s", level, potionId)
						end
					end
				end
				expect(row.prize ~= nil or row.item ~= nil).to.equal(true)
			end
		end)

		it("names only known potions and crates on the free track", function()
			for _, row in season.free do
				local prize = row.prize :: any
				for potionId in prize.potions or {} do
					expect(Catalog.getPotion(potionId)).to.be.ok()
				end
				for crateId in prize.crates or {} do
					expect(Catalog.getCrate(crateId)).to.be.ok()
				end
			end
		end)

		it("makes Maple Muffin an exclusive pass cat that never counts for rank up", function()
			local def = Catalog.getCat("maple_muffin") :: any
			expect(def).to.be.ok()
			expect(def.exclusive).to.equal(true)
			expect(def.source).to.equal("pass")
			expect(def.rarity).to.equal("Legendary")
			expect(Economy.countsForRankUp("maple_muffin")).to.equal(false)
		end)

		-- monetization-policy: what the pass gives stays with the buyer. A pass cat can't go on a trade (a gift is a
		-- one-sided trade, so this covers gifting too), and no pass item id is a tradeable decor or lawn piece.
		it("never lets a pass item be traded or gifted", function()
			for _, def in Catalog.passSeasons do
				for _, track in { def.free, def.paid } do
					for level, row in track do
						local item = row.item
						if item ~= nil then
							if Trade.piece(item.id) ~= nil then
								fail("level %d item %s is a tradeable piece", level, item.id)
							end
							if item.kind == "cat" then
								local cat: any = CatStats.newInstance("p" .. level, item.id, 100)
								expect(Trade.offerRefusal(cat, {})).to.equal(
									Trade.Messages.exclusive
								)
								expect(Trade.tradable(cat)).to.equal(false)
							end
						end
					end
				end
			end
		end)
	end)
end
