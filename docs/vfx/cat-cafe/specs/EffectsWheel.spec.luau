--!strict
-- The Spin Wheel station's world wheel (F49): the curves Effects/Wheel turns it by. Written by the vfx-animator for
-- QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local TAU = 2 * math.pi

	describe("Effects spin wheel", function()
		it("eases from a fast start to a stop and never runs backwards", function()
			expect(Logic.wheelEase(0)).to.equal(0)
			expect(Logic.wheelEase(1)).to.equal(1)
			expect(Logic.wheelEase(-1)).to.equal(0)
			expect(Logic.wheelEase(2)).to.equal(1)
			local last = 0
			for k = 0.05, 1, 0.05 do
				local now = Logic.wheelEase(k)
				expect(now >= last).to.equal(true)
				last = now
			end
			-- most of the turning is done early
			expect(Logic.wheelEase(0.5) > 0.8).to.equal(true)
		end)

		it("stops inside the won slice, well clear of its edges", function()
			local w = Presets.wheel
			local width = TAU / w.slices
			for slice = 1, w.slices do
				for _, at in { 1793113500.25, 1793113504.9, 12.5, 99.001 } do
					local rest = Logic.wheelRest(at, slice, w.slices)
					-- turning by `rest` brings slice `slice`'s centre to within this much of the pointer
					local off = ((slice - 1) * width + rest) % TAU
					if off > TAU / 2 then
						off -= TAU
					end
					expect(math.abs(off) <= width * w.landWithin / 2 + 1e-9).to.equal(true)
					expect(math.abs(off) < width * 0.4).to.equal(true)
				end
			end
			-- no slice, or a slice the wheel does not have: it stops anywhere
			for _, bad in { 0, 7, 2.5 } do
				local rest = Logic.wheelRest(12.5, bad, w.slices)
				expect(rest >= 0 and rest < TAU).to.equal(true)
			end
			expect(Logic.wheelRest(12.5, nil, w.slices)).to.equal(
				Logic.wheelRest(12.5, 0, w.slices)
			)
		end)

		it("turns forward through the whole turns and stops where every client agrees", function()
			for _, at in { 1793113500.25, 1793113504.9, 12.5 } do
				local rest = Logic.wheelRest(at, nil, 6)
				expect(rest >= 0 and rest < TAU).to.equal(true)
				expect(Logic.wheelRest(at, nil, 6)).to.equal(rest)
				for _, from in { 0, 1.2, 40.7, -3 } do
					local to = Logic.wheelTarget(from, rest, 3)
					expect(to - from >= 3 * TAU - 1e-9 and to - from < 4 * TAU).to.equal(true)
					local landed = to % TAU
					expect(
						math.abs(landed - rest) < 1e-6
							or math.abs(math.abs(landed - rest) - TAU) < 1e-6
					).to.equal(true)
				end
			end
			expect(Logic.wheelRest(1793113500.25, nil, 6) ~= Logic.wheelRest(1793113504.9, nil, 6)).to.equal(
				true
			)
		end)

		it("knocks the pointer as each slice edge passes and lets it spring back", function()
			local w = Presets.wheel
			local slice = TAU / w.slices
			expect(Logic.pointerTilt(0, w.slices, w.tick, w.tickShare)).to.equal(w.tick)
			expect(Logic.pointerTilt(slice * 2, w.slices, w.tick, w.tickShare) > w.tick * 0.99).to.equal(
				true
			)
			expect(Logic.pointerTilt(slice * (w.tickShare + 0.01), w.slices, w.tick, w.tickShare)).to.equal(
				0
			)
			for angle = 0, TAU * 2, 0.05 do
				local tilt = Logic.pointerTilt(angle, w.slices, w.tick, w.tickShare)
				expect(tilt >= 0 and tilt <= w.tick).to.equal(true)
			end
		end)

		it("chases every other rim light round and stops inside the spin cooldown", function()
			local w = Presets.wheel
			for t = 0, 3, 0.05 do
				expect(Logic.chaseOn(1, t, w.chaseStep) ~= Logic.chaseOn(2, t, w.chaseStep)).to.equal(
					true
				)
			end
			expect(Logic.chaseOn(1, 0, w.chaseStep) ~= Logic.chaseOn(1, w.chaseStep, w.chaseStep)).to.equal(
				true
			)
			-- SpinCooldownSeconds is 4: a player's next spin starts from a wheel at rest
			expect(w.seconds < 4).to.equal(true)
			expect(w.stillTurns >= 1 and w.stillTurns < w.turns).to.equal(true)
		end)
	end)
end
