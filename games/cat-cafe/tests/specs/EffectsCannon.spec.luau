--!strict
-- The Cat Cannon flight (F84, hometown-cannon.md section 3b; Derek 2026-11-03: "much further with less summer
-- salting", "a better landing animation"): where the body is and how it is posed through the four seconds from
-- CannonLaunchAt, and the flyer in the cloud cutscene (Derek 2026-10-28 13:56). Avatar.cannon,
-- Avatar.glideFrames and CannonGlide.luau need a real character, so they are checked in Studio. Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Avatar = require(Effects:WaitForChild("Avatar")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.cannonPose
	local g = Presets.cannonGlide
	local STEP = 1 / 60

	describe("Effects cannon flight", function()
		it("follows the design's timeline and lets go after the landing", function()
			expect(c.hop < c.boom and c.boom < c.gone and c.gone < c.drop).to.equal(true)
			expect(c.drop < c.touch and c.touch < c.ends).to.equal(true)
			expect(c.boom).to.equal(0.5)
			expect(c.gone).to.equal(2)
			expect(c.drop).to.equal(3)
			expect(c.touch).to.equal(3.5)
			expect(c.ends).to.equal(4)
			expect((Avatar.flight(-0.01))).to.equal(nil)
			expect((Avatar.flight(c.ends + c.blendOut))).to.equal(nil)
			local _, _, _, _, weight = Avatar.flight(c.ends + c.blendOut / 2)
			expect(weight > 0 and weight < 1).to.equal(true)
		end)

		it("hops from where the player stood into the seat, turning to the barrel", function()
			local from = Vector3.new(1, -3, 6)
			local _, start, yaw0 = Avatar.flight(0, from, math.rad(150))
			expect((start - from).Magnitude < 1e-6).to.equal(true)
			expect(yaw0).to.be.near(math.rad(150), 1e-6)
			local _, landed, yaw = Avatar.flight(c.hop - 1e-4, from, math.rad(150))
			expect(landed.Magnitude < 0.05).to.equal(true)
			expect(math.abs(yaw) < 0.01).to.equal(true)
			-- it turns the short way: from 350 degrees it goes on 10, not back 350
			local _, _, short = Avatar.flight((c.hopCrouch + c.hop) / 2, from, math.rad(350))
			expect(short < 0 and short > math.rad(-10)).to.equal(true)
			-- in the air it rises over the higher end
			local _, mid = Avatar.flight((c.hopCrouch + c.hop) / 2, from, 0)
			expect(mid.Y > 0).to.equal(true)
			-- and with no earlier frame it hops on the spot
			local _, still = Avatar.flight(c.hop / 2)
			expect(math.abs(still.X) + math.abs(still.Z) < 1e-6).to.equal(true)
		end)

		it(
			"leaves along the barrel and flies much further, climbing until it meets the cloud",
			function()
				local tilt = math.rad(c.tilt)
				local _, early = Avatar.flight(c.boom + 0.02)
				expect(early.Unit:Dot(Vector3.new(0, math.sin(tilt), -math.cos(tilt))) > 0.999).to.equal(
					true
				)
				local _, a = Avatar.flight(c.gone - 0.02)
				local _, b = Avatar.flight(c.gone - 0.01)
				expect(-b.Z > 150).to.equal(true) -- the old shot went 87 studs out before the clouds
				expect(b.Y > 80).to.equal(true)
				expect(b.Y > a.Y).to.equal(true) -- still rising when it vanishes
				local _, hidden = Avatar.flight((c.gone + c.drop) / 2)
				expect(hidden.Y).to.equal(c.hidden)
				-- nothing jumps from frame to frame faster than the shot itself
				local _, last = Avatar.flight(c.boom)
				for s = c.boom + STEP, c.gone - STEP, STEP do
					local _, at = Avatar.flight(s)
					expect((at - last).Magnitude < c.speed * STEP * 1.05).to.equal(true)
					last = at
				end
			end
		)

		it(
			"rolls over once out of the barrel, slowing, then soars head first the way it flies",
			function()
				local turns = 0
				local _, _, _, lastRoll = Avatar.flight(c.boom)
				local fastest, latest = 0, 0
				for s = c.boom + STEP, c.gone - STEP, STEP do
					local _, _, _, roll = Avatar.flight(s)
					local step = roll - lastRoll
					turns += step
					if s < c.boom + 0.1 then
						fastest = math.max(fastest, step)
					elseif s > c.boom + c.flipFor - 0.1 and s < c.boom + c.flipFor then
						latest = math.max(latest, step)
					end
					lastRoll = roll
				end
				expect(fastest > latest * 3).to.equal(true) -- the roll slows down
				expect(turns / (2 * math.pi)).to.be.near(c.flips + 0.2, 0.25) -- once, plus tipping over head first
				-- soaring: arms ahead, legs back, the body along the way it moves
				local s = c.gone - 0.1
				local pose, at, _, roll = Avatar.flight(s)
				local _, before = Avatar.flight(s - STEP)
				expect(pose.shL).to.be.near(c.poses.soar.sh, 1e-6)
				expect(pose.hipR).to.be.near(c.poses.soar.hip, 1e-6)
				local moving = at - before
				local along = math.atan2(-moving.Z, moving.Y) -- from straight up, tipping forward
				expect((roll - 2 * math.pi * c.flips) - along).to.be.near(0, math.rad(2))
			end
		)

		it("bends round towards the landing pad and leans into the turn", function()
			local left = math.rad(90)
			local _, straight = Avatar.flight(c.gone - 0.01)
			local _, turned, yaw = Avatar.flight(c.gone - 0.01, nil, nil, left)
			expect(math.abs(straight.X) < 1e-6).to.equal(true)
			expect(turned.X < -40).to.equal(true) -- off to the left
			expect(turned.Y).to.be.near(straight.Y, 1e-6) -- the climb is the same
			expect(yaw).to.be.near(left, 1e-6)
			local _, early, startYaw = Avatar.flight(c.boom + c.bendFrom / 2, nil, nil, left)
			local _, plain = Avatar.flight(c.boom + c.bendFrom / 2)
			expect((early - plain).Magnitude < 1e-6).to.equal(true)
			expect(startYaw).to.equal(0)
			local _, _, _, _, _, bank =
				Avatar.flight(c.boom + (c.bendFrom + c.bendTo) / 2, nil, nil, left)
			expect(bank).to.be.near(math.rad(c.bank), 1e-6)
			local _, _, _, _, _, other =
				Avatar.flight(c.boom + (c.bendFrom + c.bendTo) / 2, nil, nil, -left)
			expect(other).to.be.near(-math.rad(c.bank), 1e-6)
			local _, _, _, _, _, none = Avatar.flight(c.boom + (c.bendFrom + c.bendTo) / 2)
			expect(none).to.equal(0)
		end)

		it(
			"comes back from behind the pad feet first along a curve, slowing as it lands",
			function()
				local _, start = Avatar.flight(c.drop)
				expect((start - Vector3.new(0, c.height, c.back)).Magnitude < 1e-6).to.equal(true)
				local last, lastStep = start, math.huge
				for s = c.drop + STEP, c.touch - STEP / 2, STEP do
					local pose, place, yaw, roll = Avatar.flight(s)
					expect(place.Y <= last.Y + 1e-9).to.equal(true)
					expect(place.Z < last.Z).to.equal(true) -- forward over the pad
					expect(yaw).to.equal(0)
					expect(roll).to.equal(0)
					expect(pose.lean < 30).to.equal(true) -- upright, feet first
					local step = (place - last).Magnitude
					if s > (c.drop + c.touch) / 2 then
						expect(step <= lastStep + 1e-9).to.equal(true) -- slowing in the second half
					end
					last, lastStep = place, step
				end
				local pose, place = Avatar.flight(c.touch)
				expect(place.Magnitude < 1e-6).to.equal(true)
				expect(pose.knL).to.be.near(c.poses.land.kn, 1e-6)
				local early = Avatar.flight(c.drop + 0.05)
				expect(early.knL).to.be.near(c.poses.drop.kn, 1e-6)
			end
		)

		it(
			"lands on one knee with a fist down, holds it, then stands, with nothing jerky",
			function()
				local last = Avatar.flight(c.touch)
				for s = c.touch, c.ends, STEP do
					local pose = Avatar.flight(s)
					expect(math.abs(pose.knL - last.knL) < 30).to.equal(true) -- degrees a frame at 60 fps
					expect(math.abs(pose.shR - last.shR) < 30).to.equal(true)
					last = pose
				end
				local kneel = Avatar.flight(c.touch + (c.kneel + c.hold) / 2)
				expect(kneel.knR).to.be.near(c.poses.kneel.knR, 1e-6)
				expect(kneel.hipL > kneel.hipR + 45).to.equal(true) -- one foot planted ahead, the other knee down
				local done = Avatar.flight(c.ends)
				for _, field in { "lean", "air", "hipL", "knR", "shL", "elR" } do
					expect(done[field]).to.be.near(0, 1e-6)
				end
			end
		)

		it("curls into the ball, knees to the chest and the chin tucked", function()
			local ball = Avatar.flight((c.hop + c.boom) / 2)
			expect(ball.hipL > 90 and ball.hipR > 90).to.equal(true)
			expect(ball.knL > 120 and ball.knR > 120).to.equal(true)
			expect(ball.neck < 0).to.equal(true)
			expect(ball.waist > 0).to.equal(true)
		end)
		it("rises into the clouds soaring and spreads out flat into the glide", function()
			local early, below, _, tipped = Avatar.glide(c.gone - 0.5)
			expect(below.Y).to.be.near(-g.below, 1e-6)
			expect(early.shL).to.be.near(c.poses.soar.sh, 1e-6)
			expect(tipped).to.be.near(math.rad(g.pitch), 1e-6)
			local opened = c.gone + g.rise + g.open
			local pose, at, heading, roll, bank = Avatar.glide(opened)
			expect(at.Magnitude < 1e-6).to.equal(true)
			expect(heading).to.be.near(math.rad(g.heading), 1e-6)
			expect(roll).to.equal(0)
			expect(bank).to.equal(0)
			expect(pose.lean).to.be.near(c.poses.spread.lean, 1e-6)
			local _, _, _, rollBefore = Avatar.glide(opened - 0.05)
			expect(rollBefore > 0).to.equal(true) -- still levelling off
		end)

		it("glides flat with a bob and a bank, then drops out of the bottom feet first", function()
			local opened = c.gone + g.rise + g.open
			local banked = 0
			for s = opened, c.drop - g.dive, STEP do
				local pose, at, _, _, bank = Avatar.glide(s)
				expect(pose.lean).to.be.near(c.poses.spread.lean, 1e-6)
				expect(math.abs(at.Y) <= g.bob + 1e-6).to.equal(true)
				banked = math.max(banked, math.abs(bank))
			end
			expect(banked > math.rad(g.bank) * 0.8 and banked <= math.rad(g.bank) + 1e-6).to.equal(
				true
			)
			local last, at = Avatar.glide(c.drop - 1e-3)
			expect(at.Y < -g.below * 0.9).to.equal(true)
			expect(last.knL).to.be.near(c.poses.drop.kn, 1)
			expect((Avatar.glide(c.drop))).to.equal(nil)
		end)

		it("squeezes the rise, the opening and the dive into a shorter staged span", function()
			local span = 0.4
			local squeeze = span / (c.drop - c.gone)
			expect((Avatar.glide(c.gone + span, span))).to.equal(nil)
			local _, below = Avatar.glide(c.gone, span)
			expect(below.Y).to.be.near(-g.below, 1e-6)
			local opened = c.gone + (g.rise + g.open) * squeeze
			local pose, at, _, roll = Avatar.glide(opened, span)
			expect(at.Magnitude < 1e-6).to.equal(true)
			expect(roll).to.equal(0)
			expect(pose.lean).to.be.near(c.poses.spread.lean, 1e-6)
			local last, out = Avatar.glide(c.gone + span - 1e-3, span)
			expect(out.Y < -g.below * 0.9).to.equal(true)
			expect(last.knL).to.be.near(c.poses.drop.kn, 1)
			-- no span, or one as long as the flight's, is the flight's own glide
			local _, a = Avatar.glide(c.gone + 0.5)
			local _, b = Avatar.glide(c.gone + 0.5, c.drop - c.gone)
			expect((a - b).Magnitude < 1e-9).to.equal(true)
			expect((Avatar.glide(c.gone, 0))).to.equal(nil)
		end)

		it("lands the camera a little wide of the player's own view, not right in (#1081)", function()
			local k = Presets.cannonCamera
			expect(k.land > 1 and k.land < k.wide).to.equal(true)
		end)
	end)
end
