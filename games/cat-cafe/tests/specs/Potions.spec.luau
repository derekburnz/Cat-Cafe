--!strict
-- shared/Potions.luau and the potion rows (F64, data-model section 12b): time left that pauses while away, the 60
-- minute cap that refuses a drink whole (v0.13.8), each potion's effect, the Tip Potion's split in Economy.settle,
-- the save's sanitizing and the Mystery gift's roll.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function fresh(now: number?): any
		local profile: any = ProfileSchema.template(now or 1000)
		profile.lastTick = now or 1000
		return profile
	end

	describe("Catalog.potions and Catalog.mysteryGift (section 12b)", function()
		it("has the four potions in bag order with the design's minutes", function()
			local minutes: { [string]: number } = {}
			local order: { string } = {}
			for _, def in Catalog.potions do
				minutes[def.id] = def.minutes
				table.insert(order, def.id)
				expect(Catalog.getPotion(def.id)).to.equal(def)
				expect(#def.name > 0 and #def.effect > 0).to.equal(true)
			end
			expect(order).to.deepEqual({ "tip_potion", "lucky_potion", "swift_potion", "steady_potion" })
			expect(minutes).to.deepEqual({ tip_potion = 10, lucky_potion = 10, swift_potion = 5, steady_potion = 10 })
			expect(Catalog.getPotion("nope")).never.to.be.ok()
		end)

		it("shows the gift's chances summing to 100: a potion 60, 2 Salmon 20, 10 fish 10, a spin 10", function()
			local total = 0
			for _, row in Catalog.mysteryGift do
				total += row.chance
			end
			expect(total).to.equal(100)
			expect(Catalog.mysteryGift :: any).to.deepEqual({
				{ kind = "potion", count = 1, chance = 60 },
				{ kind = "lure", id = "salmon", count = 2, chance = 20 },
				{ kind = "fish", count = 10, chance = 10 },
				{ kind = "spin", count = 1, chance = 10 },
			})
			expect(Catalog.getLure("salmon")).to.be.ok()
		end)
	end)

	describe("time left and drinking (UsePotion)", function()
		it("counts down from lastTick, so a read between settles is exact, and never below 0", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 600
			expect(Potions.left(p, "tip_potion", 1000)).to.equal(600)
			expect(Potions.left(p, "tip_potion", 1100)).to.equal(500)
			expect(Potions.left(p, "tip_potion", 2000)).to.equal(0)
			expect(Potions.running(p, "tip_potion", 1599)).to.equal(true)
			expect(Potions.running(p, "tip_potion", 1600)).to.equal(false)
			expect(Potions.left(p, "lucky_potion", 1000)).to.equal(0)
		end)

		it("drinks one: the bag loses it, its minutes run, potionsUsed counts", function()
			local p = fresh(1000)
			p.potions.tip_potion = 2
			expect(Potions.useBlocker(p, "tip_potion", 1000)).to.equal(nil)
			expect(Potions.use(p, "tip_potion", 1000)).to.equal(true)
			expect(p.potions.tip_potion).to.equal(1)
			expect(Potions.left(p, "tip_potion", 1000)).to.equal(600)
			expect(p.stats.potionsUsed).to.equal(1)
			-- the second of the same kind adds its time and empties the bag's row
			expect(Potions.use(p, "tip_potion", 1000)).to.equal(true)
			expect(p.potions.tip_potion).to.equal(nil)
			expect(Potions.left(p, "tip_potion", 1000)).to.equal(1200)
			expect(Potions.useBlocker(p, "tip_potion", 1000)).to.equal("None")
			expect(Potions.use(p, "tip_potion", 1000)).to.equal(false)
		end)

		it("adds the time right even when lastTick is behind now", function()
			local p = fresh(1000)
			p.potions.swift_potion = 1
			p.buffs.swift_potion = 100 -- 100 s left at 1000, 40 at 1060
			Potions.use(p, "swift_potion", 1060)
			expect(Potions.left(p, "swift_potion", 1060)).to.equal(40 + 300)
		end)

		it("refuses a drink whole when it would pass PotionMaxMinutes (v0.13.8)", function()
			local p = fresh(1000)
			p.potions.tip_potion = 1
			local max = Config.PotionMaxMinutes * 60
			p.buffs.tip_potion = max - 600 -- exactly room for one more 10 minute potion
			expect(Potions.useBlocker(p, "tip_potion", 1000)).to.equal(nil)
			p.buffs.tip_potion = max - 599 -- a second short: Full, nothing used
			expect(Potions.useBlocker(p, "tip_potion", 1000)).to.equal("Full")
			expect(Potions.use(p, "tip_potion", 1000)).to.equal(false)
			expect(p.potions.tip_potion).to.equal(1)
			expect(p.buffs.tip_potion).to.equal(max - 599)
			-- once a second of play has passed it fits
			expect(Potions.useBlocker(p, "tip_potion", 1001)).to.equal(nil)
			expect(Potions.useBlocker(p, "nope", 1000)).to.equal("Unknown")
		end)

		it("ticks every timer down by the time played and drops the ones that ran out", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 30
			p.buffs.swift_potion = 10
			Potions.tick(p, 10)
			expect(p.buffs.tip_potion).to.equal(20)
			expect(p.buffs.swift_potion).to.equal(nil)
		end)

		it("orders a rejoin's running potions by time left, least first, and sends endsAt in server time", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 500
			p.buffs.lucky_potion = 20
			p.buffs.steady_potion = 300
			expect(Potions.runningIds(p, 1000)).to.deepEqual({ "lucky_potion", "steady_potion", "tip_potion" })
			expect(Potions.runningIds(p, 1100)).to.deepEqual({ "steady_potion", "tip_potion" })
			expect(Potions.endsAt(p, 1100)).to.deepEqual({ steady_potion = 1300, tip_potion = 1500 })
		end)
	end)

	describe("effects", function()
		it("Tip +25%, Swift +4 speed, Lucky doubles the bait gold chance, Steady the next net level", function()
			local p = fresh(1000)
			expect(Potions.tipMultiplier(p, 1000)).to.equal(1)
			expect(Potions.speedBonus(p, 1000)).to.equal(0)
			expect(Potions.baitGoldChance(p, 0.05, 1000)).to.be.near(0.05)
			expect(Potions.netLevel(p, 1, 1000)).to.equal(1)
			p.buffs.tip_potion = 60
			p.buffs.swift_potion = 60
			p.buffs.lucky_potion = 60
			p.buffs.steady_potion = 60
			expect(Potions.tipMultiplier(p, 1000)).to.be.near(1.25)
			expect(Potions.speedBonus(p, 1000)).to.equal(4)
			expect(Potions.baitGoldChance(p, 0.05, 1000)).to.be.near(0.10)
			expect(Potions.netLevel(p, 1, 1000)).to.equal(2)
			-- Circles clamps the level, so a Master net stays Master
			local Circles = require(Shared.Circles)
			expect(Circles.windows(Potions.netLevel(p, 3, 1000))).to.equal(Circles.windows(3))
		end)

		it("settle pays the Tip Potion's share only over the part of the window it covers", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 4 -- 4 of the 10 s get +25%
			local rate = Economy.incomePerSecond(p)
			local earned = Economy.settle(p, 1010)
			expect(earned).to.be.near(rate * (10 + 4 * Config.TipPotionBonus))
			expect(p.buffs.tip_potion).to.equal(nil)
		end)

		it("splits the Tip Potion's share at nightfall too", function()
			local epoch = 1000
			local dusk = epoch + Config.ServerStartDaySeconds
			local p = fresh(dusk - 20) -- 20 s of day, then 30 s of night, the potion over the first 40
			p.buffs.tip_potion = 40
			local rate = Economy.incomePerSecond(p)
			local night = Config.NightIncomeMultiplier
			local earned = Economy.settle(p, dusk + 30, epoch)
			local base = 20 + 30 * night
			local boosted = 20 + 20 * night
			expect(earned).to.be.near(rate * (base + boosted * Config.TipPotionBonus))
		end)

		it("pauses while away: the gap before a join settles nothing, so no time comes off", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 480
			-- DataService.load resets lastTick on join; an hour later the potion still has 8 minutes
			p.lastTick = 1000 + 3600
			Economy.settle(p, 1000 + 3600)
			expect(Potions.left(p, "tip_potion", 1000 + 3600)).to.equal(480)
		end)
	end)

	describe("the save (version 13)", function()
		it("keeps known potions and buffs, drops unknown ids, zeros and junk, and clamps time to the cap", function()
			local raw = ProfileSchema.template(1000) :: any
			raw.potions = { tip_potion = 3, swift_potion = 0, nope = 5, lucky_potion = -2, steady_potion = "x" }
			raw.buffs = { tip_potion = 99999, lucky_potion = 120.5, swift_potion = -1, nope = 30 }
			local p = ProfileSchema.migrate(raw, 2000)
			expect(p.potions).to.deepEqual({ tip_potion = 3 })
			expect(p.buffs).to.deepEqual({ tip_potion = Config.PotionMaxMinutes * 60, lucky_potion = 120.5 })
		end)

		it("gives a save from before version 13 an empty bag", function()
			local raw = ProfileSchema.template(1000) :: any
			raw.version = 12
			raw.potions = nil
			raw.buffs = nil
			local p = ProfileSchema.migrate(raw, 2000)
			expect(next(p.potions)).never.to.be.ok()
			expect(next(p.buffs)).never.to.be.ok()
			expect(p.version).to.equal(13)
		end)
	end)

	describe("the Mystery gift's roll", function()
		local function rolls(values: { number }): () -> number
			local i = 0
			return function()
				i += 1
				return values[i] or 0
			end
		end

		it("picks each row at its chance and a potion at even odds", function()
			expect(Potions.rollGift(rolls({ 0, 0 })) :: any).to.deepEqual({ kind = "potion", id = "tip_potion", count = 1 })
			expect(Potions.rollGift(rolls({ 0.59, 0.99 })) :: any).to.deepEqual({
				kind = "potion",
				id = "steady_potion",
				count = 1,
			})
			expect(Potions.rollGift(rolls({ 0.6 })) :: any).to.deepEqual({ kind = "lure", id = "salmon", count = 2 })
			expect(Potions.rollGift(rolls({ 0.85 })) :: any).to.deepEqual({ kind = "fish", count = 10 })
			expect(Potions.rollGift(rolls({ 0.95 })) :: any).to.deepEqual({ kind = "spin", count = 1 })
			expect(Potions.rollGift(rolls({ 0.9999 })) :: any).to.deepEqual({ kind = "spin", count = 1 })
		end)

		it("turns a gift into the prize shape Payout pays", function()
			expect(Potions.giftPrize({ kind = "potion", id = "lucky_potion", count = 1 }) :: any).to.deepEqual({
				potions = { lucky_potion = 1 },
			})
			expect(Potions.giftPrize({ kind = "lure", id = "salmon", count = 2 }) :: any).to.deepEqual({
				lures = { salmon = 2 },
			})
			expect(Potions.giftPrize({ kind = "fish", count = 10 }) :: any).to.deepEqual({ fish = 10 })
			expect(Potions.giftPrize({ kind = "spin", count = 1 }) :: any).to.deepEqual({ spins = 1 })
		end)
	end)

	describe("potion edges (QA)", function()
		it("refuses a 10 minute potion at 55 minutes left and takes it at 50; a Swift fits at 55 exactly", function()
			local p = fresh(1000)
			p.potions.tip_potion = 1
			p.potions.swift_potion = 1
			p.buffs.tip_potion = 55 * 60
			expect(Potions.useBlocker(p, "tip_potion", 1000)).to.equal("Full")
			p.buffs.tip_potion = 50 * 60
			expect(Potions.useBlocker(p, "tip_potion", 1000)).to.equal(nil)
			p.buffs.swift_potion = 55 * 60
			expect(Potions.useBlocker(p, "swift_potion", 1000)).to.equal(nil)
			p.buffs.swift_potion = 55 * 60 + 1
			expect(Potions.useBlocker(p, "swift_potion", 1000)).to.equal("Full")
		end)

		it("leaves the bag, the timer and potionsUsed alone on every refusal", function()
			local p = fresh(1000)
			p.buffs.lucky_potion = 120
			expect(Potions.use(p, "lucky_potion", 1000)).to.equal(false) -- none in the bag
			expect(Potions.use(p, "nope", 1000)).to.equal(false)
			expect(p.buffs.lucky_potion).to.equal(120)
			expect(p.potions.lucky_potion).to.equal(nil)
			expect(p.stats.potionsUsed or 0).to.equal(0)
		end)

		it("never adds time when lastTick is ahead of now, and reads junk timers as not running", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 100
			expect(Potions.left(p, "tip_potion", 900)).to.equal(100)
			p.buffs.tip_potion = 0 / 0
			expect(Potions.running(p, "tip_potion", 1000)).to.equal(false)
			p.buffs.tip_potion = "600"
			expect(Potions.left(p, "tip_potion", 1000)).to.equal(0)
			expect(Potions.tipMultiplier(p, 1000)).to.equal(1)
			p.buffs.swift_potion = 1
			expect(Potions.speedBonus(p, 1001)).to.equal(0) -- the second it ends, the speed goes
		end)

		it("ticks nothing for no time or negative time", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 30
			Potions.tick(p, 0)
			Potions.tick(p, -50)
			expect(p.buffs.tip_potion).to.equal(30)
		end)

		it("breaks a tie in time left by id, so a rejoin's order is fixed", function()
			local p = fresh(1000)
			p.buffs.tip_potion = 300
			p.buffs.lucky_potion = 300
			p.buffs.swift_potion = 300
			expect(Potions.runningIds(p, 1000)).to.deepEqual({ "lucky_potion", "swift_potion", "tip_potion" })
		end)

		it("rolls only real gifts: a known potion, a known food, counts above 0, and the last row past 100", function()
			local seen: { [string]: boolean } = {}
			for i = 0, 99 do
				for j = 0, 9 do
					local values = { i / 100 + 0.004, j / 10 + 0.05 }
					local n = 0
					local gift = Potions.rollGift(function()
						n += 1
						return values[n] or 0
					end)
					expect(gift.count > 0).to.equal(true)
					if gift.kind == "potion" then
						expect(Catalog.getPotion(gift.id :: string) ~= nil).to.equal(true)
					elseif gift.kind == "lure" then
						expect(Catalog.getLure(gift.id :: string) ~= nil).to.equal(true)
					end
					seen[gift.kind .. ":" .. tostring(gift.id)] = true
				end
			end
			for _, def in Catalog.potions do
				expect(seen["potion:" .. def.id]).to.equal(true)
			end
			expect(seen["lure:salmon"] and seen["fish:nil"] and seen["spin:nil"]).to.equal(true)
			local over = Potions.rollGift(function()
				return 1
			end)
			expect(over.kind).to.equal("spin")
		end)

		it("pays nothing for a gift it cannot name", function()
			expect(Potions.giftPrize({ kind = "potion", count = 1 } :: any) :: any).to.deepEqual({})
			expect(Potions.giftPrize({ kind = "lure", count = 2 } :: any) :: any).to.deepEqual({})
			expect(Potions.giftPrize({ kind = "hat", id = "x", count = 1 } :: any) :: any).to.deepEqual({})
		end)

		it("keeps the Config numbers the relay and data-model 12b give", function()
			expect(Config.MysteryStaySeconds).to.equal(120)
			expect(Config.MysteryGiftKeepSeconds).to.equal(600)
			expect(Config.MysteryRangeStuds).to.equal(12)
			expect(Config.PotionMaxMinutes).to.equal(60)
			expect(Config.TipPotionBonus).to.equal(0.25)
			expect(Config.SwiftPotionSpeed).to.equal(4)
			expect(Config.LuckyPotionGoldScale).to.equal(2)
		end)
	end)
end
