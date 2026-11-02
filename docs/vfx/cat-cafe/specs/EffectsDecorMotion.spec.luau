--!strict
-- Moving parts of rare decor (F89 2c): a `_Swing` part swings side to side, a `_Spin` part turns, a `_Bob` part rides
-- up and down, each on its own cycle with the piece's own numbers held in range, and none in Low performance. Written
-- by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects rare decor moving parts", function()
		it("swings side to side up to its angle and back each cycle", function()
			expect(close(Logic.swingAngle(0, 2, 10, 0), 0)).to.equal(true)
			expect(close(Logic.swingAngle(0.5, 2, 10, 0), 10)).to.equal(true)
			expect(close(Logic.swingAngle(1.5, 2, 10, 0), -10)).to.equal(true)
			expect(close(Logic.swingAngle(2, 2, 10, 0), 0)).to.equal(true)
			-- a quarter of the way round from the start
			expect(close(Logic.swingAngle(0, 2, 10, 0.25), 10)).to.equal(true)
		end)

		it("turns once a cycle and wraps", function()
			expect(close(Logic.spinAngle(0, 4, 0), 0)).to.equal(true)
			expect(close(Logic.spinAngle(1, 4, 0), 90)).to.equal(true)
			expect(close(Logic.spinAngle(5, 4, 0), 90)).to.equal(true)
			expect(close(Logic.spinAngle(0, 4, 0.5), 180)).to.equal(true)
		end)

		it("bobs up and down by its rise", function()
			expect(close(Logic.bobRise(0.5, 2, 0.08, 0), 0.08)).to.equal(true)
			expect(close(Logic.bobRise(1.5, 2, 0.08, 0), -0.08)).to.equal(true)
		end)

		it("reads the piece's own numbers within range", function()
			local d = Presets.decorMotion
			expect(d.angle.default).to.equal(10)
			expect(d.seconds.default).to.equal(2)
			expect(d.rise.default).to.equal(0.08)
			expect(Logic.motionNumber(nil, 10, 0, 45)).to.equal(10)
			expect(Logic.motionNumber("12", 10, 0, 45)).to.equal(10)
			expect(Logic.motionNumber(0 / 0, 10, 0, 45)).to.equal(10)
			expect(Logic.motionNumber(20, 10, 0, 45)).to.equal(20)
			expect(Logic.motionNumber(90, 10, 0, 45)).to.equal(45)
			expect(Logic.motionNumber(0.01, 2, 0.3, 30)).to.equal(0.3)
		end)

		it("moves only a few at once and none in Low performance", function()
			local b = Presets.budget
			expect(b.high.decorMotion >= b.low.decorMotion).to.equal(true)
			expect(b.low.decorMotion > 0).to.equal(true)
			expect(b.lowPerformance.decorMotion).to.equal(0)
		end)
	end)
end
