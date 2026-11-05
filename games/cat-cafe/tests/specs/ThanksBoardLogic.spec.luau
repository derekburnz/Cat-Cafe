--!strict
-- UI/Components/ThanksBoardLogic.luau: the Thank You board's credit line and paging (#1083).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("ThanksBoardLogic")) :: any

	describe("ThanksBoardLogic", function()
		it("words the credit line with the version and the display name", function()
			expect(Logic.creditLine({ idea = "x", version = 190, name = "MochiPie" })).to.equal(
				"v190 · Idea from MochiPie"
			)
			expect(Logic.creditLine({ idea = "x", version = 190, name = "a player" })).to.equal(
				"v190 · Idea from a player"
			)
			expect(Logic.creditLine({ idea = "x" })).to.equal("Idea from a player")
		end)
		it("pages six cards at a time and clamps the page", function()
			local rows = {}
			for index = 1, 14 do
				table.insert(rows, { idea = "idea " .. index, version = 1, name = "n" })
			end
			local first = Logic.page(rows, 1)
			expect(#first.rows).to.equal(6)
			expect(first.pages).to.equal(3)
			expect(first.rows[1].idea).to.equal("idea 1")
			local last = Logic.page(rows, 9)
			expect(last.page).to.equal(3)
			expect(#last.rows).to.equal(2)
			expect(Logic.page({}, 1).pages).to.equal(1)
		end)
	end)
end
