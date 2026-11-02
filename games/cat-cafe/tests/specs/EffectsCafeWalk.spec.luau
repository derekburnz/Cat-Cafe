--!strict
-- Cafe cats on the move (Derek 2026-10-29 19:45: "make the cats move around cafe not just waddle back and fourth
-- while sitting"): a seated waiter keeps its body still and watches the room, and now and then gets up and walks
-- (CafeWalk.luau) onto a lane, along it to a chair's Approach point, and back. Logic.idle's waiter style and the
-- route helpers (Logic.strollRoute, routeLength, along, yawOf, turnToward) are pure; the walk itself (the copy on
-- the walking body, the fades, the rate tag riding along) is a Studio row (effects-list "Cafe walks").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local w = Presets.motion.waiter
	local c = Presets.cafeWalk

	local function near(a: Vector3, b: Vector3): boolean
		return (a - b).Magnitude < 1e-6
	end

	-- the way a model turned `yaw` about Y looks (its -Z), as CFrame.Angles(0, yaw, 0).LookVector
	local function look(yaw: number): Vector3
		return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	end

	describe("Effects waiter at its station", function()
		it("keeps its body still instead of rocking from side to side, only breathing", function()
			local breathe = Presets.motion.breathe
			for t = 0, 2 * w.lookSeconds, 0.05 do
				local o = Logic.idle("waiter", t, "sit")
				local breath = (math.sin(t * 2 * math.pi / breathe.seconds) * 0.5 + 0.5)
					* breathe.studs
				expect(o.bodyRoll).to.equal(0)
				expect(o.bodyY).to.be.near(breath, 1e-9) -- no little hop on each sway any more
				expect(o.bodyPitch).to.equal(0)
			end
		end)

		it("turns its head from table to table and tilts it now and then", function()
			local most, least, tilted = 0, 0, 0
			for t = 0, 2 * w.lookSeconds, 0.05 do
				local o = Logic.idle("waiter", t, "sit")
				expect(math.abs(o.headYaw) <= math.rad(w.look) + 1e-9).to.equal(true)
				expect(math.abs(o.headRoll) <= math.rad(w.tilt) + 1e-9).to.equal(true)
				most = math.max(most, o.headYaw)
				least = math.min(least, o.headYaw)
				tilted = math.max(tilted, o.headRoll)
			end
			expect(most > math.rad(w.look) * 0.9).to.equal(true)
			expect(least < -math.rad(w.look) * 0.9).to.equal(true)
			expect(tilted > math.rad(w.tilt) * 0.5).to.equal(true)
		end)

		it("moves its head smoothly", function()
			local step = 1 / 240
			local last = Logic.idle("waiter", 0, "sit")
			for i = 1, math.floor(2 * w.lookSeconds / step) do
				local o = Logic.idle("waiter", i * step, "sit")
				expect(math.abs(o.headYaw - last.headYaw) < math.rad(0.5)).to.equal(true)
				expect(math.abs(o.headRoll - last.headRoll) < math.rad(1)).to.equal(true)
				last = o
			end
		end)
	end)

	describe("Effects cafe walk routes", function()
		-- a right-hand table's chair: the lane runs along +X at z 0.9 from the aisle (x 2) to the chair (x 8.5)
		local aisle = Vector3.new(2, 0, 0.9)
		local approach = Vector3.new(8.5, 0, 0.9)

		it("goes square onto the lane, then along it to the chair, never across a table", function()
			local station = Vector3.new(4.5, 3, -2.5)
			local route = Logic.strollRoute(station, aisle, approach)
			expect(#route).to.equal(2)
			expect(near(route[1], Vector3.new(4.5, 3, 0.9))).to.equal(true)
			expect(near(route[2], Vector3.new(8.5, 3, 0.9))).to.equal(true)
			-- the first leg is square to the lane
			expect(math.abs((route[1] - station):Dot(approach - aisle))).to.be.near(0, 1e-9)
		end)

		it("keeps every point at the station's height, the cafe floor", function()
			local station = Vector3.new(-4.5, 2.25, -2.5)
			local route =
				Logic.strollRoute(station, Vector3.new(-2, 7, -5.4), Vector3.new(-11, 7, -5.4))
			for _, point in route do
				expect(point.Y).to.equal(2.25)
			end
			expect(near(route[1], Vector3.new(-4.5, 2.25, -5.4))).to.equal(true)
		end)

		it(
			"joins the lane no nearer the middle than the aisle and no further than the chair",
			function()
				local before = Logic.strollRoute(Vector3.new(0, 0, -2.5), aisle, approach)
				expect(near(before[1], aisle)).to.equal(true)
				local past = Logic.strollRoute(Vector3.new(12, 0, -2.5), aisle, approach)
				expect(#past).to.equal(1) -- in line with the chair already: straight there
				expect(near(past[1], approach)).to.equal(true)
			end
		)

		it("walks straight along the lane from a station already on it", function()
			local route = Logic.strollRoute(Vector3.new(4.6, 0, 1), aisle, approach)
			expect(#route).to.equal(1)
			expect(near(route[1], approach)).to.equal(true)
		end)

		it("measures a route leg by leg", function()
			local points = { Vector3.new(0, 0, 0), Vector3.new(0, 0, -3), Vector3.new(4, 0, -3) }
			expect(Logic.routeLength(points)).to.be.near(7, 1e-9)
			expect(Logic.routeLength({ Vector3.new(1, 2, 3) })).to.equal(0)
		end)

		it(
			"follows the route at a distance, turning at the corner, and says when it has arrived",
			function()
				local points =
					{ Vector3.new(0, 0, 0), Vector3.new(0, 0, -3), Vector3.new(4, 0, -3) }
				local at, way, arrived = Logic.along(points, 1)
				expect(near(at, Vector3.new(0, 0, -1))).to.equal(true)
				expect(near(way, Vector3.new(0, 0, -1))).to.equal(true)
				expect(arrived).to.equal(false)
				at, way, arrived = Logic.along(points, 5)
				expect(near(at, Vector3.new(2, 0, -3))).to.equal(true)
				expect(near(way, Vector3.new(1, 0, 0))).to.equal(true)
				expect(arrived).to.equal(false)
				at, way, arrived = Logic.along(points, 99)
				expect(near(at, Vector3.new(4, 0, -3))).to.equal(true)
				expect(near(way, Vector3.new(1, 0, 0))).to.equal(true) -- still facing the way it came
				expect(arrived).to.equal(true)
				at = Logic.along(points, -2)
				expect(near(at, points[1])).to.equal(true)
			end
		)

		it("steps over a point given twice and arrives at once on a route of one point", function()
			local points = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 0), Vector3.new(2, 0, 0) }
			local at, way, arrived = Logic.along(points, 1)
			expect(near(at, Vector3.new(1, 0, 0))).to.equal(true)
			expect(near(way, Vector3.new(1, 0, 0))).to.equal(true)
			expect(arrived).to.equal(false)
			local still, _, done = Logic.along({ Vector3.new(5, 0, 5) }, 0)
			expect(near(still, Vector3.new(5, 0, 5))).to.equal(true)
			expect(done).to.equal(true)
		end)

		it("faces a model along the way it walks", function()
			for _, way in
				{
					Vector3.new(0, 0, -1),
					Vector3.new(1, 0, 0),
					Vector3.new(0, 0, 1),
					Vector3.new(-3, 0, 4),
				}
			do
				expect(near(look(Logic.yawOf(way)), way.Unit)).to.equal(true)
			end
			expect(Logic.yawOf(Vector3.new(0, 0, -1))).to.equal(0)
		end)

		it("turns the short way round, at most a step at a time, and stops on the mark", function()
			local step = math.rad(10)
			expect(Logic.turnToward(0, math.rad(5), step)).to.be.near(math.rad(5), 1e-9)
			expect(Logic.turnToward(0, math.rad(90), step)).to.be.near(step, 1e-9)
			expect(Logic.turnToward(0, -math.rad(90), step)).to.be.near(-step, 1e-9)
			-- from just short of a half turn one way to just past it the other: across the back, not all the way round
			local from, to = math.rad(170), -math.rad(170)
			local turned = Logic.turnToward(from, to, step)
			expect(turned).to.be.near(math.rad(180), 1e-9)
			local yaw = from
			for _ = 1, 3 do
				yaw = Logic.turnToward(yaw, to, step)
			end
			expect(yaw).to.equal(to)
		end)

		it(
			"walks at a waiter's pace, a few times a minute at most and a couple at a time",
			function()
				expect(c.speed > 1 and c.speed < 6).to.equal(true)
				expect(c.every[1] >= 10 and c.every[1] < c.every[2]).to.equal(true)
				expect(c.pause[1] > 0 and c.pause[1] < c.pause[2]).to.equal(true)
				expect(c.fade > 0 and c.fade <= 0.5).to.equal(true)
				expect(c.most >= 1 and c.most <= 3).to.equal(true)
				expect(c.reach > 0 and c.range > c.reach).to.equal(true)
			end
		)
	end)
end
