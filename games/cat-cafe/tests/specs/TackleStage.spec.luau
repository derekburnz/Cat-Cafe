--!strict
-- shared/TackleStage.luau (#2312): the tackling lesson's staged scene in front of the player.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local TackleStage = require(Shared.TackleStage)

	local GROUND = Vector3.new(100, 3, -40)
	local FACING = Vector3.new(0, 0, -1)

	describe("TackleStage.scene", function()
		it("puts the scene AHEAD studs in front of the player, on the ground, with one camera a shot", function()
			local scene = TackleStage.scene(GROUND, FACING)
			expect((scene.centre - GROUND).Magnitude).to.be.near(TackleStage.AHEAD, 1e-6)
			expect(scene.centre.Y).to.equal(GROUND.Y)
			expect(scene.walkFrom.Y).to.equal(GROUND.Y)
			expect(scene.tackler.Y).to.equal(GROUND.Y)
			expect(#scene.cameras).to.equal(TackleStage.SHOTS)
			for _, key in scene.cameras do
				expect(key.position.Y > GROUND.Y).to.equal(true)
				expect((key.look - key.position).Magnitude > 3).to.equal(true)
			end
		end)

		it("keeps a flat facing even when it is given a tilted or zero one", function()
			local tilted = TackleStage.scene(GROUND, Vector3.new(0, -5, -1))
			expect(tilted.forward.Y).to.equal(0)
			expect(tilted.forward.Magnitude).to.be.near(1, 1e-6)
			local none = TackleStage.scene(GROUND, Vector3.zero)
			expect(none.forward.Magnitude).to.be.near(1, 1e-6)
		end)
	end)

	describe("the walk and the lunge", function()
		it("walks the carrier at WALK_SPEED and stops at the end", function()
			local scene = TackleStage.scene(GROUND, FACING)
			local a = TackleStage.walkAt(scene.walkFrom, scene.walkTo, 0)
			local b = TackleStage.walkAt(scene.walkFrom, scene.walkTo, 1)
			expect((a - scene.walkFrom).Magnitude).to.be.near(0, 1e-6)
			expect((b - a).Magnitude).to.be.near(TackleStage.WALK_SPEED, 1e-6)
			expect((TackleStage.walkAt(scene.walkFrom, scene.walkTo, 99) - scene.walkTo).Magnitude).to.be.near(0, 1e-6)
		end)

		it("waits, then lunges to a stud short of where the carrier is when it lands", function()
			local scene = TackleStage.scene(GROUND, FACING)
			expect((TackleStage.lungeAt(scene, 0) - scene.tackler).Magnitude).to.be.near(0, 1e-6)
			local landed = TackleStage.LUNGE_AT + TackleStage.LUNGE_SECONDS
			local hit = TackleStage.hitPoint(scene.walkFrom, scene.walkTo)
			local carrier = TackleStage.walkAt(scene.walkFrom, scene.walkTo, landed)
			expect((hit - carrier).Magnitude).to.be.near(0, 1e-6)
			expect((TackleStage.lungeAt(scene, landed) - hit).Magnitude).to.be.near(1, 1e-6)
			expect((TackleStage.lungeAt(scene, 9) - hit).Magnitude).to.be.near(1, 1e-6)
		end)
	end)
end
