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

	describe("TutorialArrowLogic.place in the top bar", function()
		it("sits close under a target up in Roblox's top bar (#3154)", function()
			-- the Tutorial tile's ×, 54 px over a ScreenGui that starts under a 58 px top bar
			-- the "Hide tips with ×" tag left of it and the Rewards tile right of it are kept off, so it comes from below
			local tag = { min = Vector2.new(860, -48), max = Vector2.new(998, -24) }
			local rewards = { min = Vector2.new(1040, -58), max = Vector2.new(1104, 10) }
			local place = Logic.place(
				Vector2.new(1000, -54),
				Vector2.new(36, 36),
				SCREEN,
				64,
				{ tag, rewards },
				58
			)
			expect(place.side).to.equal("bottom")
			expect(place.y).to.equal(-54 + 36 + Logic.GAP + 32)
			local flat = Logic.place(
				Vector2.new(1000, -54),
				Vector2.new(36, 36),
				SCREEN,
				64,
				{ tag, rewards }
			)
			expect(flat.y >= 32).to.equal(true) -- without `top` it is kept under the origin, as before
		end)
	end)

	describe("TutorialArrowLogic.showing", function()
		it("stays on for as long as the step waits (#3153)", function()
			expect(Logic.showing(0)).to.equal(true)
			expect(Logic.showing(7)).to.equal(true)
			expect(Logic.showing(30)).to.equal(true)
			expect(Logic.showing(600)).to.equal(true)
			expect(Logic.showing(-1)).to.equal(false)
		end)
	end)

	describe("TutorialArrowLogic.onScreen", function()
		it(
			"is true for a target on the screen and false for one folded off an edge (#3153)",
			function()
				expect(Logic.onScreen(Vector2.new(20, 300), Vector2.new(90, 90), SCREEN)).to.equal(
					true
				)
				expect(Logic.onScreen(Vector2.new(-200, 300), Vector2.new(90, 90), SCREEN)).to.equal(
					false
				)
				expect(Logic.onScreen(Vector2.new(20, 800), Vector2.new(90, 90), SCREEN)).to.equal(
					false
				)
				expect(Logic.onScreen(Vector2.new(1250, 300), Vector2.new(20, 20), SCREEN)).to.equal(
					true
				)
			end
		)
	end)

	describe("TutorialArrowLogic.dim", function()
		it("fades in to strong, holds, then eases to soft and stays (#3153)", function()
			expect(Logic.dim(-1)).to.equal(1)
			expect(Logic.dim(0)).to.equal(1)
			local half = Logic.dim(Logic.SPOT_FADE_SECONDS / 2)
			expect(half < 1 and half > Logic.SPOT_STRONG).to.equal(true)
			expect(Logic.dim(Logic.SPOT_FADE_SECONDS)).to.equal(Logic.SPOT_STRONG)
			expect(Logic.dim(Logic.SPOT_STRONG_SECONDS - 0.01)).to.equal(Logic.SPOT_STRONG)
			expect(Logic.dim(Logic.SPOT_STRONG_SECONDS + Logic.SPOT_FADE_SECONDS)).to.equal(
				Logic.SPOT_SOFT
			)
			expect(Logic.dim(300)).to.equal(Logic.SPOT_SOFT)
			expect(Logic.SPOT_STRONG < Logic.SPOT_SOFT).to.equal(true)
		end)
	end)

	describe("TutorialArrowLogic.holes", function()
		local function covers(rects: { any }, point: Vector2): boolean
			for _, rect in rects do
				if
					point.X >= rect.min.X
					and point.X < rect.max.X
					and point.Y >= rect.min.Y
					and point.Y < rect.max.Y
				then
					return true
				end
			end
			return false
		end

		it("darkens everything but the target and its pad (#3153)", function()
			local at, size = Vector2.new(100, 400), Vector2.new(90, 90)
			local rects = Logic.holes(at, size, SCREEN)
			expect(#rects).to.equal(4)
			expect(covers(rects, Vector2.new(145, 445))).to.equal(false) -- the target's centre
			expect(covers(rects, Vector2.new(100 - Logic.SPOT_PAD + 1, 401))).to.equal(false) -- inside the pad
			expect(covers(rects, Vector2.new(5, 5))).to.equal(true)
			expect(covers(rects, Vector2.new(1275, 715))).to.equal(true)
			expect(covers(rects, Vector2.new(50, 445))).to.equal(true) -- left of the target
			expect(covers(rects, Vector2.new(400, 445))).to.equal(true) -- right of it
			expect(covers(rects, Vector2.new(-50, -30))).to.equal(true) -- the top bar, past the edge
			for _, rect in rects do
				expect(rect.max.X >= rect.min.X and rect.max.Y >= rect.min.Y).to.equal(true)
			end
		end)

		it(
			"puts every box edge on a whole pixel, so no bright seam shows between them (#3285)",
			function()
				-- a scaled HUD tile sits off the pixel grid
				local at, size = Vector2.new(100.5, 400.37), Vector2.new(90.25, 89.6)
				local rects = Logic.holes(at, size, Vector2.new(1279.5, 719.5))
				for _, rect in rects do
					for _, value in { rect.min.X, rect.min.Y, rect.max.X, rect.max.Y } do
						expect(value).to.equal(math.floor(value))
					end
				end
				-- the top box ends on the row the side boxes start on, and the bottom box starts where they end
				expect(rects[1].max.Y).to.equal(rects[3].min.Y)
				expect(rects[1].max.Y).to.equal(rects[4].min.Y)
				expect(rects[2].min.Y).to.equal(rects[3].max.Y)
				-- rounded outward: the whole target and its pad stay clear
				expect(covers(rects, Vector2.new(at.X - Logic.SPOT_PAD, at.Y - Logic.SPOT_PAD))).to.equal(
					false
				)
				expect(
					covers(
						rects,
						at + size + Vector2.new(Logic.SPOT_PAD - 0.01, Logic.SPOT_PAD - 0.01)
					)
				).to.equal(false)
				-- and every row across the screen is covered left and right of the hole
				for y = 0, 719, 7 do
					expect(covers(rects, Vector2.new(2, y + 0.5))).to.equal(true)
					expect(covers(rects, Vector2.new(1270, y + 0.5))).to.equal(true)
				end
			end
		)

		it("keeps the boxes whole for a target at the screen's corner", function()
			local rects = Logic.holes(Vector2.new(0, 0), Vector2.new(60, 60), SCREEN)
			for _, rect in rects do
				expect(rect.max.X >= rect.min.X and rect.max.Y >= rect.min.Y).to.equal(true)
			end
			expect(covers(rects, Vector2.new(30, 30))).to.equal(false)
			expect(covers(rects, Vector2.new(600, 300))).to.equal(true)
		end)
	end)

	describe("TutorialArrowLogic.margins (#3638)", function()
		it("gives the strips a phone's safe area leaves beside the HUD", function()
			-- a 2532 x 1170 phone held sideways: 141 px kept clear on each side, 63 at the bottom
			local m = Logic.margins(
				Vector2.new(0, 0),
				Vector2.new(2532, 1170),
				Vector2.new(141, 0),
				Vector2.new(2250, 1107)
			)
			expect(m.left).to.equal(141)
			expect(m.right).to.equal(141)
			expect(m.top).to.equal(0)
			expect(m.bottom).to.equal(63)
		end)

		it("is nothing where the HUD fills the screen, or before either has a size", function()
			local m = Logic.margins(Vector2.new(0, 0), SCREEN, Vector2.new(0, 0), SCREEN)
			expect(m.left + m.right + m.top + m.bottom).to.equal(0)
			local none =
				Logic.margins(Vector2.new(0, 0), Vector2.new(0, 0), Vector2.new(10, 0), SCREEN)
			expect(none.left + none.right + none.top + none.bottom).to.equal(0)
			-- an inner layer that reaches past the screen never gives a negative strip
			local past = Logic.margins(
				Vector2.new(0, 0),
				SCREEN,
				Vector2.new(-5, -5),
				Vector2.new(1300, 740)
			)
			expect(past.left).to.equal(0)
			expect(past.right).to.equal(0)
		end)
	end)
end
