--!strict
-- UI/Components/ScreenShort.luau: the screen_short report's buckets (#2913).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ScreenShort = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ScreenShort")
	) :: any

	describe("ScreenShort.bucket", function()
		it("buckets a sideways phone, a tablet and a computer by the short side", function()
			expect(ScreenShort.bucket(Vector2.new(844, 390))).to.equal("lt400")
			expect(ScreenShort.bucket(Vector2.new(1024, 600))).to.equal("400_600")
			expect(ScreenShort.bucket(Vector2.new(400, 900))).to.equal("400_600")
			expect(ScreenShort.bucket(Vector2.new(1366, 768))).to.equal("gt600")
		end)
	end)
end
