--!strict
-- #5285 E2 the wow first catch's timeline and confetti count. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Wow = require(Effects:WaitForChild("FirstCatchWow")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects wow first catch", function()
		it("adds under 1.5 s: slow push in, banner 0.3 to 1.3 s, camera back", function()
			local p = Presets.firstCatchWow
			expect(Wow.length(p) < 1.5).to.equal(true)
			local push, speed, banner = Wow.at(0, p)
			expect(push).to.equal(0)
			expect(speed).to.equal(p.slowSpeed)
			expect(banner).to.equal(0)
			push, speed = Wow.at(p.slowSeconds + 0.01, p)
			expect(push).to.equal(1)
			expect(speed).to.equal(1)
			local _, _, shown = Wow.at(p.bannerAt + p.bannerIn, p)
			expect(shown).to.be.near(1, 1e-6)
			local _, _, gone = Wow.at(p.bannerEnd, p)
			expect(gone).to.be.near(0, 1e-6)
			push = Wow.at(Wow.length(p), p)
			expect(push).to.be.near(0, 1e-6)
			expect(p.push).to.equal(0.15)
			expect(p.ringScale).to.equal(2)
			expect(p.coins).to.equal(30)
		end)

		it(
			"holds the slow on a track the Animate script or a new pose sets back to full speed",
			function()
				local speed, own = Wow.holdSpeed(1, nil, nil, 0.3)
				expect(speed).to.be.near(0.3, 1e-6)
				expect(own).to.equal(1)
				speed, own = Wow.holdSpeed(0.3, own, speed, 0.3) -- unchanged since we set it
				expect(speed).to.be.near(0.3, 1e-6)
				expect(own).to.equal(1)
				speed, own = Wow.holdSpeed(1.6, own, speed, 0.3) -- the walk sped up: its own speed is now 1.6
				expect(speed).to.be.near(0.48, 1e-6)
				expect(own).to.equal(1.6)
			end
		)

		it("halves the confetti on a phone or the low tier", function()
			local p = Presets.firstCatchWow
			expect(Wow.confetti(40, false, p)).to.equal(40)
			expect(Wow.confetti(40, true, p)).to.equal(20)
		end)

		it("is off unless the switch is true", function()
			expect(Wow.on()).to.equal(false)
		end)
	end)
end
