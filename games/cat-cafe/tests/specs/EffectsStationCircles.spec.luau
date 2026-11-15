--!strict
-- Effects/StationCircles (#4668): the walk-up rings show only for an explicit Station circles on.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local StationCircles =
		require(Client:WaitForChild("Effects"):WaitForChild("StationCircles")) :: any

	describe("Effects station circles", function()
		it("hides the rings unless the setting is true", function()
			expect(StationCircles.visible(true)).to.equal(true)
			expect(StationCircles.visible(false)).to.equal(false)
			expect(StationCircles.visible(nil)).to.equal(false)
			expect(StationCircles.visible("true")).to.equal(false)
		end)
	end)
end
