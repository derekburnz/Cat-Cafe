--!strict
-- The Bellhop Cat's five animations (F96, starter-cat.md section 1, on Model-Agent's #708 cap and bell hinges): the
-- bell ring, the cap tip, the bow when it is placed, the sleepy cap asleep and the happy hop when it is claimed.
-- The poses (Logic.bellRing, capTip, bow, happyHop), the leap's path (Logic.hopArc) and the sleep test are pure; the
-- cap and bell turning on the model, the stand's copy, the customer greeting and the hop to the player are Studio rows
-- (effects-list "Bellhop Cat").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local b = Presets.bellhop

	local function near(a: Vector3, c: Vector3): boolean
		return (a - c).Magnitude < 1e-6
	end

	local function layered(fn: string, alpha: number): any
		local o = Logic.blank()
		o.tailYaw = 0.3
		o.earL = 0.2
		Logic[fn](o, alpha)
		return o
	end

	describe("Effects Bellhop Cat poses", function()
		it("starts every cat with its cap and bell at rest, and blends them like any offset", function()
			local o = Logic.blank()
			expect(o.capTip).to.equal(0)
			expect(o.capDown).to.equal(0)
			expect(o.bell).to.equal(0)
			local asleep = Logic.blank()
			asleep.capDown = 1
			expect(Logic.mix(o, asleep, 0.25).capDown).to.be.near(0.25, 1e-9)
		end)

		it("pulls the cap down only asleep", function()
			expect(Logic.asleep("nap")).to.equal(true)
			expect(Logic.asleep("doze")).to.equal(true)
			for _, style in { "sit", "greeter", "waiter", "lick", "loaf", "stray" } do
				expect(Logic.asleep(style)).to.equal(false)
			end
			expect(b.sleepCap.turn).to.equal(-40) -- Model-Agent's numbers for #708
			expect(b.sleepCap.down).to.equal(0.17)
			expect(b.sleepCap.forward).to.equal(0.3)
		end)

		it("rings: the bell swings both ways and dies away, after a quick shake of the head", function()
			local most, least = 0, 0
			for alpha = 0, 0.999, 0.01 do
				local o = layered("bellRing", alpha)
				most = math.max(most, o.bell)
				least = math.min(least, o.bell)
				if alpha >= b.ring.shakeSeconds / b.ring.seconds then
					expect(o.headRoll).to.equal(0)
				end
			end
			expect(most > math.rad(b.ring.degrees) * 0.5).to.equal(true)
			expect(least < -math.rad(b.ring.degrees) * 0.4).to.equal(true)
			expect(math.abs(layered("bellRing", 0.95).bell) < math.rad(b.ring.degrees) * 0.01).to.equal(
				true
			)
			expect(layered("bellRing", 0).bell).to.be.near(0, 1e-9)
			for _, alpha in { -0.1, 1, 2 } do
				local o = layered("bellRing", alpha)
				expect(o.bell).to.equal(0)
				expect(o.headRoll).to.equal(0)
			end
		end)

		it("tips the cap up at the front with a nod, holds it and settles back", function()
			local top = layered("capTip", 0.4)
			expect(top.capTip).to.be.near(math.rad(b.tip.degrees), 1e-9)
			expect(top.headPitch).to.be.near(-math.rad(b.tip.nod), 1e-9)
			for _, alpha in { -0.5, 0, 1, 1.5 } do
				local o = layered("capTip", alpha)
				expect(o.capTip).to.equal(0)
				expect(o.headPitch).to.equal(0)
			end
		end)

		it("bows forward with its head down and sits back up", function()
			local low = layered("bow", 0.5)
			expect(low.bodyPitch).to.be.near(-math.rad(b.bow.lean), 1e-9)
			expect(low.headPitch).to.be.near(-math.rad(b.bow.head), 1e-9)
			expect(low.capTip).to.be.near(math.rad(b.bow.cap), 1e-9)
			expect(low.tailYaw).to.be.near(0, 1e-9)
			local up = layered("bow", 1)
			expect(up.bodyPitch).to.equal(0)
			expect(up.tailYaw).to.equal(0.3)
		end)

		it("bounces where it sits, then leaps nose and tail up with its paws reaching", function()
			local bounce = layered("happyHop", b.hop.bounce / 2)
			expect(bounce.bodyY).to.be.near(b.hop.bounceHeight, 1e-9)
			expect(bounce.pawFL).to.equal(0)
			local leap = layered("happyHop", b.hop.bounce + (1 - b.hop.bounce) / 2)
			expect(leap.bodyY).to.equal(0) -- the leap's height is the path's (Logic.hopArc)
			expect(leap.bodyPitch).to.be.near(math.rad(b.hop.lean), 1e-9)
			expect(leap.tailPitch).to.be.near(math.rad(b.hop.tailUp), 1e-9)
			expect(leap.pawFL > 0 and leap.pawFR > 0).to.equal(true)
			expect(leap.earL).to.be.near(0, 1e-9) -- ears pricked
			for _, alpha in { -0.1, 1 } do
				local o = layered("happyHop", alpha)
				expect(o.bodyY).to.equal(0)
				expect(o.earL).to.equal(0.2)
			end
		end)

		it("moves with no jumps at 60 frames a second, through the bounce into the leap", function()
			local step = 1 / (60 * b.hop.seconds)
			local last = layered("happyHop", 0)
			for alpha = step, 1 - step, step do
				local o = layered("happyHop", alpha)
				expect(math.abs(o.bodyY - last.bodyY) < 0.15).to.equal(true)
				expect(math.abs(o.tailPitch - last.tailPitch) < math.rad(15)).to.equal(true)
				expect(math.abs(o.pawFL - last.pawFL) < math.rad(15)).to.equal(true)
				last = o
			end
		end)

		it("leaps from the cart to you in an arc and lands where it aims", function()
			local from = Vector3.new(0, 2.6, 0)
			local to = Vector3.new(4, 2.4, -6)
			expect(near(Logic.hopArc(from, to, 3, 0), from)).to.equal(true)
			expect(near(Logic.hopArc(from, to, 3, 1), to)).to.equal(true)
			local middle = Logic.hopArc(from, to, 3, 0.5)
			expect(near(middle, (from + to) / 2 + Vector3.new(0, 3, 0))).to.equal(true)
			expect(near(Logic.hopArc(from, to, 3, -1), from)).to.equal(true)
			expect(near(Logic.hopArc(from, to, 3, 2), to)).to.equal(true)
		end)

		it("rings the stand every 8 to 12 seconds and greets customers close by", function()
			expect(b.every[1]).to.equal(8)
			expect(b.every[2]).to.equal(12)
			expect(b.ring.seconds < b.every[1] and b.gap >= b.ring.seconds).to.equal(true)
			expect(b.tipAfter >= b.ring.shakeSeconds and b.tipAfter < b.ring.seconds + 1).to.equal(true)
			expect(b.greet > 0 and b.greet < b.walkUp).to.equal(true)
		end)
	end)
end
