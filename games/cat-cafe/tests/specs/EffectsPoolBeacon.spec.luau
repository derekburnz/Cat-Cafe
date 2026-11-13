--!strict
-- #3821: the Mystic Pool's quiet pointer fades out with distance and is off past 60 studs, and its light breathes
-- slowly (never near a flash).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local p = Presets.poolBeacon

	describe("Effects Mystic Pool pointer", function()
		it("is full near the pool, fades between, and is off from 60 studs out", function()
			expect(Logic.beaconFade(0, p.full, p.within)).to.equal(1)
			expect(Logic.beaconFade(p.full, p.full, p.within)).to.equal(1)
			expect(Logic.beaconFade((p.full + p.within) / 2, p.full, p.within)).to.be.near(
				0.5,
				1e-9
			)
			expect(Logic.beaconFade(p.within, p.full, p.within)).to.equal(0)
			expect(Logic.beaconFade(500, p.full, p.within)).to.equal(0)
			expect(Logic.beaconFade(math.huge, p.full, p.within)).to.equal(0)
			expect(p.within).to.equal(60)
		end)

		it("only ever fades as you walk away", function()
			local last = 2
			for d = 0, 80, 2 do
				local now = Logic.beaconFade(d, p.full, p.within)
				expect(now <= last).to.equal(true)
				last = now
			end
		end)

		it("breathes slowly between 1 and 1 minus its dip", function()
			expect(Logic.beaconBreath(0, p.breathSeconds, p.breathDip)).to.be.near(1, 1e-9)
			expect(Logic.beaconBreath(p.breathSeconds / 2, p.breathSeconds, p.breathDip)).to.be.near(
				1 - p.breathDip,
				1e-9
			)
			expect(1 / p.breathSeconds < 3).to.equal(true)
			expect(p.rate <= 4).to.equal(true)
		end)
	end)
end
