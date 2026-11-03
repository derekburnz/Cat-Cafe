--!strict
-- The Cat Cannon flight on the intro's copy of you (F72 shots 1 and 2; Gameplay-Engineer 2026-11-02: the copy hopped
-- into the barrel standing straight and flew the arc in whatever pose it had). The intro moves and spins the copy's
-- root itself and names the beat in StagedFlight ("hop", "ball", "land") with StagedFlightAt; Avatar.stagedSeconds
-- maps that onto the real flight's poses, so the copy hops, curls into the ball and lands like a player. The pose
-- itself on a real character (Avatar.stagedCannon, CannonGlide.staged) is a Studio row.
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Avatar = require(Effects:WaitForChild("Avatar")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.cannonPose
	local STEP = 1 / 60

	local function pose(phase: string, since: number): any
		local seconds = Avatar.stagedSeconds(phase, since)
		if seconds == nil then
			return nil
		end
		return (Avatar.flight(seconds))
	end

	describe("Effects staged cannon flight", function()
		it("hops into the barrel on the real hop's timing, then waits curled up", function()
			expect(Avatar.stagedSeconds("hop", -0.01)).to.equal(nil)
			expect(Avatar.stagedSeconds("hop", 0)).to.equal(0)
			expect(Avatar.stagedSeconds("hop", c.hop / 2)).to.be.near(c.hop / 2, 1e-9)
			expect(Avatar.stagedSeconds("hop", 5)).to.equal(c.hop)
			local crouch = pose("hop", c.hopCrouch)
			expect(crouch.knL).to.be.near(c.poses.hopCrouch.kn, 1e-6)
			local inside = pose("hop", 5)
			expect(inside.hipL).to.be.near(c.poses.ball.hip, 1e-6)
		end)

		it("is the curled-up ball for the arc", function()
			local ball = pose("ball", 0)
			expect(ball.hipL).to.be.near(c.poses.ball.hip, 1e-6)
			expect(ball.knR).to.be.near(c.poses.ball.kn, 1e-6)
			expect(ball.neck < 0).to.equal(true)
			expect(pose("ball", 100).hipL).to.equal(ball.hipL) -- however long the arc
		end)

		it(
			"falls feet first, swings into the landing just before its feet touch and lands on them",
			function()
				local high = pose("land", -1)
				expect(high.knL).to.be.near(c.poses.drop.kn, 1e-6)
				expect(pose("land", -c.open - 0.01).knL).to.be.near(c.poses.drop.kn, 1e-6)
				local opening = pose("land", -c.open / 2)
				expect(opening.hipL > c.poses.drop.hip and opening.hipL < c.poses.land.hip).to.equal(
					true
				)
				local touch = pose("land", 0)
				expect(touch.knL).to.be.near(c.poses.land.kn, 1e-6)
			end
		)

		it("kneels, stands and then lets go", function()
			local last = pose("land", 0)
			for since = 0, c.ends - c.touch, STEP do
				local now = pose("land", since)
				expect(math.abs(now.knL - last.knL) < 30).to.equal(true) -- degrees a frame at 60 fps
				expect(math.abs(now.air - last.air) < 0.2).to.equal(true)
				last = now
			end
			local stood = pose("land", c.ends - c.touch)
			for _, field in { "lean", "air", "hipL", "knR" } do
				expect(stood[field]).to.be.near(0, 1e-6)
			end
			local _, _, _, _, fading =
				Avatar.flight(Avatar.stagedSeconds("land", c.ends - c.touch + c.blendOut / 2))
			expect(fading > 0 and fading < 1).to.equal(true)
			expect(Avatar.stagedSeconds("land", c.ends - c.touch + c.blendOut)).to.equal(nil)
		end)

		it("shows nothing for a beat it does not know", function()
			expect(Avatar.stagedSeconds("glide", 0)).to.equal(nil)
			expect(Avatar.stagedSeconds("", 0)).to.equal(nil)
		end)
	end)
end
