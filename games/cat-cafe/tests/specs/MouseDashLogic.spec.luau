--!strict
-- UI/Components/MouseDashLogic.luau (#3296): the Mouse Dash board's layout and the card's words.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("MouseDashLogic")) :: any

	-- the boards the window gives on: the smallest phone, a phone, a tablet upright and a desktop
	local BOARDS = { { 560, 262 }, { 600, 280 }, { 560, 600 }, { 600, 640 }, { 340, 520 } }

	describe("MouseDashLogic.layout", function()
		it("keeps every hole at least 64 px and inside the board", function()
			for _, size in BOARDS do
				local layout = Logic.layout(size[1], size[2])
				expect(layout.hole >= Logic.MIN_HOLE).to.equal(true)
				for hole = 1, 9 do
					local x, y = Logic.holeAt(layout, hole)
					expect(x >= 0 and y >= 0).to.equal(true)
					expect(x + layout.hole <= size[1]).to.equal(true)
					expect(y + layout.hole <= size[2]).to.equal(true)
				end
			end
		end)

		it("never lets two holes overlap", function()
			for _, size in BOARDS do
				local layout = Logic.layout(size[1], size[2])
				for a = 1, 9 do
					for b = a + 1, 9 do
						local ax, ay = Logic.holeAt(layout, a)
						local bx, by = Logic.holeAt(layout, b)
						local apart = math.abs(ax - bx) >= layout.hole
							or math.abs(ay - by) >= layout.hole
						expect(apart).to.equal(true)
					end
				end
			end
		end)

		it("keeps the hearts and score strip clear of every hole", function()
			for _, size in BOARDS do
				local layout = Logic.layout(size[1], size[2])
				for hole = 1, 9 do
					local x, y = Logic.holeAt(layout, hole)
					local clearX = x - (layout.hudX + layout.hudW)
					local clearY = y - (layout.hudY + layout.hudH)
					if layout.side == "left" then
						expect(clearX >= Logic.HUD_GAP).to.equal(true)
					else
						expect(clearY >= Logic.HUD_GAP).to.equal(true)
					end
				end
			end
		end)

		it("puts the strip on the left of a wide board and on top of a tall one", function()
			expect(Logic.layout(560, 262).side).to.equal("left")
			expect(Logic.layout(340, 520).side).to.equal("top")
		end)

		it("numbers the holes row by row from the top left", function()
			local layout = Logic.layout(600, 640)
			local x1, y1 = Logic.holeAt(layout, 1)
			local x3, y3 = Logic.holeAt(layout, 3)
			local x7, y7 = Logic.holeAt(layout, 7)
			expect(y3).to.equal(y1)
			expect(x3 > x1).to.equal(true)
			expect(x7).to.equal(x1)
			expect(y7 > y1).to.equal(true)
		end)
	end)

	describe("MouseDashLogic controls", function()
		it("maps Q W E, A S D and Z X C to the nine holes", function()
			local keys = { "Q", "W", "E", "A", "S", "D", "Z", "X", "C" }
			for hole, key in keys do
				expect(Logic.keyHole(key)).to.equal(hole)
			end
			expect(Logic.keyHole("P")).never.to.be.ok()
		end)

		it("rests the stick on the centre hole and points at the corners", function()
			expect(Logic.stickHole(0, 0)).to.equal(5)
			expect(Logic.stickHole(0.2, -0.3)).to.equal(5)
			expect(Logic.stickHole(-1, 1)).to.equal(1)
			expect(Logic.stickHole(1, 1)).to.equal(3)
			expect(Logic.stickHole(-1, -1)).to.equal(7)
			expect(Logic.stickHole(1, -1)).to.equal(9)
			expect(Logic.stickHole(0, 1)).to.equal(2)
		end)
	end)

	describe("MouseDashLogic words", function()
		it("shows the best and the titles", function()
			expect(Logic.records(nil)).to.equal("Waking up...")
			expect(Logic.records({ loaded = true, best = 0 })).to.equal("No best yet")
			expect(Logic.records({ loaded = true, best = 37, bestSeconds = 30, mouser = true })).to.equal(
				"Best 37 · Mouser"
			)
			expect(
				Logic.records({
					loaded = true,
					best = 100,
					bestSeconds = 84,
					legend = true,
					mouser = true,
				})
			).to.equal("Best 100 in 84s · Arcade Legend · Mouser")
		end)

		it("words the end of a game without near-miss talk", function()
			expect(Logic.endWords({ win = true })).to.equal("You win!")
			expect(Logic.endWords({ newBest = true })).to.equal("New best!")
			expect(Logic.endWords({})).to.equal("Nice try!")
			expect(Logic.lastLine({ points = 12, seconds = 20, best = 37, bestSeconds = 40 })).to.equal(
				"Score 12 · Best 37"
			)
			expect(Logic.lastLine({ points = 40, seconds = 50, newBest = true })).to.equal(
				"Score 40 · New best!"
			)
			for _, words in { Logic.endWords({}), Logic.RULE_LINE, Logic.FASTER } do
				local low = string.lower(words)
				expect(low:find("almost", 1, true)).never.to.be.ok()
				expect(low:find("so close", 1, true)).never.to.be.ok()
			end
		end)

		it("ticks today's prizes and names the next one", function()
			local rows = Logic.prizeRows({ 10, 20 })
			expect(#rows).to.equal(10)
			expect(rows[1].paid and rows[2].paid).to.equal(true)
			expect(rows[3].paid).to.equal(false)
			expect(Logic.nextPrize(5, { 10, 20 })).to.equal(
				"Next prize: " .. rows[3].name .. " at 30"
			)
			expect(Logic.nextPrize(100, {})).to.equal("All of today's prizes won!")
		end)
	end)
end
