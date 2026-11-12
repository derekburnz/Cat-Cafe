--!strict
-- Effects/BinRoll (the Rummage Bin's prize roll): the ticks go in list order, slow evenly, stop on the picked prize
-- and never linger on another row; a rarer prize gets a bigger show inside the phone budget.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects bin roll", function()
		local p = Presets.binRoll

		it("goes round the list in order and stops on the picked row", function()
			for target = 1, 6 do
				local steps = Logic.binRollSteps(6, target, p.laps, p.first, p.last)
				expect(#steps).to.equal(p.laps * 6 + target)
				expect(steps[1].index).to.equal(1)
				expect(steps[#steps].index).to.equal(target)
				for i = 2, #steps do
					expect(steps[i].index).to.equal(steps[i - 1].index % 6 + 1)
				end
			end
		end)

		it("slows the same way wherever it stops and never lingers before the end", function()
			local gapsFromEnd: { number }? = nil
			for target = 1, 7 do
				local steps = Logic.binRollSteps(7, target, p.laps, p.first, p.last)
				local before = 0
				local fromEnd: { number } = {}
				for i = 2, #steps do
					local gap = steps[i].at - steps[i - 1].at
					expect(gap >= before - 1e-6).to.equal(true)
					expect(gap <= p.last + 1e-6).to.equal(true)
					before = gap
				end
				for i = #steps, #steps - 6, -1 do
					table.insert(fromEnd, steps[i].at - steps[i - 1].at)
				end
				-- the honesty rule: the last seven gaps are the same for every stopping row
				if gapsFromEnd ~= nil then
					for i, gap in fromEnd do
						expect(math.abs(gap - gapsFromEnd[i]) < 1e-6).to.equal(true)
					end
				end
				gapsFromEnd = fromEnd
				-- about the design's 2.5 seconds
				expect(steps[#steps].at >= 2).to.equal(true)
				expect(steps[#steps].at <= 2.5).to.equal(true)
			end
			-- no flashing: never more than about 15 ticks a second
			expect(p.first >= 1 / 15).to.equal(true)
		end)

		it("copes with odd tables", function()
			expect(#Logic.binRollSteps(0, 1, 2, 0.1, 0.4)).to.equal(0)
			local one = Logic.binRollSteps(1, 1, 2, 0.1, 0.4)
			expect(one[#one].index).to.equal(1)
			local over = Logic.binRollSteps(6, 99, 0, 0.1, 0.4)
			expect(over[#over].index).to.equal(6)
		end)

		it("gives a rarer prize a bigger show", function()
			expect(Logic.binRewardTier(0.28, p.good, p.best)).to.equal(1)
			expect(Logic.binRewardTier(0.22, p.good, p.best)).to.equal(1)
			expect(Logic.binRewardTier(0.15, p.good, p.best)).to.equal(2)
			expect(Logic.binRewardTier(0.12, p.good, p.best)).to.equal(2)
			expect(Logic.binRewardTier(0.05, p.good, p.best)).to.equal(3)
			expect(Logic.binRewardTier(0.03, p.good, p.best)).to.equal(3)
			expect(Logic.binRewardTier(nil, p.good, p.best)).to.equal(2)
			expect(#p.tiers).to.equal(3)
			for i = 2, 3 do
				expect(p.tiers[i].sparkles > p.tiers[i - 1].sparkles).to.equal(true)
				expect(p.tiers[i].confetti >= p.tiers[i - 1].confetti).to.equal(true)
			end
			-- only the best prize raises the light column and the shake
			expect(p.tiers[1].beam + p.tiers[2].beam).to.equal(0)
			expect(p.tiers[1].shake + p.tiers[2].shake).to.equal(0)
			expect(p.tiers[3].confetti <= 1).to.equal(true)
			expect(Presets.emitters[p.emitter] ~= nil).to.equal(true)
			-- the landing never covers the bar: no confetti, no shake, and its column is short and brief
			for _, show in p.landed do
				expect(show.confetti + show.shake).to.equal(0)
				expect(show.beamSeconds <= 1).to.equal(true)
			end
			expect(p.landed[1].sparkles + p.landed[1].ring + p.landed[1].beam).to.equal(0)
		end)
		it("hops the lid for a good prize and flies it off for the best", function()
			local p = Presets.binRoll
			expect(p.lid[1].seconds).to.equal(0)
			local up, faded = Logic.binLidPop(0.5, p.lid[2].height, p.lid[2].fly)
			expect(up).to.equal(p.lid[2].height)
			expect(faded).to.equal(0)
			-- the hop lands back on the bin
			expect((Logic.binLidPop(1, p.lid[2].height, false))).to.equal(0)
			expect((Logic.binLidPop(0, p.lid[2].height, false))).to.equal(0)
			-- the fly ends up high and gone
			local high, gone = Logic.binLidPop(1, p.lid[3].height, p.lid[3].fly)
			expect(high).to.equal(p.lid[3].height)
			expect(gone).to.equal(1)
			expect(select(2, Logic.binLidPop(0.5, p.lid[3].height, true))).to.equal(0)
		end)
	end)
end
