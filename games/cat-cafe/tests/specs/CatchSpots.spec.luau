--!strict
-- UI/Components/CatchSpots.luau: Catch v3's rings move to a new spot every time (#2060).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatchSpots = require(Components:WaitForChild("CatchSpots")) :: any

	local function inBox(spot: Vector2): boolean
		return spot.X >= CatchSpots.MIN_X
			and spot.X <= CatchSpots.MAX_X
			and spot.Y >= CatchSpots.MIN_Y
			and spot.Y <= CatchSpots.MAX_Y
	end

	local function apart(a: Vector2, b: Vector2): boolean
		return math.abs(a.X - b.X) >= CatchSpots.STEP_X - 1e-9
			or math.abs(a.Y - b.Y) >= CatchSpots.STEP_Y - 1e-9
	end

	local function ring(x: number, y: number, kind: string?, half: number?): any
		return {
			startsAt = 0,
			shrinkSeconds = 1,
			x = x,
			y = y,
			kind = kind or "single",
			half = half,
		}
	end

	describe("CatchSpots.spots", function()
		it("stretches the server's range over the safe box", function()
			local spots = CatchSpots.spots({ ring(0.25, 0.3), ring(0.75, 0.7) })
			expect(spots[1].X).to.be.near(CatchSpots.MIN_X, 1e-9)
			expect(spots[1].Y).to.be.near(CatchSpots.MIN_Y, 1e-9)
			expect(spots[2].X).to.be.near(CatchSpots.MAX_X, 1e-9)
			expect(spots[2].Y).to.be.near(CatchSpots.MAX_Y, 1e-9)
		end)

		it(
			"moves every ring away from the one before, even when the server sends one spot",
			function()
				local list = {}
				for _ = 1, 8 do
					table.insert(list, ring(0.5, 0.5))
				end
				local spots = CatchSpots.spots(list)
				expect(#spots).to.equal(8)
				for index, spot in spots do
					expect(inBox(spot)).to.equal(true)
					if index > 1 then
						expect(apart(spot, spots[index - 1])).to.equal(true)
					end
				end
			end
		)

		it("keeps any roll inside the box and apart from the last ring", function()
			local rng = Random.new(2060)
			local list = {}
			for _ = 1, 200 do
				table.insert(
					list,
					ring(0.25 + rng:NextNumber() * 0.5, 0.3 + rng:NextNumber() * 0.4)
				)
			end
			table.insert(list, ring(-3, 9)) -- out of range is clamped
			table.insert(list, ring(0 / 0, 0.5)) -- NaN goes to the middle
			local spots = CatchSpots.spots(list)
			for index, spot in spots do
				expect(inBox(spot)).to.equal(true)
				if index > 1 then
					expect(apart(spot, spots[index - 1])).to.equal(true)
				end
			end
		end)

		it("keeps a double ring's halves on one spot", function()
			local spots = CatchSpots.spots({
				ring(0.3, 0.4),
				ring(0.6, 0.6, "double", 1),
				ring(0.6, 0.6, "double", 2),
				ring(0.4, 0.4, "paw"),
			})
			expect(spots[3]).to.equal(spots[2])
			expect(apart(spots[2], spots[1])).to.equal(true)
			expect(apart(spots[4], spots[3])).to.equal(true)
		end)
	end)
end
