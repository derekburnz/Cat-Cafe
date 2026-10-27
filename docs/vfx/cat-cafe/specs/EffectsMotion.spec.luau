--!strict
-- Design v0.5 motion in the client Effects module (src/client/Effects/Logic.luau and Presets.luau, effects list
-- v0.4): the nap curl, settling from one style into the next, the walk and gallop, and the pant after a sprint.
-- Written by the vfx-animator for QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects.Logic v0.5 motion", function()
		it("curls a napping cat up on its belly", function()
			local o = Logic.idle("nap", 1)
			expect(o.sink).to.equal(1)
			expect(o.pawFL).to.be.near(math.rad(90), 1e-6)
			expect(o.pawBR).to.be.near(math.rad(90), 1e-6)
			expect(o.headYaw > 0).to.equal(true) -- the head turns to the left
			expect(o.tailYaw < 0).to.equal(true) -- and the tail wraps round the left side to meet it
			expect(Logic.idle("sit", 1).sink).to.equal(0)
		end)

		it("settles from one style into the next", function()
			local sit, nap = Logic.idle("sit", 2), Logic.idle("nap", 2)
			local start, finish, half =
				Logic.mix(sit, nap, 0), Logic.mix(sit, nap, 1), Logic.mix(sit, nap, 0.5)
			for key, value in sit do
				expect(start[key]).to.be.near(value, 1e-9)
				expect(finish[key]).to.be.near(nap[key], 1e-9)
			end
			expect(half.sink).to.be.near(0.5, 1e-9)
		end)

		it("trots at a walk and gallops at a run", function()
			local g = Presets.motion.gait
			expect(Logic.runFactor(g.runFrom)).to.equal(0)
			expect(Logic.runFactor(26)).to.equal(1) -- F40's StrayFleeSpeed
			expect(Logic.strideLength(1)).to.equal(g.walkStride)
			expect(Logic.strideLength(26)).to.equal(g.runStride)

			local still = Logic.blank()
			Logic.gait(still, g.moveFrom / 2, 0.25)
			expect(still.pawFL).to.equal(0)
			expect(still.bodyY).to.equal(0)

			-- A quarter cycle in: a trot swings diagonal legs together, the other pair the opposite way.
			local walk = Logic.blank()
			Logic.gait(walk, 4, 0.25)
			expect(walk.pawFL > 0 and walk.pawBR > 0).to.equal(true)
			expect(walk.pawFR < 0 and walk.pawBL < 0).to.equal(true)
			expect(walk.pawFL <= math.rad(g.walkSwing) + 1e-6).to.equal(true)

			-- A gallop swings the front legs together and the back legs the other way.
			local run = Logic.blank()
			Logic.gait(run, 26, 0.25)
			expect(run.pawFL > 0 and run.pawFR > 0).to.equal(true)
			expect(run.pawBL < 0 and run.pawBR < 0).to.equal(true)
			expect(run.headPitch < 0).to.equal(true) -- stretched forward and down
			for _, value in run do
				expect(value == value and math.abs(value) <= 2).to.equal(true)
			end
		end)

		it("pants after a sprint with its head and tail low", function()
			local p = Presets.motion.pant
			for t = 0, 1, 0.05 do
				local o = Logic.idle("stray", t)
				Logic.pant(o, t)
				expect(o.bodyY >= 0 and o.bodyY <= p.studs + 1e-9).to.equal(true)
				expect(o.headPitch).to.be.near(-math.rad(p.headDown), 1e-9)
				expect(o.tailPitch).to.be.near(-math.rad(p.tailDown), 1e-9)
			end
		end)

		it("has the run, breath and shove presets it fires", function()
			expect(Presets.emitters.kick ~= nil and Presets.emitters.huff ~= nil).to.equal(true)
			expect(Presets.emitters.shiny ~= nil and Presets.emitters.hissPuff ~= nil).to.equal(
				true
			)
			local low = Presets.budget.low
			for _, count in
				{ Presets.reveal.sparkles, Presets.shove.puff, Presets.motion.gait.dust }
			do
				expect(math.min(math.floor(count * low.burstScale + 0.5), low.maxBurst) <= 12).to.equal(
					true
				)
			end
		end)
	end)
end
