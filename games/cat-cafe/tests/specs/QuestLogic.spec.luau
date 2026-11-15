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

		it("counts one set's quests ready to claim, for Claim All (Derek 2026-10-29)", function()
			local daily = {
				quest("d_catch5", 5, 5, true),
				quest("d_perfect10", 10, 10),
				quest("d_rescue2", 2, 2),
				quest("d_coins", 1, 600),
			}
			expect(QuestLogic.readyCount(daily)).to.equal(2)
			expect(QuestLogic.readyCount({})).to.equal(0)
			expect(QuestLogic.readyCount(nil)).to.equal(0)
		end)
	end)

	describe("QuestLogic.rowOrder", function()
		it("drops claimed quests below the rest and keeps slot order in each group", function()
			-- the head and the set strip are LayoutOrder 1 and 2
			expect(QuestLogic.rowOrder(1, false) > 2).to.equal(true)
			expect(QuestLogic.rowOrder(1, false) < QuestLogic.rowOrder(5, false)).to.equal(true)
			expect(QuestLogic.rowOrder(5, false) < QuestLogic.rowOrder(1, true)).to.equal(true)
			expect(QuestLogic.rowOrder(1, true) < QuestLogic.rowOrder(5, true)).to.equal(true)
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

	describe("QuestLogic.swapText and swapFree (#1166)", function()
		it("counts the used weekly swap down in hours and minutes", function()
			expect(QuestLogic.swapText(7 * 3600 + 12 * 60)).to.equal("7h 12m")
			expect(QuestLogic.swapText(7 * 3600 + 11 * 60 + 1)).to.equal("7h 12m")
			expect(QuestLogic.swapText(3599.5)).to.equal("1h 0m")
			expect(QuestLogic.swapText(12 * 60)).to.equal("12m")
			expect(QuestLogic.swapText(-5)).to.equal("1m")
		end)

		it("is free only while unused and a quest is unfinished and unclaimed", function()
			local open = { id = "w1", progress = 1, needs = 5, claimed = false }
			local done = { id = "w2", progress = 5, needs = 5, claimed = false }
			local claimed = { id = "w3", progress = 5, needs = 5, claimed = true }
			expect(QuestLogic.swapFree({ open, done } :: any, false)).to.equal(true)
			expect(QuestLogic.swapFree({ open } :: any, true)).to.equal(false)
			expect(QuestLogic.swapFree({ done, claimed } :: any, false)).to.equal(false)
			expect(QuestLogic.swapFree({}, false)).to.equal(false)
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

		it("leaves out one behind a switch until the server sends it (#3694 section 3)", function()
			local gated: any = table.clone(catalog :: any)
			gated.achievements = table.clone(gated.achievements)
			table.insert(gated.achievements, {
				id = "a_traits10",
				name = "Pool Regular",
				needs = 10,
				size = "M",
				flag = "traits",
			})
			expect(#QuestLogic.achievementRows(gated, nil)).to.equal(4)
			expect(
				#QuestLogic.achievementRows(gated, { a_rare1 = { progress = 1, claimed = false } })
			).to.equal(4)
			local rows = QuestLogic.achievementRows(
				gated,
				{ a_traits10 = { progress = 3, claimed = false } }
			)
			expect(#rows).to.equal(5)
		end)
	end)

	describe("QuestLogic.claimAllCount", function()
		it("counts Claim all's ready rewards across all three tabs (#1073)", function()
			local count = QuestLogic.claimAllCount
			expect(count({ Daily = 1, Weekly = 0, Achievements = 0 })).to.equal(1)
			expect(count({ Daily = 2, Weekly = 1, Achievements = 3 })).to.equal(6)
			-- after one claim the rest still count, so the button stays
			expect(count({ Daily = 0, Weekly = 0, Achievements = 1 })).to.equal(1)
			expect(count({ Daily = 0, Weekly = 0, Achievements = 0 })).to.equal(0)
			expect(count({})).to.equal(0)
			expect(count(nil)).to.equal(0)
		end)
	end)

	describe("QuestLogic.hoursText (#3694)", function()
		it("counts play time in whole hours, rounded down", function()
			local devoted: any =
				{ id = "a_hours100", measure = "playtimeSeconds", needs = 180000, size = "XL" }
			expect(QuestLogic.hoursText(devoted, 97153)).to.equal("26/50 hours")
			expect(QuestLogic.hoursText(devoted, 0)).to.equal("0/50 hours")
			expect(QuestLogic.hoursText(devoted, 999999)).to.equal("50/50 hours")
			local first: any =
				{ id = "a_hours1", measure = "playtimeSeconds", needs = 3600, size = "S" }
			expect(QuestLogic.hoursText(first, 3599)).to.equal("0/1 hour")
			expect(QuestLogic.hoursText(first, 3600)).to.equal("1/1 hour")
		end)

		it("counts resting time in hours too", function()
			local napper: any =
				{ id = "a_rest1h", measure = "restSeconds", needs = 3600, size = "M" }
			expect(QuestLogic.hoursText(napper, 1800)).to.equal("0/1 hour")
			expect(QuestLogic.hoursText(napper, 3700)).to.equal("1/1 hour")
		end)

		it("leaves every other count alone", function()
			local catches: any =
				{ id = "a_catch100", measure = "catsCaught", needs = 100, size = "M" }
			expect(QuestLogic.hoursText(catches, 40)).to.equal(nil)
		end)
	end)

	describe("the achievement list (#3694)", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Catalog =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
		local function find(id: string): any
			for _, def in Catalog.achievements do
				if def.id == id then
					return def
				end
			end
			return nil
		end

		it("keeps every old id and lowers the big targets", function()
			expect(find("a_catch1k").needs).to.equal(500)
			expect(find("a_catch10k").needs).to.equal(2500)
			expect(find("a_perfect5k").needs).to.equal(2000)
			expect(find("a_rescue250").needs).to.equal(100)
			expect(find("a_quests100").needs).to.equal(60)
			expect(find("a_week10").needs).to.equal(5)
			expect(find("a_hours100").needs).to.equal(50 * 3600)
		end)

		it("has a step on every catch count from 1 to 2,500, with unique ids and names", function()
			local catches = {}
			local ids, names = {}, {}
			for _, def in Catalog.achievements do
				expect(ids[def.id]).to.equal(nil)
				expect(names[def.name]).to.equal(nil)
				ids[def.id], names[def.name] = true, true
				if def.measure == "catsCaught" then
					table.insert(catches, def.needs)
				end
			end
			table.sort(catches)
			expect(table.concat(catches, ",")).to.equal("1,25,100,250,500,1000,2500")
			expect(#Catalog.achievements).to.equal(69) -- #3694 section 3: ten for the newer features
		end)
	end)
end
