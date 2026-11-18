--!strict
-- shared/FollowLogic.luau (#5172): the cat follower's spot behind the player, its walk, its pop past SNAP and its hop.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local FollowLogic = require(Shared.FollowLogic)

	describe("FollowLogic (#5172)", function()
		it("puts the spot behind and to the side of the player, at their feet", function()
			local spot = FollowLogic.spot(Vector3.new(10, 5, 10), Vector3.new(0, 0, -1), 2)
			expect(spot.Y).to.equal(2)
			expect(spot.X).to.be.near(10 + FollowLogic.SIDE, 1e-6)
			expect(spot.Z).to.be.near(10 + FollowLogic.BEHIND, 1e-6)
			expect(FollowLogic.feet(5, 2, 2)).to.equal(2)
			local aside = FollowLogic.spot(Vector3.new(10, 5, 10), Vector3.new(0, 0, -1), 2, true)
			expect(aside.X).to.be.near(10 + FollowLogic.SIDE * FollowLogic.ASIDE, 1e-6)
			expect(aside.Z).to.be.near(10 + FollowLogic.BEHIND * FollowLogic.ASIDE, 1e-6)
		end)

		it("stands still near its spot and pops to it from far away", function()
			local still = FollowLogic.move(Vector3.new(0, 0, 0), Vector3.new(0.3, 1, 0), 16, 1 / 60)
			expect(still.moved).to.equal(0)
			expect(still.snapped).to.equal(false)
			expect(still.position.Y).to.equal(1)
			local far = Vector3.new(FollowLogic.SNAP + 5, 0, 0)
			local pop = FollowLogic.move(Vector3.zero, far, 16, 1 / 60)
			expect(pop.snapped).to.equal(true)
			expect(pop.position).to.equal(far)
		end)

		it(
			"walks at the player's speed, faster when behind, and never past the stop ring",
			function()
				local near = FollowLogic.move(Vector3.zero, Vector3.new(2, 0, 0), 16, 1 / 60)
				expect(near.moved).to.be.near(16 / 60, 1e-6)
				local behind = FollowLogic.move(Vector3.zero, Vector3.new(20, 0, 0), 16, 1 / 60)
				expect(behind.moved > near.moved).to.equal(true)
				expect(behind.moved <= 16 * (1 + FollowLogic.CATCH_UP) / 60 + 1e-9).to.equal(true)
				local big = FollowLogic.move(Vector3.zero, Vector3.new(3, 0, 0), 16, 10)
				expect(big.position.X).to.be.near(3 - FollowLogic.STOP, 1e-6)
				expect(big.facing.X).to.be.near(1, 1e-6)
			end
		)

		it("hops up and back down over HOP_SECONDS", function()
			expect(FollowLogic.hop(0)).to.equal(0)
			expect(FollowLogic.hop(FollowLogic.HOP_SECONDS / 2)).to.be.near(
				FollowLogic.HOP_HEIGHT,
				1e-6
			)
			expect(FollowLogic.hop(FollowLogic.HOP_SECONDS)).to.equal(0)
		end)
	end)
end
