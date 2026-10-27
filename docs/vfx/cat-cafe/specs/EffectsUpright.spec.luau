--!strict
-- Upright working cats (F25, engineer PR #159) in the client Effects module: legs found in the body's own axes,
-- and the standing doze at night in place of the curl. Written by the vfx-animator for QA to move into
-- tests/specs next to EffectsMotion.spec.luau. The leg cases use the exported Bengal's numbers, in its body part's
-- axes (body 0.855 x 0.665 x 1.47).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local BODY = Vector3.new(0.855, 0.665, 1.47)
	local LEG = Vector3.new(0.28, 0.5, 0.28)

	describe("Effects upright cats", function()
		it("finds the four legs in the body's own axes", function()
			expect(Logic.legOf(Vector3.new(0.266, -0.5125, -0.5), LEG, BODY)).to.equal("pawFR")
			expect(Logic.legOf(Vector3.new(-0.266, -0.5125, -0.5), LEG, BODY)).to.equal("pawFL")
			expect(Logic.legOf(Vector3.new(0.266, -0.5125, 0.45), LEG, BODY)).to.equal("pawBR")
			expect(Logic.legOf(Vector3.new(-0.266, -0.5125, 0.45), LEG, BODY)).to.equal("pawBL")
		end)

		it("takes no marking, collar bead or flat piece for a leg", function()
			-- a stripe on the flank: tall and thin, but up beside the body
			expect(
				Logic.legOf(Vector3.new(0.4375, 0.1375, 0.2), Vector3.new(0.04, 0.18, 0.18), BODY)
			).to.equal(nil)
			-- the low bead of a collar ring: under the body, but on the middle line
			expect(
				Logic.legOf(Vector3.new(0, -0.3725, -0.785), Vector3.new(0.16, 0.16, 0.12), BODY)
			).to.equal(nil)
			-- a flat piece under the body: wider than it is tall
			expect(Logic.legOf(Vector3.new(0.2, -0.45, 0), Vector3.new(0.3, 0.1, 0.3), BODY)).to.equal(
				nil
			)
		end)

		it("dozes on its feet: head down, no sink, legs straight", function()
			local d = Presets.motion.doze
			for t = 0, 8, 0.1 do
				local o = Logic.idle("doze", t)
				expect(o.sink).to.equal(0)
				expect(o.pawFL == 0 and o.pawFR == 0 and o.pawBL == 0 and o.pawBR == 0).to.equal(
					true
				)
				local droop = -math.deg(o.headPitch)
				expect(droop >= d.headDroop - d.nod - 1e-6 and droop <= d.headDroop + d.nod + 1e-6).to.equal(
					true
				)
				expect(math.abs(o.bodyRoll) <= math.rad(d.sway) + 1e-9).to.equal(true)
				expect(o.bodyY >= 0 and o.bodyY <= d.breathe + 1e-9).to.equal(true)
			end
			-- settling from a role idle into the doze never sinks either
			local mid = Logic.mix(Logic.idle("barista", 3), Logic.idle("doze", 3), 0.5)
			expect(mid.sink).to.equal(0)
		end)
	end)
end
