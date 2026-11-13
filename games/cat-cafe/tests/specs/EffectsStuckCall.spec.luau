--!strict
-- The stuck cat that calls for help (#2912, Effects/StuckCall): when it calls, how its light pillar reads from near
-- and far, how often it meows, and that nothing in it flashes or hurries.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local AudioLogic = require(Client:WaitForChild("Audio"):WaitForChild("Logic")) :: any

	describe("Effects stuck cat call", function()
		local s = Presets.stuckCall

		it("calls only while the save waits, you are not rescuing and the cat is free", function()
			expect(Logic.stuckCallOn(true, false, 0)).to.equal(true)
			expect(Logic.stuckCallOn(true, false, nil)).to.equal(true)
			expect(Logic.stuckCallOn(true, true, 0)).to.equal(false) -- your rescue bar is up
			expect(Logic.stuckCallOn(true, false, 12345)).to.equal(false) -- someone is on it
			expect(Logic.stuckCallOn(false, false, 0)).to.equal(false)
			expect(Logic.stuckCallOn(nil, false, 0)).to.equal(false) -- an older server
		end)

		it("keeps the pillar easy to see from the camp and fades it as you walk up", function()
			local p = s.pillar
			local nearWidth, nearFade = Logic.stuckPillar(0)
			local farWidth, farFade = Logic.stuckPillar(300)
			expect(nearWidth).to.equal(p.widthMin)
			expect(nearFade).to.equal(p.near)
			expect(farWidth <= p.widthMax and farWidth > nearWidth).to.equal(true)
			expect(math.abs(farFade - p.far) < 1e-6).to.equal(true)
			expect(p.near > p.far).to.equal(true) -- more see-through up close
			local midWidth = Logic.stuckPillar(100)
			expect(midWidth >= p.widthMin and midWidth <= p.widthMax).to.equal(true)
			expect(p.height < Presets.secretStray.beam.height).to.equal(true) -- a Secret's stays the tall one
			-- seen by day (Review-QA's Studio look): wide, nearly solid from afar, with a soft halo
			expect(p.widthMin >= 2).to.equal(true)
			expect(p.far <= 0.2).to.equal(true)
			expect(p.halo.wide > 1 and p.far + p.halo.add < 1).to.equal(true)
			-- and a ground glow the arch cannot hide, breathing slowly (never near a flash)
			local g = s.glow
			expect(g.radius >= 3).to.equal(true)
			expect(g.bright < g.dim and g.dim < 1).to.equal(true)
			expect(1 / (2 * g.seconds) < 1).to.equal(true)
		end)

		it("meows near the cat, well apart, a few times at most", function()
			local m = s.meow
			expect(Logic.stuckMeowDue(nil, 0, 10, m.near, m.near, m.gap, m.most)).to.equal(true)
			expect(Logic.stuckMeowDue(nil, 0, 10, m.near + 1, m.near, m.gap, m.most)).to.equal(
				false
			)
			expect(Logic.stuckMeowDue(10, 1, 10 + m.gap - 1, 5, m.near, m.gap, m.most)).to.equal(
				false
			)
			expect(Logic.stuckMeowDue(10, 1, 10 + m.gap, 5, m.near, m.gap, m.most)).to.equal(true)
			expect(Logic.stuckMeowDue(10, m.most, 1000, 5, m.near, m.gap, m.most)).to.equal(false)
			expect(m.most <= 4 and m.gap >= 30).to.equal(true)
			expect(AudioLogic.beatCue("stuckCall")).to.equal("strayCall")
		end)

		it("moves gently: no flashing, no countdown words", function()
			-- the bubble rocks there and back well under 3 times a second
			expect(1 / (2 * s.bubble.rockSeconds) < 1).to.equal(true)
			expect(s.bubble.rock <= 10).to.equal(true)
			expect(s.wiggle.every >= 3).to.equal(true)
			expect(s.wiggle.hits).to.equal(1) -- as small as a rescue's first hit
			local words = string.lower(s.bubble.text)
			for _, bad in { "hurry", "quick", "now", "fast", "last", "left" } do
				expect(string.find(words, bad, 1, true)).to.equal(nil)
			end
			expect(s.bubble.hideWithin < s.bubble.within).to.equal(true)
		end)
	end)
end
