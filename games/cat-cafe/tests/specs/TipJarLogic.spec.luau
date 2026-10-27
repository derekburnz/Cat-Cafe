--!strict
-- UI/Components/TipJarLogic.luau: the Tip Jar's playtime gifts (F47, data-model section 11b).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local TipJarLogic = require(Components:WaitForChild("TipJarLogic")) :: any

	local ROWS = {
		{ step = 2, minutes = 5, kind = "lure", lureId = "kibble", count = 2 },
		{ step = 1, minutes = 2, kind = "coins", seconds = 30, minCoins = 50 },
		{ step = 3, minutes = 10, kind = "coins", seconds = 60, minCoins = 100 },
	}

	describe("TipJarLogic.coins", function()
		it("pays the day rate times the seconds, never under the minimum", function()
			expect(TipJarLogic.coins(ROWS[2], 10)).to.equal(300)
			expect(TipJarLogic.coins(ROWS[2], 1)).to.equal(50)
			expect(TipJarLogic.coins(ROWS[2], 2.9)).to.equal(87)
			expect(TipJarLogic.coins(ROWS[2], -5)).to.equal(50)
		end)

		it("undoes the night share for the day rate", function()
			expect(TipJarLogic.dayRate(6, true, 0.6)).to.be.near(10, 1e-9)
			expect(TipJarLogic.dayRate(6, false, 0.6)).to.equal(6)
			expect(TipJarLogic.dayRate(6, true, 0)).to.equal(6)
		end)
	end)

	describe("TipJarLogic.views", function()
		it("orders by step and counts down from the session start", function()
			local views = TipJarLogic.views(ROWS, { sessionStartedAt = 1000, claimed = {} }, 1000 + 90)
			expect(#views).to.equal(3)
			expect(views[1].row.step).to.equal(1)
			expect(views[1].state).to.equal("waiting")
			expect(views[1].remaining).to.equal(30)
			expect(views[3].remaining).to.equal(510)
		end)

		it("marks reached steps ready and claimed steps claimed, with string keys too", function()
			local jar = { sessionStartedAt = 0, claimed = { ["1"] = true } }
			local views = TipJarLogic.views(ROWS, jar, 6 * 60)
			expect(views[1].state).to.equal("claimed")
			expect(views[2].state).to.equal("ready")
			expect(views[3].state).to.equal("waiting")
			expect(TipJarLogic.isClaimed({ sessionStartedAt = 0, claimed = { [2] = true } }, 2)).to.equal(true)
			expect(TipJarLogic.isClaimed(nil, 2)).to.equal(false)
		end)

		it("waits on everything before the first TipJarState", function()
			local views = TipJarLogic.views(ROWS, nil, 99999)
			for _, view in views do
				expect(view.state).to.equal("waiting")
			end
		end)
	end)

	describe("TipJarLogic.summary", function()
		it("counts ready gifts, gifts left and the soonest wait", function()
			local jar = { sessionStartedAt = 0, claimed = { [1] = true } }
			local summary = TipJarLogic.summary(TipJarLogic.views(ROWS, jar, 6 * 60))
			expect(summary.ready).to.equal(1)
			expect(summary.left).to.equal(2)
			expect(summary.nextIn).to.equal(240)
		end)

		it("has no wait once every gift is claimed", function()
			local jar = { sessionStartedAt = 0, claimed = { [1] = true, [2] = true, [3] = true } }
			local summary = TipJarLogic.summary(TipJarLogic.views(ROWS, jar, 0))
			expect(summary.left).to.equal(0)
			expect(summary.nextIn).to.equal(nil)
		end)
	end)

	describe("TipJarLogic.clock", function()
		it("reads m:ss under an hour and h:mm:ss past it", function()
			expect(TipJarLogic.clock(0)).to.equal("0:00")
			expect(TipJarLogic.clock(245)).to.equal("4:05")
			expect(TipJarLogic.clock(244.2)).to.equal("4:05")
			expect(TipJarLogic.clock(3725)).to.equal("1:02:05")
		end)
	end)
end
