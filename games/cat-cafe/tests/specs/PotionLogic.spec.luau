--!strict
-- UI/Components/PotionLogic.luau: the potion bag, the HUD's potion timers and the Mystery gift's words (F64).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local PotionLogic = require(Components:WaitForChild("PotionLogic")) :: any

	local NOW = 1000
	local function state(potions: { [string]: number }?, buffs: { [string]: number }?): any
		return { potions = potions, buffs = buffs }
	end
	local function ids(rows: { any }): string
		local list = {}
		for _, row in rows do
			table.insert(list, row.potion.id)
		end
		return table.concat(list, ",")
	end
	local function noFood(_id: string): string?
		return nil
	end

	describe("PotionLogic.list", function()
		it("falls back to the four F64 potions before the server sends Catalog.potions", function()
			local list = PotionLogic.list(nil)
			expect(#list).to.equal(4)
			expect(list[1].id).to.equal("tip_potion")
			expect(list[4].name).to.equal("Steady Paw Potion")
			expect(list[1].effect).to.equal("+25% money")
		end)

		it(
			"follows the catalog's order and keeps the bag's short line for known potions",
			function()
				local catalog = {
					potions = {
						{
							id = "swift_potion",
							name = "Swift Potion",
							minutes = 5,
							effect = "server words",
						},
						{ id = "tip_potion", minutes = 10 },
					},
				}
				local list = PotionLogic.list(catalog)
				expect(#list).to.equal(2)
				expect(list[1].id).to.equal("swift_potion")
				expect(list[1].effect).to.equal("+4 walk speed")
				expect(list[2].name).to.equal("Money Potion")
			end
		)

		it("names an unknown potion from its id and uses the catalog's effect", function()
			local list = PotionLogic.list({
				potions = { { id = "moon_potion", minutes = 15, effect = "Glows" } },
			})
			expect(list[1].name).to.equal("Moon Potion")
			expect(list[1].minutes).to.equal(15)
			expect(list[1].effect).to.equal("Glows")
		end)

		it("skips rows without an id", function()
			local list =
				PotionLogic.list({ potions = { { name = "No id" }, { id = "tip_potion" } } })
			expect(#list).to.equal(1)
		end)
	end)

	describe("PotionLogic.rows", function()
		it("counts the bag and the time left from endsAt", function()
			local rows =
				PotionLogic.rows(nil, state({ tip_potion = 2 }, { tip_potion = NOW + 90 }), NOW)
			expect(rows[1].count).to.equal(2)
			expect(rows[1].secondsLeft).to.equal(90)
			expect(rows[2].count).to.equal(0)
			expect(rows[2].secondsLeft).to.equal(0)
		end)

		it("counts Use presses still on their way at once, as the server will (#3190)", function()
			local base = state({ tip_potion = 3 }, { tip_potion = NOW + 60 })
			expect(PotionLogic.ahead(nil, base, {}, NOW)).to.equal(base)
			local shown = PotionLogic.ahead(nil, base, { tip_potion = 2, lucky_potion = 1 }, NOW)
			local rows = PotionLogic.rows(nil, shown, NOW)
			expect(rows[1].count).to.equal(1)
			expect(rows[1].secondsLeft).to.equal(60 + 2 * rows[1].potion.minutes * 60)
			expect(rows[2].count).to.equal(0)
			expect(rows[2].secondsLeft).to.equal(rows[2].potion.minutes * 60) -- not running: from now
			expect(base.potions.tip_potion).to.equal(3) -- the real state is kept
			expect(base.buffs.tip_potion).to.equal(NOW + 60)
		end)

		it("counts only potions Use can drink now for the Potions button (#3937)", function()
			local max = PotionLogic.MAX_MINUTES * 60
			local usable, held = PotionLogic.drinkable(
				nil,
				state({ tip_potion = 3, lucky_potion = 16, swift_potion = 0 }, {
					tip_potion = NOW + max - 10 * 60, -- room for one more: Use is on for all 3
					lucky_potion = NOW + max - 60, -- Full: none of the 16 count
				}),
				NOW
			)
			expect(usable).to.equal(3)
			expect(held).to.equal(19)
			usable, held = PotionLogic.drinkable(
				nil,
				state({ lucky_potion = 2 }, { lucky_potion = NOW + max }),
				NOW
			)
			expect(usable).to.equal(0)
			expect(held).to.equal(2)
			usable, held = PotionLogic.drinkable(nil, state(nil, nil), NOW)
			expect(usable).to.equal(0)
			expect(held).to.equal(0)
		end)

		it("lets Use take a potion only with one in the bag and room under the cap", function()
			local max = PotionLogic.MAX_MINUTES * 60
			local rows = PotionLogic.rows(
				nil,
				state({ tip_potion = 1, lucky_potion = 1, swift_potion = 0 }, {
					tip_potion = NOW + max - 10 * 60, -- exactly room for one more 10 minutes
					lucky_potion = NOW + max - 9 * 60, -- one minute short
				}),
				NOW
			)
			expect(rows[1].canUse).to.equal(true)
			expect(rows[2].canUse).to.equal(false)
			expect(rows[3].canUse).to.equal(false)
		end)

		it(
			"counts how many Use all drinks: the bag cut to the room under the cap (#1600)",
			function()
				local max = PotionLogic.MAX_MINUTES * 60
				local rows = PotionLogic.rows(
					nil,
					state({ tip_potion = 9, lucky_potion = 3, swift_potion = 1 }, {
						tip_potion = NOW + max - 35 * 60, -- 35 minutes of room: three 10-minute potions
						lucky_potion = NOW + max - 9 * 60, -- one minute short of one
					}),
					NOW
				)
				expect(rows[1].fit).to.equal(3)
				expect(rows[2].fit).to.equal(0)
				expect(rows[3].fit).to.equal(1) -- the bag has one
				expect(rows[4].fit).to.equal(0) -- none in the bag
				-- nothing running: the bag's count, up to the cap's worth of 5-minute Swift Potions
				local swift = PotionLogic.rows(nil, state({ swift_potion = 100000 }, {}), NOW)
				expect(swift[3].fit).to.equal(PotionLogic.MAX_MINUTES // 5)
			end
		)

		it("shows a potion the catalog does not name yet, after the rest, in id order", function()
			local rows = PotionLogic.rows(
				nil,
				state({ zeta_potion = 1, big_tip_potion = 1 }, { alpha_potion = NOW + 5 }),
				NOW
			)
			expect(ids(rows)).to.equal(
				"tip_potion,lucky_potion,swift_potion,steady_potion,alpha_potion,big_tip_potion,zeta_potion"
			)
			expect(rows[6].potion.name).to.equal("Big Money Potion")
			expect(rows[7].potion.name).to.equal("Zeta Potion")
		end)

		it("reads a finished or broken timer as not running", function()
			local rows = PotionLogic.rows(
				nil,
				state(nil, { tip_potion = NOW - 5, lucky_potion = 0 / 0 }),
				NOW
			)
			expect(rows[1].secondsLeft).to.equal(0)
			expect(rows[2].secondsLeft).to.equal(0)
		end)
	end)

	describe("PotionLogic.running", function()
		it("keeps only the potions with time left, in bag order", function()
			local running = PotionLogic.running(
				nil,
				state(
					{},
					{ steady_potion = NOW + 30, tip_potion = NOW + 600, lucky_potion = NOW - 1 }
				),
				NOW
			)
			expect(ids(running)).to.equal("tip_potion,steady_potion")
		end)
	end)

	describe("PotionLogic.owned", function()
		it(
			"plans Use all potions as the server's Potions.useAll, sizes sharing a timer (#3326)",
			function()
				local catalog: any = {
					potions = {
						{ id = "tip_potion", name = "Tip Potion", minutes = 10, effect = "" },
						{ id = "swift_potion", name = "Swift Potion", minutes = 10, effect = "" },
						{
							id = "swift_potion_small",
							name = "Small Swift Potion",
							minutes = 3,
							effect = "",
							buff = "swift_potion",
						},
						{ id = "lucky_potion", name = "Lucky Potion", minutes = 10, effect = "" },
					},
				}
				local max = PotionLogic.MAX_MINUTES * 60
				local s = state(
					{ tip_potion = 3, swift_potion = 2, swift_potion_small = 4, lucky_potion = 1 },
					{ lucky_potion = NOW + max, swift_potion = NOW + max - 600 - 2 * 180 }
				)
				local plan = PotionLogic.allPlan(catalog, s, NOW)
				local line, total = PotionLogic.allLine(plan)
				expect(line).to.equal("Tip x3, Swift x1, Small Swift x2")
				expect(total).to.equal(6)
				expect(
					#PotionLogic.allPlan(
						catalog,
						state({ lucky_potion = 2 }, { lucky_potion = NOW + max }),
						NOW
					)
				).to.equal(0)
				expect(#PotionLogic.allPlan(catalog, state({}, {}), NOW)).to.equal(0)
			end
		)

		it("keeps the potions in the bag and the running ones, in bag order", function()
			local owned = PotionLogic.owned(
				nil,
				state(
					{ tip_potion = 2, lucky_potion = 0 },
					{ steady_potion = NOW + 30, lucky_potion = NOW - 1 }
				),
				NOW
			)
			expect(ids(owned)).to.equal("tip_potion,steady_potion")
			expect(owned[1].count).to.equal(2)
			expect(owned[2].count).to.equal(0)
		end)

		it("has no rows for an empty bag with nothing running", function()
			expect(#PotionLogic.owned(nil, state({}, {}), NOW)).to.equal(0)
			expect(#PotionLogic.owned(nil, state(nil, nil), NOW)).to.equal(0)
		end)
	end)

	describe("PotionLogic.boosts", function()
		it("sums what the running potions add to food set now, as the server's Potions", function()
			local none = PotionLogic.boosts(nil, state({}, nil), NOW)
			expect(none.goldLuck).to.equal(0)
			expect(none.baitSpeed).to.equal(0)
			expect(none.goldScale).to.equal(1)
			-- before the catalog carries the numbers, the quest potions' own
			local all = PotionLogic.boosts(
				nil,
				state({}, {
					gold_rush_potion = NOW + 60,
					quick_bait_potion = NOW + 60,
					lucky_potion = NOW + 60,
					tip_potion = NOW + 60,
				}),
				NOW
			)
			expect(all.goldLuck).to.be.near(0.25, 1e-9)
			expect(all.baitSpeed).to.be.near(0.25, 1e-9)
			expect(all.goldScale).to.equal(2)
		end)

		it("reads the catalog's numbers and skips finished timers", function()
			local catalog: any = {
				potions = {
					{ id = "gold_rush_potion", goldLuck = 0.3 },
					{ id = "quick_bait_potion", baitSpeed = 0.2 },
				},
			}
			local boosts = PotionLogic.boosts(
				catalog,
				state(
					{},
					{ gold_rush_potion = NOW + 1, quick_bait_potion = NOW - 1, lucky_potion = NOW }
				),
				NOW
			)
			expect(boosts.goldLuck).to.be.near(0.3, 1e-9)
			expect(boosts.baitSpeed).to.equal(0)
			expect(boosts.goldScale).to.equal(1)
		end)
	end)

	describe("PotionLogic.clock", function()
		it("shows minutes and seconds, rounded up", function()
			expect(PotionLogic.clock(545)).to.equal("9:05")
			expect(PotionLogic.clock(3600)).to.equal("60:00")
			expect(PotionLogic.clock(0.2)).to.equal("0:01")
			expect(PotionLogic.clock(0)).to.equal("0:00")
			expect(PotionLogic.clock(0 / 0)).to.equal("0:00")
		end)
	end)

	describe("PotionLogic gift words", function()
		local function foodName(id: string): string?
			return if id == "salmon" then "Salmon" else nil
		end

		it("falls back to the data model's gift table, adding up to 100", function()
			local rows = PotionLogic.giftRows(nil)
			local sum = 0
			for _, row in rows do
				sum += row.chance
			end
			expect(#rows).to.equal(4)
			expect(sum).to.equal(100)
		end)

		it("reads Catalog.mysteryGift when it is there", function()
			local rows = PotionLogic.giftRows({
				mysteryGift = { { kind = "fish", count = 25, chance = 100 } },
			})
			expect(#rows).to.equal(1)
			expect(rows[1].count).to.equal(25)
		end)

		it("reads the waiting wrap's own rows from Catalog.mysteryGiftTiers (#2614)", function()
			local catalog = {
				mysteryGift = { { kind = "fish", count = 8, chance = 100 } },
				mysteryGiftTiers = {
					{
						tier = "Common",
						chance = 70,
						rows = { { kind = "fish", count = 8, chance = 100 } },
					},
					{
						tier = "Super",
						chance = 5,
						rows = {
							{ kind = "crate", id = "highest", count = 1, fish = 15, chance = 60 },
							{ kind = "fish", count = 50, chance = 40 },
						},
					},
				},
			}
			expect(PotionLogic.giftLine(PotionLogic.giftRows(catalog, "Super"), foodName)).to.equal(
				"Zone crate + 15 golden fish 60%  ·  50 golden fish 40%"
			)
			expect(#PotionLogic.giftRows(catalog, nil)).to.equal(1)
		end)

		it("names and pictures #2614's new prizes", function()
			expect(PotionLogic.giftTitle("coins", nil, 180, foodName)).to.equal(
				"3 minutes of earnings"
			)
			expect(PotionLogic.giftTitle("food", "big_cat_snack", 2, foodName)).to.equal(
				"2 Big Cat Snacks"
			)
			expect(PotionLogic.giftPrize("coins", nil, 180).coinSeconds).to.equal(180)
			local crate = PotionLogic.giftPrize("crate", "highest", 1, 15)
			expect(crate.crates.highest).to.equal(1)
			expect(crate.fish).to.equal(15)
			expect(PotionLogic.giftPrize("food", "big_cat_snack", 2).catFood.big_cat_snack).to.equal(
				2
			)
		end)

		it("lists the chances in one short line", function()
			expect(PotionLogic.giftLine(PotionLogic.giftRows(nil), foodName)).to.equal(
				"Potion 60%  ·  2 Salmon 20%  ·  10 golden fish 10%  ·  1 spin 10%"
			)
		end)

		it("names what a gift held", function()
			expect(PotionLogic.giftTitle("potion", "tip_potion", 1, noFood)).to.equal(
				"Money Potion"
			)
			expect(PotionLogic.giftTitle("potion", "tip_potion", 2, noFood)).to.equal(
				"2 Money Potions"
			)
			expect(PotionLogic.giftTitle("lure", "salmon", 2, foodName)).to.equal("2 Salmon")
			expect(PotionLogic.giftTitle("lure", "star_treat", 1, noFood)).to.equal("1 Star Treat")
			expect(PotionLogic.giftTitle("fish", nil, 10, noFood)).to.equal("10 golden fish")
			expect(PotionLogic.giftTitle("spin", nil, 1, noFood)).to.equal("1 spin")
			expect(PotionLogic.giftTitle("spin", nil, 3, noFood)).to.equal("3 spins")
			expect(PotionLogic.giftTitle("hat", nil, 1, noFood)).to.equal("A surprise")
		end)

		it("prefers the catalog's potion name", function()
			local function potionName(id: string): string?
				return if id == "tip_potion" then "Tippy Tonic" else nil
			end
			expect(PotionLogic.giftTitle("potion", "tip_potion", 1, noFood, potionName)).to.equal(
				"Tippy Tonic"
			)
		end)

		it("turns a result into the prize the gift card draws", function()
			expect(PotionLogic.giftPrize("potion", "tip_potion", 1)).to.deepEqual({
				potions = { tip_potion = 1 },
			})
			expect(PotionLogic.giftPrize("lure", "salmon", 2)).to.deepEqual({
				lures = { salmon = 2 },
			})
			expect(PotionLogic.giftPrize("fish", nil, 10)).to.deepEqual({ fish = 10 })
			expect(PotionLogic.giftPrize("spin", nil, 0)).to.deepEqual({ spins = 1 })
			expect(PotionLogic.giftPrize("hat", nil, 1)).to.deepEqual({})
		end)
	end)

	describe("Small and Big sizes share their regular potion's timer (#3344)", function()
		local catalog = {
			potions = {
				{ id = "quick_bait_potion", name = "Quick Bait Potion", minutes = 30 },
				{
					id = "quick_bait_potion_big",
					name = "Big Quick Bait Potion",
					minutes = 60,
					buff = "quick_bait_potion",
				},
			},
		}
		local now = 1000
		local function rowOf(rows: { any }, id: string): any
			for _, row in rows do
				if row.potion.id == id then
					return row
				end
			end
			return nil
		end

		it("reads the regular timer, so a full one greys the Big size's Use", function()
			local state: any = {
				potions = { quick_bait_potion = 3, quick_bait_potion_big = 2 },
				buffs = { quick_bait_potion = now + 1439 * 60 + 15 },
			}
			local big = rowOf(PotionLogic.rows(catalog :: any, state, now), "quick_bait_potion_big")
			expect(big.shared).to.equal(true)
			expect(big.secondsLeft).to.equal(1439 * 60 + 15)
			expect(big.canUse).to.equal(false)
			expect(big.fit).to.equal(0)
		end)

		it(
			"puts a pressed Big size's minutes on the regular timer, not a timer of its own",
			function()
				local state: any = {
					potions = { quick_bait_potion_big = 2 },
					buffs = { quick_bait_potion = now + 600 },
				}
				local shown =
					PotionLogic.ahead(catalog :: any, state, { quick_bait_potion_big = 2 }, now)
				expect(shown.buffs.quick_bait_potion).to.equal(now + 600 + 120 * 60)
				expect(shown.buffs.quick_bait_potion_big).never.to.be.ok()
				expect(shown.potions.quick_bait_potion_big).to.equal(0)
			end
		)

		it("shows one chip per timer, and no Big row once none are left in the bag", function()
			local state: any = { potions = {}, buffs = { quick_bait_potion = now + 600 } }
			local running = PotionLogic.running(catalog :: any, state, now)
			expect(#running).to.equal(1)
			expect(running[1].potion.id).to.equal("quick_bait_potion")
			local owned = PotionLogic.owned(catalog :: any, state, now)
			expect(#owned).to.equal(1)
			expect(owned[1].potion.id).to.equal("quick_bait_potion")
		end)
	end)
end
