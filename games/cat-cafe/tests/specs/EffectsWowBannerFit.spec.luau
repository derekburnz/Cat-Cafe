--!strict
-- #5686: the FIRST CATCH! banner stays whole below the top edge. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Wow = require(Effects:WaitForChild("FirstCatchWow")) :: any

	describe("FIRST CATCH! banner fit", function()
		it("keeps the strip's spot when the switch is off", function()
			expect(Wow.fitY(10, 60, 1.12, 6, false)).to.equal(10)
		end)

		it("keeps the strip's spot when the banner already fits", function()
			expect(Wow.fitY(80, 60, 1.12, 6, true)).to.equal(80)
		end)

		it("moves the middle down so the grown banner clears the top edge", function()
			local y = Wow.fitY(10, 60, 1.12, 6, true)
			expect(y - 60 * 1.12 / 2 >= 6 - 1e-6).to.equal(true)
		end)
	end)
end
