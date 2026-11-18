--!strict
-- #5284 the Cat Companion unlock scene's timeline and words. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Cut = require(Effects:WaitForChild("CompanionUnlockCut")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Cat Companion unlock scene", function()
		it("runs about 8 s: fade in, the cat walks in, the label, fade back", function()
			local p = Presets.companionCut
			expect(Cut.length(p)).to.be.near(7.9, 0.3)
			local fade, there, _, walk, label = Cut.at(0, p)
			expect(fade).to.equal(0)
			expect(there).to.equal(false)
			expect(walk).to.equal(0)
			expect(label).to.equal(0)
			fade, there = Cut.at(p.fade, p)
			expect(fade).to.be.near(1, 1e-6)
			expect(there).to.equal(true)
			fade, there, _, walk = Cut.at(p.walkAt + p.walkSeconds / 2, p)
			expect(fade).to.equal(0)
			expect(walk).to.be.near(0.5, 1e-6)
			local _, _, _, walked, shown = Cut.at(p.labelAt + p.labelIn, p)
			expect(walked).to.equal(1) -- the cat is beside the player before the words
			expect(shown).to.be.near(1, 1e-6)
			fade, there = Cut.at(p.endAt + p.fade, p)
			expect(fade).to.be.near(1, 1e-6)
			expect(there).to.equal(false)
			fade = Cut.at(Cut.length(p), p)
			expect(fade).to.equal(0)
		end)

		it("names the cat in its line, and has a line with no name", function()
			expect(Cut.line("Mochi")).to.equal("Mochi will follow you. Pick Money or Luck in Cats.")
			expect(Cut.line(nil)).to.equal(Presets.companionCut.lineNoName)
			expect(Cut.line("")).to.equal(Presets.companionCut.lineNoName)
			expect(Presets.companionCut.title:find("CAT COMPANION") ~= nil).to.equal(true)
		end)

		it("does not run without a cat", function()
			expect(Cut.play(nil, function() end)).to.equal(false)
			expect(Cut.playing()).to.equal(false)
		end)
	end)
end
