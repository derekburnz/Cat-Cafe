--!strict
-- The red "!" over a stuck cat (Derek 2026-10-28 01:01: "rescue mini games like stuck in trash and others should
-- have a red exclamation mark coming out"): it shows from across an area while nobody is rescuing the cat, hides
-- while someone is and once you are close enough for the Rescue card, and stays small in number. Written by the
-- vfx-animator for QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects stuck cat mark", function()
		it("shows across the area while nobody is rescuing the cat", function()
			local m = Presets.stuckMark
			expect(Logic.stuckMarkShows(0, 40)).to.equal(true)
			expect(Logic.stuckMarkShows(nil, 40)).to.equal(true) -- LockedBy not replicated yet
			expect(Logic.stuckMarkShows(0, m.maxDistance)).to.equal(true)
			expect(Logic.stuckMarkShows(0, m.maxDistance + 1)).to.equal(false)
			expect(Logic.stuckMarkShows(123456, 40)).to.equal(false) -- someone is rescuing it
		end)

		it("hides once you are close enough for the Rescue card", function()
			local m = Presets.stuckMark
			expect(Logic.stuckMarkShows(0, m.hideWithin)).to.equal(false)
			expect(Logic.stuckMarkShows(0, m.hideWithin + 0.5)).to.equal(true)
			expect(m.hideWithin >= 8 and m.hideWithin <= 12).to.equal(true) -- GrabRangeStuds is 10
		end)

		it("is red, readable and few", function()
			local m = Presets.stuckMark
			expect(m.colour).to.equal(Presets.palette.shirtRed)
			expect(m.size >= 1 and m.pixels >= 12).to.equal(true)
			expect(m.most >= 1 and m.most <= 8).to.equal(true)
			expect(m.bob > 0 and m.bob < m.rise + m.above).to.equal(true)
			expect(m.checkEvery > 0 and m.checkEvery <= 0.5).to.equal(true)
		end)
	end)
end
