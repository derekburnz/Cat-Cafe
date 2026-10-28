--!strict
-- shared/DailyTreat.luau and Catalog.dailyTreat (F70, data-model section 11e): seven stamps, one per UTC day played,
-- never reset; a missed day loses nothing and a full card starts again at day 1. The F70 acceptance: a player who
-- plays on Monday and Thursday has claimed days 1 and 2; day 7 pays all four prizes; a missed week loses nothing.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local DailyTreat = require(Shared.DailyTreat)
	local Types = require(Shared.Types)

	local DAY = 86400
	local MONDAY = 1792972800 -- 2026-10-26 00:00 UTC

	local function fresh(): Types.DailyTreatState
		return { stamp = 0, lastDay = 0 }
	end

	describe("the card's days (Catalog.dailyTreat)", function()
		it("has seven days in order", function()
			expect(DailyTreat.DAYS).to.equal(7)
			for n, row in Catalog.dailyTreat do
				expect(row.day).to.equal(n)
			end
		end)

		it("pays the data-model's prizes", function()
			expect(DailyTreat.prize(1) :: any).to.deepEqual({ coins = 300, coinSeconds = 300 })
			expect(DailyTreat.prize(2) :: any).to.deepEqual({ lures = { salmon = 2 }, fish = 15, spins = 1 })
			expect(DailyTreat.prize(3) :: any).to.deepEqual({ coins = 600, coinSeconds = 600 })
			expect(DailyTreat.prize(4) :: any).to.deepEqual({
				lures = { caviar = 1 },
				crates = { classic_crate = 1 },
				spins = 1,
			})
			expect(DailyTreat.prize(5) :: any).to.deepEqual({ coins = 1000, coinSeconds = 900 })
			expect(DailyTreat.prize(6) :: any).to.deepEqual({ lures = { tuna = 3 }, potions = { lucky_potion = 1 } })
			expect(DailyTreat.prize(7) :: any).to.deepEqual({
				crates = { classic_golden_crate = 1 },
				lures = { star_treat = 1 },
				fish = 50,
				spins = 3,
			})
		end)

		it("names only foods, crates and potions that exist", function()
			for _, row in Catalog.dailyTreat do
				for lureId in row.prize.lures or {} do
					expect(Catalog.getLure(lureId)).to.be.ok()
				end
				for crateId in row.prize.crates or {} do
					expect(Catalog.cratesById[crateId]).to.be.ok()
				end
				for potionId in row.prize.potions or {} do
					local found = false
					for _, potion in Catalog.potions do
						found = found or potion.id == potionId
					end
					expect(found).to.equal(true)
				end
			end
		end)
	end)

	describe("stamping the card", function()
		it("has a stamp due on a fresh card and pays day 1 first", function()
			local card = fresh()
			expect(DailyTreat.due(card, MONDAY)).to.equal(true)
			expect(DailyTreat.nextDay(card)).to.equal(1)
			expect(DailyTreat.claim(card, MONDAY + 3600)).to.equal(1)
			expect(card.stamp).to.equal(1)
			expect(card.lastDay).to.equal(MONDAY // DAY)
		end)

		it("takes one stamp a UTC day, the next at 00:00 UTC", function()
			local card = fresh()
			DailyTreat.claim(card, MONDAY + 60)
			expect(DailyTreat.due(card, MONDAY + DAY - 1)).to.equal(false)
			expect(DailyTreat.claim(card, MONDAY + DAY - 1)).to.equal(nil)
			expect(card.stamp).to.equal(1)
			expect(DailyTreat.due(card, MONDAY + DAY)).to.equal(true)
		end)

		it("gives a Monday and Thursday player days 1 and 2", function()
			local card = fresh()
			expect(DailyTreat.claim(card, MONDAY + 10 * 3600)).to.equal(1)
			expect(DailyTreat.claim(card, MONDAY + 3 * DAY + 20 * 3600)).to.equal(2)
		end)

		it("loses nothing over a missed week", function()
			local card: Types.DailyTreatState = { stamp = 4, lastDay = MONDAY // DAY }
			expect(DailyTreat.claim(card, MONDAY + 8 * DAY)).to.equal(5)
		end)

		it("starts a fresh card at day 1 after day 7", function()
			local card = fresh()
			for day = 1, 7 do
				expect(DailyTreat.claim(card, MONDAY + (day - 1) * DAY)).to.equal(day)
			end
			expect(DailyTreat.nextDay(card)).to.equal(1)
			expect(DailyTreat.claim(card, MONDAY + 7 * DAY)).to.equal(1)
			expect(card.stamp).to.equal(1)
		end)
	end)

	describe("what ProfileSync sends", function()
		it("shows the card, whether a stamp is due and the day it pays", function()
			local card: Types.DailyTreatState = { stamp = 6, lastDay = MONDAY // DAY }
			expect(DailyTreat.view(card, MONDAY + 60) :: any).to.deepEqual({
				stamp = 6,
				lastDay = MONDAY // DAY,
				due = false,
				nextDay = 7,
			})
			expect(DailyTreat.view(card, MONDAY + DAY).due).to.equal(true)
		end)
	end)

	describe("a save's card", function()
		it("comes back whole and in range, a fresh card from anything else", function()
			local now = MONDAY + 60
			expect(DailyTreat.sanitize({ stamp = 2.7, lastDay = 20000.5 }, now) :: any).to.deepEqual({
				stamp = 2,
				lastDay = 20000,
			})
			expect(DailyTreat.sanitize({ stamp = 99, lastDay = 99999 }, now) :: any).to.deepEqual({
				stamp = 7,
				lastDay = MONDAY // DAY,
			})
			expect(DailyTreat.sanitize({ stamp = "3", lastDay = -5 }, now) :: any).to.deepEqual({
				stamp = 0,
				lastDay = 0,
			})
			expect(DailyTreat.sanitize(nil, now) :: any).to.deepEqual({ stamp = 0, lastDay = 0 })
		end)
	end)
end
