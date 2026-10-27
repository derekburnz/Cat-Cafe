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
	end)
end
