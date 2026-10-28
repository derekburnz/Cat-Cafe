--!strict
-- The Cat Cannon flight (F84, hometown-cannon.md section 3b): where the body is and how it is posed through the
-- three seconds from CannonLaunchAt, and the flyer in the cloud cutscene (Derek 2026-10-28 13:56). Avatar.cannon,
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
			expect(c.gone).to.equal(1.4)
			expect(c.drop).to.equal(2.4)
			expect(c.ends).to.equal(3)
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

		it("leaves along the barrel, climbing and rolling, then waits out of sight", function()
			local tilt = math.rad(c.tilt)
			local _, early = Avatar.flight(c.boom + 0.02)
			expect(early.Unit:Dot(Vector3.new(0, math.sin(tilt), -math.cos(tilt))) > 0.999).to.equal(
				true
			)
			local _, a, _, rollA = Avatar.flight(c.gone - 0.02)
			local _, b, _, rollB = Avatar.flight(c.gone - 0.01)
			expect(a.Y > 40).to.equal(true)
			expect(b.Y > a.Y).to.equal(true) -- still rising when it vanishes
			expect(rollB > rollA).to.equal(true)
			local _, hidden = Avatar.flight((c.gone + c.drop) / 2)
			expect(hidden.Y).to.equal(c.hidden)
		end)

		it("falls onto the pad faster and faster and arrives upright", function()
			local last, fell = math.huge, 0
			for s = c.drop, c.touch - STEP, STEP do
				local _, place = Avatar.flight(s)
				expect(place.Y < last).to.equal(true)
				if last < math.huge then
					expect(last - place.Y >= fell - 1e-9).to.equal(true)
					fell = last - place.Y
				end
				last = place.Y
			end
			local _, start = Avatar.flight(c.drop)
			expect(start.Y).to.be.near(c.dropHeight, 1e-6)
			local pose, place, _, roll = Avatar.flight(c.touch)
			expect(place.Magnitude < 1e-6).to.equal(true)
			expect(roll).to.equal(0)
			expect(pose.knL).to.be.near(c.poses.land.kn, 1e-6)
		end)

		it("crouches, bounces up and stands at the end, with nothing jerky", function()
			local highest = 0
			local last = Avatar.flight(c.touch)
			for s = c.touch, c.ends, STEP do
				local pose = Avatar.flight(s)
				highest = math.max(highest, pose.air)
				expect(math.abs(pose.knL - last.knL) < 30).to.equal(true) -- degrees a frame at 60 fps
				expect(math.abs(pose.air - last.air) < 0.2).to.equal(true)
				last = pose
			end
			expect(highest).to.be.near(c.bounce, 0.05)
			local done = Avatar.flight(c.ends)
			for _, field in { "lean", "air", "hipL", "knR", "shL", "elR" } do
				expect(done[field]).to.be.near(0, 1e-6)
			end
		end)

		it("curls into the ball, knees to the chest and the chin tucked", function()
			local ball = Avatar.flight((c.hop + c.boom) / 2)
			expect(ball.hipL > 90 and ball.hipR > 90).to.equal(true)
			expect(ball.knL > 120 and ball.knR > 120).to.equal(true)
			expect(ball.neck < 0).to.equal(true)
			expect(ball.waist > 0).to.equal(true)
		end)
		it("rises into the clouds as the ball and opens out upright into the glide", function()
			local early, below = Avatar.glide(c.gone - 0.5)
			expect(below.Y).to.be.near(-g.below, 1e-6)
			expect(early.hipL).to.be.near(c.poses.ball.hip, 1e-6)
			local opened = c.gone + g.rise + g.open
			local pose, at, heading, roll, bank = Avatar.glide(opened)
			expect(at.Magnitude < 1e-6).to.equal(true)
			expect(heading).to.be.near(math.rad(g.heading), 1e-6)
			expect(roll).to.equal(0)
			expect(bank).to.equal(0)
			expect(pose.lean).to.be.near(c.poses.spread.lean, 1e-6)
			local _, _, _, rollBefore = Avatar.glide(opened - 0.05)
			expect(rollBefore < 0).to.equal(true) -- still coming round
		end)

		it("glides flat with a bob and a bank, then tucks and dives out of the bottom", function()
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
			expect(last.knL).to.be.near(c.poses.ball.kn, 1)
			expect((Avatar.glide(c.drop))).to.equal(nil)
		end)
	end)
end
