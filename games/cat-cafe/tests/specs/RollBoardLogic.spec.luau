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

		it("shows only the fixed first prize, with no chance, while one waits", function()
			local view = RollBoardLogic.bin(input({ uses = 0 }))
			expect(view.line).to.equal(RollBoardLogic.BIN_NEXT)
			expect(#view.rows).to.equal(1)
			expect(view.rows[1].id).to.equal(Config.BinFirstPrizes[1].id)
			expect(view.rows[1].chance).to.equal(nil)
			expect(view.foot).to.equal(
				string.format("After your first %d: prizes are rolled", Config.BinFirstUses)
			)
		end)

		it("shows the prize kept after a miss ahead of the list and of a fixed prize", function()
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
end
