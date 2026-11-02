--!strict
-- Cats make the orders (F90, cats-make-orders.md section 2 step 2 and section 4): the station puffs, the oven's glow
-- and door, the ding, and who plays them. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Orders", function()
		it("puffs a few at a time while a 2 s drink or a 3 s bake is made", function()
			local o = Presets.orders
			for _, name in { "steam", "flour", "counter" } do
				local puff = o[name]
				expect(puff.every > 0 and puff.every < 2).to.equal(true) -- more than one puff in a drink
				expect(puff.count > 0 and puff.count <= Presets.budget.low.maxBurst).to.equal(true)
			end
			for _, name in { "orderSteam", "flourPuff", "counterTwinkle", "dingSparkle" } do
				expect(Presets.emitters[name] ~= nil).to.equal(true)
				expect(Presets.emitters[name].rate).to.equal(0) -- bursts only
			end
			expect(o.ding.sparkles <= Presets.budget.high.maxBurst).to.equal(true)
			expect(o.ding.goldSparkles > o.ding.sparkles).to.equal(true)
			expect(o.ding.gold).to.equal(Presets.palette.golden)
			expect(o.grace > 0).to.equal(true)
		end)

		it("swings the oven door out and shut again in under a second and a half", function()
			local keys = Presets.orders.door
			expect(Logic.keyed(keys, 0)).to.equal(0)
			expect(Logic.keyed(keys, Logic.keyedSeconds(keys) + 1)).to.equal(0)
			expect(Logic.keyedSeconds(keys) <= 1.5).to.equal(true)
			local widest = 0
			for _, key in keys do
				widest = math.min(widest, key[2])
			end
			expect(widest < -20 and widest >= -90).to.equal(true) -- out toward the front, never past flat
		end)

		it("brings the window glow up and down within its times", function()
			local g = Presets.orders.glow
			local level = 0
			for _ = 1, 10 do
				level = Logic.glowStep(level, true, g.rise / 8, g.rise, g.fade)
			end
			expect(level).to.equal(1)
			for _ = 1, 10 do
				level = Logic.glowStep(level, false, g.fade / 8, g.rise, g.fade)
			end
			expect(level).to.equal(0)
			for t = 0, 2, 0.1 do
				local shown = Logic.glowFlicker(1, t, g.flicker, g.hz)
				expect(shown >= 1 - g.flicker and shown <= 1 + g.flicker).to.equal(true)
			end
			expect(g.transparency > 0 and g.transparency < 1).to.equal(true)
		end)

		it("plays your own cafe always and others only on a PC or console", function()
			local o = Presets.orders
			expect(Logic.orderPlays(true, 10, o.within, 99, 0)).to.equal(true)
			expect(Logic.orderPlays(true, o.within + 1, o.within, 0, 3)).to.equal(false)
			expect(Logic.orderPlays(false, 10, o.within, 0, 3)).to.equal(true)
			expect(Logic.orderPlays(false, 10, o.within, 3, 3)).to.equal(false)
			expect(Presets.budget.low.cafeOrders).to.equal(0)
			expect(Presets.budget.lowPerformance.cafeOrders).to.equal(0)
			expect(Presets.budget.high.cafeOrders >= 1).to.equal(true)
		end)
	end)
end
