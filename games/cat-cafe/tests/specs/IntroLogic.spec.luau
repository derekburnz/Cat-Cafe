--!strict
-- UI/Components/IntroLogic.luau: the intro cutscene screen's numbers (F72, intro-cutscene.md sections 2 and 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local IntroLogic = require(Components:WaitForChild("IntroLogic")) :: any

	describe("IntroLogic.skipAfter", function()
		it("shows Skip 2.0 s into a first play and at once on a replay", function()
			expect(IntroLogic.skipAfter(nil)).to.equal(2.0)
			expect(IntroLogic.skipAfter({})).to.equal(2.0)
			expect(IntroLogic.skipAfter({ replay = false })).to.equal(2.0)
			expect(IntroLogic.skipAfter({ replay = true })).to.equal(0)
		end)

		it("takes the controller's skipAfter, never below 0", function()
			expect(IntroLogic.skipAfter({ skipAfter = 1.25 })).to.equal(1.25)
			expect(IntroLogic.skipAfter({ skipAfter = 0, replay = false })).to.equal(0)
			expect(IntroLogic.skipAfter({ skipAfter = -3 })).to.equal(0)
		end)

		it("ignores a skipAfter that is not a real number", function()
			expect(IntroLogic.skipAfter({ skipAfter = 0 / 0 })).to.equal(2.0)
			expect(IntroLogic.skipAfter({ skipAfter = math.huge, replay = true })).to.equal(0)
		end)
	end)

	describe("IntroLogic.closerRadius", function()
		it("closes from the start radius onto the ring by 1.3 s at a steady speed", function()
			expect(IntroLogic.closerRadius(0)).to.equal(IntroLogic.START_RADIUS)
			expect(IntroLogic.closerRadius(IntroLogic.CLOSE)).to.equal(IntroLogic.RING_RADIUS)
			local half = (IntroLogic.START_RADIUS + IntroLogic.RING_RADIUS) / 2
			local midway = IntroLogic.closerRadius(IntroLogic.CLOSE / 2)
			expect(math.abs(midway - half) < 1e-9).to.equal(true)
		end)

		it("rests on the ring after it closes and never starts wider", function()
			expect(IntroLogic.closerRadius(IntroLogic.END)).to.equal(IntroLogic.RING_RADIUS)
			expect(IntroLogic.closerRadius(-1)).to.equal(IntroLogic.START_RADIUS)
		end)

		it("keeps the design's demo timing: PERFECT at 1.3 s, gone by 2.0 s", function()
			expect(IntroLogic.CLOSE).to.equal(1.3)
			expect(IntroLogic.END).to.equal(2.0)
			local fade = IntroLogic.FADE_FROM
			expect(fade > IntroLogic.CLOSE and fade < IntroLogic.END).to.equal(true)
		end)
	end)

	describe("IntroLogic.skipPlace", function()
		it("centres a 40 px pill on a desktop's lower bar", function()
			-- 720 px tall at scale 1: the bar is 64.8 px, so 12.4 px of bar shows under the pill
			local height, below = IntroLogic.skipPlace(720, 1, false)
			expect(height).to.equal(40)
			expect(math.abs(below - 12.4) < 1e-9).to.equal(true)
		end)

		it("is at least 44 real pixels tall on touch", function()
			local height = IntroLogic.skipPlace(390, 0.75, true)
			expect(height * 0.75 >= 44).to.equal(true)
			local tall = IntroLogic.skipPlace(1080, 1.3, true)
			expect(tall).to.equal(40)
		end)

		it("stays 4 above the bottom edge when the bar is shorter than the pill", function()
			local _, below = IntroLogic.skipPlace(390, 0.75, true)
			expect(below).to.equal(4)
			local _, none = IntroLogic.skipPlace(0, 0, true)
			expect(none).to.equal(4)
		end)
	end)

	describe("IntroLogic dots and Skip's shot", function()
		it("lights the current shot's dot and dims the ones to come", function()
			expect(IntroLogic.dot(3, 3)).to.equal("now")
			expect(IntroLogic.dot(1, 3)).to.equal("past")
			expect(IntroLogic.dot(9, 3)).to.equal("next")
			expect(IntroLogic.dot(1, 0)).to.equal("next")
		end)

		it("reports the shot showing, 1 before the first shot and never past 9", function()
			expect(IntroLogic.skipShot(0)).to.equal(1)
			expect(IntroLogic.skipShot(5)).to.equal(5)
			expect(IntroLogic.skipShot(12)).to.equal(IntroLogic.SHOTS)
		end)
	end)
end
