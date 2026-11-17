--!strict
-- UI/Components/ThankfulLogic.luau: the Thankful Board's pie lines and notes (#4251).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ThankfulLogic")
	) :: any

	describe("ThankfulLogic.pie", function()
		it("counts slices and cats", function()
			local pie = Logic.pie(12345, 25000, 3)
			expect(pie.slices).to.equal(3)
			expect(pie.done).to.equal(false)
			expect(pie.title).to.equal("Feast Pie 3/8 baked")
			expect(pie.line).to.equal("12,345 / 25,000 harvest cats")
		end)
		it("says when it is baked and never runs past the goal", function()
			local pie = Logic.pie(26000, 25000, 8)
			expect(pie.done).to.equal(true)
			expect(pie.title).to.equal("The Feast Pie is baked!")
			expect(pie.line).to.equal("25,000 / 25,000 harvest cats")
		end)
		it("reads missing attributes as an empty pie", function()
			local pie = Logic.pie(nil, nil, nil)
			expect(pie.slices).to.equal(0)
			expect(pie.line).to.equal("0 / 25,000 harvest cats")
			expect(Logic.pie(5, 15000, 12).slices).to.equal(8)
			expect(Logic.pie(5, 15000, -1).slices).to.equal(0)
		end)
	end)

	describe("ThankfulLogic.notes", function()
		it("shows the newest first with their fixed words", function()
			local notes = Logic.notesFrom({ { userId = 1, note = 1 }, { userId = 2, note = 6 } })
			expect(#notes).to.equal(2)
			expect(notes[1].userId).to.equal(2)
			expect(notes[1].text).to.equal("See you next autumn!")
			expect(notes[2].text).to.equal("Thank you, cats!")
		end)
		it("drops bad rows and bad JSON", function()
			expect(#Logic.notesFrom({
				{ userId = 1, note = 9 },
				{ userId = "x", note = 1 },
				{ userId = 3, note = 2.5 },
			})).to.equal(0)
			expect(#Logic.notesFrom("x")).to.equal(0)
			expect(#Logic.notes("not json")).to.equal(0)
			expect(#Logic.notes(nil)).to.equal(0)
			expect(#Logic.notes("")).to.equal(0)
		end)
		it("keeps at most twelve", function()
			local rows = {}
			for index = 1, 20 do
				table.insert(rows, { userId = index, note = (index % 6) + 1 })
			end
			local notes = Logic.notesFrom(rows)
			expect(#notes).to.equal(12)
			expect(notes[1].userId).to.equal(20)
		end)
	end)

	describe("ThankfulLogic lines", function()
		it("says whether you helped and when you can pin again", function()
			expect(Logic.helpedLine(true)).to.equal("You helped bake it! 🥧")
			expect(Logic.helpedLine(false)).to.equal("Catch a harvest cat to add a slice")
			expect(Logic.pickLine(100, nil)).to.equal(nil)
			expect(Logic.pickLine(100, 95)).to.equal("Pinned! Pick again in 5 s")
			expect(Logic.pickLine(100, 90)).to.equal(nil)
			expect(Logic.headshot(42)).to.equal("rbxthumb://type=AvatarHeadShot&id=42&w=48&h=48")
		end)
	end)
end
