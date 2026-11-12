--!strict
-- Components/SpotlightGuideLogic (#3555): the words sit by the lit button and stay on the screen on a small phone,
-- a tablet and a PC, and only a press off the button counts as a press on the dim.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("SpotlightGuideLogic")) :: any

	local CAPTION = Vector2.new(280, 40)
	local SCREENS = { Vector2.new(705, 338), Vector2.new(1180, 820), Vector2.new(1920, 1080) }

	describe("SpotlightGuideLogic", function()
		it("puts the words under the button when there is room, centred on it", function()
			local at = Logic.captionAt(
				Vector2.new(300, 60),
				Vector2.new(100, 50),
				Vector2.new(705, 338),
				CAPTION
			)
			expect(at.Y).to.equal(60 + 50 + Logic.GAP)
			expect(at.X).to.equal(300 + 50 - 140)
		end)

		it("goes over a button at the bottom of the screen", function()
			local at = Logic.captionAt(
				Vector2.new(300, 280),
				Vector2.new(100, 50),
				Vector2.new(705, 338),
				CAPTION
			)
			expect(at.Y).to.equal(280 - Logic.GAP - CAPTION.Y)
		end)

		it("never leaves the screen, wherever the button is", function()
			for _, screen in SCREENS do
				for _, corner in
					{
						Vector2.new(0, 0),
						Vector2.new(screen.X - 60, 0),
						Vector2.new(0, screen.Y - 60),
						Vector2.new(screen.X - 60, screen.Y - 60),
						Vector2.new(screen.X / 2, screen.Y / 2),
						Vector2.new(4, screen.Y / 2 - 150), -- a tall button that fills a small phone
					}
				do
					local size = if corner.X == 4 then Vector2.new(60, 300) else Vector2.new(60, 60)
					local at = Logic.captionAt(corner, size, screen, CAPTION)
					expect(at.X >= Logic.MARGIN).to.equal(true)
					expect(at.Y >= Logic.MARGIN).to.equal(true)
					expect(at.X + CAPTION.X <= screen.X - Logic.MARGIN).to.equal(true)
					expect(at.Y + CAPTION.Y <= screen.Y - Logic.MARGIN).to.equal(true)
				end
			end
		end)

		it("counts only a press off the button as a press on the dim", function()
			local position, size = Vector2.new(100, 100), Vector2.new(80, 40)
			expect(Logic.outside(Vector2.new(140, 120), position, size)).to.equal(false)
			-- a thumb just off its edge is still the button
			expect(Logic.outside(Vector2.new(100 - Logic.PAD, 120), position, size)).to.equal(false)
			expect(Logic.outside(Vector2.new(100 - Logic.PAD - 1, 120), position, size)).to.equal(
				true
			)
			expect(Logic.outside(Vector2.new(140, 300), position, size)).to.equal(true)
			expect(Logic.outside(Vector2.new(500, 120), position, size)).to.equal(true)
		end)
	end)
end
