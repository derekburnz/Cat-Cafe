--!strict
-- UI/Components/CafeGrewLogic.luau: "Your cafe grew!" on the Rank Up card (#4543).

return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CafeGrewLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CafeGrewLogic")
	) :: any

	describe("CafeGrewLogic (#4543)", function()
		it("reads a missing room as 44 x 34", function()
			local w, d = CafeGrewLogic.size(nil, nil)
			expect(w).to.equal(44)
			expect(d).to.equal(34)
			w, d = CafeGrewLogic.size(52, 40)
			expect(w).to.equal(52)
			expect(d).to.equal(40)
			w, d = CafeGrewLogic.size("52", -1)
			expect(w).to.equal(44)
			expect(d).to.equal(34)
		end)

		it("calls a bigger room a growth, the same or smaller not", function()
			expect(CafeGrewLogic.grew(44, 34, 52, 40)).to.equal(true)
			expect(CafeGrewLogic.grew(44, 34, 52, 34)).to.equal(true)
			expect(CafeGrewLogic.grew(44, 34, 44, 34)).to.equal(false)
			expect(CafeGrewLogic.grew(52, 40, 44, 34)).to.equal(false)
			expect(CafeGrewLogic.grew(52, 40, 60, 38)).to.equal(false)
		end)

		it(
			"counts a growth only within RANK_WINDOW of a rank up (join growth is not one)",
			function()
				expect(CafeGrewLogic.fromRankUp(100, nil)).to.equal(false) -- the join growth: no rank up
				expect(CafeGrewLogic.fromRankUp(nil, 100)).to.equal(false)
				expect(CafeGrewLogic.fromRankUp(100, 95)).to.equal(true) -- the tier came first
				expect(CafeGrewLogic.fromRankUp(95, 100)).to.equal(true) -- the room came first
				local late = 100 - CafeGrewLogic.RANK_WINDOW - 1
				expect(CafeGrewLogic.fromRankUp(late, 100)).to.equal(false)
			end
		)

		it("shows the line only on the tier the room grew at", function()
			expect(CafeGrewLogic.shows(3, 3)).to.equal(true)
			expect(CafeGrewLogic.shows(3, 4)).to.equal(false)
			expect(CafeGrewLogic.shows(nil, 3)).to.equal(false)
			expect(#CafeGrewLogic.LINE <= 28).to.equal(true)
		end)
	end)
end
