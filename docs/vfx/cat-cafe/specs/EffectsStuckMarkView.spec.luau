--!strict
-- The red "!" over a stuck cat only in view (Derek 2026-10-28 12:13) with the cat's rarity gem over it (12:14), and
-- Common strays wearing a gem too (12:15). Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects stuck mark in view", function()
		it("stays a moment after the cat was last seen, then hides", function()
			local m = Presets.stuckMark
			expect(Logic.stillInView(nil, 10, m.lostAfter)).to.equal(false) -- never seen
			expect(Logic.stillInView(10, 10, m.lostAfter)).to.equal(true)
			expect(Logic.stillInView(10, 10 + m.lostAfter, m.lostAfter)).to.equal(true)
			expect(Logic.stillInView(10, 10 + m.lostAfter + 0.01, m.lostAfter)).to.equal(false)
		end)

		it(
			"outlasts one check, looks past a few see-through parts and stays fairly close",
			function()
				local m = Presets.stuckMark
				expect(m.lostAfter > m.checkEvery).to.equal(true) -- one missed check never pops it
				expect(m.lostAfter <= 1).to.equal(true)
				expect(m.seeThrough >= 1 and m.seeThrough <= 5).to.equal(true)
				expect(m.maxDistance > m.hideWithin + m.showAfter and m.maxDistance <= 120).to.equal(
					true
				)
			end
		)

		it("holds the cat's gem just over the red mark", function()
			local m = Presets.stuckMark
			expect(m.gem > 0 and m.gem <= m.size).to.equal(true)
			expect(m.gemGap > 0 and m.gemGap < m.gem).to.equal(true)
			expect(m.gem).to.equal(Presets.rarityMark.size)
		end)

		it("gives Common strays a gem in the Common colour", function()
			expect(Presets.rarityMark.shows.Common).to.equal(true)
			expect(Presets.rarity.Common ~= nil).to.equal(true)
			expect(Presets.rarityMark.glints.Common == true).to.equal(false)
		end)
	end)
end
