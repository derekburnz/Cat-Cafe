--!strict
-- Controller rumble (#4224, Effects/Rumble): the pure parts. A bump's strength and length stay inside the presets'
-- limits and a catch's pulse grows with rarity. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Rumble = require(Effects:WaitForChild("Rumble")) :: any

	describe("Effects controller rumble", function()
		it("turns a camera bump into a strength between least and most", function()
			local r = Presets.rumble
			expect(Rumble.strength(0)).to.equal(0)
			expect(Rumble.strength(-1)).to.equal(0)
			expect(Rumble.strength(0 / 0)).to.equal(0)
			expect(Rumble.strength(0.01)).to.equal(r.least)
			expect(Rumble.strength(100)).to.equal(r.most)
			local missed = Rumble.strength(Presets.shake.studs)
			local shoved = Rumble.strength(Presets.shove.shakeStuds)
			expect(missed > r.least and missed < r.most).to.equal(true)
			expect(shoved > missed).to.equal(true)
		end)

		it("keeps a pulse short", function()
			local r = Presets.rumble
			expect(Rumble.length(0)).to.equal(0)
			expect(Rumble.length(0.01)).to.equal(r.shortest)
			expect(Rumble.length(10)).to.equal(r.longest)
			expect(Rumble.length(0.18)).to.equal(0.18)
			expect(r.longest <= 0.5).to.equal(true)
			expect(r.most < 1).to.equal(true)
		end)

		it("waits behind a switch that is off by default", function()
			local LiveFlags = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("LiveFlags")
			) :: any
			expect(LiveFlags.OFF_BY_DEFAULT.deviceFixes).to.equal(true)
			expect(LiveFlags.shown("deviceFixes", nil)).to.equal(false)
			expect(LiveFlags.shown("deviceFixes", true)).to.equal(true)
		end)

		it("buzzes more for a rarer catch", function()
			local order = { "Common", "Rare", "Epic", "Legendary", "Mythical", "Secret" }
			local lastSeconds, lastStrength = 0, 0
			for _, rarity in order do
				local seconds, strength = Rumble.catch(rarity)
				expect(seconds > lastSeconds and strength > lastStrength).to.equal(true)
				expect(seconds <= Presets.rumble.longest).to.equal(true)
				expect(strength <= Presets.rumble.most).to.equal(true)
				lastSeconds, lastStrength = seconds, strength
			end
			local seconds, strength = Rumble.catch("NoSuchRarity")
			expect(seconds).to.equal(Presets.rumble.catch.Common.seconds)
			expect(strength).to.equal(Presets.rumble.catch.Common.strength)
		end)
	end)
end
