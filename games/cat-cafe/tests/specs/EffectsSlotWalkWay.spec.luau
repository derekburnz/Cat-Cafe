--!strict
-- The way a moved cafe cat's copy walks to its new spot (#2050, Desktop-Tester 2026-11-07: walkers drawn at the
-- world origin and far below the floor). A found way is taken only while it stays near the straight line and the
-- floor. The walk on screen is a Studio row.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local s = Presets.slotWalk
	local from = Vector3.new(-31, 2, -67)
	local to = Vector3.new(-10, 2, -60)

	describe("slot walk way", function()
		it("measures across the floor to the nearest point of the segment", function()
			expect(
				math.abs(
					Logic.flatDistanceToSegment(
						Vector3.new(0, 50, 3),
						Vector3.zero,
						Vector3.new(10, 0, 0)
					) - 3
				) < 1e-6
			).to.equal(true)
			expect(
				math.abs(
					Logic.flatDistanceToSegment(
						Vector3.new(-4, 0, 3),
						Vector3.zero,
						Vector3.new(10, 0, 0)
					) - 5
				) < 1e-6
			).to.equal(true)
			expect(
				Logic.flatDistanceToSegment(
					Vector3.new(2, 0, 2),
					Vector3.new(2, 0, 2),
					Vector3.new(2, 0, 2)
				)
			).to.equal(0)
		end)
		it("takes a way round a table", function()
			local way = { Vector3.new(-25, 2.4, -70), Vector3.new(-15, 1.8, -66), to }
			expect(Logic.walkableWay(way, from, to, s.detour, s.waypointRise)).to.equal(true)
		end)
		it("throws away a waypoint at the world origin or far below the floor", function()
			expect(
				Logic.walkableWay({ Vector3.new(0, 2, 0), to }, from, to, s.detour, s.waypointRise)
			).to.equal(false)
			expect(
				Logic.walkableWay(
					{ Vector3.new(-20, -1e6, -64), to },
					from,
					to,
					s.detour,
					s.waypointRise
				)
			).to.equal(false)
		end)
		it("throws away a waypoint that is not a number, and an empty way", function()
			local nan = 0 / 0
			expect(
				Logic.walkableWay(
					{ Vector3.new(nan, 2, -64), to },
					from,
					to,
					s.detour,
					s.waypointRise
				)
			).to.equal(false)
			expect(Logic.walkableWay({}, from, to, s.detour, s.waypointRise)).to.equal(false)
		end)
		it("waits a moment for a way, then walks straight", function()
			expect(s.planWait > 0 and s.planWait < s.maxSeconds).to.equal(true)
		end)
	end)
end
