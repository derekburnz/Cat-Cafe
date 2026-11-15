--!strict
-- TutorialMoves.luau (#2697 part 2): which step moves the player where, and where they stand.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local TutorialMoves = require(Shared.TutorialMoves)

	describe("TutorialMoves", function()
		it("moves to the bowl on reaching step 4 and to the cannon on reaching step 5", function()
			expect(TutorialMoves.target(3, 4)).to.equal("bowl")
			expect(TutorialMoves.target(4, 5)).to.equal("cannon")
			expect(TutorialMoves.target(3, 5)).to.equal("cannon")
			expect(TutorialMoves.target(2, 3)).to.equal(nil)
			expect(TutorialMoves.target(0, 2)).to.equal(nil)
			expect(TutorialMoves.target(5, 5)).to.equal(nil)
			expect(TutorialMoves.target(4, 4)).to.equal(nil)
		end)

		it("stands the given studs out toward a point, facing the target", function()
			local target = Vector3.new(10, 0, 10)
			local at, look = TutorialMoves.standAt(target, Vector3.new(10, 5, 30), 4, 3)
			expect(at.X).to.be.near(10, 1e-6)
			expect(at.Y).to.be.near(3, 1e-6)
			expect(at.Z).to.be.near(14, 1e-6)
			expect(look.Z).to.be.near(-1, 1e-6)
			expect(look.Y).to.be.near(0, 1e-6)
		end)

		it("stands out along -Z when the point is right above the target", function()
			local at, look = TutorialMoves.standAt(Vector3.zero, Vector3.new(0, 9, 0), 7, 3)
			expect(at.Z).to.be.near(-7, 1e-6)
			expect(look.Z).to.be.near(1, 1e-6)
		end)

		it(
			"waits a beat before the move to the cannon, none before the bowl's (#3158, #3640)",
			function()
				expect(TutorialMoves.delay("bowl")).to.equal(0)
				expect(TutorialMoves.delay("cannon")).to.equal(TutorialMoves.CANNON_DELAY)
				expect(TutorialMoves.CANNON_DELAY > 0).to.equal(true)
				expect(TutorialMoves.CANNON_DELAY <= 2).to.equal(true)
			end
		)

		it("drops the move for a player who walked off in that time (#3158)", function()
			local from = Vector3.new(100, 3, 50)
			expect(TutorialMoves.stayed(from, from)).to.equal(true)
			expect(TutorialMoves.stayed(from, from + Vector3.new(10, 0, -10))).to.equal(true)
			expect(TutorialMoves.stayed(from, from + Vector3.new(0, 40, 0))).to.equal(true) -- a jump is not a walk
			expect(TutorialMoves.stayed(from, from + Vector3.new(TutorialMoves.LEFT_STUDS, 0, 0))).to.equal(
				true
			)
			expect(
				TutorialMoves.stayed(from, from + Vector3.new(TutorialMoves.LEFT_STUDS + 1, 0, 0))
			).to.equal(false)
		end)

		it(
			"stands the cannon move in front of the cannon, outside its ring and range (#4097)",
			function()
				local Config = require(Shared.Config) :: any
				local WalkUp = require(Shared.WalkUp) :: any
				local range = Config.World.TownCannonRangeStuds
				expect(TutorialMoves.CANNON_STUDS > range - WalkUp.EDGE_SLACK).to.equal(true)
				expect(TutorialMoves.CANNON_STUDS > range).to.equal(true)
				-- near enough that the cannon is right in front of them
				expect(TutorialMoves.CANNON_STUDS <= range + 5).to.equal(true)
			end
		)
	end)
end
