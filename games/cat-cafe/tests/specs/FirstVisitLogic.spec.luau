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
			end
		)
	end)
end
