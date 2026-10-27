--!strict
-- The loaf (Derek 2026-10-27, from draft E): resting cafe cats sit up from their nap now and then, tucked in and
-- still. Written by the vfx-animator for QA to move into tests/specs next to EffectsMotion.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects loaf", function()
		it("lies tucked in on its belly, head up and level, and keeps still", function()
			local l = Presets.motion.loaf
			for t = 0, 30, 0.1 do
				local o = Logic.idle("loaf", t)
				expect(o.sink).to.equal(1)
				local folded = math.rad(90)
				expect(
					o.pawFL == folded
						and o.pawFR == folded
						and o.pawBL == folded
						and o.pawBR == folded
				).to.equal(true)
				expect(math.abs(o.headYaw) <= math.rad(l.look) + 1e-9).to.equal(true)
				expect(math.abs(o.headRoll) <= math.rad(l.flick) + 1e-9).to.equal(true)
				expect(math.abs(o.headPitch) <= math.rad(l.headDroop) + 1e-9).to.equal(true)
				expect(o.bodyY >= 0 and o.bodyY <= l.breathe + 1e-9).to.equal(true)
				expect(o.bodyRoll == 0 and o.bodyPitch == 0).to.equal(true)
				-- the tail lies along the right side, opposite the nap's wrap to the left
				expect(o.tailYaw > 0).to.equal(true)
			end
			expect(Logic.idle("nap", 3).tailYaw < 0).to.equal(true)
		end)

		it("loafs for hold seconds of every cycle, each cat at its own time", function()
			local l = Presets.motion.loaf
			local phase = Logic.phaseOf("cat_uid_1")
			local on = 0
			for t = 0, l.every * 4 - 1 do
				if Logic.loafing(1000 + t, phase) then
					on += 1
				end
			end
			expect(on).to.equal(l.hold * 4)
			expect(l.hold < l.every / 2).to.equal(true)
			-- two cats are not up at the same moments
			local other = Logic.phaseOf("cat_uid_2")
			local same = true
			for t = 0, l.every - 1 do
				if Logic.loafing(t, phase) ~= Logic.loafing(t, other) then
					same = false
				end
			end
			expect(same).to.equal(false)
		end)

		it("gives each key one steady phase from 0 to under 1", function()
			for _, key in { "", "a", "cat_uid_1", "00000000-0000-4000-8000-000000000000" } do
				local phase = Logic.phaseOf(key)
				expect(phase >= 0 and phase < 1).to.equal(true)
				expect(Logic.phaseOf(key)).to.equal(phase)
			end
			expect(Logic.phaseOf("cat_uid_1") ~= Logic.phaseOf("cat_uid_2")).to.equal(true)
		end)

		it("settles from the nap into the loaf without leaving the floor", function()
			for k = 0, 1, 0.1 do
				local o = Logic.mix(Logic.idle("nap", 5), Logic.idle("loaf", 5), k)
				expect(o.sink).to.equal(1)
			end
		end)
	end)
end
