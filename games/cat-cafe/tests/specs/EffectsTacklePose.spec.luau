--!strict
-- The Tackle's character poses (design v0.11, F74; Derek 2026-10-27: the Shove becomes a Tackle): which pose a
-- character is in from its tackle times. Avatar.bind and Avatar.solve need a real R15 character, so they are
-- checked in Studio. Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Avatar = require(Effects:WaitForChild("Avatar")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local p = Presets.tacklePose
	local timing = {
		lunge = p.lunge,
		grace = p.grace,
		hitRecover = p.hitRecover,
		missRecover = p.missRecover,
		push = p.push,
		down = p.down,
	}

	describe("Effects tackle poses", function()
		it("fills both sides from one key and leaves the rest standing", function()
			local pose = Avatar.pose({ sh = 40, hipL = 10, hip = 5 })
			expect(pose.shL).to.equal(40)
			expect(pose.shR).to.equal(40)
			expect(pose.hipL).to.equal(10)
			expect(pose.hipR).to.equal(5)
			expect(pose.lean).to.equal(0)
			expect(pose.knL).to.equal(0)
		end)

		it("dives forward with the arms out ahead, then lands flat on its belly", function()
			local start, mid, done = Avatar.dive(0), Avatar.dive(0.5), Avatar.dive(1)
			expect(start.lean).to.equal(0)
			expect(mid.lean > 30).to.equal(true)
			expect(done.lean > 75).to.equal(true)
			expect(done.shL > 150 and done.shR > 150).to.equal(true)
			expect(done.air > 0).to.equal(true) -- still in the air
			local down = Avatar.landing(p.land)
			expect(down.lean).to.be.near(90, 1e-6)
			expect(down.air < 0.1).to.equal(true)
		end)

		it("plays a miss: the dive, the landing, the slide and the get up", function()
			local times = { tackleAt = 10, missAt = 10 + p.lunge + p.grace }
			local dive, w = Avatar.at(times, 10.2, timing)
			expect(dive.lean > 30).to.equal(true)
			expect(w).to.equal(1)
			local landing = Avatar.at(times, 10 + p.lunge + 0.2, timing)
			expect(landing.lean).to.be.near(90, 1e-6)
			local slide = Avatar.at(times, times.missAt + 0.2 * p.missRecover, timing)
			expect(math.abs(slide.lean - 90) < 1e-6).to.equal(true)
			local up, upWeight = Avatar.at(times, times.missAt + 0.99 * p.missRecover, timing)
			expect(up.lean < 5).to.equal(true)
			expect(upWeight < 1).to.equal(true) -- easing back into the character's own animation
			expect(Avatar.at(times, times.missAt + p.missRecover + 0.01, timing)).to.equal(nil)
		end)

		it("gets up after a miss even when TackleMissAt never arrives", function()
			local times = { tackleAt = 10 }
			local late = 10 + p.lunge + p.grace + p.lost + 0.1
			local pose = Avatar.at(times, late, timing)
			expect(pose).never.to.equal(nil)
			expect(Avatar.at(times, 10 + p.lunge + p.grace + p.missRecover + 0.01, timing)).to.equal(
				nil
			)
		end)

		it("stumbles to a stop after a hit and is up when the hit's stand-up time ends", function()
			local times = { tackleAt = 10, hitAt = 10.15 }
			local stumble = Avatar.at(times, 10.15 + 0.25 * p.hitRecover, timing)
			expect(stumble.hipL > 30 and stumble.hipR < 0).to.equal(true) -- one foot out ahead to catch itself
			expect(stumble.lean < 45).to.equal(true)
			expect(Avatar.at(times, 10.15 + p.hitRecover + 0.01, timing)).to.equal(nil)
		end)

		it("throws a tackled player down on its back or front, then up", function()
			local total = p.push + p.down
			local back = Avatar.at({ shovedAt = 5 }, 5 + 0.45 * total, timing)
			expect(back.lean).to.be.near(-90, 1e-6)
			local front = Avatar.at({ shovedAt = 5, fallForward = true }, 5 + 0.45 * total, timing)
			expect(front.lean).to.be.near(90, 1e-6)
			local tipped = Avatar.at({ shovedAt = 5, side = 1 }, 5 + 0.45 * total, timing)
			expect(tipped.roll).to.be.near(p.sideRoll, 1e-6)
			local _, w, began, still = Avatar.at({ shovedAt = 5 }, 5 + 0.5 * total, timing)
			expect(w).to.equal(1)
			expect(began).to.equal(5)
			expect(still).to.be.near(5 + p.push, 1e-9) -- held still once the push is over
			expect(Avatar.at({ shovedAt = 5 }, 5 + total + 0.01, timing)).to.equal(nil)
		end)

		it("lets a tackle that lands on a diving player win over its own dive", function()
			local pose = Avatar.at(
				{ tackleAt = 10, shovedAt = 10.1 },
				10.1 + 0.45 * (p.push + p.down),
				timing
			)
			expect(pose.lean).to.be.near(-90, 1e-6)
		end)

		it("eases a pose in from what the character was playing", function()
			local _, w0 = Avatar.at({ shovedAt = 5 }, 5, timing)
			local _, w1 = Avatar.at({ shovedAt = 5 }, 5 + p.blendIn / 2, timing)
			expect(w0).to.equal(0)
			expect(w1 > 0 and w1 < 1).to.equal(true)
		end)
	end)
end
