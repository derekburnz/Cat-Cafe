--!strict
-- Effects/FirstMinuteFx cheers only the walk-through's first net catch.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FirstMinuteFx =
		require(Client:WaitForChild("Effects"):WaitForChild("FirstMinuteFx")) :: any

	describe("FirstMinuteFx", function()
		it("cheers a catch before the first check-in, once", function()
			expect(FirstMinuteFx.cheers(0, false)).to.equal(true)
			expect(FirstMinuteFx.cheers(1, false)).to.equal(true)
			expect(FirstMinuteFx.cheers(1, true)).to.equal(false)
		end)
		it("stays quiet after the first check-in or before the save is known", function()
			expect(FirstMinuteFx.cheers(2, false)).to.equal(false)
			expect(FirstMinuteFx.cheers(9, false)).to.equal(false)
			expect(FirstMinuteFx.cheers(nil, false)).to.equal(false)
		end)
	end)
end
