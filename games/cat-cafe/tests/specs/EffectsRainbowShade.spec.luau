--!strict
-- Rainbow coats on dark cats (#3470: a rainbow Nebula came out duller than the other cats). A part's band is as
-- bright as its own colour is against the body's, so the body is always at full brightness, darker stripes are
-- darker and lighter marks (stars, a white chest) are paler.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-4
	end

	describe("Effects rainbow coat shade", function()
		local r = Presets.rainbow
		-- a Nebula's deep blue body and one of its pale stars
		local body = Logic.lightness(Color3.new(0.1216, 0.1647, 0.2667))
		local star = Logic.lightness(Color3.new(1, 0.9569, 0.6902))

		it("keeps a dark cat's body at full brightness", function()
			expect(near(Logic.rainbowShade(body, body, r.least), 1)).to.equal(true)
			expect(near(Logic.rainbowLift(body, body, r.lift), 0)).to.equal(true)
		end)

		it("shows a mark lighter than the body as a paler band, never darker", function()
			expect(near(Logic.rainbowShade(star, body, r.least), 1)).to.equal(true)
			local lift = Logic.rainbowLift(star, body, r.lift)
			expect(lift > 0.3 and lift <= r.lift).to.equal(true)
			expect(near(Logic.rainbowLift(1, body, r.lift), r.lift)).to.equal(true)
		end)

		it("still shows stripes darker than the body as darker bands", function()
			local stripe = body * 0.5
			local shade = Logic.rainbowShade(stripe, body, r.least)
			expect(shade < 1 and shade >= r.least).to.equal(true)
			expect(near(Logic.rainbowShade(0, body, r.least), r.least)).to.equal(true)
			expect(near(Logic.rainbowLift(stripe, body, r.lift), 0)).to.equal(true)
		end)

		it("leaves a light cat as it was", function()
			-- the body is the lightest part: stripes shade exactly as before and nothing is lifted
			expect(near(Logic.rainbowShade(0.45, 0.9, r.least), r.least + (1 - r.least) * 0.5)).to.equal(
				true
			)
			expect(near(Logic.rainbowLift(0.45, 0.9, r.lift), 0)).to.equal(true)
		end)

		it("copes with a black or a white body", function()
			expect(Logic.rainbowShade(0.5, 0, r.least)).to.equal(1)
			expect(Logic.rainbowLift(1, 1, r.lift)).to.equal(0)
			expect(r.lift > 0 and r.lift < 1).to.equal(true)
		end)
	end)
end
