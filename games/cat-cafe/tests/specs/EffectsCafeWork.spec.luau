--!strict
-- Cats make the orders (F90, cats-make-orders.md sections 2 and 6), the Animation-Engineer's part: the Barista's
-- working bob (Logic.makingBob, makingPose; Cats.luau on its local Making attribute), getting up and sitting down at a
-- station (Logic.crouch), the trot with a tray (Logic.gait's level, Logic.trayCarry), the tip sweep (Logic.sweepPose,
-- sweepScoop; Moments.TipSwept) and the drop at the till (Logic.bankNod; Moments.TipBanked). These are pure; the walk
-- holding still for them and the tray hopping onto the head are Studio rows (effects-list "Cafe walks").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local m = Presets.motion.making
	local c = Presets.cafeWalk
	local FRAME = 1 / 60
	local FIELDS = {
		"bodyY",
		"bodyPitch",
		"bodyRoll",
		"headPitch",
		"headYaw",
		"headRoll",
		"tailPitch",
		"tailYaw",
		"pawFL",
		"pawFR",
		"pawBL",
		"pawBR",
	}

	local function same(a: any, b: any): boolean
		for _, field in FIELDS do
			if math.abs(a[field] - b[field]) > 1e-9 then
				return false
			end
		end
		return true
	end

	-- a pose with something in every field, so a layer that zeroes or scales a field shows
	local function busy(): any
		local o = Logic.blank()
		for i, field in FIELDS do
			o[field] = 0.01 * i
		end
		return o
	end

	describe("Effects Barista working bob (F90)", function()
		it("hops twice and tilts its head once each loop, the tilt the other way the next loop", function()
			expect(m.hops).to.equal(2)
			expect(m.hops * m.hopSeconds + m.tiltGap + m.tiltSeconds <= m.seconds).to.equal(true)
			for loop = 0, 1 do
				local peaks, before, now = 0, 0, 0
				local most = 0
				for t = loop * m.seconds, (loop + 1) * m.seconds - 1e-6, 0.002 do
					local lift, tilt = Logic.makingBob(t)
					expect(lift >= 0 and lift <= m.height + 1e-9).to.equal(true)
					if math.abs(tilt) > math.abs(most) then
						most = tilt
					end
					if now > before and now > lift then
						peaks += 1
					end
					before, now = now, lift
				end
				expect(peaks).to.equal(m.hops)
				expect(math.abs(most)).to.be.near(math.rad(m.tilt), 1e-3)
				expect(most > 0).to.equal(loop == 0)
			end
			local lift, tilt = Logic.makingBob(-1)
			expect(lift).to.equal(0)
			expect(tilt).to.equal(0)
		end)

		it("moves with no jumps at 60 frames a second", function()
			local lastLift, lastTilt = Logic.makingBob(0)
			for t = FRAME, 3 * m.seconds, FRAME do
				local lift, tilt = Logic.makingBob(t)
				expect(math.abs(lift - lastLift) < m.height * 0.3).to.equal(true)
				expect(math.abs(tilt - lastTilt) < math.rad(m.tilt) * 0.15).to.equal(true)
				lastLift, lastTilt = lift, tilt
			end
		end)

		it("leaves the pose alone at weight 0, drops the paw tap for the bob, and keeps only the tilt with Reduce Motion", function()
			local o = busy()
			Logic.makingPose(o, 0.1, 0, false)
			expect(same(o, busy())).to.equal(true)
			-- a quarter into the first hop: lifted, paws up a touch, the idle's head dip and paw tap gone
			local t = m.hopSeconds / 2
			local lift = Logic.makingBob(t)
			local full = busy()
			Logic.makingPose(full, t, 1, false)
			expect(full.bodyY).to.be.near(busy().bodyY + lift, 1e-9)
			expect(full.pawFL).to.be.near(math.rad(m.paws), 1e-9)
			expect(full.headPitch).to.be.near(0, 1e-9)
			local still = busy()
			Logic.makingPose(still, t, 1, true)
			expect(still.bodyY).to.be.near(busy().bodyY, 1e-9)
			-- in the tilt the head tips either way
			local tiltAt = m.hops * m.hopSeconds + m.tiltGap + m.tiltSeconds / 2
			local tilted = busy()
			Logic.makingPose(tilted, tiltAt, 1, true)
			expect(tilted.headRoll - busy().headRoll).to.be.near(math.rad(m.tilt), 1e-6)
			expect(m.ease > 0 and m.ease <= 0.5).to.equal(true)
		end)
	end)

	describe("Effects station cats getting up and sitting down (F90)", function()
		it("crouches into a sit with the back legs tucked and the front legs kept upright", function()
			local o = busy()
			Logic.crouch(o, 0)
			expect(same(o, busy())).to.equal(true)
			local down = Logic.blank()
			Logic.crouch(down, 1)
			expect(down.bodyY).to.be.near(-c.sit.drop, 1e-9)
			expect(down.bodyPitch).to.be.near(math.rad(c.sit.pitch), 1e-9)
			expect(down.pawFL + down.bodyPitch).to.be.near(0, 1e-9)
			expect(down.pawBL > 0 and down.pawBR > 0).to.equal(true)
			expect(down.tailPitch < 0).to.equal(true)
			local half = Logic.blank()
			Logic.crouch(half, 0.5)
			expect(half.bodyY).to.be.near(-c.sit.drop / 2, 1e-9)
		end)

		it("fits the cross-fade inside the rise, so the seated cat is gone before the copy stands", function()
			expect(c.sit.rise >= c.fade).to.equal(true)
			expect(c.sit.rise <= 0.8).to.equal(true)
			expect(c.sit.drop > 0 and c.sit.drop < 0.3).to.equal(true)
		end)
	end)

	describe("Effects trot with a tray (F90)", function()
		it("keeps the head from nodding with the steps under a tray and bobs half as much", function()
			local speed = Presets.motion.gait.trotFull + 1
			local free: { number } = {}
			local steady: { number } = {}
			local freeBob, steadyBob = 0, 0
			for stride = 0, 1, 0.05 do
				local a = Logic.blank()
				Logic.gait(a, speed, stride)
				local b = Logic.blank()
				Logic.gait(b, speed, stride, 1)
				table.insert(free, a.headPitch)
				table.insert(steady, b.headPitch)
				freeBob = math.max(freeBob, a.bodyY)
				steadyBob = math.max(steadyBob, b.bodyY)
			end
			local function spread(values: { number }): number
				return math.max(table.unpack(values)) - math.min(table.unpack(values))
			end
			expect(spread(free) > math.rad(1)).to.equal(true)
			expect(spread(steady)).to.be.near(0, 1e-9)
			expect(steadyBob).to.be.near(freeBob / 2, 1e-9)
			-- no level is the same as level 0
			local a, b = Logic.blank(), Logic.blank()
			Logic.gait(a, speed, 0.3)
			Logic.gait(b, speed, 0.3, 0)
			expect(same(a, b)).to.equal(true)
		end)

		it("carries with its chin up, eyes front and tail high", function()
			local o = busy()
			Logic.trayCarry(o, 0)
			expect(same(o, busy())).to.equal(true)
			local carried = busy()
			Logic.trayCarry(carried, 1)
			expect(carried.headPitch).to.be.near(busy().headPitch + math.rad(c.carry.chin), 1e-9)
			expect(carried.headYaw).to.equal(0)
			expect(carried.headRoll).to.equal(0)
			expect(carried.tailPitch).to.be.near(busy().tailPitch + math.rad(c.carry.tail), 1e-9)
			expect(c.carry.ease > 0 and c.carry.ease <= 0.5).to.equal(true)
		end)
	end)

	describe("Effects tip sweep and till drop (F90)", function()
		it("rears up, drags the right paw in the set number of times and is back on all fours at the end", function()
			local s = c.sweep
			for _, alpha in { -0.1, 0, 1, 1.1 } do
				local o = busy()
				Logic.sweepPose(o, alpha)
				expect(same(o, busy())).to.equal(true)
			end
			local mid = Logic.blank()
			Logic.sweepPose(mid, (s.up + s.down) / 2)
			expect(mid.bodyPitch).to.be.near(math.rad(s.rear), 1e-9)
			expect(mid.pawFL).to.be.near(math.rad(s.reach), 1e-9)
			-- the paw is pulled in `swipes` times between rearing up and dropping back down
			local pulls, before, now = 0, 0, 0
			for alpha = s.up, s.down, 0.001 do
				local o = Logic.blank()
				Logic.sweepPose(o, alpha)
				local drag = math.rad(s.reach) - o.pawFR
				if now > before and now > drag then
					pulls += 1
				end
				before, now = now, drag
			end
			expect(pulls).to.equal(s.swipes)
			expect(0 < s.up and s.up < s.down and s.down < 1).to.equal(true)
		end)

		it("moves with no jumps at 60 frames a second", function()
			local step = FRAME / c.sweep.seconds
			local last = Logic.blank()
			for alpha = step, 1 + step, step do
				local o = Logic.blank()
				Logic.sweepPose(o, alpha)
				for _, field in FIELDS do
					expect(math.abs(o[field] - last[field]) < 0.25).to.equal(true)
				end
				last = o
			end
		end)

		it("hops the coin bag from the pile onto the head in an arc while the cat comes down", function()
			local s = c.sweep
			local share, arc = Logic.sweepScoop(0)
			expect(share).to.equal(0)
			expect(arc).to.equal(0)
			share, arc = Logic.sweepScoop(s.scoop)
			expect(share).to.equal(0)
			share, arc = Logic.sweepScoop(s.land)
			expect(share).to.equal(1)
			expect(arc).to.equal(0)
			share, arc = Logic.sweepScoop((s.scoop + s.land) / 2)
			expect(share).to.be.near(0.5, 1e-9)
			expect(arc).to.be.near(s.arc, 1e-9)
			local last = 0
			for alpha = 0, 1, 0.01 do
				local now = Logic.sweepScoop(alpha)
				expect(now >= last).to.equal(true)
				last = now
			end
			expect(s.scoop < s.land and s.land < 1).to.equal(true)
			expect(s.seconds > 0.5 and s.seconds < 2).to.equal(true)
		end)

		it("dips toward the till and comes back up", function()
			local b = c.bank
			for _, alpha in { 0, 1 } do
				local o = busy()
				Logic.bankNod(o, alpha)
				expect(same(o, busy())).to.equal(true)
			end
			local o = Logic.blank()
			Logic.bankNod(o, 0.5)
			expect(o.headPitch).to.be.near(-math.rad(b.nod), 1e-9)
			expect(o.bodyPitch).to.be.near(-math.rad(b.lean), 1e-9)
			expect(b.seconds > 0 and b.seconds < 1).to.equal(true)
		end)
	end)
end
