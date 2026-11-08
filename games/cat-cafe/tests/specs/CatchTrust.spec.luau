--!strict
-- UI/Components/CatchTrust.luau: Catch v3's trust bar numbers and the Purrfect streak line (#1884, catch-rework.md 7b, 7d).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatchTrust = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CatchTrust")
	) :: any

	describe("CatchTrust", function()
		it("adds Perfect +3, Good +2, Miss -2 and a paw ring left alone +1 (#2005)", function()
			expect(CatchTrust.after(2, { "perfect", "perfect", "perfect" })).to.equal(11)
			expect(CatchTrust.after(2, { "good", "miss" })).to.equal(2)
			expect(CatchTrust.after(3, { "left", "perfect" })).to.equal(7)
			expect(CatchTrust.after(2, {})).to.equal(2)
		end)

		it("fills the bar from 0 to 1 and never past either end", function()
			expect(CatchTrust.fill(4, 8)).to.equal(0.5)
			expect(CatchTrust.fill(-1, 8)).to.equal(0)
			expect(CatchTrust.fill(12, 8)).to.equal(1)
			expect(CatchTrust.fill(3, 0)).to.equal(0)
		end)

		it("shows the streak from the second Purrfect in a row", function()
			expect(CatchTrust.streakText(nil)).to.equal(nil)
			expect(CatchTrust.streakText(1)).to.equal(nil)
			expect(CatchTrust.streakText(2)).to.equal("Purrfect x2")
			expect(CatchTrust.streakText(7)).to.equal("Purrfect x7")
		end)
	end)
end
