--!strict
-- The near miss (F93, catch-rework.md section 1): a swing that hits nothing sends the free strays within
-- NetMissHopStuds off at a run, each with HopAt (server time); the cat springs up startled as it sets off, without the
-- hiss. Logic.startle is pure; the spring on a real stray (Cats.startle from HopAt) is a Studio row.
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local s = Presets.motion.startle

	local function at(alpha: number): any
		local o = Logic.blank()
		o.tailYaw = 0.3
		Logic.startle(o, alpha)
		return o
	end

	describe("Effects near-miss startle", function()
		it("springs up and lands in one arc, highest halfway", function()
			expect(at(0).bodyY).to.be.near(0, 1e-9)
			expect(at(0.5).bodyY).to.be.near(s.hop, 1e-9)
			expect(at(0.25).bodyY).to.be.near(at(0.75).bodyY, 1e-9)
			expect(at(0.999).bodyY < s.hop * 0.01).to.equal(true)
		end)

		it(
			"throws its nose, tail and ears up at the top and leaves them as they were after",
			function()
				local top = at(0.5)
				expect(top.bodyPitch).to.be.near(math.rad(s.lean), 1e-9)
				expect(top.tailPitch).to.be.near(math.rad(s.tailUp), 1e-9)
				expect(top.tailYaw).to.be.near(0, 1e-9) -- the swish stops while it springs
				expect(top.earL).to.be.near(math.rad(s.ears), 1e-9)
				expect(top.earR).to.be.near(math.rad(s.ears), 1e-9)
				for _, alpha in { -0.1, 1, 1.5 } do
					local o = at(alpha)
					expect(o.bodyY).to.equal(0)
					expect(o.tailYaw).to.equal(0.3)
					expect(o.earL).to.equal(0)
				end
			end
		)

		it("moves with no jumps at 60 frames a second", function()
			local step = 1 / (60 * s.seconds)
			local last = at(0)
			for alpha = step, 1 - step, step do
				local o = at(alpha)
				expect(math.abs(o.bodyY - last.bodyY) < 0.15).to.equal(true)
				expect(math.abs(o.earL - last.earL) < math.rad(10)).to.equal(true)
				last = o
			end
		end)

		it("is a quick spring, not the hiss", function()
			expect(s.seconds > 0 and s.seconds < Presets.motion.hiss.seconds).to.equal(true)
			expect(s.hop > 0 and s.hop < Presets.motion.hiss.hop).to.equal(true)
		end)
	end)
end
