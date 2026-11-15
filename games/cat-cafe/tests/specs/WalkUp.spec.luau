--!strict
-- shared/WalkUp.luau (#2398): walking up to a station opens its window once, walking away closes it, nothing opens
-- over a catch or another window, and the edge never flickers.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local WalkUp = require(Shared.WalkUp)

	local function at(key: string, distance: number?, window: string?): any
		return { key = key, window = window or key, distance = distance, radius = 6 }
	end

	describe("inside", function()
		it("comes in at the radius and leaves only LEAVE_EXTRA past it", function()
			expect(WalkUp.inside(false, 6, 6)).to.equal(true)
			expect(WalkUp.inside(false, 6.1, 6)).to.equal(false)
			expect(WalkUp.inside(true, 6 + WalkUp.LEAVE_EXTRA, 6)).to.equal(true)
			expect(WalkUp.inside(true, 6 + WalkUp.LEAVE_EXTRA + 0.1, 6)).to.equal(false)
			expect(WalkUp.inside(true, nil, 6)).to.equal(false)
			expect(WalkUp.inside(false, 0 / 0, 6)).to.equal(false)
		end)
	end)

	describe("step", function()
		it("opens on walking up, once, and closes on walking away", function()
			local state = WalkUp.new()
			local open, close = WalkUp.step(state, { at("spin", 20, "Spin") }, false, nil)
			expect(open).to.equal(nil)
			expect(close).to.equal(false)
			open, close = WalkUp.step(state, { at("spin", 5, "Spin") }, false, nil)
			expect(open).to.equal("spin")
			-- standing there opens nothing more
			open = WalkUp.step(state, { at("spin", 4, "Spin") }, false, "Spin")
			expect(open).to.equal(nil)
			open, close = WalkUp.step(state, { at("spin", 12, "Spin") }, false, "Spin")
			expect(open).to.equal(nil)
			expect(close).to.equal(true)
		end)

		it("opens nothing for a player who spawns or lands already there", function()
			local state = WalkUp.new()
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(nil)
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(nil)
			-- out and back in opens it
			WalkUp.step(state, { at("cannon", 20, "Cannon") }, false, nil)
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(
				"cannon"
			)
		end)

		it("never opens over a catch or another window, and waits for the next walk up", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("market", 30, "Market") }, false, nil)
			local open = WalkUp.step(state, { at("market", 3, "Market") }, true, nil)
			expect(open).to.equal(nil)
			-- the catch ended while standing there: nothing pops up
			open = WalkUp.step(state, { at("market", 3, "Market") }, false, nil)
			expect(open).to.equal(nil)
			local other = WalkUp.new()
			WalkUp.step(other, { at("market", 30, "Market") }, false, nil)
			open = WalkUp.step(other, { at("market", 3, "Market") }, false, "Store")
			expect(open).to.equal(nil)
		end)

		it(
			"leaves a window closed by hand shut, and never closes a window the player opened",
			function()
				local state = WalkUp.new()
				WalkUp.step(state, { at("cannon", 30, "Cannon") }, false, nil)
				expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(
					"cannon"
				)
				-- closed by hand, still standing there: it stays shut
				expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(
					nil
				)
				-- the player opened the Store by hand, then walked off: the Store stays open
				local _, close = WalkUp.step(state, { at("cannon", 30, "Cannon") }, false, "Store")
				expect(close).to.equal(false)
			end
		)

		it("opens the nearest of two stations stepped into together", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("spin", 30, "Spin"), at("market", 30, "Market") }, false, nil)
			local open =
				WalkUp.step(state, { at("spin", 5, "Spin"), at("market", 3, "Market") }, false, nil)
			expect(open).to.equal("market")
		end)

		it(
			"counts a station that left (the night market at sunrise) as walked away from",
			function()
				local state = WalkUp.new()
				WalkUp.step(state, { at("dealer", 30, "Dealer") }, false, nil)
				expect((WalkUp.step(state, { at("dealer", 2, "Dealer") }, false, nil))).to.equal(
					"dealer"
				)
				local open, close = WalkUp.step(state, {}, false, "Dealer")
				expect(open).to.equal(nil)
				expect(close).to.equal(true)
				expect(next(state.inside)).to.equal(nil)
			end
		)

		it("goes straight from one station's window to the next one's", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("spin", 30, "Spin"), at("market", 40, "Market") }, false, nil)
			WalkUp.step(state, { at("spin", 3, "Spin"), at("market", 40, "Market") }, false, nil)
			local open, close = WalkUp.step(
				state,
				{ at("spin", 40, "Spin"), at("market", 3, "Market") },
				false,
				"Spin"
			)
			expect(open).to.equal("market")
			expect(close).to.equal(true)
		end)
	end)

	describe("the floor rings", function()
		it(
			"puts a front ring against the station's front, its far edge inside the server's range",
			function()
				-- a stall 3 studs deep in front of its pivot, range 14: the ring touches the front
				expect(WalkUp.frontOffset(3, 4, 14)).to.equal(7)
				-- a deep stall: pulled in so the far edge is EDGE_SLACK inside the range
				expect(WalkUp.frontOffset(9, 4, 14)).to.equal(14 - WalkUp.EDGE_SLACK - 4)
				expect(WalkUp.frontOffset(9, 4, 14) + 4 <= 14 - WalkUp.EDGE_SLACK).to.equal(true)
				-- never behind the pivot
				expect(WalkUp.frontOffset(-2, 4, 14)).to.equal(4)
				expect(WalkUp.frontOffset(5, 4, 6)).to.equal(0)
			end
		)

		-- #3112 (Derek2: "make the circles infront of the stations bigger"): radius 6, and every town station's range
		-- grew with it, so each ring still touches its station's front (the fronts measured off the models)
		-- #3448 (Derek: "bigger for stepping on and auto claiming"): radius 8, each range 4 further out with it
		it("fits a radius 8 ring in front of every town station, inside its range", function()
			local Config = require(Shared.Config)
			local FeedbackStand = require(Shared.FeedbackStand)
			expect(WalkUp.FRONT_RADIUS).to.equal(8)
			local stations: { [string]: { number } } = {
				spin = { 2.99, Config.SpinStationRange },
				market = { 2.8, Config.FishMarketRange },
				mystery = { 3.5, Config.MysteryMarketRange },
				dayCart = { 1.82, Config.CornerShopRange },
				dealer = { 2.01, Config.DealerRangeStuds },
				feedback = { 1.9, FeedbackStand.RANGE },
			}
			for name, pair in stations do
				local front, range = pair[1], pair[2]
				local out = WalkUp.frontOffset(front, WalkUp.FRONT_RADIUS, range)
				-- touching the front, or tucked under it by a hair (the night cart's 2.01 front)
				if out < front + WalkUp.FRONT_RADIUS - 0.05 then
					error(
						string.format(
							"the %s ring sits %.2f out, not %.2f",
							name,
							out,
							front + WalkUp.FRONT_RADIUS
						)
					)
				end
				expect(out + WalkUp.FRONT_RADIUS + WalkUp.EDGE_SLACK <= range).to.equal(true)
			end
		end)

		-- #3113: a camp station's front ring is the town's size where the floor is clear, slides off a wall beside
		-- it, and shrinks no further than FRONT_FIT_LEAST
		it(
			"fits a camp station's front ring to what stands in it, never under FRONT_FIT_LEAST",
			function()
				local wide, least = WalkUp.FRONT_RADIUS, WalkUp.FRONT_FIT_LEAST
				expect(least < wide and least >= 4).to.equal(true)
				expect(WalkUp.BOARD_RADIUS <= wide and WalkUp.BOARD_RADIUS >= 4).to.equal(true)
				-- the Mystic Pool's is a little smaller than the town's and never under the least
				expect(WalkUp.POOL_RADIUS < wide and WalkUp.POOL_RADIUS >= least).to.equal(true)
				local shift, fitted = WalkUp.fitRing(wide, {}, WalkUp.FIT_SHIFT_MAX, least)
				expect(shift.Magnitude).to.equal(0)
				expect(fitted).to.equal(wide)
				-- a wall 1 stud inside the rim on the east: the ring slides west and keeps its size
				shift, fitted =
					WalkUp.fitRing(wide, { Vector2.new(wide - 1, 0) }, WalkUp.FIT_SHIFT_MAX, least)
				expect(shift.X < 0 and shift.Magnitude <= WalkUp.FIT_SHIFT_MAX + 1e-6).to.equal(
					true
				)
				expect(math.abs(fitted - wide) < 0.05).to.equal(true)
				-- walls close on both sides: it shrinks, but not under the least
				shift, fitted = WalkUp.fitRing(
					wide,
					{ Vector2.new(3, 0), Vector2.new(-3, 0) },
					WalkUp.FIT_SHIFT_MAX,
					least
				)
				expect(fitted).to.equal(least)
			end
		)

		it("rings the cannon all the way round, clear of it and inside its range", function()
			expect(WalkUp.aroundRadius(6, 10)).to.equal(10 - WalkUp.EDGE_SLACK)
			expect(WalkUp.aroundRadius(3, 10)).to.equal(3 + WalkUp.AROUND_PAD)
			expect(WalkUp.aroundRadius(0, 2)).to.equal(1)
		end)

		it("fills the Town Square cannon's wider range with its ring (#3671)", function()
			local Cannon = require(Shared.Cannon)
			local W = require(Shared.Config).World
			expect(Cannon.range("town")).to.equal(11.5)
			expect(Cannon.range("alley")).to.equal(W.CannonRangeStuds)
			expect(Cannon.range(nil)).to.equal(W.CannonRangeStuds)
			local radius = WalkUp.aroundRadius(4.8, Cannon.range("town"), nil, true)
			expect(radius).to.equal(9.5)
			expect(radius > WalkUp.aroundRadius(4.8, W.CannonRangeStuds)).to.equal(true)
			-- a player who has just spawned stands outside the ring, so the window does not open by itself
			local Layout = require(game:GetService("ServerScriptService").Server.World.Layout)
			local cannon = Layout.cannons.town
			local function away(point: any): number
				return math.sqrt((point.x - cannon.x) ^ 2 + (point.z - cannon.z) ^ 2)
			end
			expect(away(Layout.playerSpawn) - radius >= 3).to.equal(true)
			-- nor for a player who lands in town: every landing spot is outside the ring, and the landing circle's
			-- edge is clear of it
			local pad = Layout.landingPads.town
			for _, spot in pad.spots do
				expect(away(spot) - radius >= 1).to.equal(true)
			end
			expect(away(pad.centre) - W.LandingPadRadius - radius > 0).to.equal(true)
			-- a cap still wins, and without fill nothing changes
			expect(WalkUp.aroundRadius(4.8, 12, WalkUp.CAMP_RING_MAX, true)).to.equal(
				WalkUp.CAMP_RING_MAX
			)
			expect(WalkUp.aroundRadius(4.8, 12)).to.equal(4.8 + WalkUp.AROUND_PAD)
		end)
	end)

	describe("when a window opens (#3448, instant since 2026-11-14)", function()
		local wait = WalkUp.DWELL_SECONDS

		-- Derek 2026-11-14 (top priority): no wait, the first look inside the ring opens the window
		it("opens on the first look inside the ring", function()
			expect(wait).to.equal(0)
			local state = WalkUp.new()
			WalkUp.step(state, { at("spin", 20, "Spin") }, false, nil, 10)
			expect((WalkUp.step(state, { at("spin", 5, "Spin") }, false, nil, 10.05))).to.equal(
				"spin"
			)
			-- once per step in
			expect((WalkUp.step(state, { at("spin", 5, "Spin") }, false, nil, 12))).to.equal(nil)
			-- and again after stepping out and back in
			WalkUp.step(state, { at("spin", 20, "Spin") }, false, nil, 13)
			expect((WalkUp.step(state, { at("spin", 5, "Spin") }, false, nil, 13.05))).to.equal(
				"spin"
			)
		end)

		it("keeps a window closed by hand closed until the player steps out and back in", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("market", 20, "Market") }, false, nil, 0)
			expect((WalkUp.step(state, { at("market", 3, "Market") }, false, nil, 1 + wait))).to.equal(
				"market"
			)
			-- closed by hand: still inside, nothing opens however long they stand there
			for tick = 2, 6 do
				expect((WalkUp.step(state, { at("market", 3, "Market") }, false, nil, tick))).to.equal(
					nil
				)
			end
			WalkUp.step(state, { at("market", 20, "Market") }, false, nil, 7)
			expect((WalkUp.step(state, { at("market", 3, "Market") }, false, nil, 8 + wait))).to.equal(
				"market"
			)
		end)

		it("asks once: blocked when the wait ends, it waits for the next step in", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("spin", 20, "Spin") }, false, nil, 0)
			WalkUp.step(state, { at("spin", 3, "Spin") }, false, nil, 1)
			expect((WalkUp.step(state, { at("spin", 3, "Spin") }, true, nil, 1 + wait))).to.equal(
				nil
			)
			expect((WalkUp.step(state, { at("spin", 3, "Spin") }, false, nil, 3))).to.equal(nil)
		end)

		it("opens the nearer of two rings the player stands in", function()
			local state = WalkUp.new()
			local far = { at("spin", 30, "Spin"), at("arcade", 30, "Arcade") }
			WalkUp.step(state, far, false, nil, 0)
			local both = { at("spin", 5, "Spin"), at("arcade", 3, "Arcade") }
			expect((WalkUp.step(state, both, false, nil, 1 + wait))).to.equal("arcade")
			expect((WalkUp.step(state, both, false, "Arcade", 2))).to.equal(nil)
		end)

		it("opens nothing on landing inside a ring whose prompt was off", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("cannon", 40, "Cannon") }, true, nil, 0)
			local landed = at("cannon", 3, "Cannon")
			landed.off = true
			expect((WalkUp.step(state, { landed }, false, nil, 1))).to.equal(nil)
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil, 5))).to.equal(nil)
		end)
	end)

	describe("rings that would overlap (#3448)", function()
		local function front(x: number, z: number, deep: number, range: number): WalkUp.Ring
			local way = -Vector2.new(x, z).Unit -- every town station faces the cannon at (0, 0)
			return {
				pivot = Vector2.new(x, z),
				way = way,
				front = deep,
				range = range,
				shift = Vector2.zero,
				radius = WalkUp.FRONT_RADIUS,
				least = WalkUp.FRONT_FIT_LEAST,
			}
		end
		local function between(a: WalkUp.Ring, ra: number, b: WalkUp.Ring, rb: number): number
			return (WalkUp.ringCentre(a, ra) - WalkUp.ringCentre(b, rb)).Magnitude - ra - rb
		end

		it("leaves two rings that are clear of each other alone", function()
			local a, b = front(-45, -49.6, 3.5, 22), front(42, 44.5, 2.8, 22)
			local ra, rb = WalkUp.apart(a, b)
			expect(ra).to.equal(WalkUp.FRONT_RADIUS)
			expect(rb).to.equal(WalkUp.FRONT_RADIUS)
		end)

		it(
			"shrinks both until RING_GAP studs of floor show, each still against its front",
			function()
				-- the Spin Wheel and the arcade cabinet where they stand today: 1.3 studs into each other at radius 8
				local wheel, cabinet = front(-35, 35, 2.99, 22), front(-43, 18, 1.55, 20)
				expect(between(wheel, 8, cabinet, 8) < 0).to.equal(true)
				local ra, rb = WalkUp.apart(wheel, cabinet)
				expect(ra).to.equal(rb)
				expect(ra < WalkUp.FRONT_RADIUS and ra >= WalkUp.FRONT_FIT_LEAST).to.equal(true)
				expect(between(wheel, ra, cabinet, rb) >= WalkUp.RING_GAP).to.equal(true)
				-- no smaller than it has to be
				expect(between(wheel, ra + 0.1, cabinet, rb + 0.1) < WalkUp.RING_GAP).to.equal(true)
				expect((WalkUp.ringCentre(wheel, ra) - wheel.pivot).Magnitude).to.be.near(
					2.99 + ra,
					1e-6
				)
			end
		)

		it(
			"shrinks only the one that can when the other is at its least (a board, a cannon)",
			function()
				local station = front(0, 21, 1, math.huge)
				local cannon: WalkUp.Ring = {
					pivot = Vector2.new(0, 0),
					way = Vector2.zero,
					front = 0,
					range = 30,
					shift = Vector2.new(0.5, 0),
					radius = 6.5,
					least = 6.5,
				}
				expect(WalkUp.ringCentre(cannon, 3)).to.equal(Vector2.new(0.5, 0))
				local ra, rb = WalkUp.apart(station, cannon)
				expect(rb).to.equal(6.5)
				expect(ra < 8 and ra >= WalkUp.FRONT_FIT_LEAST).to.equal(true)
				expect(between(station, ra, cannon, rb) >= WalkUp.RING_GAP).to.equal(true)
			end
		)

		it("stops at the least sizes when the floor is too tight", function()
			local a, b = front(0, 10, 0, math.huge), front(0, -10, 0, math.huge)
			local ra, rb = WalkUp.apart(a, b)
			expect(ra).to.be.near(WalkUp.FRONT_FIT_LEAST, 1e-6)
			expect(rb).to.be.near(WalkUp.FRONT_FIT_LEAST, 1e-6)
		end)
	end)

	describe("Laptop-Tester's fixes on #2427", function()
		it("opens nothing on a landing inside a ring while the prompt was off", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("cannon", 40, "Cannon") }, true, nil) -- mid flight, far away
			local landed = at("cannon", 3, "Cannon")
			landed.off = true -- the prompt is off until the flight ends
			expect((WalkUp.step(state, { landed }, false, nil))).to.equal(nil)
			-- the prompt back on: already inside, so nothing opens until the player walks out and back
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(nil)
			WalkUp.step(state, { at("cannon", 20, "Cannon") }, false, nil)
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(
				"cannon"
			)
		end)

		it("keeps a window open while the player stands still in the ring", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("market", 20, "Market") }, false, nil)
			expect((WalkUp.step(state, { at("market", 3, "Market") }, false, nil))).to.equal(
				"market"
			)
			for _ = 1, 20 do
				local open, close =
					WalkUp.step(state, { at("market", 3, "Market") }, false, "Market")
				expect(open).to.equal(nil)
				expect(close).to.equal(false)
			end
		end)

		it("caps a camp cannon's ring", function()
			expect(WalkUp.aroundRadius(4.8, 10, WalkUp.CAMP_RING_MAX)).to.equal(
				WalkUp.CAMP_RING_MAX
			)
			expect(WalkUp.aroundRadius(2, 10, WalkUp.CAMP_RING_MAX)).to.equal(2 + WalkUp.AROUND_PAD)
			expect(WalkUp.aroundRadius(4.8, 10)).to.equal(4.8 + WalkUp.AROUND_PAD) -- the town cannon: no cap
		end)
	end)

	describe("fitRing (#2433)", function()
		local function clear(shift: Vector2, radius: number, blocks: { Vector2 }): boolean
			for _, block in blocks do
				if (block - shift).Magnitude < radius + WalkUp.FIT_CLEAR - 1e-3 then
					return false
				end
			end
			return true
		end

		it("stays put and whole with nothing in the way", function()
			local shift, radius = WalkUp.fitRing(5.5, {}, 1.5, 4.6)
			expect(shift.Magnitude).to.equal(0)
			expect(radius).to.equal(5.5)
			shift, radius = WalkUp.fitRing(5.5, { Vector2.new(0, 8) }, 1.5, 4.6)
			expect(shift.Magnitude).to.equal(0)
			expect(radius).to.equal(5.5)
		end)

		it("slides off a low side wall 4.4 studs out, as at each camp", function()
			local wall: { Vector2 } = {}
			for x = -3, 3 do
				table.insert(wall, Vector2.new(x, 4.4))
			end
			local shift, radius = WalkUp.fitRing(5.5, wall, 1.5, 4.6)
			expect(radius).to.equal(5.5)
			expect(shift.Y < -1).to.equal(true) -- away from the wall
			expect(math.abs(shift.X) < 0.05).to.equal(true)
			expect(shift.Magnitude <= 1.5 + 1e-6).to.equal(true)
			expect(clear(shift, radius, wall)).to.equal(true)
		end)

		it("shrinks, but not below least, when sliding is not enough", function()
			local walls = { Vector2.new(0, 4.4), Vector2.new(0, -4.4) }
			local shift, radius = WalkUp.fitRing(5.5, walls, 1.5, 4)
			expect(shift.Magnitude < 0.05).to.equal(true)
			expect(math.abs(radius - (4.4 - WalkUp.FIT_CLEAR)) < 1e-3).to.equal(true)
			local _, least =
				WalkUp.fitRing(5.5, { Vector2.new(0, 2), Vector2.new(0, -2) }, 1.5, 4.6)
			expect(least).to.equal(4.6)
			local still, kept = WalkUp.fitRing(5.5, { Vector2.new(0, 4.4) }, 0, 4)
			expect(still.Magnitude).to.equal(0)
			expect(math.abs(kept - (4.4 - WalkUp.FIT_CLEAR)) < 1e-3).to.equal(true)
		end)

		-- Laptop-Tester on #2435: the slide left the cannon's base trim 0.73 studs past the rim on the wall side
		local function base(towardWall: number): { Vector2 }
			return {
				Vector2.new(-3, -3),
				Vector2.new(3, -3),
				Vector2.new(-3, 3),
				Vector2.new(3, 3),
				Vector2.new(-1.3, towardWall),
				Vector2.new(1.3, towardWall),
			}
		end
		local wall: { Vector2 } = {}
		for x = -3, 3 do
			table.insert(wall, Vector2.new(x, 4.4))
		end

		it("slides off the wall only as far as still holds the station's base", function()
			local keep = base(4.2)
			local shift, radius = WalkUp.fitRing(5.5, wall, 1.5, 1, keep)
			expect(clear(shift, radius, wall)).to.equal(true)
			for _, point in keep do
				expect((point - shift).Magnitude <= radius + 1e-3).to.equal(true)
			end
			expect(shift.Y < -1).to.equal(true)
			expect(shift.Y > -1.2).to.equal(true)
		end)

		it("keeps the station inside when its base reaches past the wall", function()
			local keep = base(4.6)
			local shift, radius = WalkUp.fitRing(5.5, wall, 1.5, 1, keep)
			for _, point in keep do
				expect((point - shift).Magnitude <= radius + 1e-3).to.equal(true)
			end
			expect(radius <= 5.5).to.equal(true)
		end)

		it("leaves out a base wider than the ring, so it never throws the ring about", function()
			local wide =
				{ Vector2.new(-9, 0), Vector2.new(9, 0), Vector2.new(0, 9), Vector2.new(0, -9) }
			local shift, radius = WalkUp.fitRing(8, {}, 1.5, 1, wide)
			expect(shift.Magnitude).to.equal(0)
			expect(radius).to.equal(8)
		end)
	end)

	describe("WalkUp.promptReach (#3114)", function()
		it("gives a station with a ring no click prompt", function()
			expect(WalkUp.promptReach(true, 12)).to.equal(0)
			expect(WalkUp.SILENT_REACH).to.equal(0)
		end)
		it("leaves a station without a ring its prompt, so it always has a way in", function()
			expect(WalkUp.promptReach(false, 12)).to.equal(12)
		end)
		it("gives the prompt its own reach back when the ring goes away", function()
			local own = 12
			expect(WalkUp.promptReach(true, own)).to.equal(0)
			expect(WalkUp.promptReach(false, own)).to.equal(12) -- from the remembered reach, not the silenced 0
		end)
	end)
end
