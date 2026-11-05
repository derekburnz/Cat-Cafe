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
		it("lines up What's new with its icon, short date and linked credit (#1216)", function()
			local updates = {
				{
					id = "a",
					date = "2026-11-05",
					icon = "faster",
					text = "Faster cannon",
					creditId = "c2",
				},
				{
					id = "b",
					date = "2026-11-04",
					icon = "fix",
					text = "Fixed a bug",
					creditId = "c9",
				},
				{ id = "c", date = "2026-11-03", icon = "look", text = "Cleaner buttons" },
			}
			local board = {
				{ idea = "x", version = 1, name = "MochiPie", creditId = "c2" },
				{ idea = "y", version = 1, name = "a player", creditId = "c9" },
			}
			local lines = Logic.whatsNew(updates, board)
			expect(lines[1].glyph).to.equal("⚡")
			expect(lines[1].date).to.equal("Nov 5")
			expect(lines[1].credit).to.equal("💡 Idea from MochiPie")
			expect(lines[2].credit).to.equal("💡 A player's idea")
			expect(lines[3].credit).to.equal(nil)
			expect(Logic.whatsNew(updates, nil)[1].credit).to.equal("💡 A player's idea")
		end)
	end)
end
