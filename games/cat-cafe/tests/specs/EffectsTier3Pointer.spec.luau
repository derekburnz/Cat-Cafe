--!strict
-- #5715 tier3Pointer: the Tier 3 coins pointer's look (Effects/Tier3PointerFx, Effects/PointerArrow). Written by
-- the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Fx = require(Effects:WaitForChild("Tier3PointerFx")) :: any
	local PointerArrow = require(Effects:WaitForChild("PointerArrow")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Tier 3 coins pointer look", function()
		local p = Presets.tier3Pointer

		it("draws the arrow 1.3 times as big on a tablet only", function()
			expect(Fx.arrowScale(true, p.tabletScale)).to.equal(1.3)
			expect(Fx.arrowScale(false, p.tabletScale)).to.equal(1)
		end)

		it("sizes parkCatArrow's arrow at the asked scale", function()
			expect(PointerArrow.pixels(1)).to.equal(64)
			expect(PointerArrow.pixels(p.tabletScale)).to.equal(83)
		end)

		it("breathes the ring once every period between its two fades", function()
			expect(
				math.abs(
					Fx.ringFade(0, p.period, p.ringLow, p.ringHigh, false, p.ringStill) - p.ringHigh
				) < 1e-6
			).to.equal(true)
			expect(
				math.abs(
					Fx.ringFade(p.period / 2, p.period, p.ringLow, p.ringHigh, false, p.ringStill)
						- p.ringLow
				) < 1e-6
			).to.equal(true)
			for t = 0, 3, 0.1 do
				local a = Fx.ringFade(t, p.period, p.ringLow, p.ringHigh, false, p.ringStill)
				expect(a >= p.ringLow - 1e-6 and a <= p.ringHigh + 1e-6).to.equal(true)
			end
		end)

		it("holds the ring still on the low graphics path and with Reduce Motion", function()
			expect(Fx.ringFade(0.3, p.period, p.ringLow, p.ringHigh, true, p.ringStill)).to.equal(
				p.ringStill
			)
		end)

		it("holds the arrow still with Reduce Motion", function()
			expect(PointerArrow.bob(1.7, true)).to.equal(0)
			expect(math.abs(PointerArrow.bob(1.7, false)) <= PointerArrow.BOB).to.equal(true)
		end)

		it("hides with no target", function()
			Fx.point(nil, nil) -- must not error
		end)
	end)
end
