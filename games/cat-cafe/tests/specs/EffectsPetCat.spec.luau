--!strict
-- Effects/PetCat (petting a cat in your cafe, #3651): the arm reaches, strokes and comes back; the hearts float up,
-- fan out and fade; everything is short and gentle.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects pet cat", function()
		local p = Presets.petCat
		local function at(seconds: number): (number, number)
			return Logic.petAt(seconds, p.raise, p.strokes, p.every, p.lower)
		end

		it("reaches down, strokes and comes back", function()
			local whole = p.raise + p.strokes * p.every + p.lower
			expect((at(0))).to.equal(0)
			expect((at(whole))).to.equal(0)
			expect((at(-1))).to.equal(0)
			local rising = at(p.raise / 2)
			expect(rising > 0 and rising < 1).to.equal(true)
			-- a quarter into the first stroke the hand is fully one way, three quarters in fully the other
			local weight, stroke = at(p.raise + p.every * 0.25)
			expect(weight).to.equal(1)
			expect(math.abs(stroke - 1) < 1e-6).to.equal(true)
			local _, back = at(p.raise + p.every * 0.75)
			expect(math.abs(back + 1) < 1e-6).to.equal(true)
			-- short, and a slow stroke (nothing fast or flashing)
			expect(whole <= 1.5).to.equal(true)
			expect(1 / p.every <= 3).to.equal(true)
		end)

		it("floats the hearts up, fanned out, and fades them", function()
			local count = p.hearts
			for index = 1, count do
				local offset, scale, fade = Logic.petHeart(index, count, 1, p.heartRise, p.heartFan)
				expect(math.abs(offset.Y - p.heartRise) < 1e-6).to.equal(true)
				expect(scale).to.equal(1)
				expect(fade).to.equal(1)
				local mid, _, showing = Logic.petHeart(index, count, 0.5, p.heartRise, p.heartFan)
				expect(mid.Y > 0 and mid.Y < p.heartRise).to.equal(true)
				expect(showing).to.equal(0)
			end
			local first = Logic.petHeart(1, count, 1, p.heartRise, p.heartFan)
			local last = Logic.petHeart(count, count, 1, p.heartRise, p.heartFan)
			expect(math.abs((last.X - first.X) - p.heartFan) < 1e-6).to.equal(true)
			-- one heart alone goes straight up
			local one = Logic.petHeart(1, 1, 1, p.heartRise, p.heartFan)
			expect(one.X).to.equal(0)
			-- a small puff: a handful of hearts
			expect(count <= 6).to.equal(true)
			expect(p.move.seconds <= 1).to.equal(true)
		end)
	end)
end
