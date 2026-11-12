--!strict
-- #3360 (rich-money-bags.md): shared/RichBags, the rules for the money bags a rich customer leaves. RichTipService
-- (Studio-only: Players, plots, remotes) holds and pays them with these.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local RichBags = require(Shared.RichBags)

	local function bag(
		serial: number,
		slot: number,
		droppedAt: number,
		seconds: number?
	): RichBags.Bag
		return {
			id = RichBags.idOf(serial),
			slot = slot,
			amount = 100 * serial,
			boost = 1,
			droppedAt = droppedAt,
			expiresAt = droppedAt + (seconds or Config.RichBagSeconds),
			first = false,
		}
	end

	describe("money bags (#3360)", function()
		it("waits 180 s, twice the old 90, three at once, the customer sitting 20 s", function()
			expect(Config.RichBagSeconds).to.equal(180)
			expect(Config.RichBagsMax).to.equal(3)
			expect(Config.RichCustomerSitSeconds).to.equal(20)
			expect(#RichBags.SLOTS >= Config.RichBagsMax).to.equal(true)
		end)

		it("gives each bag its own slot, the lowest free, and none past the cap", function()
			local bags: { RichBags.Bag } = {}
			expect(RichBags.freeSlot(bags)).to.equal(1)
			table.insert(bags, bag(1, 1, 0))
			expect(RichBags.freeSlot(bags)).to.equal(2)
			table.insert(bags, bag(2, 2, 10))
			table.insert(bags, bag(3, 3, 20))
			expect(RichBags.freeSlot(bags)).to.equal(nil)
			-- the middle one goes: the next bag takes its spot
			expect(RichBags.remove(bags, "b2") ~= nil).to.equal(true)
			expect(RichBags.freeSlot(bags)).to.equal(2)
		end)

		it("keeps the slots on the table and clear of each other", function()
			for i, a in RichBags.SLOTS do
				expect(math.abs(a.x) <= 1.5 and math.abs(a.z) <= 0.5).to.equal(true)
				for j, b in RichBags.SLOTS do
					if i ~= j then
						local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
						expect(gap >= 1.2).to.equal(true) -- a pile is about 1.1 across
					end
				end
			end
			expect(RichBags.offset(99)).to.equal(RichBags.SLOTS[#RichBags.SLOTS])
		end)

		it(
			"shows the bag that goes first, a first visit's longer wait behind a later one",
			function()
				local bags = { bag(1, 1, 0, 300), bag(2, 2, 50) }
				expect(assert(RichBags.front(bags)).id).to.equal("b2") -- 230 before 300
				expect(RichBags.front({})).to.equal(nil)
				local tie = { bag(5, 1, 10), bag(4, 2, 10) }
				tie[2].droppedAt = 5
				tie[2].expiresAt = tie[1].expiresAt
				expect(assert(RichBags.front(tie)).id).to.equal("b4") -- the older on a tie
			end
		)

		it("a bag is found by its id and taken out exactly once (S29)", function()
			local bags = { bag(1, 1, 0), bag(2, 2, 5) }
			expect(assert(RichBags.find(bags, "b2")).amount).to.equal(200)
			expect(RichBags.find(bags, "b9")).to.equal(nil)
			expect(assert(RichBags.remove(bags, "b1")).amount).to.equal(100)
			expect(RichBags.remove(bags, "b1")).to.equal(nil)
			expect(#bags).to.equal(1)
			expect(RichBags.total(bags)).to.equal(200)
		end)

		it("is up at its own time only: full time from the drop, whatever the hour", function()
			local bags = { bag(1, 1, 1000), bag(2, 2, 1100) }
			expect(#RichBags.expired(bags, 1000 + Config.RichBagSeconds - 1)).to.equal(0)
			expect(RichBags.expired(bags, 1000 + Config.RichBagSeconds) :: any).to.deepEqual({
				"b1",
			})
			expect(#RichBags.expired(bags, 1100 + Config.RichBagSeconds)).to.equal(2)
		end)

		it(
			"names the records with no bag behind them, which nobody could collect (#3632)",
			function()
				local bags = { bag(1, 1, 1000), bag(3, 2, 1010) }
				local orphans = RichBags.orphans({ "b1", "b2", "b3", "b9" }, bags)
				expect(#orphans).to.equal(2)
				expect(orphans[1]).to.equal("b2")
				expect(orphans[2]).to.equal("b9")
				expect(#RichBags.orphans({ "b1", "b3" }, bags)).to.equal(0)
				expect(#RichBags.orphans({ "b1" }, {})).to.equal(1)
			end
		)

		it("makes ids ClaimRichTip's guard accepts", function()
			expect(RichBags.idOf(12)).to.equal("b12")
			expect(string.match(RichBags.idOf(12), "^[%l%d_%-]+$") ~= nil).to.equal(true)
		end)
	end)
end
