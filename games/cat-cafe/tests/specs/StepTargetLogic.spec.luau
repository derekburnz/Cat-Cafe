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
end
