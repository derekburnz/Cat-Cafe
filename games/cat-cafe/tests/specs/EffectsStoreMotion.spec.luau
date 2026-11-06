--!strict
-- The store's motion (#1823): Logic.sparkOut is pure; StoreMotion.press and bought on the Store screen are a Studio row.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Logic.sparkOut", function()
		it("throws the sparks evenly round the card's middle, the first straight up", function()
			local b = Presets.storeMotion.bought
			local first = Logic.sparkOut(1, b.sparks, b.reach)
			expect(math.abs(first.X) < 1e-6).to.equal(true)
			expect(math.abs(first.Y + b.reach) < 1e-6).to.equal(true)
			local sumX, sumY = 0, 0
			for k = 1, b.sparks do
				local out = Logic.sparkOut(k, b.sparks, b.reach)
				expect(out.Magnitude <= b.reach + 1e-6).to.equal(true)
				expect(out.Magnitude >= 0.7 * b.reach - 1e-6).to.equal(true)
				sumX += out.X
				sumY += out.Y
			end
			-- spread all round, not all to one side
			expect(math.sqrt(sumX * sumX + sumY * sumY) < b.reach).to.equal(true)
		end)

		it("never divides by nothing", function()
			local out = Logic.sparkOut(1, 0, 10)
			expect(math.abs(out.Magnitude - 10) < 1e-6).to.equal(true)
		end)
	end)

	describe("Presets.storeMotion", function()
		it("dips a pressed button a little and pops a bought card a little", function()
			local m = Presets.storeMotion
			expect(m.press.dip < 1 and m.press.dip > 0.85).to.equal(true)
			expect(m.bought.pop > 1 and m.bought.pop < 1.15).to.equal(true)
			expect(m.press.down + m.press.up < 0.4).to.equal(true)
		end)
	end)
end
