--!strict
-- The Settings switches the client Effects module follows (Derek 2026-10-27): Screen shake and Low performance.
-- Written by the vfx-animator for QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects settings", function()
		it("keeps shake on and Low performance off until the player flips them", function()
			local shake, low = Logic.readSettings(nil)
			expect(shake == true and low == false).to.equal(true)
			shake, low = Logic.readSettings({})
			expect(shake == true and low == false).to.equal(true)
			shake, low = Logic.readSettings({ music = false, sfx = false })
			expect(shake == true and low == false).to.equal(true)
			shake, low = Logic.readSettings({ screenShake = false, lowPerformance = true })
			expect(shake == false and low == true).to.equal(true)
			-- anything but a real false or true keeps the default
			shake, low = Logic.readSettings({ screenShake = 0, lowPerformance = "yes" })
			expect(shake == true and low == false).to.equal(true)
		end)

		it("runs on the Low performance budget on any device and reads as low", function()
			for _, device in { "low", "high" } do
				local tier, budget = Logic.budgetFor(device, true)
				expect(tier).to.equal("low")
				expect(budget).to.equal(Presets.budget.lowPerformance)
				tier, budget = Logic.budgetFor(device, false)
				expect(tier).to.equal(device)
				expect(budget).to.equal(Presets.budget[device])
			end
		end)

		it("keeps the Low performance budget at or under the phone budget everywhere", function()
			local low, saver = Presets.budget.low, Presets.budget.lowPerformance
			for field, value in low do
				expect(type(saver[field])).to.equal("number")
				expect(saver[field] <= value).to.equal(true)
			end
			expect(saver.animatedCats < low.animatedCats).to.equal(true)
			expect(saver.burstScale < low.burstScale and saver.rateScale < low.rateScale).to.equal(
				true
			)
		end)

		it(
			"gives a console the high tier with a budget between the phone's and the PC's (#2871)",
			function()
				local tier, budget = Logic.budgetFor("high", false, true)
				expect(tier).to.equal("high")
				expect(budget).to.equal(Presets.budget.console)
				-- Low performance still wins on a console, and a console flag never lifts a phone
				tier, budget = Logic.budgetFor("high", true, true)
				expect(budget).to.equal(Presets.budget.lowPerformance)
				tier, budget = Logic.budgetFor("low", false, true)
				expect(budget).to.equal(Presets.budget.low)
				local low, console, high =
					Presets.budget.low, Presets.budget.console, Presets.budget.high
				for field, value in high do
					expect(type(console[field])).to.equal("number")
					expect(console[field] <= value).to.equal(true)
					expect(console[field] >= low[field]).to.equal(true)
				end
				expect(
					console.animatedCats < high.animatedCats and console.maxBurst < high.maxBurst
				).to.equal(true)
			end
		)

		it("scales steady rates within the preset and keeps every burst at one to eight", function()
			for _, budget in Presets.budget do
				expect(budget.rateScale > 0 and budget.rateScale <= 1).to.equal(true)
			end
			local saver = Presets.budget.lowPerformance
			for _, count in Presets.catchSparkle do
				local n = math.clamp(math.floor(count * saver.burstScale + 0.5), 1, saver.maxBurst)
				expect(n >= 1 and n <= 8).to.equal(true)
			end
		end)
		-- #3794: the lighter budget for phones and graphics quality 1 to 3, behind the fxLite switch
		it("takes the lite budget under Low performance and over the phone's", function()
			local tier, budget = Logic.budgetFor("high", false, false, true)
			expect(tier).to.equal("low")
			expect(budget).to.equal(Presets.budget.lite)
			tier, budget = Logic.budgetFor("low", true, false, true)
			expect(budget).to.equal(Presets.budget.lowPerformance)
			tier, budget = Logic.budgetFor("low", false, false, false)
			expect(tier).to.equal("low")
			expect(budget).to.equal(Presets.budget.low)
			local low, lite, saver =
				Presets.budget.low, Presets.budget.lite, Presets.budget.lowPerformance
			for field, value in low do
				expect(type(lite[field])).to.equal("number")
				expect(lite[field] <= value).to.equal(true)
				expect(lite[field] >= saver[field]).to.equal(true)
			end
			expect(lite.animatedCats < low.animatedCats and lite.animHz < low.animHz).to.equal(true)
		end)

		it("wants lite on phones and graphics quality 1 to 3, only with the switch on", function()
			expect(Logic.wantsLite(true, "low", 0)).to.equal(true)
			expect(Logic.wantsLite(true, "high", 2)).to.equal(true)
			expect(Logic.wantsLite(true, "high", 3)).to.equal(true)
			expect(Logic.wantsLite(true, "high", 4)).to.equal(false)
			expect(Logic.wantsLite(true, "high", 0)).to.equal(false)
			expect(Logic.wantsLite(true, "high", nil)).to.equal(false)
			expect(Logic.wantsLite(false, "low", 1)).to.equal(false)
		end)
	end)
end
