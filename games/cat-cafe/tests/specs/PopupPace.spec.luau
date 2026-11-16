--!strict
-- UI/Components/PopupPace.luau: one self-opening card every 5 minutes (#4833).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PopupPace = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("PopupPace")
	) :: any

	describe("PopupPace.free", function()
		it("is free before any card this session", function()
			expect(PopupPace.free(nil, 0)).to.equal(true)
		end)

		it("waits five minutes after a card", function()
			expect(PopupPace.GAP_SECONDS).to.equal(300)
			expect(PopupPace.free(100, 100)).to.equal(false)
			expect(PopupPace.free(100, 399.9)).to.equal(false)
			expect(PopupPace.free(100, 400)).to.equal(true)
		end)
	end)
end
