--!strict
-- UI/Components/ReturnGoalWords.luau and RecapLogic's goals: the session recap's next goals with bars and the welcome
-- back card's goal line (#2916), from Gameplay's ReturnGoalView.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local ReturnGoalWords = require(Components:WaitForChild("ReturnGoalWords")) :: any
	local RecapLogic = require(Components:WaitForChild("RecapLogic")) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	local function money(n: number): string
		return "$" .. tostring(n)
	end

	local GOALS = {
		{ kind = "cats", have = 3, need = 5, tier = 2, area = "park" },
		{ kind = "rarity", have = 1, need = 2, tier = 2, rarity = "Epic" },
		{ kind = "coins", have = 1200, need = 5000, tier = 2 },
		{ kind = "away", amount = 4500, hours = 8 },
	}

	describe("ReturnGoalWords.row", function()
		it("words each kind with its count and bar", function()
			local cats = ReturnGoalWords.row(GOALS[1], money)
			expect(cats.text).to.equal("Open the Park: 3 of 5 cats")
			expect(cats.count).to.equal("3/5")
			expect(cats.progress).to.equal(0.6)
			local rarity = ReturnGoalWords.row(GOALS[2], money)
			expect(rarity.text).to.equal("Rank up: 1 of 2 Epic or better cats")
			expect(rarity.progress).to.equal(0.5)
			local coins = ReturnGoalWords.row(GOALS[3], money)
			local tier2 = nil
			for _, def in Catalog.tiers do
				if def.tier == 2 then
					tier2 = def.name
				end
			end
			expect(coins.text).to.equal("Rank up to " .. tier2)
			expect(coins.count).to.equal("$1200 / $5000")
			local away = ReturnGoalWords.row(GOALS[4], money)
			expect(away.text).to.equal("About $4500 while you're away (8\u{00A0}h)")
			expect(away.progress).to.equal(nil)
		end)

		it("skips a kind it doesn't know or a goal with missing numbers", function()
			expect(ReturnGoalWords.row({ kind = "rally" }, money)).to.equal(nil)
			expect(ReturnGoalWords.row({ kind = "cats", have = 1 }, money)).to.equal(nil)
			expect(ReturnGoalWords.row({ kind = "away", amount = 0 }, money)).to.equal(nil)
			expect(ReturnGoalWords.row(nil, money)).to.equal(nil)
		end)
	end)

	describe("ReturnGoalWords.rows and welcomeLine", function()
		it("keeps the server's order, at most max", function()
			local rows = ReturnGoalWords.rows(GOALS, money, 2)
			expect(#rows).to.equal(2)
			expect(rows[1].kind).to.equal("cats")
			expect(rows[2].kind).to.equal("rarity")
			expect(#ReturnGoalWords.rows(nil, money)).to.equal(0)
		end)

		it("points the welcome back card at the first goal that isn't away", function()
			expect(ReturnGoalWords.welcomeLine(GOALS, money)).to.equal(
				"Next: open the Park, 3 of 5 cats"
			)
			expect(ReturnGoalWords.welcomeLine({ GOALS[4] }, money)).to.equal(nil)
			expect(ReturnGoalWords.welcomeLine(nil, money)).to.equal(nil)
		end)
	end)

	describe("RecapLogic with goals", function()
		it("drops the one what's next line when the card draws goals", function()
			local base = {
				view = { minutes = 41, newCats = 3, earned = 1200 },
				state = { tutorialStep = 9 },
				nextTier = "Cozy Cafe",
				baitReadyAt = {},
				now = 1000,
				offlineRate = 0.5,
				offlineCapSeconds = 28800,
				money = money,
			}
			local plain = RecapLogic.lines(base)
			expect(plain[2]).to.equal("Next: rank up to Cozy Cafe")
			base.goals = true
			local lines = RecapLogic.lines(base)
			expect(#lines).to.equal(#plain - 1)
			expect(RecapLogic.isToday(lines[1])).to.equal(true)
			expect(RecapLogic.isToday(lines[2])).to.equal(false)
		end)
	end)
end
