--!strict
-- A stray's rarity gem (Derek 2026-10-28 01:25): which strays show one, when it hides and that it stays readable.
-- Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects stray rarity gem", function()
		it("shows on Rare and better strays, never on Common", function()
			for _, rarity in { "Rare", "Epic", "Legendary", "Mythical" } do
				expect(Logic.rarityMarkShows(rarity, 0, 40, false)).to.equal(true)
				expect(Presets.rarity[rarity] ~= nil).to.equal(true)
			end
			expect(Logic.rarityMarkShows("Common", 0, 40, false)).to.equal(false)
			expect(Logic.rarityMarkShows(nil, 0, 40, false)).to.equal(false) -- Rarity not replicated yet
			expect(Logic.rarityMarkShows("Sparkly", 0, 40, false)).to.equal(false)
			expect(Presets.rarityMark.glints.Mythical).to.equal(true)
		end)

		it("hides while the cat is being caught, up close and far away", function()
			local r = Presets.rarityMark
			expect(Logic.rarityMarkShows("Epic", 123456, 40, true)).to.equal(false)
			expect(Logic.rarityMarkShows("Epic", nil, 40, false)).to.equal(true) -- LockedBy not replicated yet
			expect(Logic.rarityMarkShows("Epic", 0, r.maxDistance, true)).to.equal(true)
			expect(Logic.rarityMarkShows("Epic", 0, r.maxDistance + 1, true)).to.equal(false)
			expect(Logic.rarityMarkShows("Epic", 0, r.hideWithin, true)).to.equal(false)
			expect(Logic.rarityMarkShows("Epic", 0, r.hideWithin + 0.5, true)).to.equal(true)
			-- once hidden it waits until you step back past hideWithin + showAfter, so the edge never flickers
			expect(Logic.rarityMarkShows("Epic", 0, r.hideWithin + r.showAfter * 0.5, false)).to.equal(
				false
			)
			expect(Logic.rarityMarkShows("Epic", 0, r.hideWithin + r.showAfter + 0.1, false)).to.equal(
				true
			)
			expect(r.hideWithin >= 8 and r.hideWithin <= 12).to.equal(true) -- GrabRangeStuds is 10
		end)

		it("is small but readable far away", function()
			local r = Presets.rarityMark
			expect(r.size > 0 and r.size <= 1.5).to.equal(true)
			expect(r.pixels >= 12).to.equal(true)
			expect(r.gem > 0 and r.gem * math.sqrt(2) <= 1).to.equal(true) -- the turned square fits its gui
			expect(r.bob > 0 and r.bob < r.above).to.equal(true)
			expect(r.glintEvery > 2 * r.glintSeconds).to.equal(true)
			expect(r.most >= 1 and r.most <= 16).to.equal(true)
		end)
	end)
end
