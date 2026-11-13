--!strict
-- Mouse Dash's pops (#3296, Effects/MouseDashFx): the bigger catch lands on every 5th of a streak, the golden mouse
-- has its own, the sad moments stay soft, the bounce settles, and no pop goes over the phone's burst cap. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local MouseDashFx = require(Effects:WaitForChild("MouseDashFx")) :: any

	describe("Effects mouse dash", function()
		it("gives every 5th catch of a streak the big pop and the golden mouse its own", function()
			expect(MouseDashFx.catchKind("mouse", 1)).to.equal("small")
			expect(MouseDashFx.catchKind("mouse", 4)).to.equal("small")
			expect(MouseDashFx.catchKind("mouse", 5)).to.equal("big")
			expect(MouseDashFx.catchKind("mouse", 6)).to.equal("small")
			expect(MouseDashFx.catchKind("mouse", 50)).to.equal("big")
			expect(MouseDashFx.catchKind("mouse", 0)).to.equal("small")
			expect(MouseDashFx.catchKind(nil, nil)).to.equal("small")
			expect(MouseDashFx.catchKind("mouse", 0 / 0)).to.equal("small")
			expect(MouseDashFx.catchKind("golden", 3)).to.equal("golden")
			-- the window draws "+1", "+3" and "Faster!" itself, so the pops carry no words of their own
			expect(Presets.mouseDash.catch.word).to.equal(nil)
			expect(Presets.mouseDash.catchGolden.word).to.equal(nil)
			expect(Presets.mouseDash.faster.word).to.equal(nil)
		end)

		it(
			"keeps every pop within the phone's burst cap and halves the dust on a slow device",
			function()
				local m = Presets.mouseDash
				local most = Presets.budget.low.maxBurst
				for _, count in
					{
						m.pop.golden.sparkles,
						m.catch.sparkles,
						m.catchBig.sparkles,
						m.catchGolden.sparkles,
						m.heart.sparkles,
						m.faster.sparkles,
						m.best.sparkles,
						m.puff.count,
						m.wrong.empty.stars + m.wrong.empty.puffs,
					}
				do
					expect(count <= most).to.equal(true)
				end
				expect(MouseDashFx.puffCount(6, false)).to.equal(6)
				expect(MouseDashFx.puffCount(6, true)).to.equal(3)
				expect(MouseDashFx.puffCount(3, true)).to.equal(2)
			end
		)

		it("keeps the sad moments soft: dust and small words, never a red flash", function()
			local m = Presets.mouseDash
			expect(m.heart.lost).to.equal(Presets.palette.furGrey)
			expect(m.wrong.kitten.word).to.equal("mrow?")
			expect(m.puff.seconds >= 0.34).to.equal(true) -- one soft fade, nowhere near a 3 Hz flash
		end)

		it("bounces out and settles back on exactly 1", function()
			local b = Presets.mouseDash.bounce
			for _, peak in { b.peaks.pop, b.peaks.squash, b.peaks.pulse } do
				expect(MouseDashFx.bounceScale(0, peak)).to.equal(1)
				expect(MouseDashFx.bounceScale(1, peak)).to.equal(1)
				expect(MouseDashFx.bounceScale(2, peak)).to.equal(1)
				expect(math.abs(MouseDashFx.bounceScale(0.4, peak) - peak) < 0.001).to.equal(true)
				for step = 0, 20 do
					local scale = MouseDashFx.bounceScale(step / 20, peak)
					expect(scale > 0.7 and scale < 1.3).to.equal(true)
				end
			end
			expect(b.seconds >= 0.15 and b.seconds <= 0.35).to.equal(true)
		end)

		it("exposes every hook the window calls", function()
			for _, name in
				{ "pop", "catch", "escape", "wrong", "heart", "faster", "prize", "best", "bounce" }
			do
				expect(type(MouseDashFx[name])).to.equal("function")
			end
		end)
	end)
end
