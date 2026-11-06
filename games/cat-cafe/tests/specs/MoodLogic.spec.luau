--!strict
-- UI/Components/MoodLogic.luau: the Catch v3 mood icon's look and the Skittish view arc (catch-rework.md 7a).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local MoodLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("MoodLogic")
	) :: any

	describe("MoodLogic.look", function()
		it("gives each mood its glyph, and only Skittish the arc", function()
			expect(MoodLogic.look("Sleepy").glyph).to.equal("zZ")
			expect(MoodLogic.look("Curious").glyph).to.equal("?")
			expect(MoodLogic.look("Skittish").glyph).to.equal("!")
			expect(MoodLogic.look("Sleepy").arc).to.equal(false)
			expect(MoodLogic.look("Skittish").arc).to.equal(true)
		end)

		it("shows nothing without a known mood", function()
			expect(MoodLogic.look(nil)).to.equal(nil)
			expect(MoodLogic.look("Grumpy")).to.equal(nil)
			expect(MoodLogic.look(3)).to.equal(nil)
		end)
	end)

	describe("MoodLogic.range", function()
		it("is a positive number of studs", function()
			expect(MoodLogic.range() > 0).to.equal(true)
		end)
	end)

	describe("MoodLogic.arcAngle", function()
		it("points the way the cat faces on screen", function()
			expect(MoodLogic.arcAngle(10, 0)).to.equal(0)
			expect(MoodLogic.arcAngle(0, 10)).to.equal(90)
			expect(MoodLogic.arcAngle(-10, 0)).to.equal(180)
			expect(math.abs(MoodLogic.arcAngle(0, -10) + 90) < 1e-9).to.equal(true)
		end)

		it("keeps the last angle when the cat faces the camera, else points down", function()
			expect(MoodLogic.arcAngle(1, 1, 45)).to.equal(45)
			expect(MoodLogic.arcAngle(0, 0)).to.equal(90)
			expect(MoodLogic.arcAngle(0 / 0, 5, 30)).to.equal(30)
		end)
	end)
end
