--!strict
-- #3338: the Cat Arcade's leaderboard rows (shared/Arcade fromScore and topRows; Services/ArcadeBoard writes and reads
-- the store, ArcadeState.top carries the rows to the window's Leaderboard tab).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Arcade = require(Shared.Arcade)
	local Config = require(Shared.Config)
	local Leaderboards = require(Shared.Leaderboards)

	local function row(userId: number, name: string, value: number): any
		return { rank = 0, userId = userId, name = name, value = value, crown = false }
	end

	describe("Arcade.fromScore", function()
		it("gives back the points and circles score packed", function()
			local points, circles = Arcade.fromScore(Arcade.score(37, 20))
			expect(points).to.equal(37)
			expect(circles).to.equal(20)
			points, circles = Arcade.fromScore(Arcade.score(Config.ArcadeMaxPoints, 58))
			expect(points).to.equal(Config.ArcadeMaxPoints)
			expect(circles).to.equal(58)
		end)

		it("reads anything not a score as nothing", function()
			for _, bad in { nil, "12", -5, 0, 0 / 0 } :: { any } do
				local points, circles = Arcade.fromScore(bad)
				expect(points).to.equal(0)
				expect(circles).to.equal(0)
			end
		end)
	end)

	describe("Arcade.topRows", function()
		it("ranks the rows, marks the viewer and stops at TOP", function()
			local rows = {}
			for i = 1, Arcade.TOP + 5 do
				table.insert(rows, row(i, "P" .. i, Arcade.score(100 - i, 10)))
			end
			local top = Arcade.topRows(rows, 3)
			expect(#top).to.equal(Arcade.TOP)
			expect(top[1].rank).to.equal(1)
			expect(top[1].points).to.equal(99)
			expect(top[3].me).to.equal(true)
			expect(top[2].me).to.equal(nil)
		end)

		it("drops rows with no points and closes the ranks up", function()
			local top = Arcade.topRows({
				row(1, "A", Arcade.score(50, 30)),
				row(2, "B", 0),
				row(3, "C", Arcade.score(10, 5)),
			}, nil)
			expect(#top).to.equal(2)
			expect(top[2].name).to.equal("C")
			expect(top[2].rank).to.equal(2)
		end)

		it("puts the players here in at their bests and leaves hidden owners out", function()
			local read = { row(1, "A", Arcade.score(40, 25)) }
			local present = {
				{ userId = 2, name = "B", value = Arcade.score(60, 40) },
				{ userId = 9, name = "Owner", value = Arcade.score(100, 50) },
			}
			local top = Arcade.topRows(Leaderboards.withPresent(read, present, { [9] = true }), 2)
			expect(#top).to.equal(2)
			expect(top[1].name).to.equal("B")
			expect(top[1].me).to.equal(true)
			expect(top[2].name).to.equal("A")
		end)

		it("ranks fewer circles first at the same points", function()
			local rows = Leaderboards.withPresent({}, {
				{ userId = 1, name = "Slow", value = Arcade.score(100, 70) },
				{ userId = 2, name = "Fast", value = Arcade.score(100, 55) },
			}, {})
			local top = Arcade.topRows(rows, nil)
			expect(top[1].name).to.equal("Fast")
		end)
	end)
end
