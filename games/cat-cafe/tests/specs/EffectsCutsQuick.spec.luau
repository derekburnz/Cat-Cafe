--!strict
-- #5550 cutsQuick: the quick station unlock and Cat Companion scenes (about 2 s and 3 s, no skip, over by 0.5 s past
-- their end), and off keeping today's scenes. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Station = require(Effects:WaitForChild("StationUnlockCut")) :: any
	local Companion = require(Effects:WaitForChild("CompanionUnlockCut")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects quick cuts (#5550)", function()
		it("keeps today's scenes with the switch off", function()
			expect(Station.preset(false)).to.equal(Presets.stationCut)
			expect(Companion.preset(false)).to.equal(Presets.companionCut)
			expect(Station.preset(false).endAt).to.equal(4.0)
			expect(Companion.preset(false).endAt).to.equal(7.4)
			expect(Station.preset(false).skip).to.equal(true)
			expect(Companion.preset(false).skip).to.equal(true)
			expect(Station.preset(false).cap).to.equal(1)
			expect(Companion.line("Mochi")).to.equal(
				"Mochi will follow you. Pick Money or Luck in Cats."
			)
		end)

		it("plays the station scene in about 2 s with no skip, capped past its end", function()
			local p = Station.preset(true)
			expect(p.endAt).to.equal(2.0)
			expect(p.skip).to.equal(false)
			expect(p.cap).to.equal(0.5)
			expect(Station.length(p)).to.be.near(2.4, 0.01)
			expect(p.appearAt < p.labelAt and p.labelAt + p.labelIn < p.endAt).to.equal(true)
			expect(p.appearAt + p.grow < p.endAt).to.equal(true)
			expect(p.stations[3].tag).to.equal("ArcadeCabinet")
			-- the base is never changed
			expect(Presets.stationCut.endAt).to.equal(4.0)
			local _, there, _, grow, label = Station.at(1.2, p)
			expect(there).to.equal(true)
			expect(grow).to.equal(1)
			expect(label).to.equal(1)
		end)

		it("plays the companion scene in about 3 s with no skip and a shorter line", function()
			local p = Companion.preset(true)
			expect(p.endAt).to.equal(3.0)
			expect(p.skip).to.equal(false)
			expect(p.cap).to.equal(0.5)
			expect(Companion.length(p)).to.be.near(3.4, 0.01)
			expect(p.walkAt + p.walkSeconds < p.labelAt + p.labelIn).to.equal(true)
			expect(p.labelAt + p.labelIn < p.endAt).to.equal(true)
			local _, there, _, walk, label = Companion.at(2.0, p)
			expect(there).to.equal(true)
			expect(walk).to.equal(1)
			expect(label).to.equal(1)
			expect(Companion.line("Mochi", true)).to.equal("Mochi follows you now!")
			expect(Companion.line(nil, true)).to.equal("Your cat follows you now!")
			expect(#Companion.line("Mochi", true) < #Companion.line("Mochi")).to.equal(true)
			expect(Presets.companionCut.endAt).to.equal(7.4)
		end)
	end)
end
