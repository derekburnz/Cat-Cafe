--!strict
-- The Corner Shop's shows (#1052, corner-shop.md sections 2 and 5): a queued show waits for its own start, a late
-- joiner keeps the firework beat, the shows last as long as Catalog.cornerShop says and stay in budget.
-- Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects cafe shows", function()
		it("waits, plays and ends on the server's times", function()
			expect(Logic.showPhase(99, 100, 120)).to.equal("waiting") -- queued behind another show
			expect(Logic.showPhase(100, 100, 120)).to.equal("on")
			expect(Logic.showPhase(119.9, 100, 120)).to.equal("on")
			expect(Logic.showPhase(120, 100, 120)).to.equal("over")
		end)

		it("keeps the firework beat for a late joiner", function()
			-- not started: the first shell at the start
			expect(Logic.nextShell(100, 90, 0.8)).to.equal(100)
			expect(close(Logic.nextShell(100, 100, 0.8), 100.8)).to.equal(true)
			-- joined at 5.1 s: the next beat, no catch-up volley
			expect(close(Logic.nextShell(100, 105.1, 0.8), 105.6)).to.equal(true)
			expect(close(Logic.nextShell(100, 105.6, 1.6), 106.4)).to.equal(true)
		end)

		it("lasts as long as the Corner Shop sells it", function()
			-- Catalog.cornerShop's showSeconds: bubble_machine 600, cafe_fireworks 20
			expect(Presets.cafeShow.bubbles.seconds).to.equal(600)
			expect(Presets.cafeShow.fireworks.seconds).to.equal(20)
		end)

		it("fires fewer shells on the low budget", function()
			local every = Presets.cafeShow.fireworks.every
			expect(every.low > every.high).to.equal(true)
			local f = Presets.cafeShow.fireworks
			expect(f.rise < f.seconds).to.equal(true)
			expect(#f.colours >= 3).to.equal(true)
		end)

		it("stays in budget", function()
			local b = Presets.budget
			expect(b.low.cafeBubbles <= b.high.cafeBubbles).to.equal(true)
			expect(b.lowPerformance.cafeBubbles <= b.low.cafeBubbles).to.equal(true)
			expect(b.low.cafeFireworks <= b.high.cafeFireworks).to.equal(true)
			expect(b.lowPerformance.cafeFireworks <= b.low.cafeFireworks).to.equal(true)
			expect(b.lowPerformance.cafeFireworks >= 1).to.equal(true)
			expect(Presets.emitters.cafeBubble.rate <= 8).to.equal(true)
			expect(Presets.cafeShow.fireworks.stars <= 30).to.equal(true)
		end)
	end)
end
