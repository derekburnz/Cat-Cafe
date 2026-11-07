--!strict
-- UI/Components/Cooldown.luau: the short "Cooling down Ns" line (#2324).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Cooldown = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("Cooldown")
	) :: any

	describe("Cooldown.text", function()
		it("rounds the seconds left up, so the last second reads 1s", function()
			expect(Cooldown.text(3.2)).to.equal("Cooling down 4s")
			expect(Cooldown.text(3)).to.equal("Cooling down 3s")
			expect(Cooldown.text(0.05)).to.equal("Cooling down 1s")
		end)

		it("says nothing once the wait is over", function()
			expect(Cooldown.text(0)).to.equal(nil)
			expect(Cooldown.text(-1)).to.equal(nil)
			expect(Cooldown.text(0 / 0)).to.equal(nil)
		end)
	end)

	describe("Cooldown.nextTick", function()
		it("waits until the number goes down by one", function()
			expect(math.abs(Cooldown.nextTick(3.25) - 0.25) < 1e-6).to.equal(true)
			expect(math.abs(Cooldown.nextTick(3) - 1) < 1e-6).to.equal(true)
			expect(Cooldown.nextTick(0)).to.equal(0)
		end)
	end)
end
