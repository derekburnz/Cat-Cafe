--!strict
-- The Oasis Spa's and the Relic Museum's effects (#2925): their presets exist and stay inside the phone budgets.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects late stations", function()
		it("has the spa steam as a gentle steady emitter", function()
			local p = Presets.lateStations
			local steam = Presets.emitters[p.steamPreset]
			expect(steam).to.be.ok()
			expect(steam.rate <= 4).to.equal(true)
		end)

		it("keeps every burst within the phone's burst cap", function()
			local p = Presets.lateStations
			local most = Presets.budget.low.maxBurst
			for _, count in { p.splash, p.levelUp, p.donate } do
				expect(count <= most).to.equal(true)
			end
			expect(p.levelUpMost >= 1).to.equal(true)
			expect(p.roomConfetti <= 1).to.equal(true)
			for _, name in { "splashDrops", "fishRise", "catchSparkle" } do
				expect(Presets.emitters[name]).to.be.ok()
			end
		end)

		it("has the Museum card's tile bursts", function()
			local kinds = Presets.storeBurst.kinds
			expect(kinds.exhibit).to.be.ok()
			expect(kinds.room).to.be.ok()
			expect(kinds.room.sparkles >= kinds.exhibit.sparkles).to.equal(true)
		end)
	end)
end
