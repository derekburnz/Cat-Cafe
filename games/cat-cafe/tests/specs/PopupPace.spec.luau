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

	describe("PopupPace.early (#4848, #4854)", function()
		it("holds the first five minutes of a session and the whole walk-through", function()
			expect(PopupPace.EARLY_SECONDS).to.equal(300)
			expect(PopupPace.early(10, 10, false)).to.equal(true)
			expect(PopupPace.early(10, 309.9, false)).to.equal(true)
			expect(PopupPace.early(10, 310, false)).to.equal(false)
			expect(PopupPace.early(10, 5000, true)).to.equal(true)
		end)
	end)
end
