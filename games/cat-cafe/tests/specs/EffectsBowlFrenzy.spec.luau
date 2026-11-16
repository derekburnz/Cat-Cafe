--!strict
-- Bowl Frenzy at your bait bowl (#4195): which bowls pop, how often, and when a ring spreads; numbers in budget.
-- Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local BowlFrenzyFx = require(Effects:WaitForChild("BowlFrenzyFx")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Bowl Frenzy at the bait bowl", function()
		it(
			"pops only a bowl with food whose cat is still on the way, while the frenzy runs",
			function()
				expect(BowlFrenzyFx.pops(true, true, false)).to.equal(true)
				expect(BowlFrenzyFx.pops(false, true, false)).to.equal(false)
				expect(BowlFrenzyFx.pops(true, false, false)).to.equal(false)
				expect(BowlFrenzyFx.pops(true, true, true)).to.equal(false)
			end
		)

		it(
			"pops less often in Low performance and spreads a ring every few pops, never there",
			function()
				local p = Presets.bowlFrenzy
				expect(BowlFrenzyFx.gap(false, p.every, p.lowEvery)).to.equal(p.every)
				expect(BowlFrenzyFx.gap(true, p.every, p.lowEvery)).to.equal(p.lowEvery)
				expect(p.lowEvery > p.every).to.equal(true)
				expect(BowlFrenzyFx.rings(3, 3, false)).to.equal(true)
				expect(BowlFrenzyFx.rings(2, 3, false)).to.equal(false)
				expect(BowlFrenzyFx.rings(3, 3, true)).to.equal(false)
				expect(BowlFrenzyFx.rings(3, 0, false)).to.equal(false)
			end
		)

		it("keeps its sparkles small and its preset real", function()
			local p = Presets.bowlFrenzy
			expect(Presets.emitters[p.preset]).to.be.ok()
			expect(p.count <= 6 and p.lowCount < p.count).to.equal(true)
			expect(p.every >= 1).to.equal(true)
			expect(#p.folders).to.equal(2)
		end)
	end)
end
