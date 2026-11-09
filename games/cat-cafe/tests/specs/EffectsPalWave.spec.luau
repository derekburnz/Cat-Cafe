--!strict
-- The pal wave (F92, playing-together.md section 5: "a little wave from both characters" when an invited or
-- following player spawns at a pal's front door). Avatar.waveAt and waveSeconds are pure; the arm on a character
-- (Avatar.waveArm through PalWave.luau and Tackle.luau, on Gameplay-Engineer's PalArrived) is a Studio row
-- (effects-list "Pal wave").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Avatar = require(Effects:WaitForChild("Avatar")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local w = Presets.palWave
	local FRAME = 1 / 60

	describe("Effects pal wave", function()
		it("lasts the raise, the waves and the lowering, under two seconds", function()
			local total: number = Avatar.waveSeconds()
			expect(total).to.be.near(w.raise + w.waves * w.every + w.lower, 1e-9)
			expect(total < 2).to.equal(true)
			-- the pal waves back while the joiner is still waving
			expect(w.palDelay > 0 and w.palDelay < total / 2).to.equal(true)
		end)

		it("eases the arm up, holds it through the waves and eases it down", function()
			local total: number = Avatar.waveSeconds()
			for _, t in { -1, 0, total, total + 1 } do
				local weight, swing = Avatar.waveAt(t)
				expect(weight).to.equal(0)
				expect(swing).to.equal(0)
			end
			local last = 0
			for t = FRAME, w.raise, FRAME do
				local weight = Avatar.waveAt(t)
				expect(weight >= last).to.equal(true)
				last = weight
			end
			for t = w.raise + 0.01, w.raise + w.waves * w.every - 0.01, 0.01 do
				local weight = Avatar.waveAt(t)
				expect(weight).to.equal(1)
			end
			last = 1
			for t = w.raise + w.waves * w.every + FRAME, total - 1e-6, FRAME do
				local weight = Avatar.waveAt(t)
				expect(weight <= last).to.equal(true)
				expect(weight >= 0).to.equal(true)
				last = weight
			end
		end)

		it("waves the hand side to side the set number of times, still while the arm goes up or down", function()
			local peaks = 0
			local before, now = 0, 0
			for t = 0, Avatar.waveSeconds(), 0.001 do
				local weight, swing = Avatar.waveAt(t)
				expect(math.abs(swing) <= 1).to.equal(true)
				if t < w.raise or t > w.raise + w.waves * w.every then
					expect(swing).to.be.near(0, 1e-6)
				end
				expect(weight >= 0 and weight <= 1).to.equal(true)
				if now > before and now > swing then
					peaks += 1
				end
				before, now = now, swing
			end
			expect(peaks).to.equal(w.waves)
		end)

		it("moves with no jumps at 60 frames a second", function()
			local lastWeight, lastSwing = 0, 0
			for t = 0, Avatar.waveSeconds() + FRAME, FRAME do
				local weight, swing = Avatar.waveAt(t)
				expect(math.abs(weight - lastWeight) < 0.15).to.equal(true)
				expect(math.abs(swing - lastSwing) < 0.3).to.equal(true)
				lastWeight, lastSwing = weight, swing
			end
		end)
	end)
end
