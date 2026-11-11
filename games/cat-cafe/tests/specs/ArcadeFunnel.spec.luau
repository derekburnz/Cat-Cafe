--!strict
-- shared/ArcadeFunnel.luau (#3378): the arcade_v1 funnel's step order and its once-a-day run, and the leaderboard
-- reset (Arcade.BOARD_EPOCH on the save).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Arcade = require(ReplicatedStorage.Shared.Arcade)
	local ArcadeFunnel = require(ReplicatedStorage.Shared.ArcadeFunnel)
	local StationOpens = require(ReplicatedStorage.Shared.StationOpens)

	local function list(steps: { number }): string
		local out = {}
		for _, s in steps do
			table.insert(out, tostring(s))
		end
		return table.concat(out, " ")
	end

	describe("ArcadeFunnel.due", function()
		it("has six named steps in order", function()
			expect(#ArcadeFunnel.STEPS).to.equal(6)
			expect(ArcadeFunnel.STEPS[ArcadeFunnel.SEEN]).to.equal("arcade_seen")
			expect(ArcadeFunnel.STEPS[ArcadeFunnel.OPENED]).to.equal("arcade_opened")
			expect(ArcadeFunnel.STEPS[ArcadeFunnel.STARTED]).to.equal("arcade_started")
			expect(ArcadeFunnel.STEPS[ArcadeFunnel.FIRST_CIRCLE]).to.equal("arcade_first_circle")
			expect(ArcadeFunnel.STEPS[ArcadeFunnel.FINISHED]).to.equal("arcade_finished")
			expect(ArcadeFunnel.STEPS[ArcadeFunnel.PLAYED_AGAIN]).to.equal("arcade_played_again")
		end)

		it("logs each step once a day, in order", function()
			local state = ArcadeFunnel.fresh()
			expect(list(ArcadeFunnel.due(state, 100, 1))).to.equal("1")
			expect(list(ArcadeFunnel.due(state, 100, 1))).to.equal("")
			expect(list(ArcadeFunnel.due(state, 100, 2))).to.equal("2")
			expect(list(ArcadeFunnel.due(state, 100, 3))).to.equal("3")
			expect(list(ArcadeFunnel.due(state, 100, 4))).to.equal("4")
			expect(list(ArcadeFunnel.due(state, 100, 5))).to.equal("5")
			expect(list(ArcadeFunnel.due(state, 100, 6))).to.equal("6")
			expect(list(ArcadeFunnel.due(state, 100, 3))).to.equal("")
			expect(list(ArcadeFunnel.due(state, 100, 6))).to.equal("")
		end)

		it("fills in seen and opened for a player who starts a game", function()
			local state = ArcadeFunnel.fresh()
			expect(list(ArcadeFunnel.due(state, 100, 3))).to.equal("1 2 3")
			local other = ArcadeFunnel.fresh()
			expect(list(ArcadeFunnel.due(other, 100, 2))).to.equal("1 2")
		end)

		it("never counts a quit game as finished: a later step is logged alone", function()
			local late = ArcadeFunnel.fresh()
			expect(list(ArcadeFunnel.due(late, 100, 5))).to.equal("1 2 3 5")
		end)

		it("keeps played again back until a game is finished, so 6 never comes before 5", function()
			local state = ArcadeFunnel.fresh()
			ArcadeFunnel.due(state, 100, 4)
			-- game 1 was quit, then a second game starts: nothing yet
			expect(list(ArcadeFunnel.due(state, 100, 6))).to.equal("")
			expect(list(ArcadeFunnel.due(state, 100, 4))).to.equal("")
			-- the second game is played to its end: finished, then played again
			expect(list(ArcadeFunnel.due(state, 100, 5))).to.equal("5 6")
			expect(list(ArcadeFunnel.due(state, 100, 5))).to.equal("")
			expect(list(ArcadeFunnel.due(state, 100, 6))).to.equal("")
		end)

		it(
			"holds a played again that comes with the first start here (free game used elsewhere)",
			function()
				local state = ArcadeFunnel.fresh()
				expect(list(ArcadeFunnel.due(state, 100, 3))).to.equal("1 2 3")
				expect(list(ArcadeFunnel.due(state, 100, 6))).to.equal("")
				expect(list(ArcadeFunnel.due(state, 100, 4))).to.equal("4")
				expect(list(ArcadeFunnel.due(state, 100, 5))).to.equal("5 6")
				-- and a new day forgets it
				local other = ArcadeFunnel.fresh()
				ArcadeFunnel.due(other, 100, 6)
				expect(list(ArcadeFunnel.due(other, 101, 5))).to.equal("1 2 3 5")
			end
		)

		it("starts again on a new day", function()
			local state = ArcadeFunnel.fresh()
			ArcadeFunnel.due(state, 100, 6)
			expect(list(ArcadeFunnel.due(state, 101, 1))).to.equal("1")
			expect(state.starts).to.equal(0)
		end)

		it("ignores a step that is not one", function()
			local state = ArcadeFunnel.fresh()
			expect(#ArcadeFunnel.due(state, 100, 0)).to.equal(0)
			expect(#ArcadeFunnel.due(state, 100, 7)).to.equal(0)
			expect(#ArcadeFunnel.due(state, 100, 1.5)).to.equal(0)
			expect(state.step).to.equal(0)
		end)

		it("keys a run by day and player", function()
			expect(ArcadeFunnel.key(100, 7)).to.equal("100:7")
			expect(ArcadeFunnel.key(101, 7) ~= ArcadeFunnel.key(100, 7)).to.equal(true)
		end)
	end)

	describe("ArcadeFunnel.started", function()
		it("calls the second game of a day played again", function()
			local state = ArcadeFunnel.fresh()
			expect(ArcadeFunnel.started(state, 100, false)).to.equal(false)
			expect(ArcadeFunnel.started(state, 100, false)).to.equal(true)
			expect(ArcadeFunnel.started(state, 101, false)).to.equal(false)
		end)

		it("counts a free game used on another server", function()
			expect(ArcadeFunnel.started(ArcadeFunnel.fresh(), 100, true)).to.equal(true)
		end)
	end)

	describe("ArcadeFunnel.blockedReason", function()
		it("names what refused the start", function()
			expect(ArcadeFunnel.blockedReason(true, true, false, false)).to.equal("closed")
			expect(ArcadeFunnel.blockedReason(false, false, false, false)).to.equal("loading")
			expect(ArcadeFunnel.blockedReason(false, true, true, false)).to.equal("running")
			expect(ArcadeFunnel.blockedReason(false, true, false, true)).to.equal("busy")
			expect(ArcadeFunnel.blockedReason(false, true, false, false)).to.equal("no_fish")
		end)
	end)

	describe("the leaderboard reset (#3378)", function()
		local now = 100 * Arcade.DAY_SECONDS + 5
		local at = Arcade.milestones()[1].at

		it("uses a new board store and marks new saves with the board's epoch", function()
			expect(Arcade.BOARD_STORE ~= "CatCafe_LB_Arcade").to.equal(true)
			expect(Arcade.fresh().epoch).to.equal(Arcade.BOARD_EPOCH)
		end)

		it("drops the record of a save from before the reset and keeps the rest", function()
			local save = Arcade.sanitize({
				best = 61,
				bestCircles = 70,
				day = 100,
				paid = { at },
				legend = true,
				runs = 12,
				freeDay = 100,
			}, now)
			expect(save.best).to.equal(0)
			expect(save.bestCircles).to.equal(0)
			expect(save.epoch).to.equal(Arcade.BOARD_EPOCH)
			expect(save.legend).to.equal(true)
			expect(save.runs).to.equal(12)
			expect(save.freeDay).to.equal(100)
			expect(#save.paid).to.equal(1)
			expect(save.paid[1]).to.equal(at)
			expect(Arcade.freeToday(save, now)).to.equal(false)
		end)

		it("drops a record marked with another epoch", function()
			local save = Arcade.sanitize({ best = 61, bestCircles = 70, epoch = 1 }, now)
			expect(save.best).to.equal(0)
			save = Arcade.sanitize({ best = 61, bestCircles = 70, epoch = "2" }, now)
			expect(save.best).to.equal(0)
		end)

		it("keeps a record made since the reset", function()
			local save = Arcade.sanitize(
				{ best = 61, bestCircles = 70, epoch = Arcade.BOARD_EPOCH, runs = 3 },
				now
			)
			expect(save.best).to.equal(61)
			expect(save.bestCircles).to.equal(70)
			-- and it reads back as itself
			local again = Arcade.sanitize(save, now)
			expect(again.best).to.equal(61)
			expect(again.epoch).to.equal(Arcade.BOARD_EPOCH)
		end)

		it(
			"a write on top of an old server's save keeps this server's record and both servers' paid",
			function()
				-- an older server rewrote the save with its own best, no epoch, and a milestone paid there today
				local stored =
					Arcade.sanitize({ best = 90, bestCircles = 95, day = 100, paid = { at } }, now)
				local mine = Arcade.fresh()
				Arcade.record(mine, 20, 21)
				local out = Arcade.merge(stored, mine)
				expect(out.best).to.equal(20)
				expect(out.epoch).to.equal(Arcade.BOARD_EPOCH)
				expect(#out.paid).to.equal(1)
				expect(out.paid[1]).to.equal(at)
			end
		)
	end)

	describe("the Arcade station open (#3378)", function()
		it("is a counted window with its prompt", function()
			expect(StationOpens.valid("Arcade", "ring")).to.equal(true)
			expect(StationOpens.windowOfPrompt(Arcade.PROMPT)).to.equal("Arcade")
		end)
	end)
end
