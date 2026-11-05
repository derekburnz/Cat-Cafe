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

		it("reads the slice widths off the Wheel, else equal slices (#1411)", function()
			local spans = Logic.wheelSpans("52,52,52,52,52,52,24,24", 6)
			expect(#spans).to.equal(8)
			expect(spans[1]).to.equal(52)
			expect(spans[8]).to.equal(24)
			for _, bad in { nil, 5, "", "52,52,x", "90,90,90", "120,-120,360" } do
				local equal = Logic.wheelSpans(bad, 6)
				expect(#equal).to.equal(6)
				expect(math.abs(equal[1] - 60) < 1e-9).to.equal(true)
			end
			-- slice 1's middle is under the pointer at rest; the jackpots' middles follow the six wide slices
			expect(Logic.sliceMiddle(spans, 1)).to.equal(0)
			expect(Logic.sliceMiddle(spans, 2)).to.equal(52)
			expect(Logic.sliceMiddle(spans, 7)).to.equal(52 * 5 + 26 + 12)
			expect(Logic.sliceMiddle(spans, 8)).to.equal(52 * 5 + 26 + 24 + 12)
		end)

		it("stops inside the won slice, well clear of its edges, wide or narrow", function()
			local w = Presets.wheel
			local wheels = { Logic.wheelSpans(nil, w.slices), Logic.wheelSpans("52,52,52,52,52,52,24,24", 6) }
			for _, spans in wheels do
				for slice = 1, #spans do
					local width = math.rad(spans[slice])
					for _, at in { 1793113500.25, 1793113504.9, 12.5, 99.001 } do
						local rest = Logic.wheelRest(at, slice, spans)
						-- turning by `rest` brings slice `slice`'s middle to within this much of the pointer
						local off = (math.rad(Logic.sliceMiddle(spans, slice)) + rest) % TAU
						if off > TAU / 2 then
							off -= TAU
						end
						expect(math.abs(off) <= width * w.landWithin / 2 + 1e-9).to.equal(true)
						expect(math.abs(off) < width * 0.4).to.equal(true)
					end
				end
				-- no slice, or a slice the wheel does not have: it stops anywhere
				for _, bad in { 0, #spans + 1, 2.5 } do
					local rest = Logic.wheelRest(12.5, bad, spans)
					expect(rest >= 0 and rest < TAU).to.equal(true)
				end
				expect(Logic.wheelRest(12.5, nil, spans)).to.equal(Logic.wheelRest(12.5, 0, spans))
			end
		end)

		it("turns forward through the whole turns and stops where every client agrees", function()
			for _, at in { 1793113500.25, 1793113504.9, 12.5 } do
				local rest = Logic.wheelRest(at, nil, Logic.wheelSpans(nil, 6))
				expect(rest >= 0 and rest < TAU).to.equal(true)
				expect(Logic.wheelRest(at, nil, Logic.wheelSpans(nil, 6))).to.equal(rest)
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
			expect(Logic.wheelRest(1793113500.25, nil, Logic.wheelSpans(nil, 6))
					~= Logic.wheelRest(1793113504.9, nil, Logic.wheelSpans(nil, 6))).to.equal(
				true
			)
		end)

		it("knocks the pointer as each slice edge passes and lets it spring back", function()
			local w = Presets.wheel
			local spans = Logic.wheelSpans("52,52,52,52,52,52,24,24", 6)
			-- at rest the pointer is mid-slice, so it hangs straight
			expect(Logic.pointerTilt(0, spans, w.tick, w.tickShare)).to.equal(0)
			-- turning forward, the edge between slices 1 and 8 passes at half of slice 1, then every edge after it
			local edge = 0
			for k = 0, #spans - 1 do
				local slice = if k == 0 then 1 else #spans - k + 1
				edge += if k == 0 then spans[1] / 2 else spans[slice]
				local past = math.rad(edge + 0.01)
				expect(Logic.pointerTilt(past, spans, w.tick, w.tickShare) > w.tick * 0.95).to.equal(true)
				local before = math.rad(edge - 0.5)
				expect(Logic.pointerTilt(before, spans, w.tick, w.tickShare) < w.tick * 0.2).to.equal(true)
			end
			for angle = 0, TAU * 2, 0.05 do
				local tilt = Logic.pointerTilt(angle, spans, w.tick, w.tickShare)
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
