--!strict
-- The Rally board's marquee (F101): the bulbs chasing round its face while a Rally runs, and the flash on each step
-- of the bar. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Rally board", function()
		it("lights every third bulb and moves them one bulb on each step", function()
			local gap = Presets.rallyBoard.gap
			local count = 32
			local function lit(phase: number): { number }
				local out: { number } = {}
				for i = 1, count do
					if Logic.marqueeLit(i, phase, gap) then
						table.insert(out, i)
					end
				end
				return out
			end
			local first = lit(0)
			expect(first[1]).to.equal(1)
			expect(#first).to.equal(math.ceil(count / gap))
			for k = 2, #first do
				expect(first[k] - first[k - 1]).to.equal(gap)
			end
			-- one step on, each lit bulb has moved to the next
			local second = lit(1)
			expect(second[1]).to.equal(2)
			-- part way through a step nothing moves yet
			expect(lit(0.6)[1]).to.equal(1)
			-- a full round of steps comes back to the start
			expect(lit(gap)[1]).to.equal(1)
			-- a gap of 1 lights them all
			expect(Logic.marqueeLit(5, 3.2, 1)).to.equal(true)
		end)

		it("flashes every bulb on and off, then hands back to the chase", function()
			local o = Presets.rallyBoard
			expect(Logic.marqueeFlash(0, o.flashes, o.flashHz)).to.equal(true)
			expect(Logic.marqueeFlash(0.25 / o.flashHz, o.flashes, o.flashHz)).to.equal(true)
			expect(Logic.marqueeFlash(0.75 / o.flashHz, o.flashes, o.flashHz)).to.equal(false)
			expect(Logic.marqueeFlash(1.25 / o.flashHz, o.flashes, o.flashHz)).to.equal(true)
			expect(Logic.marqueeFlash(o.flashes / o.flashHz, o.flashes, o.flashHz) == nil).to.equal(
				true
			)
			expect(Logic.marqueeFlash(-0.1, o.flashes, o.flashHz) == nil).to.equal(true)
			expect(Logic.marqueeFlash(math.huge, o.flashes, o.flashHz) == nil).to.equal(true)
			expect(Logic.marqueeFlash(0, o.flashes, 0) == nil).to.equal(true)
		end)

		it("stays gentle on the eyes and inside the budget", function()
			local o = Presets.rallyBoard
			expect(o.flashHz < 3).to.equal(true) -- under 3 flashes a second
			expect(o.fullFlashes >= o.flashes).to.equal(true)
			expect(o.gap >= 2).to.equal(true) -- a chase, not a strobe
			expect(o.hz / o.gap < 3).to.equal(true) -- each bulb blinks under 3 times a second
			expect(o.burstHz / o.gap < 3).to.equal(true) -- and while it runs faster after a point
			expect(o.full).to.equal(Presets.rally.full)
			expect(o.grow > 1).to.equal(true) -- the cover hides the bulb under it
			local b = Presets.budget
			expect(b.lowPerformance.rallyBoards).to.equal(0)
			expect(b.low.rallyBoards <= b.high.rallyBoards).to.equal(true)
		end)
	end)
end
