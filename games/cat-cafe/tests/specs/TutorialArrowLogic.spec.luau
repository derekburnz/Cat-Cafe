--!strict
-- UI/Components/TutorialArrowLogic.luau: where the tutorial's big arrow sits and when it shows (#2314).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TutorialArrowLogic")
	) :: any
	local SCREEN = Vector2.new(1280, 720)

	describe("TutorialArrowLogic.place", function()
		it("comes from above, pointing down, when there is room", function()
			local place = Logic.place(Vector2.new(100, 500), Vector2.new(60, 60), SCREEN, 64)
			expect(place.side).to.equal("top")
			expect(place.rotation).to.equal(0)
			expect(place.x).to.equal(130)
			expect(place.y).to.equal(500 - Logic.GAP - 32)
		end)

		it("comes from the side when the target is at the top", function()
			local place = Logic.place(Vector2.new(300, 10), Vector2.new(60, 40), SCREEN, 64)
			expect(place.side).to.equal("left")
			expect(place.rotation).to.equal(-90)
			expect(place.x).to.equal(300 - Logic.GAP - 32)
		end)

		it("comes from the right or below when the left is full too", function()
			expect(Logic.place(Vector2.new(0, 0), Vector2.new(60, 40), SCREEN, 64).side).to.equal(
				"right"
			)
			local wide = Logic.place(Vector2.new(0, 0), Vector2.new(1280, 40), SCREEN, 64)
			expect(wide.side).to.equal("bottom")
			expect(wide.rotation).to.equal(180)
		end)

		it("keeps off the other buttons when a side is clear", function()
			-- a tile under the Store tile: from above it would sit on the Store, so it comes from the right; with the right
			-- taken too, from below
			local store = { min = Vector2.new(10, 60), max = Vector2.new(60, 110) }
			local place =
				Logic.place(Vector2.new(10, 120), Vector2.new(50, 50), SCREEN, 64, { store })
			expect(place.side).to.equal("right")
			local walled = {
				store,
				{ min = Vector2.new(70, 120), max = Vector2.new(140, 170) },
			}
			expect(Logic.place(Vector2.new(10, 120), Vector2.new(50, 50), SCREEN, 64, walled).side).to.equal(
				"bottom"
			)
		end)

		it("stays whole on the screen", function()
			local place = Logic.place(Vector2.new(1250, 600), Vector2.new(30, 30), SCREEN, 64)
			expect(place.x <= 1280 - 32).to.equal(true)
			expect(place.y >= 32).to.equal(true)
		end)
	end)

	describe("TutorialArrowLogic.showing", function()
		it("shows for a while, rests, then comes back", function()
			expect(Logic.showing(0)).to.equal(true)
			expect(Logic.showing(Logic.SHOW_SECONDS - 0.1)).to.equal(true)
			expect(Logic.showing(Logic.SHOW_SECONDS + 1)).to.equal(false)
			expect(Logic.showing(Logic.SHOW_SECONDS + Logic.AGAIN_SECONDS + 0.5)).to.equal(true)
			expect(Logic.showing(-1)).to.equal(false)
		end)
	end)
end
