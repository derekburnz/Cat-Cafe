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
			expect(list[1].effect).to.equal("+25% tips")
		end)

		it("follows the catalog's order and keeps the bag's short line for known potions", function()
			local catalog = {
				potions = {
					{ id = "swift_potion", name = "Swift Potion", minutes = 5, effect = "server words" },
					{ id = "tip_potion", minutes = 10 },
				},
			}
			local list = PotionLogic.list(catalog)
			expect(#list).to.equal(2)
			expect(list[1].id).to.equal("swift_potion")
			expect(list[1].effect).to.equal("+4 walk speed")
			expect(list[2].name).to.equal("Tip Potion")
		end)

		it("names an unknown potion from its id and uses the catalog's effect", function()
			local list = PotionLogic.list({ potions = { { id = "moon_potion", minutes = 15, effect = "Glows" } } })
			expect(list[1].name).to.equal("Moon Potion")
			expect(list[1].minutes).to.equal(15)
			expect(list[1].effect).to.equal("Glows")
		end)

		it("skips rows without an id", function()
			local list = PotionLogic.list({ potions = { { name = "No id" }, { id = "tip_potion" } } })
			expect(#list).to.equal(1)
		end)
	end)

	describe("PotionLogic.rows", function()
		it("counts the bag and the time left from endsAt", function()
			local rows = PotionLogic.rows(nil, state({ tip_potion = 2 }, { tip_potion = NOW + 90 }), NOW)
			expect(rows[1].count).to.equal(2)
			expect(rows[1].secondsLeft).to.equal(90)
			expect(rows[2].count).to.equal(0)
			expect(rows[2].secondsLeft).to.equal(0)
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

		it("shows a potion the catalog does not name yet, after the rest, in id order", function()
			local rows = PotionLogic.rows(nil, state({ zeta_potion = 1, big_tip_potion = 1 }, { alpha_potion = NOW + 5 }), NOW)
			expect(ids(rows)).to.equal(
				"tip_potion,lucky_potion,swift_potion,steady_potion,alpha_potion,big_tip_potion,zeta_potion"
			)
			expect(rows[6].potion.name).to.equal("Big Tip Potion")
			expect(rows[7].potion.name).to.equal("Zeta Potion")
		end)

		it("reads a finished or broken timer as not running", function()
			local rows = PotionLogic.rows(nil, state(nil, { tip_potion = NOW - 5, lucky_potion = 0 / 0 }), NOW)
			expect(rows[1].secondsLeft).to.equal(0)
			expect(rows[2].secondsLeft).to.equal(0)
		end)
	end)

	describe("PotionLogic.running", function()
		it("keeps only the potions with time left, in bag order", function()
			local running = PotionLogic.running(
				nil,
				state({}, { steady_potion = NOW + 30, tip_potion = NOW + 600, lucky_potion = NOW - 1 }),
				NOW
			)
			expect(ids(running)).to.equal("tip_potion,steady_potion")
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
				state({}, { gold_rush_potion = NOW + 1, quick_bait_potion = NOW - 1, lucky_potion = NOW }),
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
			local rows = PotionLogic.giftRows({ mysteryGift = { { kind = "fish", count = 25, chance = 100 } } })
			expect(#rows).to.equal(1)
			expect(rows[1].count).to.equal(25)
		end)

		it("lists the chances in one short line", function()
			expect(PotionLogic.giftLine(PotionLogic.giftRows(nil), foodName)).to.equal(
				"Potion 60%  ·  2 Salmon 20%  ·  10 golden fish 10%  ·  1 spin 10%"
			)
		end)

		it("names what a gift held", function()
			expect(PotionLogic.giftTitle("potion", "tip_potion", 1, noFood)).to.equal("Tip Potion")
			expect(PotionLogic.giftTitle("potion", "tip_potion", 2, noFood)).to.equal("2 Tip Potions")
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
			expect(PotionLogic.giftTitle("potion", "tip_potion", 1, noFood, potionName)).to.equal("Tippy Tonic")
		end)

		it("turns a result into the prize the gift card draws", function()
			expect(PotionLogic.giftPrize("potion", "tip_potion", 1)).to.deepEqual({ potions = { tip_potion = 1 } })
			expect(PotionLogic.giftPrize("lure", "salmon", 2)).to.deepEqual({ lures = { salmon = 2 } })
			expect(PotionLogic.giftPrize("fish", nil, 10)).to.deepEqual({ fish = 10 })
			expect(PotionLogic.giftPrize("spin", nil, 0)).to.deepEqual({ spins = 1 })
			expect(PotionLogic.giftPrize("hat", nil, 1)).to.deepEqual({})
		end)
	end)
end
