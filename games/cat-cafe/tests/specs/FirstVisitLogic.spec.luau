--!strict
-- UI/Components/FirstVisitLogic.luau: the first rich customer, Mystery Visitor and Collector's arrival (#2792).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FirstVisitLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FirstVisitLogic")
	) :: any

	describe("FirstVisitLogic", function()
		it("reads the three kinds from the plot's attribute and nothing else", function()
			expect(FirstVisitLogic.kind("rich")).to.equal("rich")
			expect(FirstVisitLogic.kind("mystery")).to.equal("mystery")
			expect(FirstVisitLogic.kind("collector")).to.equal("collector")
			expect(FirstVisitLogic.kind(nil)).to.equal(nil)
			expect(FirstVisitLogic.kind("")).to.equal(nil)
			expect(FirstVisitLogic.kind(3)).to.equal(nil)
		end)

		it("is away past the cafe, and not before the character loads", function()
			expect(FirstVisitLogic.away(nil)).to.equal(false)
			expect(FirstVisitLogic.away(10)).to.equal(false)
			expect(FirstVisitLogic.away(FirstVisitLogic.AWAY_STUDS + 1)).to.equal(true)
			expect(FirstVisitLogic.away(0 / 0)).to.equal(false)
		end)

		it(
			"asks with Go when away, toasts at the cafe, and leaves the Collector to the server's toast",
			function()
				local how, text = FirstVisitLogic.show("rich", true)
				expect(how).to.equal("card")
				expect(text).to.equal("💰 A rich customer is at your cafe!")
				expect((FirstVisitLogic.show("mystery", false))).to.equal("toast")
				expect((FirstVisitLogic.show("collector", true))).to.equal("card")
				expect((FirstVisitLogic.show("collector", false))).to.equal(nil)
				expect((FirstVisitLogic.show("nope", true))).to.equal(nil)
				-- the call waits while the tutorial is under way and the player is away from the cafe
				expect(FirstVisitLogic.holds(4, true)).to.equal(true)
				expect(FirstVisitLogic.holds(0, true)).to.equal(true)
				expect(FirstVisitLogic.holds(4, false)).to.equal(false)
				expect(FirstVisitLogic.holds(5, true)).to.equal(false)
				expect(FirstVisitLogic.holds(nil, true)).to.equal(false)
				-- the walk-through's last cannon line is still up at step 5: the call waits for it too
				expect(FirstVisitLogic.holds(5, true, true)).to.equal(true)
				expect(FirstVisitLogic.holds(5, true, false)).to.equal(false)
				expect(FirstVisitLogic.holds(5, false, true)).to.equal(false)
				expect(FirstVisitLogic.holds(nil, true, true)).to.equal(true)
				-- #3891: below Tier 2 every call waits, at the cafe too; from Tier 2 the old rules
				expect(FirstVisitLogic.holds(5, false, false, 1)).to.equal(true)
				expect(FirstVisitLogic.holds(5, true, false, 1)).to.equal(true)
				expect(FirstVisitLogic.holds(5, false, false, 2)).to.equal(false)
				expect(FirstVisitLogic.holds(5, true, false, 3)).to.equal(false)
				expect(FirstVisitLogic.holds(4, true, false, 2)).to.equal(true)
				-- #3620: a window or the "Unlocked!" perk card holds the call and makes a shown card step aside
				expect(FirstVisitLogic.yields(nil, false)).to.equal(false)
				expect(FirstVisitLogic.yields(nil, nil)).to.equal(false)
				expect(FirstVisitLogic.yields("DailyTreat", false)).to.equal(true)
				expect(FirstVisitLogic.yields(nil, true)).to.equal(true)
				expect(FirstVisitLogic.yields("Store", true)).to.equal(true)
				expect(FirstVisitLogic.YIELD_STEP > 0 and FirstVisitLogic.YIELD_STEP <= 0.5).to.equal(
					true
				)
			end
		)
	end)
end
