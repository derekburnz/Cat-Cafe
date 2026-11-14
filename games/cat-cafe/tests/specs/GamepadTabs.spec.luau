--!strict
-- UI/Components/GamepadTabs.luau: which tab L1 / R1 land on (#4224).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GamepadTabs = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GamepadTabs")
	) :: any

	describe("GamepadTabs.index", function()
		it("steps from the open tab (the one not in ghost) and wraps round", function()
			local styles = { "ghost", "gold", "ghost", "ghost" }
			expect(GamepadTabs.index(styles, 1)).to.equal(3)
			expect(GamepadTabs.index(styles, -1)).to.equal(1)
			expect(GamepadTabs.index({ "ghost", "ghost", "primary" }, 1)).to.equal(1)
			expect(GamepadTabs.index({ "gold", "ghost", "ghost" }, -1)).to.equal(3)
		end)

		it("takes the first or last tab when none looks open, and nothing with one tab", function()
			expect(GamepadTabs.index({ "ghost", "ghost", "ghost" }, 1)).to.equal(1)
			expect(GamepadTabs.index({ "ghost", "ghost", "ghost" }, -1)).to.equal(3)
			expect(GamepadTabs.index({ "gold" }, 1)).to.equal(nil)
			expect(GamepadTabs.index({}, 1)).to.equal(nil)
		end)
	end)
end
