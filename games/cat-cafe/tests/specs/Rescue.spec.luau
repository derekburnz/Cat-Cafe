--!strict
-- Rescue.luau and shared/RescueMarker.luau against data-model section 10b (F27): the bar, the tree's shake then
-- catch, paws, the deadline, and the features.md acceptance (three misses end the attempt; a tree ends with one catch
-- circle). F93 (catch-rework.md section 4): one more hit at every rarity, a zone not hit within RescueZonePasses
-- sweeps costs a paw and moves on, and every hit makes the marker RescueSpeedUpPerHit faster.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Circles = require(Shared.Circles)
	local Config = require(Shared.Config)
	local Rescue = require(Shared.Rescue)
	local RescueMarker = require(Shared.RescueMarker)

	-- Rolls from a fixed list, round and round.
	local function rolls(list: { number }): () -> number
		local i = 0
		return function()
			i = i % #list + 1
			return list[i]
		end
	end

	-- The first server time at or after the attempt's last press (or the marker's start) when its marker is at `x` on
	-- its way out from the left end. Within a zone's two sweeps that comes exactly once.
	local function timeAt(attempt: any, x: number): number
		local from = math.max(attempt.lastPressAt, attempt.markerAt)
		local phase =
			RescueMarker.phaseAt(attempt.markerAt, attempt.markerPhase, attempt.speed, from)
		return from + ((x - phase) % 2) / attempt.speed
	end

	local function zoneTime(attempt: any): number
		return timeAt(attempt, Rescue.currentZone(attempt) :: number)
	end

	-- The first time after the last press when the marker is well outside the zone waiting to be hit.
	local function missTime(attempt: any): number
		local centre = Rescue.currentZone(attempt) :: number
		local half = attempt.challenge.zoneWidth / 2 + Config.RescueTolerance + 0.02
		local t = math.max(attempt.lastPressAt, attempt.markerAt) + 0.001
		while math.abs(Rescue.marker(attempt, t) - centre) <= half do
			t += 0.002
		end
		return t
	end

	describe("RescueMarker", function()
		it("waits at its phase, then runs out to the right end and back", function()
			expect(RescueMarker.position(10, 0.25, 1, 5)).to.be.near(0.25, 1e-9)
			expect(RescueMarker.position(10, 0, 0.5, 11)).to.be.near(0.5, 1e-9)
			expect(RescueMarker.position(10, 0, 0.5, 12)).to.be.near(1, 1e-9)
			expect(RescueMarker.position(10, 0, 0.5, 13)).to.be.near(0.5, 1e-9)
			expect(RescueMarker.position(10, 1.5, 1, 10)).to.be.near(0.5, 1e-9)
		end)

		it(
			"phaseAt says where on the back-and-forth it is, so a faster marker carries on from there (F93)",
			function()
				expect(RescueMarker.phaseAt(10, 0.25, 1, 5)).to.be.near(0.25, 1e-9)
				expect(RescueMarker.phaseAt(10, 0, 0.5, 13)).to.be.near(1.5, 1e-9)
				expect(RescueMarker.phaseAt(10, 1.5, 1, 11)).to.be.near(0.5, 1e-9)
				for _, t in { 10.3, 11.7, 12.9 } do
					local phase = RescueMarker.phaseAt(10, 0.4, 0.8, t)
					expect(RescueMarker.position(t, phase, 2, t)).to.be.near(
						RescueMarker.position(10, 0.4, 0.8, t),
						1e-9
					)
				end
			end
		)

		it("counts RescueTolerance either side of the zone", function()
			expect(RescueMarker.inZone(0.64, 0.5, 0.3, 0)).to.equal(true)
			expect(RescueMarker.inZone(0.67, 0.5, 0.3, 0)).to.equal(false)
			expect(RescueMarker.inZone(0.67, 0.5, 0.3, Config.RescueTolerance)).to.equal(true)
			expect(RescueMarker.inZone(0.69, 0.5, 0.3, Config.RescueTolerance)).to.equal(false)
		end)
	end)

	describe("challenges", function()
		it("a tree is shaken then caught, every other trap is the bar", function()
			expect(Rescue.kind("tree")).to.equal("shake_catch")
			for _, trap in { "trash_bin", "garbage_bag", "trashcan", "hollow_log", "drain_pipe" } do
				expect(Rescue.kind(trap)).to.equal("bar")
			end
		end)

		it("a bar needs rescueHits, a tree one fewer, never fewer than one", function()
			for _, rarity in Catalog.rarityOrder do
				local hits = Catalog.rarities[rarity].rescueHits
				expect(Rescue.hitsNeeded(rarity, "bar")).to.equal(hits)
				expect(Rescue.hitsNeeded(rarity, "shake_catch")).to.equal(math.max(1, hits - 1))
			end
			-- F93: 3 for a Common up to 7 for a Mythical
			expect(Rescue.hitsNeeded("Common", "bar")).to.equal(3)
			expect(Rescue.hitsNeeded("Mythical", "bar")).to.equal(7)
			expect(Rescue.hitsNeeded("Common", "shake_catch")).to.equal(2)
		end)

		it("zones stay on the bar and each moves at least MIN_ZONE_STEP from the last", function()
			local roll = rolls({ 0.5, 0.51, 0.02, 0.99, 0.5, 0.3, 0.7, 0.0, 1 - 1e-9 })
			for _, width in { 0.30, 0.12 } do
				local zones = Rescue.zones(6, width, roll)
				expect(#zones).to.equal(6)
				for i, centre in zones do
					expect(centre >= width / 2 - 1e-9 and centre <= 1 - width / 2 + 1e-9).to.equal(
						true
					)
					if i > 1 then
						expect(math.abs(centre - zones[i - 1]) >= Rescue.MIN_ZONE_STEP - 1e-9).to.equal(
							true
						)
					end
				end
			end
		end)

		it("carries the rarity's speed, width, hits, paws and a 15 s deadline", function()
			local c = Rescue.newChallenge("Epic", "garbage_bag", 100, rolls({ 0.3, 0.8, 0.1, 0.6 }))
			expect(c.kind).to.equal("bar")
			expect(c.startsAt).to.be.near(100 + Config.CircleLeadInSeconds, 1e-9)
			expect(c.endsAt).to.be.near(100 + Config.RescueAttemptMaxSeconds, 1e-9)
			expect(c.speed).to.equal(Config.RescueBarSpeed.Epic)
			expect(c.zoneWidth).to.equal(Config.RescueZoneWidth.Epic)
			expect(c.hitsNeeded).to.equal(Catalog.rarities.Epic.rescueHits)
			expect(c.paws).to.equal(Config.RescuePatience)
		end)

		it("holds a spare zone per paw and says when the first one moves on (F93)", function()
			local c = Rescue.newChallenge("Epic", "garbage_bag", 100, rolls({ 0.3, 0.8, 0.1, 0.6 }))
			expect(#(c.zones :: { number })).to.equal(
				(c.hitsNeeded :: number) + Config.RescuePatience
			)
			expect(c.zone).to.equal(1)
			expect(c.zonePasses).to.equal(2)
			expect(c.speedUpPerHit).to.be.near(0.08, 1e-12)
			-- two trips along the bar from when the marker starts
			expect(c.zoneEndsAt).to.be.near(c.startsAt + 2 / Config.RescueBarSpeed.Epic, 1e-9)
		end)

		it("the marker never waits inside the first zone", function()
			local rng = Random.new(7)
			for _ = 1, 300 do
				local c = Rescue.newChallenge("Common", "trash_bin", 0, function()
					return rng:NextNumber()
				end)
				local waiting = RescueMarker.position(c.startsAt, c.phase :: number, 0, 0)
				local first = (c.zones :: { number })[1]
				local inside = RescueMarker.inZone(
					waiting,
					first,
					c.zoneWidth :: number,
					Config.RescueTolerance
				)
				expect(inside).to.equal(false)
			end
		end)
	end)

	describe("the bar", function()
		local function binAttempt(rarity: any): any
			return Rescue.newAttempt(
				Rescue.newChallenge(rarity, "trash_bin", 0, rolls({ 0.2, 0.7, 0.4, 0.9 })),
				rarity
			)
		end

		it("frees a Common from a bin in three hits (F93)", function()
			local attempt = binAttempt("Common")
			for _ = 1, 2 do
				expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
				expect(attempt.stage).to.equal("bar")
			end
			expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(true)
			expect(attempt.paws).to.equal(Config.RescuePatience)
		end)

		it("a Mythical needs seven hits on the bar (F93)", function()
			local attempt = binAttempt("Mythical")
			for i = 1, 7 do
				expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
				expect(attempt.stage).to.equal(if i < 7 then "bar" else "done")
			end
			expect(attempt.success).to.equal(true)
		end)

		it("three misses end the attempt without the cat", function()
			local attempt = binAttempt("Rare")
			for i = 1, 3 do
				expect(Rescue.pressBar(attempt, missTime(attempt))).to.equal("miss")
				expect(attempt.paws).to.equal(3 - i)
			end
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(false)
			expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("ignored")
		end)

		it("a hit moves the zone: the same time is a miss against the next one", function()
			local attempt = binAttempt("Epic")
			local t = zoneTime(attempt)
			expect(Rescue.pressBar(attempt, t)).to.equal("hit")
			expect(Rescue.pressBar(attempt, t)).to.equal("miss")
		end)

		it("ignores presses before the marker moves and after the deadline", function()
			local attempt = binAttempt("Common")
			local c = attempt.challenge
			expect(Rescue.pressBar(attempt, c.startsAt - 0.01)).to.equal("ignored")
			expect(Rescue.pressBar(attempt, (c.endsAt :: number) + 0.01)).to.equal("ignored")
			expect(attempt.paws).to.equal(Config.RescuePatience)
		end)

		it("runs out at its deadline plus the latency allowance", function()
			local attempt = binAttempt("Common")
			local endsAt = attempt.challenge.endsAt :: number
			expect(Rescue.expire(attempt, endsAt + Config.CatchLatencyCapSeconds)).to.equal(false)
			expect(Rescue.expire(attempt, endsAt + Config.CatchLatencyCapSeconds + 0.01)).to.equal(
				true
			)
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(false)
		end)

		it("Give up ends it as a fail", function()
			local attempt = binAttempt("Common")
			Rescue.abandon(attempt)
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(false)
		end)
	end)

	describe("no waiting for the perfect moment (F93, catch-rework.md section 4)", function()
		local function binAttempt(rarity: any): any
			return Rescue.newAttempt(
				Rescue.newChallenge(rarity, "trash_bin", 0, rolls({ 0.2, 0.7, 0.4, 0.9 })),
				rarity
			)
		end

		it(
			"a zone not hit within two sweeps costs a paw and the next one takes over from then",
			function()
				local attempt = binAttempt("Rare")
				local first = attempt.zoneEndsAt
				expect(Rescue.advance(attempt, first)).to.equal(0) -- not yet: it runs out after zoneEndsAt
				expect(Rescue.advance(attempt, first + 0.01)).to.equal(1)
				expect(attempt.paws).to.equal(Config.RescuePatience - 1)
				expect(attempt.zone).to.equal(2)
				expect(Rescue.currentZone(attempt)).to.equal(attempt.challenge.zones[2])
				expect(attempt.zoneEndsAt).to.be.near(first + 2 / Config.RescueBarSpeed.Rare, 1e-9)
				expect(attempt.stage).to.equal("bar")
			end
		)

		it("zones that run out one after another take the last paw and end the attempt", function()
			local attempt = binAttempt("Common")
			expect(Rescue.advance(attempt, 1000)).to.equal(Config.RescuePatience)
			expect(attempt.paws).to.equal(0)
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(false)
			expect(Rescue.pressBar(attempt, 1000)).to.equal("ignored")
		end)

		it(
			"a press after a zone ran out is judged on the next zone, and the lost paw stays lost",
			function()
				local attempt = binAttempt("Epic")
				-- wait out zone 1 without pressing: the press lands on zone 2's spot
				attempt.lastPressAt = attempt.zoneEndsAt + 0.001
				local t = timeAt(attempt, attempt.challenge.zones[2])
				expect(t < attempt.zoneEndsAt + 2 / attempt.speed).to.equal(true)
				expect(Rescue.pressBar(attempt, t)).to.equal("hit")
				expect(attempt.hits).to.equal(1)
				expect(attempt.paws).to.equal(Config.RescuePatience - 1)
				expect(attempt.zone).to.equal(3)
			end
		)

		it("a press in the zone is always a hit, on the later of its two passes too", function()
			local attempt = binAttempt("Legendary")
			local centre = Rescue.currentZone(attempt) :: number
			-- the marker passes the zone once each way inside its two sweeps: take the later pass
			local t = math.max(timeAt(attempt, centre), timeAt(attempt, 2 - centre))
			expect(t < attempt.zoneEndsAt).to.equal(true)
			expect(Rescue.pressBar(attempt, t)).to.equal("hit")
		end)

		it(
			"every hit makes the marker RescueSpeedUpPerHit faster from the spot it was hit at",
			function()
				local attempt = binAttempt("Epic")
				local base = Config.RescueBarSpeed.Epic
				for hits = 1, 3 do
					local t = zoneTime(attempt)
					local before = Rescue.marker(attempt, t)
					expect(Rescue.pressBar(attempt, t)).to.equal("hit")
					expect(attempt.speed).to.be.near(base * 1.08 ^ hits, 1e-9)
					expect(Rescue.marker(attempt, t)).to.be.near(before, 1e-9) -- no jump
					expect(attempt.markerAt).to.equal(t)
					expect(attempt.zoneEndsAt).to.be.near(t + 2 / attempt.speed, 1e-9)
				end
			end
		)

		it("a miss costs a paw and leaves the zone where it is", function()
			local attempt = binAttempt("Rare")
			local zone, endsAt = attempt.zone, attempt.zoneEndsAt
			expect(Rescue.pressBar(attempt, missTime(attempt))).to.equal("miss")
			expect(attempt.zone).to.equal(zone)
			expect(attempt.zoneEndsAt).to.equal(endsAt)
			expect(attempt.speed).to.equal(Config.RescueBarSpeed.Rare)
		end)

		it("a press never lands before one already judged", function()
			local attempt = binAttempt("Common")
			local t = zoneTime(attempt)
			expect(Rescue.pressBar(attempt, t)).to.equal("hit")
			-- a later press whose ping dropped arrives stamped earlier: it is judged at the last press, in the old zone
			expect(Rescue.pressBar(attempt, t - 0.05)).to.equal("miss")
			expect(attempt.lastPressAt).to.equal(t)
		end)

		it("RescueResult's bar is the marker and zone as they run now", function()
			local attempt = binAttempt("Rare")
			Rescue.pressBar(attempt, zoneTime(attempt))
			local bar = Rescue.barState(attempt)
			expect(bar.zone).to.equal(attempt.zone)
			expect(bar.startsAt).to.equal(attempt.markerAt)
			expect(bar.phase).to.equal(attempt.markerPhase)
			expect(bar.speed).to.equal(attempt.speed)
			expect(bar.zoneEndsAt).to.equal(attempt.zoneEndsAt)
			local t = attempt.markerAt + 0.37
			expect(RescueMarker.position(bar.startsAt, bar.phase, bar.speed, t)).to.be.near(
				Rescue.marker(attempt, t),
				1e-12
			)
		end)

		it(
			"a steady player's worst case still fits the 15 s deadline: every zone run out but the last paw",
			function()
				for _, rarity in Catalog.rarityOrder do
					local hits = Rescue.hitsNeeded(rarity :: any, "bar")
					-- every hit at the end of its zone's two sweeps, after two zones ran out
					local worst = Config.CircleLeadInSeconds
					local speed = Config.RescueBarSpeed[rarity]
					worst += (Config.RescuePatience - 1) * 2 / speed
					for _ = 1, hits do
						worst += 2 / speed
						speed *= 1 + Config.RescueSpeedUpPerHit
					end
					expect(worst < Config.RescueAttemptMaxSeconds).to.equal(true)
				end
			end
		)
	end)

	describe("the tree", function()
		local function treeAttempt(rarity: any): any
			return Rescue.newAttempt(
				Rescue.newChallenge(rarity, "tree", 0, rolls({ 0.6, 0.1, 0.8, 0.3 })),
				rarity
			)
		end

		it(
			"a Common tree takes two shakes, then ends with one catch circle on the Pro Net",
			function()
				local attempt = treeAttempt("Common")
				expect(attempt.challenge.kind).to.equal("shake_catch")
				expect(attempt.challenge.hitsNeeded).to.equal(2)
				expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
				expect(attempt.stage).to.equal("bar")
				expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
				expect(attempt.stage).to.equal("falling")
				local now = 5
				local circle = Rescue.startCircle(attempt, now, rolls({ 0.5 }))
				expect(circle.kind).to.equal("circle")
				expect(attempt.stage).to.equal("circle")
				local windows = Circles.windowsFor(Rescue.CIRCLE_NET_LEVEL, "Common")
				expect((circle.windows :: any).good).to.equal(windows.good)
				expect((circle.windows :: any).good).to.be.near(0.1705, 1e-12) -- the Pro Net's 0.155 x 1.1 (F93)
				local c = circle.circle :: any
				expect(c.startsAt).to.be.near(now + Config.CircleLeadInSeconds, 1e-9)
				expect(c.shrinkSeconds).to.be.near(Catalog.rarities.Common.shrinkSeconds, 1e-9)
				local target = Circles.target(c)
				expect(Rescue.pressCircle(attempt, target + 0.01, target + 0.05)).to.equal(
					"perfect"
				)
				expect(attempt.stage).to.equal("done")
				expect(attempt.success).to.equal(true)
			end
		)

		it("a Mythical's falling circle has the Pro Net's windows times 0.6 (F83, F93)", function()
			local attempt = treeAttempt("Mythical")
			while attempt.stage == "bar" do
				Rescue.pressBar(attempt, zoneTime(attempt))
			end
			local challenge = Rescue.startCircle(attempt, 10, rolls({ 0.5 }))
			expect((challenge.windows :: any).good).to.be.near(0.093, 1e-12)
			expect((challenge.windows :: any).perfect).to.be.near(0.039, 1e-12)
			local circle = challenge.circle :: any
			local target = Circles.target(circle)
			-- Good on a Common's circle, a Miss on a Mythical's
			expect(Rescue.pressCircle(attempt, target + 0.1, target + 0.1)).to.equal("miss")
		end)

		it("a missed circle means the cat climbs back up", function()
			local attempt = treeAttempt("Rare")
			while attempt.stage == "bar" do
				Rescue.pressBar(attempt, zoneTime(attempt))
			end
			expect(attempt.hits).to.equal(Catalog.rarities.Rare.rescueHits - 1)
			local circle = Rescue.startCircle(attempt, 10, rolls({ 0.5 })).circle :: any
			local target = Circles.target(circle)
			-- past Good (0.147 on the Pro Net for a Rare, F93) but before the circle's deadline: judged, and a Miss
			expect(Rescue.pressCircle(attempt, target + 0.25, target + 0.25)).to.equal("miss")
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(false)
		end)

		it("an unpressed circle runs out at its deadline", function()
			local attempt = treeAttempt("Common")
			while attempt.stage == "bar" do
				Rescue.pressBar(attempt, zoneTime(attempt))
			end
			local circle = Rescue.startCircle(attempt, 0, rolls({ 0.5 })).circle :: any
			local deadline =
				Circles.deadline(circle, Circles.windowsFor(Rescue.CIRCLE_NET_LEVEL, "Common"))
			expect(Rescue.deadline(attempt)).to.be.near(deadline, 1e-9)
			expect(Rescue.expire(attempt, deadline + 0.01)).to.equal(true)
			expect(attempt.success).to.equal(false)
			expect(Rescue.pressCircle(attempt, deadline, deadline + 0.02)).never.to.be.ok()
		end)
	end)
end
