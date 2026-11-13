--!strict
-- UI/Components/RollBoardLogic.luau: what the roll board over the Rummage Bin says (#3611).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RollBoardLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RollBoardLogic")
	) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config")) :: any
	local RummageBin = require(Shared:WaitForChild("RummageBin")) :: any

	local function input(over: { [string]: any }?): any
		local made: { [string]: any } =
			{ uses = Config.BinFirstUses, prize = nil, nextAt = 0, now = 1000 }
		for key, value in over or {} do
			made[key] = value
		end
		return made
	end

	describe("RollBoardLogic.clock", function()
		it("reads minutes and seconds and never 0:00 while the wait lasts", function()
			expect(RollBoardLogic.clock(245)).to.equal("4:05")
			expect(RollBoardLogic.clock(59.2)).to.equal("1:00")
			expect(RollBoardLogic.clock(0.2)).to.equal("0:01")
		end)
	end)

	describe("RollBoardLogic.bin", function()
		it("lists every prize of the rolled table with its chance, in the table's order", function()
			local view = RollBoardLogic.bin(input())
			expect(view.title).to.equal("RUMMAGE BIN")
			expect(view.line).to.equal(RollBoardLogic.BIN_LIST)
			expect(view.dim).to.equal(false)
			expect(view.foot).to.equal(nil)
			expect(#view.rows).to.equal(#Config.BinRollTable)
			local total = 0
			for index, row in view.rows do
				local from = Config.BinRollTable[index]
				expect(row.id).to.equal(from.id)
				expect(row.chance).to.equal(RollBoardLogic.percent(from.chance))
				expect(row.tier).to.equal(from.tier)
				expect(#row.images >= 1).to.equal(true)
				total += tonumber((string.gsub(row.chance, "%%", ""))) :: number
			end
			expect(total).to.equal(100) -- the chances a player reads add to 100
		end)

		it("names a food with its golden fish and gives it both pictures", function()
			local view = RollBoardLogic.bin(input())
			expect(view.rows[1].name).to.equal("2 Tuna + 3 golden fish")
			expect(#view.rows[1].images).to.equal(2)
			expect(view.rows[2].name).to.equal("10 golden fish")
			expect(#view.rows[2].images).to.equal(1)
		end)

		it("shows a new account the list with its chances: no fixed first prize (#3680)", function()
			for uses = 0, Config.BinFirstUses do
				local view = RollBoardLogic.bin(input({ uses = uses }))
				expect(view.line).to.equal(RollBoardLogic.BIN_LIST)
				expect(#view.rows).to.equal(#Config.BinRollTable)
				expect(view.rows[1].chance).to.equal(
					RollBoardLogic.percent(Config.BinRollTable[1].chance)
				)
				expect(view.foot).to.equal(nil)
			end
		end)

		it("shows the prize kept after a miss ahead of the list, new account or not", function()
			for _, uses in { 0, Config.BinFirstUses } do
				local view = RollBoardLogic.bin(input({ uses = uses, prize = "golden" }))
				expect(view.line).to.equal(RollBoardLogic.BIN_WAITING)
				expect(#view.rows).to.equal(1)
				expect(view.rows[1].id).to.equal("golden")
				expect(view.rows[1].chance).to.equal(nil)
				expect(view.rows[1].tier).to.equal(3)
			end
			-- a stored id that names no row is as nothing stored
			expect(RollBoardLogic.bin(input({ prize = "nope" })).line).to.equal(
				RollBoardLogic.BIN_LIST
			)
		end)

		it("fades the list and counts down while the bin is empty", function()
			local view = RollBoardLogic.bin(input({ nextAt = 1245, prize = nil }))
			expect(view.dim).to.equal(true)
			expect(view.line).to.equal("Fills in 4:05")
			expect(#view.rows).to.equal(#Config.BinRollTable)
		end)

		it(
			"keeps the whole list up while the roll passes, then names the prize for the bar",
			function()
				local rolling = RollBoardLogic.bin(input({ playing = "crate", rolling = true }))
				expect(rolling.line).to.equal(RollBoardLogic.BIN_ROLLING)
				expect(#rolling.rows).to.equal(#Config.BinRollTable)
				local bar = RollBoardLogic.bin(
					input({ playing = "crate", rolling = false, prize = "crate" })
				)
				expect(bar.line).to.equal(RollBoardLogic.BIN_PLAYING)
				expect(#bar.rows).to.equal(1)
				expect(bar.rows[1].name).to.equal(RummageBin.rowName(RummageBin.rollRow("crate")))
			end
		)
	end)

	describe("RollBoardLogic.yard (#3615)", function()
		local rows = {
			{ crateId = "classic_crate", chance = 0.38, golden = false, tier = 1 },
			{ crateId = "park_crate", chance = 0.125, golden = false, tier = 1 },
			{ crateId = "classic_golden_crate", chance = 0.08, golden = true, tier = 3 },
		}

		it(
			"shows every crate with its chance to one decimal and golden rows as the best",
			function()
				local view = RollBoardLogic.yard({ rows = rows, nextAt = nil, now = 100 })
				expect(view.title).to.equal(RollBoardLogic.YARD_TITLE)
				expect(view.line).to.equal(RollBoardLogic.yardLine())
				expect(view.dim).to.equal(false)
				expect(#view.rows).to.equal(3)
				expect(view.rows[1].chance).to.equal("38.0%")
				expect(view.rows[2].chance).to.equal("12.5%")
				expect(view.rows[3].chance).to.equal("8.0%")
				expect(view.rows[1].tier).to.equal(1)
				expect(view.rows[3].tier).to.equal(3)
			end
		)

		it("says the pick is free and how often", function()
			expect(RollBoardLogic.yardLine()).to.equal(
				string.format("Free every %d hours", Config.YardSaleRollHours)
			)
		end)

		it("dims the rows and counts down while the next pick waits", function()
			local view = RollBoardLogic.yard({ rows = rows, nextAt = 100 + 80 * 60, now = 100 })
			expect(view.dim).to.equal(true)
			expect(view.line).to.equal("Next pick in 1 h 20 m")
		end)

		it("keeps the rows at full strength while the light rolls, wait or not", function()
			local view =
				RollBoardLogic.yard({ rows = rows, nextAt = 9999, now = 100, rolling = true })
			expect(view.dim).to.equal(false)
			expect(view.line).to.equal(RollBoardLogic.YARD_ROLLING)
		end)
	end)

	describe("RollBoardLogic.rowOf (#3615)", function()
		it("finds the crate the server named, whatever its place in the rows", function()
			local rows = { { crateId = "a" }, { crateId = "b" }, { crateId = "c" } }
			expect(RollBoardLogic.rowOf(rows, "c")).to.equal(3)
			expect(RollBoardLogic.rowOf(rows, "a")).to.equal(1)
			expect(RollBoardLogic.rowOf(rows, "z")).to.equal(nil)
		end)
	end)

	describe("RollBoardLogic.rollSteps (#3615)", function()
		it(
			"walks down from the top row to the landing row and never lights a row under it",
			function()
				for landing = 1, 5 do
					local steps = RollBoardLogic.rollSteps(5, landing)
					expect(#steps).to.equal(landing)
					expect(steps[1].index).to.equal(1)
					expect(steps[#steps].index).to.equal(landing)
					for at = 1, #steps do
						-- no rarer row (further down the list) is ever lit before the landing
						expect(steps[at].index <= landing).to.equal(true)
						if at > 1 then
							expect(steps[at].index).to.equal(steps[at - 1].index + 1)
							-- it only ever slows: no pause that could look like a near miss
							expect(steps[at].rest >= steps[at - 1].rest).to.equal(true)
						end
					end
				end
			end
		)

		it(
			"lights the top row straight away, clamps a landing past the end, and has no steps for no rows",
			function()
				expect(#RollBoardLogic.rollSteps(0, 1)).to.equal(0)
				expect(#RollBoardLogic.rollSteps(4, 1)).to.equal(1)
				local past = RollBoardLogic.rollSteps(4, 9)
				expect(#past).to.equal(4)
				expect(past[4].index).to.equal(4)
			end
		)
	end)

	describe("sizeOffsetY (#3683)", function()
		it("keeps the board's bottom on its point when the clock is not in the way", function()
			expect(RollBoardLogic.sizeOffsetY(400, 300, 320, 200, nil, nil, nil)).to.equal(0.5)
			expect(RollBoardLogic.sizeOffsetY(400, 300, 320, 200, 60, 300, 500)).to.equal(0.5) -- top at 100
			expect(RollBoardLogic.sizeOffsetY(100, 150, 100, 200, 60, 300, 500)).to.equal(0.5) -- beside it
		end)

		it("comes down just enough to clear the clock, and no more than LOWER_MOST", function()
			-- top at 20, the clock ends at 60: 40 px down of 200
			expect(RollBoardLogic.sizeOffsetY(400, 220, 320, 200, 60, 300, 500)).to.be.near(
				0.3,
				0.0001
			)
			expect(RollBoardLogic.sizeOffsetY(400, 50, 320, 200, 60, 300, 500)).to.be.near(
				0.5 - RollBoardLogic.LOWER_MOST,
				0.0001
			)
		end)
	end)
end
