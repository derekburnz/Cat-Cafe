--!strict
-- #5655: the flight and hop clouds' hold before they part. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Clouds = require(Effects:WaitForChild("Clouds")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	-- runs a plan from 0 to `seconds` in steps of `dt`, landing at `landAt` (seconds, nil: never), and returns the shift
	local function run(seconds: number, landAt: number?): number
		local c = Presets.clouds
		local partFrom = c.hop.partFrom
		local shift, t, dt = 0, 0, 1 / 60
		while t < seconds do
			t += dt
			local landed = landAt ~= nil and t >= landAt
			shift = Clouds.holdStep(shift, t, partFrom, landed, c.hold, c.holdMost, dt)
		end
		return shift
	end

	describe("Effects clouds hold", function()
		it("does nothing before the part", function()
			local c = Presets.clouds
			expect(
				Clouds.holdStep(
					0,
					c.hop.partFrom - 0.1,
					c.hop.partFrom,
					false,
					c.hold,
					c.holdMost,
					0.1
				)
			).to.equal(0)
		end)

		it("holds about `hold` seconds when the landing is already in", function()
			local shift = run(5, 0)
			local c = Presets.clouds
			expect(math.abs(shift - c.hold) < 0.05).to.equal(true)
		end)

		it("waits for the landing, but never past holdMost", function()
			local c = Presets.clouds
			local late = c.hop.partFrom + 1
			local shift = run(6, late)
			expect(shift > c.hold).to.equal(true)
			expect(shift <= c.holdMost).to.equal(true)
			expect(run(8, nil)).to.equal(c.holdMost)
		end)

		it("reads cloudsHold, which starts off", function()
			local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags) :: any
			expect(Presets.clouds.holdFlag).to.equal("cloudsHold")
			expect(LiveFlags.OFF_BY_DEFAULT.cloudsHold).to.equal(true)
		end)
	end)
end
