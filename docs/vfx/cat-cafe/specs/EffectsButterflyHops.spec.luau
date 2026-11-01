--!strict
-- Butterflies flying between flower beds (Derek 2026-10-28 17:48: the Town Square's butterflies "going in circles
-- are a little repetitive make them go between each one"): the arc of a flight to another bed and the numbers that
-- let a lamp basket's butterflies reach the next lamp. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects butterfly hops", function()
		it("arcs up to its height halfway and lands level", function()
			expect(close(Logic.hopLift(0, 1.2), 0)).to.equal(true)
			expect(close(Logic.hopLift(1, 1.2), 0)).to.equal(true)
			expect(close(Logic.hopLift(0.5, 1.2), 1.2)).to.equal(true)
			expect(close(Logic.hopLift(-1, 1.2), 0)).to.equal(true)
			expect(close(Logic.hopLift(2, 1.2), 0)).to.equal(true)
			expect(Logic.hopLift(0.25, 1.2) < Logic.hopLift(0.5, 1.2)).to.equal(true)
		end)

		it("reaches the next Town Square lamp but not across the square", function()
			local hop = Presets.butterfly.hop
			local lamps = 22 -- the square's lamps stand at x and z of plus or minus 11 (square.py LAMP_AT)
			expect(hop.range >= lamps).to.equal(true)
			expect(hop.range < 2 * lamps).to.equal(true)
		end)

		it("flies over at a butterfly's pace and stays a moment after landing", function()
			local b = Presets.butterfly
			local hop = b.hop
			expect(hop.chance > 0 and hop.chance < 0.5).to.equal(true) -- most flights stay on the bed
			expect(hop.shortest <= 22 / hop.speed and 22 / hop.speed <= hop.longest).to.equal(true)
			expect(hop.speed >= b.speed).to.equal(true)
			expect(hop.stay >= b.fade).to.equal(true)
			expect(hop.arc > 0 and hop.arc <= 2).to.equal(true)
		end)
	end)
end
