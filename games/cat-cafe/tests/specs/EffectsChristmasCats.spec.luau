--!strict
-- Effects/ChristmasCats (snowglobe-village-spec section 4): Jingle's bell jiggle and the star and gem glows.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects.ChristmasCats", function()
		it("names the three cats with beats, and only Jingle wears the bell", function()
			local cats = Presets.christmasCats.cats
			expect(cats.jingle.bell).to.equal(true)
			expect(cats.star_topper.bell).to.equal(false)
			expect(#cats.star_topper.glows >= 1).to.equal(true)
			expect(#cats.sugar_plum.glows >= 1).to.equal(true)
		end)

		it("jiggles the bell and settles, moving nothing else", function()
			local o = { bell = 0, headRoll = 0, headPitch = 0 }
			Logic.jingleBell(o, 0.08)
			expect(o.bell ~= 0).to.equal(true)
			expect(o.headRoll).to.equal(0)
			local done = { bell = 0 }
			Logic.jingleBell(done, 1)
			Logic.jingleBell(done, -0.1)
			expect(done.bell).to.equal(0)
			local j = Presets.christmasCats.jingle
			expect(math.abs(o.bell) <= math.rad(j.degrees) + 1e-9).to.equal(true)
			expect(j.every[1] < j.every[2]).to.equal(true)
		end)

		it("glows dim by day, twinkles at night and holds steady with Reduce Motion", function()
			local c = Presets.christmasCats
			expect(Logic.christmasGlow(3, false, 0, false)).to.equal(c.dayDim)
			for t = 0, 4, 0.1 do
				local k = Logic.christmasGlow(t, true, 1, false)
				expect(k >= 0 and k <= c.nightDim + 1e-9).to.equal(true)
			end
			expect(Logic.christmasGlow(1, true, 0, true)).to.equal(0)
			expect(c.nightDim < c.dayDim).to.equal(true) -- brighter at night than by day
		end)
	end)
end
