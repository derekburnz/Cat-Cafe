--!strict
-- UI/Components/LeaderboardLogic.luau: the leaderboards' rows, values and "You" line (F98, leaderboards.md).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local LeaderboardLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LeaderboardLogic")
	) :: any

	local function row(rank: number, userId: number, value: number, crown: boolean?): any
		return { rank = rank, userId = userId, name = "P" .. userId, value = value, crown = crown }
	end

	local SYNC = {
		boards = {
			index = { allTime = { row(2, 20, 60), row(1, 10, 68, true), row(3, 30, 55) } },
			playtime = {
				allTime = { row(1, 10, 2472, true) },
				week = { row(1, 40, 300), row(2, 7, 180) },
			},
			money = { allTime = { row(1, 50, 12400, true) }, week = {} },
		},
		me = {
			index = { rank = 23, value = 31 },
			playtime = { value = 2472 },
			money = { value = 640, weekRank = 4 },
		},
		week = 2901,
	}

	describe("LeaderboardLogic.value", function()
		it("says cats, hours and minutes, and money a second", function()
			expect(LeaderboardLogic.value("index", 68)).to.equal("68 cats")
			expect(LeaderboardLogic.value("index", 1)).to.equal("1 cat")
			expect(LeaderboardLogic.value("playtime", 2472)).to.equal("41 h 12 m")
			expect(LeaderboardLogic.value("playtime", 45)).to.equal("45 m")
			expect(LeaderboardLogic.value("playtime", 0)).to.equal("0 m")
			expect(LeaderboardLogic.value("money", 12400)).to.equal("$12,400/s") -- the HUD's numbers
			expect(LeaderboardLogic.value("money", 1240000)).to.equal("$1.24M/s")
			expect(LeaderboardLogic.value("money", nil)).to.equal("$0/s")
		end)
	end)

	describe("LeaderboardLogic.rows", function()
		it("puts the rows in rank order and cuts them to the board's ten", function()
			local rows = LeaderboardLogic.rows(SYNC, "index", "allTime")
			expect(#rows).to.equal(3)
			expect(rows[1].userId).to.equal(10)
			expect(rows[3].userId).to.equal(30)
			expect(#LeaderboardLogic.rows(SYNC, "index", "allTime", 2)).to.equal(2)
		end)

		it("gives an empty list for a missing board, window or sync", function()
			expect(#LeaderboardLogic.rows(SYNC, "index", "week")).to.equal(0)
			expect(#LeaderboardLogic.rows(nil, "money", "allTime")).to.equal(0)
			expect(
				#LeaderboardLogic.rows(
					{ boards = { money = { allTime = { { rank = 1 } } } } },
					"money",
					"allTime"
				)
			).to.equal(0)
		end)
	end)

	describe("LeaderboardLogic.meLine", function()
		it("gives the rank in the top 50, else the value", function()
			expect(LeaderboardLogic.meLine(SYNC, "index", "allTime", 99)).to.equal("You: #23")
			expect(LeaderboardLogic.meLine(SYNC, "playtime", "allTime", 99)).to.equal(
				"You: 41 h 12 m"
			)
			expect(LeaderboardLogic.meLine({}, "index", "allTime", 99)).to.equal(nil)
		end)

		it("finds the player on this week's list, else says so", function()
			expect(LeaderboardLogic.meLine(SYNC, "playtime", "week", 7)).to.equal("You: #2")
			expect(LeaderboardLogic.meLine(SYNC, "money", "week", 99)).to.equal("You: #4")
			expect(LeaderboardLogic.meLine(SYNC, "playtime", "week", 99)).to.equal(
				"You: not on this week's list yet"
			)
		end)
	end)

	describe("LeaderboardLogic.faceWindow, hasWeek and medal", function()
		it("swaps Playtime and Money every 15 s, never Index", function()
			expect(LeaderboardLogic.faceWindow("playtime", 0)).to.equal("allTime")
			expect(LeaderboardLogic.faceWindow("playtime", 16)).to.equal("week")
			expect(LeaderboardLogic.faceWindow("money", 31)).to.equal("allTime")
			expect(LeaderboardLogic.faceWindow("index", 16)).to.equal("allTime")
			expect(LeaderboardLogic.hasWeek("index")).to.equal(false)
			expect(LeaderboardLogic.hasWeek("money")).to.equal(true)
		end)

		it("gives gold, silver and bronze to the top three", function()
			expect(LeaderboardLogic.medal(1)).to.equal("gold")
			expect(LeaderboardLogic.medal(2)).to.equal("silver")
			expect(LeaderboardLogic.medal(3)).to.equal("bronze")
			expect(LeaderboardLogic.medal(4)).to.equal(nil)
		end)

		it("names each board and draws a head picture", function()
			expect(LeaderboardLogic.info("money").name).to.equal("Money")
			expect(#LeaderboardLogic.BOARDS).to.equal(3)
			expect(LeaderboardLogic.headshot(42)).to.equal(
				"rbxthumb://type=AvatarHeadShot&id=42&w=48&h=48"
			)
		end)
	end)
end
