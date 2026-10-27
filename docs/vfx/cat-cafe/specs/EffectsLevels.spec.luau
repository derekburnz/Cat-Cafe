--!strict
-- A cat levelling up (F75, data-model 4b and 13 v0.12): only a real rise in `Level` sparkles, never the first value
-- a client sees, and the sparkle stays small inside every budget. Written by the vfx-animator for QA to move into
-- tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects cat level up", function()
		it("sparkles only when a level goes up", function()
			expect(Logic.levelledUp(1, 2)).to.equal(true)
			expect(Logic.levelledUp(12, 14)).to.equal(true) -- two levels in one settle still sparkle once
			expect(Logic.levelledUp(nil, 5)).to.equal(false) -- the model was built at its level
			expect(Logic.levelledUp(5, 5)).to.equal(false)
			expect(Logic.levelledUp(24, 10)).to.equal(false) -- a reset or an old save mapped down
			expect(Logic.levelledUp(5, nil)).to.equal(false)
			expect(Logic.levelledUp("5", 6)).to.equal(false)
		end)

		it("stays small in every budget", function()
			local l = Presets.levelUp
			expect(Presets.emitters.catchSparkle ~= nil and Presets.emitters.fishRise ~= nil).to.equal(
				true
			)
			for _, budget in Presets.budget do
				for _, count in { l.sparkles, l.glints } do
					local shown =
						math.clamp(math.floor(count * budget.burstScale + 0.5), 1, budget.maxBurst)
					expect(shown <= 6).to.equal(true)
				end
			end
		end)

		it("is smaller than a golden fish pickup", function()
			local l = Presets.levelUp
			expect(l.sparkles < Presets.fishPickup.steps[1].sparkles).to.equal(true)
			expect(l.colour).to.equal(Presets.palette.mint)
			expect(l.above >= 0 and l.above <= 1).to.equal(true)
		end)
	end)
end
