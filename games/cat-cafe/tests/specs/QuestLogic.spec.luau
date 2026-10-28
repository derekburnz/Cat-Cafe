--!strict
-- UI/Components/QuestLogic.luau: the Quests window's prizes, counts, order and the HUD's quest line (F73,
-- quests.md sections 1 and 7).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local QuestLogic = require(Components:WaitForChild("QuestLogic")) :: any

	local function quest(id: string, progress: number, needs: number, claimed: boolean?): any
		return { id = id, text = id, progress = progress, needs = needs, claimed = claimed == true }
	end

	local catalog: any = {
		quests = {
			daily = {
				cafe = { { id = "d_coins", text = "Earn coins", stat = "lifetimeCoins" } },
				streets = { { id = "d_catch5", text = "Catch 5 cats", stat = "catsCaught" } },
			},
			weekly = { b = { { id = "w_coins", text = "Earn coins", stat = "lifetimeCoins" } } },
		},
		questPrizes = {
			daily = { coins = 200, coinSeconds = 180, fish = 2 },
			dailyBig = { coins = 400, coinSeconds = 300, fish = 4 },
			dailySet = { fish = 10, spins = 1 },
			weekly = { coins = 2000, coinSeconds = 1200, fish = 15 },
			weeklySet = { fish = 40, spins = 3 },
		},
		achievements = {
			{ id = "a_first_catch", name = "First Catch", needs = 1, size = "S" },
			{ id = "a_catch100", name = "Cat Catcher", needs = 100, size = "M" },
			{ id = "a_catch1k", name = "Cat Wrangler", needs = 1000, size = "L" },
			{ id = "a_rare1", name = "Rare Find", needs = 1, size = "S" },
		},
	}

	describe("QuestLogic prizes", function()
		it("pays the Big Request on the fifth daily and the weekly row on every weekly", function()
			expect(QuestLogic.prize(catalog, "daily", 1).fish).to.equal(2)
			expect(QuestLogic.prize(catalog, "daily", 5).fish).to.equal(4)
			expect(QuestLogic.prize(catalog, "weekly", 2).fish).to.equal(15)
			expect(QuestLogic.setPrize(catalog, "daily").fish).to.equal(10)
			expect(QuestLogic.setPrize(catalog, "weekly").spins).to.equal(3)
			expect(QuestLogic.prize(nil, "daily", 1)).to.equal(nil)
		end)
	end)

	describe("QuestLogic counts", function()
		it("counts finished quests, claimed or not, and what waits to be claimed", function()
			local daily = {
				quest("d_catch5", 5, 5, true),
				quest("d_perfect10", 10, 10),
				quest("d_rescue2", 1, 2),
			}
			expect(QuestLogic.doneCount(daily)).to.equal(2)
			local state: any = {
				quests = { daily = daily, weekly = { quest("w_catch60", 60, 60) } },
				achievements = {
					a_first_catch = { progress = 1, claimed = false },
					a_catch100 = { progress = 100, claimed = true },
					a_rare1 = { progress = 0, claimed = false },
				},
			}
			-- one daily, one weekly and First Catch
			expect(QuestLogic.claimable(state, catalog)).to.equal(3)
			expect(QuestLogic.claimable({}, catalog)).to.equal(0)
			expect(QuestLogic.claimedCount(catalog, state.achievements)).to.equal(1)
		end)
	end)

	describe("QuestLogic.isCoins and resetText", function()
		it("reads coins quests from the catalog", function()
			expect(QuestLogic.isCoins(catalog, "d_coins")).to.equal(true)
			expect(QuestLogic.isCoins(catalog, "w_coins")).to.equal(true)
			expect(QuestLogic.isCoins(catalog, "d_catch5")).to.equal(false)
			expect(QuestLogic.isCoins(nil, "d_coinsbig")).to.equal(true)
		end)

		it("says when new quests come in days, hours or minutes", function()
			expect(QuestLogic.resetText(3 * 86400 + 5)).to.equal("New quests in 3 d")
			expect(QuestLogic.resetText(5 * 3600 + 59)).to.equal("New quests in 5 h")
			expect(QuestLogic.resetText(41 * 60 + 1)).to.equal("New quests in 42 min")
			expect(QuestLogic.resetText(-10)).to.equal("New quests in 1 min")
		end)
	end)

	describe("QuestLogic.achievementRows", function()
		it("puts ready ones first, then the closest to done, and claimed ones last", function()
			local rows = QuestLogic.achievementRows(catalog, {
				a_first_catch = { progress = 1, claimed = true },
				a_catch100 = { progress = 40, claimed = false },
				a_catch1k = { progress = 40, claimed = false },
				a_rare1 = { progress = 1, claimed = false },
			})
			expect(rows[1].def.id).to.equal("a_rare1")
			expect(rows[1].ready).to.equal(true)
			expect(rows[2].def.id).to.equal("a_catch100")
			expect(rows[3].def.id).to.equal("a_catch1k")
			expect(rows[4].def.id).to.equal("a_first_catch")
			expect(rows[4].claimed).to.equal(true)
		end)

		it("shows every achievement with no progress yet", function()
			local rows = QuestLogic.achievementRows(catalog, nil)
			expect(#rows).to.equal(4)
			expect(rows[1].progress).to.equal(0)
			expect(rows[1].ready).to.equal(false)
		end)
	end)

	describe("QuestLogic.tracker", function()
		it("picks the unfinished daily closest to done", function()
			local quests: any = {
				daily = {
					quest("d_catch5", 5, 5),
					quest("d_perfect10", 3, 10),
					quest("d_rescue2", 1, 2),
					quest("d_spin1", 1, 1, true),
				},
			}
			expect(QuestLogic.tracker(quests).id).to.equal("d_rescue2")
			expect(QuestLogic.tracker({ daily = { quest("d_catch5", 5, 5) } })).to.equal(nil)
			expect(QuestLogic.tracker(nil)).to.equal(nil)
		end)
	end)
end
