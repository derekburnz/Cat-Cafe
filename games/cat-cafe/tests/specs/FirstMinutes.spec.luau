--!strict
-- #2774 (Derek2 2026-11-09, the 2 to 5 minute drop): the first bait's short wait and a beginner's wide net.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Bait = require(Shared.Bait)
	local Config = require(Shared.Config)
	local NetSwing = require(Shared.NetSwing)

	describe("First minutes (#2774)", function()
		it("brings the account's first bait in 1 second (#2946; 45 before) and leaves later ones alone", function()
			expect(Config.FirstBaitWaitSeconds).to.equal(1) -- #2946: was 45
			expect(Bait.firstWait(600, 0)).to.equal(1)
			expect(Bait.firstWait(300, 0)).to.equal(1)
			expect(Bait.firstWait(600, 1)).to.equal(600)
		end)

		it(
			"lands a beginner's swing on their tutorial stray nearby whichever way they face",
			function()
				local origin = Vector3.new(0, 3, 0)
				expect(NetSwing.beginnerReach(origin, Vector3.new(0, 3, -8))).to.equal(true) -- ahead
				expect(NetSwing.beginnerReach(origin, Vector3.new(0, 3, 8))).to.equal(true) -- behind
				expect(NetSwing.beginnerReach(origin, Vector3.new(6, 1, 6))).to.equal(true) -- 8.5 to the side, a step down
				expect(NetSwing.beginnerReach(origin, Vector3.new(0, 3, 9.5))).to.equal(false) -- too far
				expect(NetSwing.beginnerReach(origin, Vector3.new(0, 10, 2))).to.equal(false) -- up on a perch
			end
		)

		it("reaches further than a normal swing behind the player", function()
			local origin = Vector3.new(0, 3, 0)
			local look = Vector3.new(0, 0, -1)
			local behind = Vector3.new(0, 3, 6)
			expect(NetSwing.inReach(origin, look, behind)).to.equal(false)
			expect(NetSwing.beginnerReach(origin, behind)).to.equal(true)
		end)
	end)
end
