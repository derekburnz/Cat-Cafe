--!strict
-- Snowglobe Village's Snowflake patch: the pick and regrow reads, the "+N Snowflakes" pop and the bob. Written by the
-- vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Fx = require(Effects:WaitForChild("SnowglobeFlakes")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Snowglobe Snowflakes", function()
		it("reads a pick and a regrow, and not a first sight", function()
			expect(Fx.change(nil, true)).to.equal(nil)
			expect(Fx.change(nil, false)).to.equal(nil)
			expect(Fx.change(true, true)).to.equal(nil)
			expect(Fx.change(true, false)).to.equal("pick")
			expect(Fx.change(false, true)).to.equal("regrow")
		end)

		it("pops only when the count rises, never on the first value or a nil", function()
			expect(Fx.rise(nil, 40)).to.equal(nil)
			expect(Fx.rise(40, nil)).to.equal(nil)
			expect(Fx.rise(40, "50")).to.equal(nil)
			expect(Fx.rise(40, 40)).to.equal(nil)
			expect(Fx.rise(40, 30)).to.equal(nil)
			expect(Fx.rise(40, 55)).to.equal(15)
			expect(Fx.popText(1)).to.equal("+1 Snowflake")
			expect(Fx.popText(15)).to.equal("+15 Snowflakes")
		end)

		it("bobs within its height and turns once a spin", function()
			local p = Presets.snowglobeFlakes
			for t = 0, 10, 0.25 do
				local lift, turn = Fx.bob(t, 0.3, p.height, p.period, p.spin)
				expect(math.abs(lift) <= p.height + 1e-6).to.equal(true)
				expect(turn >= 0 and turn < 2 * math.pi).to.equal(true)
			end
			local _, start = Fx.bob(0, 0, p.height, p.period, p.spin)
			local _, quarter = Fx.bob(p.spin / 4, 0, p.height, p.period, p.spin)
			expect(start).to.equal(0)
			expect(math.abs(quarter - math.pi / 2) < 1e-6).to.equal(true)
		end)

		it("keeps still when picked, far, Reduce Motion or Low performance", function()
			local p = Presets.snowglobeFlakes
			expect(Fx.bobs(true, 10, p.bobWithin, false, false)).to.equal(true)
			expect(Fx.bobs(false, 10, p.bobWithin, false, false)).to.equal(false)
			expect(Fx.bobs(true, p.bobWithin + 1, p.bobWithin, false, false)).to.equal(false)
			expect(Fx.bobs(true, 10, p.bobWithin, true, false)).to.equal(false)
			expect(Fx.bobs(true, 10, p.bobWithin, false, true)).to.equal(false)
			expect(p.flag).to.equal("christmasEvent")
			expect(Presets.emitters[p.sparkle] ~= nil).to.equal(true)
		end)
	end)
end
