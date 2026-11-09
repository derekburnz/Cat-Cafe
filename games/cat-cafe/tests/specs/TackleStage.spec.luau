--!strict
-- shared/TackleStage.luau (#2312): the tackling lesson's staged scene in front of the player.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local TackleStage = require(Shared.TackleStage)

	local GROUND = Vector3.new(100, 3, -40)
	local FACING = Vector3.new(0, 0, -1)

	describe("TackleStage.scene", function()
		it(
			"puts the scene AHEAD studs in front of the player, on the ground, with one camera a shot",
			function()
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
			end
		)

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
			expect((TackleStage.walkAt(scene.walkFrom, scene.walkTo, 99) - scene.walkTo).Magnitude).to.be.near(
				0,
				1e-6
			)
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

	describe("the shots (#2468, #2469)", function()
		local function flat(v: Vector3): Vector3
			return Vector3.new(v.X, 0, v.Z).Unit
		end

		it("films the hit side on, square to the knock, from the player's side", function()
			local scene = TackleStage.scene(GROUND, FACING)
			local key = scene.cameras[2]
			local view = flat(key.look - key.position)
			expect(math.abs(view:Dot(scene.knock)) < 0.05).to.equal(true)
			expect(view:Dot(scene.forward) > 0).to.equal(true) -- looking away from the player, so it stands behind
			expect((scene.knocked - scene.hit).Magnitude).to.be.near(TackleStage.KNOCK_STUDS, 1e-6)
			-- the lunge starts once the camera's glide to the shot is over
			expect(TackleStage.LUNGE_AT >= 0.6).to.equal(true)
		end)

		it(
			"walks the tackler from the lunge to a stud short of the dropped cat, and has it take the cat",
			function()
				local scene = TackleStage.scene(GROUND, FACING)
				local start, startTaken = TackleStage.pickupAt(scene, 0)
				expect((start - scene.tackler).Magnitude).to.be.near(0, 1e-6)
				expect(startTaken).to.equal(false)
				local from, taken = TackleStage.pickupTimes(scene)
				expect(from > TackleStage.LUNGE_AT + TackleStage.LUNGE_SECONDS).to.equal(true)
				local mid, midTaken = TackleStage.pickupAt(scene, from)
				expect((mid - scene.stop).Magnitude).to.be.near(0, 1e-6)
				expect(midTaken).to.equal(false)
				local done, doneTaken = TackleStage.pickupAt(scene, taken)
				expect((done - scene.pickup).Magnitude).to.be.near(0, 1e-6)
				expect(doneTaken).to.equal(true)
				expect((scene.pickup - scene.drop).Magnitude).to.be.near(1, 1e-6)
				-- taken well before the third caption's 4.2 s hold ends
				expect(taken < 3).to.equal(true)
			end
		)

		it(
			"puts shot 4's cat beside the knocked copy, clear of the tackler, and pins it after the swing",
			function()
				local scene = TackleStage.scene(GROUND, FACING)
				expect((scene.catchAt - scene.knocked).Magnitude).to.be.near(
					TackleStage.CATCH_STUDS,
					1e-6
				)
				expect((scene.catchAt - scene.pickup).Magnitude > 3).to.equal(true)
				expect(TackleStage.PIN_AT > TackleStage.SWING_AT).to.equal(true)
				expect(scene.catchAt.Y).to.equal(GROUND.Y)
			end
		)
	end)
end
