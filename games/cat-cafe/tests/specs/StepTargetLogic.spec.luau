--!strict
-- UI/Components/StepTargetLogic.luau: the edge arrow for a tutorial target off screen (#2697).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local StepTargetLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("StepTargetLogic")
	) :: any

	local SCREEN = Vector2.new(800, 400)
	local ARROW = 40
	local GAP = 10

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("StepTargetLogic.edge", function()
		it("shows no edge arrow while the target is on screen", function()
			expect(StepTargetLogic.edge(Vector3.new(400, 200, 30), SCREEN, ARROW, GAP)).to.equal(
				nil
			)
			expect(StepTargetLogic.edge(Vector3.new(10, 390, 5), SCREEN, ARROW, GAP)).to.equal(nil)
		end)

		it("points right from the right edge at a target off to the right", function()
			local place = StepTargetLogic.edge(Vector3.new(1200, 200, 30), SCREEN, ARROW, GAP)
			expect(near(place.x, 800 - GAP - ARROW / 2)).to.equal(true)
			expect(near(place.y, 200)).to.equal(true)
			expect(near(place.rotation, -90)).to.equal(true)
		end)

		it("points up from the top edge at a target above", function()
			local place = StepTargetLogic.edge(Vector3.new(400, -300, 30), SCREEN, ARROW, GAP)
			expect(near(place.x, 400)).to.equal(true)
			expect(near(place.y, GAP + ARROW / 2)).to.equal(true)
			expect(near(math.abs(place.rotation), 180)).to.equal(true)
		end)

		it("flips a target behind the camera, so the arrow points the way to turn", function()
			-- projected to the right while behind: the player turns left
			local place = StepTargetLogic.edge(Vector3.new(600, 200, -20), SCREEN, ARROW, GAP)
			expect(near(place.x, GAP + ARROW / 2)).to.equal(true)
			expect(near(place.rotation, 90)).to.equal(true)
		end)

		it("points down when the target is straight behind", function()
			local place = StepTargetLogic.edge(Vector3.new(400, 200, -20), SCREEN, ARROW, GAP)
			expect(near(place.y, 400 - GAP - ARROW / 2)).to.equal(true)
			expect(near(place.rotation, 0)).to.equal(true)
		end)

		it("keeps the arrow whole in a corner", function()
			local place = StepTargetLogic.edge(Vector3.new(5000, 5000, 30), SCREEN, ARROW, GAP)
			expect(place.x <= 800 - GAP - ARROW / 2 + 1e-6).to.equal(true)
			expect(place.y <= 400 - GAP - ARROW / 2 + 1e-6).to.equal(true)
		end)
	end)

	describe("StepTargetLogic.small", function()
		it("takes a bowl or a cannon whole, not a cafe", function()
			expect(StepTargetLogic.small(Vector3.new(4, 2, 4))).to.equal(true)
			expect(StepTargetLogic.small(Vector3.new(12, 10, 18))).to.equal(true)
			expect(StepTargetLogic.small(Vector3.new(80, 30, 60))).to.equal(false)
		end)
	end)
	describe("StepTargetLogic.clear (#4152)", function()
		local screen = Vector2.new(667, 375)
		it(
			"slides an arrow on a side edge up or down, off a HUD piece, keeping its turn",
			function()
				local place = { x = 44, y = 300, rotation = 90 }
				local moved = StepTargetLogic.clear(
					place,
					64,
					{ { x0 = 0, y0 = 280, x1 = 120, y1 = 330 } },
					screen
				)
				expect(moved.x).to.equal(44)
				expect(moved.rotation).to.equal(90)
				expect(moved.y + 32 <= 280 or moved.y - 32 >= 330).to.equal(true)
			end
		)
		it("slides an arrow on the top or bottom sideways", function()
			local place = { x = 300, y = 44, rotation = 180 }
			local moved = StepTargetLogic.clear(
				place,
				64,
				{ { x0 = 260, y0 = 0, x1 = 420, y1 = 60 } },
				screen
			)
			expect(moved.y).to.equal(44)
			expect(moved.x + 32 <= 260 or moved.x - 32 >= 420).to.equal(true)
		end)
		it("counts the drawn arrow's reach, not only its square (Review-QA on #4158)", function()
			-- the 48 px square at y 278 ends at 302; the coin's box starts at 330, inside the 72 px reach
			local place = { x = 36, y = 278, rotation = 63 }
			local coin = { { x0 = 0, y0 = 330, x1 = 200, y1 = 375 } }
			local square = StepTargetLogic.clear(place, 48, coin, screen)
			expect(square.y).to.equal(278)
			local reached = StepTargetLogic.clear(place, 48, coin, screen, nil, 72)
			expect(reached.y + 72 <= 330).to.equal(true)
			expect(reached.rotation).to.equal(63)
		end)
		it(
			"keeps the square clear where the whole reach has no room (Review-QA on #4158, PC)",
			function()
				-- 110 px between two HUD pieces: too short for a 72 px reach each way, room for the 48 px square
				local place = { x = 36, y = 160, rotation = 63 }
				local pieces = {
					{ x0 = 0, y0 = 0, x1 = 200, y1 = 150 },
					{ x0 = 0, y0 = 260, x1 = 200, y1 = 375 },
				}
				local kept = StepTargetLogic.clear(place, 48, pieces, screen, nil, 72) :: any
				expect(kept).never.to.equal(nil)
				expect(kept.y - 24 >= 150).to.equal(true)
				expect(kept.y + 24 <= 260).to.equal(true)
			end
		)
		it(
			"shows no arrow where not even the square has room (Review-QA on #4158, 667x375)",
			function()
				local place = { x = 36, y = 160, rotation = 63 }
				local pieces = {
					{ x0 = 0, y0 = 0, x1 = 200, y1 = 150 },
					{ x0 = 0, y0 = 190, x1 = 200, y1 = 375 },
				}
				expect(StepTargetLogic.clear(place, 48, pieces, screen, nil, 72)).to.equal(nil)
			end
		)
		it("leaves a clear arrow alone, and gives none where no spot is clear", function()
			local place = { x = 44, y = 200, rotation = 90 }
			local same = StepTargetLogic.clear(
				place,
				64,
				{ { x0 = 300, y0 = 0, x1 = 400, y1 = 40 } },
				screen
			)
			local kept = same :: any
			expect(kept.x).to.equal(44)
			expect(kept.y).to.equal(200)
			local blocked =
				StepTargetLogic.clear(place, 64, { { x0 = 0, y0 = 0, x1 = 120, y1 = 375 } }, screen)
			expect(blocked).to.equal(nil)
		end)
	end)
end
