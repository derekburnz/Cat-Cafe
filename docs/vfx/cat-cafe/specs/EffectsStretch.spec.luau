--!strict
-- Stretching, getting up and lying down, and the slow walk (Derek 2026-10-27: "also walking animations and changing
-- between positions and stretching"). Written by the Animation-Engineer for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local m = Presets.motion

	describe("Effects stretch", function()
		it("eases an action in, holds it and eases it out", function()
			expect(Logic.envelope(0.1, 0.2, 0.4, 0.6, 0.8)).to.equal(0)
			expect(Logic.envelope(0.5, 0.2, 0.4, 0.6, 0.8)).to.equal(1)
			expect(Logic.envelope(0.9, 0.2, 0.4, 0.6, 0.8)).to.equal(0)
			expect(Logic.envelope(0.3, 0.2, 0.4, 0.6, 0.8)).to.be.near(0.5, 1e-9)
			expect(Logic.envelope(0.7, 0.2, 0.4, 0.6, 0.8)).to.be.near(0.5, 1e-9)
		end)

		it("bows, then stretches each back leg behind, on all fours", function()
			local bow = Logic.blank()
			Logic.stretch(bow, 0.4, "walk")
			expect(bow.bodyPitch).to.be.near(-math.rad(m.stretch.bow), 1e-6) -- nose down, rear up
			expect(bow.pawFL > 0 and bow.pawFR > 0).to.equal(true) -- front legs out ahead
			expect(bow.pawBL > 0 and bow.pawBR > 0).to.equal(true) -- back legs turned back upright
			expect(bow.tailPitch > 0).to.equal(true)
			expect(bow.blink).to.equal(1)
			expect(bow.bodyY < 0).to.equal(true)

			local left = Logic.blank()
			Logic.stretch(left, 0.64, "walk")
			expect(left.pawBL < 0).to.equal(true) -- back left out behind
			expect(math.abs(left.pawBR) < math.abs(left.pawBL)).to.equal(true)
			local right = Logic.blank()
			Logic.stretch(right, 0.8, "walk")
			expect(right.pawBR < 0).to.equal(true)
			expect(math.abs(right.pawBL) < math.abs(right.pawBR)).to.equal(true)
		end)

		it("reaches up with both front paws and yawns, sat up", function()
			local o = Logic.blank()
			Logic.stretch(o, 0.5, "sit")
			expect(o.pawFL > 0 and o.pawFR > 0).to.equal(true)
			expect(o.bodyPitch > 0 and o.headPitch > 0).to.equal(true)
			expect(o.blink).to.equal(1)
		end)

		it("gets up out of a nap for the stretch and lies back down after", function()
			local mid = Logic.idle("nap", 1, "walk")
			Logic.stretch(mid, 0.4, "walk")
			expect(mid.sleep).to.equal(0)
			expect(mid.sink).to.equal(0)
			local done = Logic.idle("nap", 1, "walk")
			Logic.stretch(done, 0.999, "walk")
			expect(done.sleep > 0.99).to.equal(true)
		end)

		it("does nothing outside its time or at no weight, and stays small", function()
			for _, alpha in { -0.1, 1, 1.5 } do
				local o = Logic.blank()
				Logic.stretch(o, alpha, "walk")
				for _, value in o do
					expect(value).to.equal(0)
				end
			end
			local none = Logic.blank()
			Logic.stretch(none, 0.4, "walk", 0)
			for _, value in none do
				expect(value).to.equal(0)
			end
			for _, body in { "walk", "sit", "parts" } do
				for alpha = 0, 0.99, 0.01 do
					local o = Logic.idle("stray", alpha * 3, body)
					Logic.stretch(o, alpha, body)
					for _, value in o do
						expect(value == value and math.abs(value) <= 2).to.equal(true)
					end
				end
			end
		end)

		it("lies down slowly, gets up a little quicker", function()
			expect(Logic.settleSeconds("stray", "nap")).to.equal(m.settleDown)
			expect(Logic.settleSeconds("sit", "loaf")).to.equal(m.settleDown)
			expect(Logic.settleSeconds("nap", "stray")).to.equal(m.settleUp)
			expect(Logic.settleSeconds("nap", "loaf")).to.equal(m.settle)
			expect(Logic.settleSeconds("sit", "doze")).to.equal(m.settle)
			expect(Logic.settleSeconds(nil, "nap")).to.equal(m.settleDown)
			expect(Logic.asleep("nap") and Logic.asleep("doze")).to.equal(true)
			expect(Logic.asleep("loaf") or Logic.asleep("sit") or Logic.asleep(nil)).to.equal(false)
		end)
	end)

	describe("Effects walk", function()
		local g = m.gait

		it("walks one leg at a time below a trot", function()
			local speed = (g.moveFrom * 2 + g.trotFrom) / 3 -- a slow wander, fully walking
			expect(speed >= g.moveFrom * 2 and speed < g.trotFrom).to.equal(true)
			-- a quarter cycle in, the back left leg is fully forward, the back right fully back and the front
			-- legs pass under the body
			local o = Logic.blank()
			Logic.gait(o, speed, 0.25)
			expect(o.pawBL).to.be.near(math.rad(g.walkSwing), 1e-6)
			expect(o.pawBR).to.be.near(-math.rad(g.walkSwing), 1e-6)
			expect(math.abs(o.pawFL) < 1e-6 and math.abs(o.pawFR) < 1e-6).to.equal(true)
			-- each leg a quarter cycle behind the last: back left, front left, back right, front right
			local f = Logic.blank()
			Logic.gait(f, speed, 0.5)
			expect(f.pawFL).to.be.near(math.rad(g.walkSwing), 1e-6)
		end)

		it("holds its tail up and nods while walking, not when running flat out", function()
			local walk = Logic.blank()
			Logic.gait(walk, 3, 0.1)
			expect(walk.tailPitch > 0).to.equal(true)
			local nods = 0
			for stride = 0, 1, 0.05 do
				local o = Logic.blank()
				Logic.gait(o, 3, stride)
				if math.abs(o.headPitch) > math.rad(g.walkNod) * 0.5 then
					nods += 1
				end
			end
			expect(nods > 0).to.equal(true)
			local run = Logic.blank()
			Logic.gait(run, 26, 0.1)
			expect(run.tailPitch).to.be.near(math.rad(8), 1e-6)
			expect(run.bodyRoll).to.equal(0)
		end)
	end)
end
