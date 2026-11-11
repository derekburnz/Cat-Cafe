--!strict
-- UI/Components/LoadingCount.luau: the loading screen's count from 0 to 100 (#3109).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local LoadingCount = require(Components:WaitForChild("LoadingCount")) :: any

	describe("LoadingCount.creep", function()
		it("starts at 0, climbs fast and never passes CREEP_TOP", function()
			expect(LoadingCount.creep(0)).to.equal(0)
			expect(LoadingCount.creep(-1)).to.equal(0)
			expect(LoadingCount.creep(0 / 0)).to.equal(0)
			expect(LoadingCount.creep(LoadingCount.CREEP_HALF)).to.be.near(
				LoadingCount.CREEP_TOP / 2,
				0.001
			)
			local last = 0
			for step = 1, 200 do
				local value = LoadingCount.creep(step * 0.1)
				expect(value >= last).to.equal(true)
				expect(value <= LoadingCount.CREEP_TOP).to.equal(true)
				last = value
			end
			expect(LoadingCount.CREEP_TOP < LoadingCount.FULL).to.equal(true)
		end)
	end)

	describe("LoadingCount.raceSeconds", function()
		it(
			"fills SHOWN_MIN when the save came at once and takes RACE_MIN after a long wait",
			function()
				expect(LoadingCount.raceSeconds(0)).to.equal(LoadingCount.SHOWN_MIN)
				expect(LoadingCount.raceSeconds(-3)).to.equal(LoadingCount.SHOWN_MIN)
				expect(LoadingCount.raceSeconds(0 / 0)).to.equal(LoadingCount.SHOWN_MIN)
				expect(LoadingCount.raceSeconds(1)).to.be.near(LoadingCount.SHOWN_MIN - 1, 0.001)
				expect(LoadingCount.raceSeconds(10)).to.equal(LoadingCount.RACE_MIN)
			end
		)

		it("is quick: two seconds at the very most", function()
			expect(LoadingCount.SHOWN_MIN <= 2).to.equal(true)
			expect(LoadingCount.RACE_MIN <= LoadingCount.SHOWN_MIN).to.equal(true)
		end)
	end)

	describe("LoadingCount.race", function()
		it("runs from where the count stood to 100 and never back", function()
			expect(LoadingCount.race(40, 0)).to.equal(40)
			expect(LoadingCount.race(40, 1)).to.equal(100)
			expect(LoadingCount.race(40, 7)).to.equal(100)
			expect(LoadingCount.race(40, 0 / 0)).to.equal(100)
			expect(LoadingCount.race(250, 0)).to.equal(100)
			local last = 40
			for step = 1, 20 do
				local value = LoadingCount.race(40, step / 20)
				expect(value >= last).to.equal(true)
				last = value
			end
		end)
	end)

	describe("LoadingCount.text", function()
		it("reads as a whole percent from 0% to 100%", function()
			expect(LoadingCount.text(0)).to.equal("0%")
			expect(LoadingCount.text(62.6)).to.equal("63%")
			expect(LoadingCount.text(100)).to.equal("100%")
			expect(LoadingCount.text(140)).to.equal("100%")
			expect(LoadingCount.text(-5)).to.equal("0%")
			expect(LoadingCount.text(0 / 0)).to.equal("0%")
		end)
	end)
end
