--!strict
-- The first catch's held-ring pulse (#2920): slower than 3 Hz and no longer than the hold.
-- Written by the vfx-animator.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

	describe("Effects hold pulse", function()
		it("pulses under 3 Hz and grows outward", function()
			local p = Presets.holdPulse
			expect(p.gap >= 1 / 3).to.equal(true)
			expect(p.seconds > 0).to.equal(true)
			expect(p.to > p.from).to.equal(true)
		end)

		it("stops by the end of the hold", function()
			local hold = Config.FirstRingHoldSeconds
			if type(hold) == "number" then
				expect(Presets.holdPulse.most <= hold).to.equal(true)
			end
		end)
	end)
end
