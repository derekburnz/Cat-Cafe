--!strict
-- UI/Components/MoneyCardLogic.luau: the HUD Money button's boost card (#4437).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("MoneyCardLogic")
	) :: any

	local CONFIG = { MoneyPassIds = { [2] = 1002, [3] = 1003, [4] = 1004 } }

	describe("MoneyCardLogic.rungOf", function()
		it("finds the rung of a Money pass id", function()
			expect(Logic.rungOf(CONFIG, 1002)).to.equal(2)
			expect(Logic.rungOf(CONFIG, 1004)).to.equal(4)
		end)
		it("is nil for any other id", function()
			expect(Logic.rungOf(CONFIG, 999)).to.equal(nil)
			expect(Logic.rungOf(CONFIG, 0)).to.equal(nil)
			expect(Logic.rungOf(CONFIG, "1002")).to.equal(nil)
			expect(Logic.rungOf({}, 1002)).to.equal(nil)
		end)
	end)

	describe("MoneyCardLogic.offer", function()
		it("opens once a session, for a rung above the cafe's", function()
			expect(Logic.offer({ on = true, shown = false, rung = 2, current = 1 })).to.equal(true)
			expect(Logic.offer({ on = true, shown = true, rung = 2, current = 1 })).to.equal(false)
			expect(Logic.offer({ on = true, shown = false, rung = 3, current = 2 })).to.equal(true)
		end)
		it("prompts as before with the switch off, an owned rung or an unknown pass", function()
			expect(Logic.offer({ on = false, shown = false, rung = 2, current = 1 })).to.equal(
				false
			)
			expect(Logic.offer({ on = true, shown = false, rung = 2, current = 2 })).to.equal(false)
			expect(Logic.offer({ on = true, shown = false, rung = nil, current = 1 })).to.equal(
				false
			)
		end)
	end)

	describe("MoneyCardLogic.view", function()
		it("says the money a minute now and with the pass, and the price", function()
			local view = Logic.view(2, 180, 360, 49)
			expect(view.title).to.equal("2x Money")
			expect(view.subtitle).to.equal("Yours forever")
			expect(view.now).to.equal("$180 a minute")
			expect(view.with).to.equal("$360 a minute")
			expect(view.withLabel).to.equal("With 2x Money")
			expect(view.plain).to.equal(nil)
			expect(view.buy).to.equal("Buy R$49")
		end)
		it("writes big numbers short", function()
			local view = Logic.view(3, 120000, 180000, 99)
			expect(view.now).to.equal("$120K a minute")
			expect(view.with).to.equal("$180K a minute")
		end)
		it(
			"drops the numbers while the cafe makes nothing, and the price until it is known",
			function()
				local view = Logic.view(2, 0, 0, nil)
				expect(view.now).to.equal(nil)
				expect(view.with).to.equal(nil)
				expect(type(view.plain)).to.equal("string")
				expect(view.buy).to.equal("Buy")
			end
		)
	end)
end
