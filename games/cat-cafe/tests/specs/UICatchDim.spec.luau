--!strict
-- UI/Components/CatchDim (#4842): the dim the world takes while the catch runs, and plain values when it ends.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatchDim = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CatchDim")
	) :: any

	describe("UI catch dim", function()
		it("dims and greys the world while on, but keeps it readable", function()
			local on = CatchDim.look(true)
			expect(on.Brightness < 0 and on.Brightness >= -0.35).to.equal(true)
			expect(on.Saturation < 0 and on.Saturation >= -0.6).to.equal(true)
		end)

		it("goes back to plain values when off", function()
			local off = CatchDim.look(false)
			expect(off.Brightness).to.equal(0)
			expect(off.Saturation).to.equal(0)
			expect(off.Contrast).to.equal(0)
		end)

		it("eases in quickly", function()
			expect(CatchDim.IN <= 0.25).to.equal(true)
		end)
	end)
end
