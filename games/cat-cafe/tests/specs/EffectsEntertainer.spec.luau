--!strict
-- The entertainer's pom-pom (Derek 2026-10-28 17:41: Comet's ball was "kind of floating" and its foot "randomly"
-- twitched): the paws take turns batting a pom-pom on a springy wand stood on the perch, the pom-pom resting against
-- the pad of a raised paw so every bat meets it, springing away and wobbling back to rest before the next bat.
-- Logic.idle, Logic.bat, Logic.toySway, Logic.toyRest and Logic.toy are pure; the parts themselves (Cats.luau's
-- addYarn) and the cat tree under them are Studio rows (effects-list "Role idles").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local e = Presets.motion.entertainer
	local reach = math.rad(e.reach)
	-- the sitting body's front leg hinges at Scale 1 (Model-Agent's B body), the pad at the leg's foot 0.05 ahead
	local HINGE_Y, HINGE_Z = 0.59, -0.28
	local TOE = -0.465 -- how far ahead the resting paws' toes reach

	local function idle(t: number): any
		return Logic.idle("entertainer", t, "sit")
	end

	describe("Effects entertainer pom-pom", function()
		it("bats with the left paw, then the right, taking turns every `every` seconds", function()
			local first = idle(e.hold / 2)
			expect(first.pawFL).to.be.near(reach, 1e-6)
			expect(first.pawFR).to.equal(0)
			local second = idle(e.every + e.hold / 2)
			expect(second.pawFR).to.be.near(reach, 1e-6)
			expect(second.pawFL).to.equal(0)
			local third = idle(2 * e.every + e.hold / 2)
			expect(third.pawFL).to.be.near(reach, 1e-6)
		end)

		it(
			"brings the paw up faster and faster to the hit, holds it, then lowers it smoothly",
			function()
				expect(Logic.bat(-e.windup - 0.01)).to.equal(0)
				expect(Logic.bat(-e.windup)).to.be.near(0, 1e-9)
				local early = Logic.bat(-e.windup * 0.75) - Logic.bat(-e.windup)
				local late = Logic.bat(0) - Logic.bat(-e.windup * 0.25)
				expect(late > early * 3).to.equal(true) -- it strikes
				expect(Logic.bat(-1e-6)).to.be.near(1, 1e-4)
				expect(Logic.bat(0)).to.equal(1)
				expect(Logic.bat(e.hold - 1e-6)).to.equal(1)
				expect(Logic.bat(e.hold + e.back - 1e-6)).to.be.near(0, 1e-4)
				expect(Logic.bat(e.hold + e.back)).to.equal(0)
				expect(e.windup + e.hold + e.back < e.every).to.equal(true) -- one paw is down before the other comes up
			end
		)

		it("is still when a paw meets it and springs away from the cat first, then back", function()
			local out, side = Logic.toySway(0, 1)
			expect(out).to.equal(0)
			expect(side).to.equal(0)
			local away = Logic.toySway(0.25 / e.hz, 1)
			expect(away > math.rad(e.tilt) * 0.3).to.equal(true)
			local back = Logic.toySway(0.75 / e.hz, 1)
			expect(back < 0).to.equal(true)
			expect(math.abs(back) < away).to.equal(true) -- dying away
		end)

		it("goes off to the far side from the paw that batted it", function()
			local out, right = Logic.toySway(0.25 / e.hz, 1)
			local _, left = Logic.toySway(0.25 / e.hz, -1)
			expect(right).to.be.near(out * e.side, 1e-9)
			expect(left).to.be.near(-out * e.side, 1e-9)
			-- in the idle: after the left paw's bat it goes right, after the right paw's to the left
			expect(idle(0.25 / e.hz).yarn > 0).to.equal(true)
			expect(idle(e.every + 0.25 / e.hz).yarn < 0).to.equal(true)
		end)

		it("has settled before the next paw meets it", function()
			local out, side = Logic.toySway(e.every - 1e-6, 1)
			expect(math.abs(out) < 1e-4).to.equal(true)
			expect(math.abs(side) < 1e-4).to.equal(true)
			for since = e.every - e.windup, e.every, 0.01 do
				expect(math.abs((Logic.toySway(since, 1))) < math.rad(1)).to.equal(true)
			end
		end)

		it("moves with no jumps, the paws at most a strike's step and the wand smoothly", function()
			local step = 1 / 240
			local last = idle(0)
			for i = 1, math.floor(2 * e.every / step) + 4 do
				local o = idle(i * step)
				expect(math.abs(o.pawFL - last.pawFL) < math.rad(3)).to.equal(true)
				expect(math.abs(o.pawFR - last.pawFR) < math.rad(3)).to.equal(true)
				expect(math.abs(o.yarnOut - last.yarnOut) < math.rad(1.5)).to.equal(true)
				expect(math.abs(o.yarn - last.yarn) < math.rad(1)).to.equal(true)
				expect(math.abs(o.headYaw - last.headYaw) < math.rad(1)).to.equal(true)
				last = o
			end
		end)

		it("looks down at it and turns after it", function()
			local o = idle(0.25 / e.hz)
			expect(o.headPitch).to.be.near(-math.rad(e.look), 1e-9)
			expect(o.headYaw).to.be.near(-e.follow * o.yarn, 1e-9) -- negative yaw turns the head right
		end)

		it(
			"rests on the pad of a paw raised `reach`, above the perch and ahead of the resting toes",
			function()
				local y, z = Logic.toyRest(HINGE_Y, HINGE_Z, 1)
				local r = e.pom / 2
				-- the pad's centre with the leg swung forward `reach` about the hinge
				local padY = HINGE_Y - HINGE_Y * math.cos(reach) + 0.05 * math.sin(reach)
				local padZ = HINGE_Z - HINGE_Y * math.sin(reach) - 0.05 * math.cos(reach)
				expect(math.sqrt((y - padY) ^ 2 + (z - padZ) ^ 2)).to.be.near(r, 1e-6)
				expect(y - r > 0).to.equal(true)
				expect(z + r < TOE).to.equal(true)
			end
		)

		it("sits in the same place on a bigger cat, scaled with it", function()
			local y, z = Logic.toyRest(HINGE_Y, HINGE_Z, 1)
			local y2, z2 = Logic.toyRest(HINGE_Y * 1.2, HINGE_Z * 1.2, 1.2)
			expect(y2).to.be.near(y * 1.2, 1e-9)
			expect(z2).to.be.near(z * 1.2, 1e-9)
		end)

		it(
			"stands the wand from its foot on the perch to the pom-pom, which it holds at rest",
			function()
				local y, z = Logic.toyRest(HINGE_Y, HINGE_Z, 1)
				local o = Logic.blank()
				local pom, foot, tip = Logic.toy(o, y, z, 1)
				expect((pom - Vector3.new(0, y, z)).Magnitude < 1e-6).to.equal(true)
				expect((foot - Vector3.new(0, 0, -e.wandBase)).Magnitude < 1e-6).to.equal(true)
				-- the tip is on the line from the foot to the pom-pom, at its underside
				expect(math.abs((pom - tip).Magnitude - e.pom / 2) < 1e-6).to.equal(true)
				expect(((tip - foot).Unit - (pom - foot).Unit).Magnitude < 1e-6).to.equal(true)
			end
		)

		it("leans the wand away from the cat and to the side it was sent", function()
			local y, z = Logic.toyRest(HINGE_Y, HINGE_Z, 1)
			local o = Logic.blank()
			o.yarnOut = math.rad(20)
			local away = Logic.toy(o, y, z, 1)
			expect(away.Z < z).to.equal(true)
			o.yarnOut = 0
			o.yarn = math.rad(10)
			local right = Logic.toy(o, y, z, 1)
			expect(right.X > 0).to.equal(true)
		end)

		it("swings the pom-pom about the wand's foot, never back into the resting paws", function()
			local y, z = Logic.toyRest(HINGE_Y, HINGE_Z, 1)
			local foot = Vector3.new(0, 0, -e.wandBase)
			local arm = (Vector3.new(0, y, z) - foot).Magnitude
			for t = 0, 2 * e.every, 0.02 do
				local pom = Logic.toy(idle(t), y, z, 1)
				expect(math.abs((pom - foot).Magnitude - arm) < 1e-6).to.equal(true)
				expect(pom.Z + e.pom / 2 < TOE).to.equal(true)
			end
		end)
	end)
end
