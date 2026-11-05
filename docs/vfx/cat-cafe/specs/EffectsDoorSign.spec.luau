--!strict
-- The decor door sign (#1172): the names DoorSign.luau switches between match Model-Agent's two boards.
-- Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects door sign", function()
		it("switches between Model-Agent's two boards", function()
			-- CatCafe_Decor_DoorSign: the OPEN board's parts and the CLOSED board's child Model
			expect(Presets.doorSign.open).to.equal("CatCafe_Decor_DoorSign_Open")
			expect(Presets.doorSign.closed).to.equal("CatCafe_Decor_DoorSign_Closed")
		end)

		it("never confuses the two boards", function()
			expect(Presets.doorSign.open ~= Presets.doorSign.closed).to.equal(true)
		end)
	end)
end
