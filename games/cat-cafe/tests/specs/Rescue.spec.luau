--!strict
-- Rescue.luau and shared/RescueMarker.luau against data-model section 10b (F27): the bar, the tree's shake then
-- catch, paws, the deadline, and the features.md acceptance (a Common from a bin in two hits; three misses end the
-- attempt; a tree ends with one catch circle).
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

	-- The first server time at or after the marker's start when it is at `x` on its way out from the left end.
	local function timeAt(challenge: any, x: number): number
		local travelled = (x - (challenge.phase or 0)) % 2
		return challenge.startsAt + travelled / challenge.speed
	end

	local function zoneTime(attempt: any): number
		return timeAt(attempt.challenge, attempt.challenge.zones[attempt.hits + 1])
	end

	-- A time when the marker is well outside the next zone.
	local function missTime(attempt: any): number
		local centre = attempt.challenge.zones[attempt.hits + 1]
		local away = if centre > 0.5 then 0.02 else 0.98
		return timeAt(attempt.challenge, away)
	end

	describe("RescueMarker", function()
		it("waits at its phase, then runs out to the right end and back", function()
			expect(RescueMarker.position(10, 0.25, 1, 5)).to.be.near(0.25, 1e-9)
			expect(RescueMarker.position(10, 0, 0.5, 11)).to.be.near(0.5, 1e-9)
			expect(RescueMarker.position(10, 0, 0.5, 12)).to.be.near(1, 1e-9)
			expect(RescueMarker.position(10, 0, 0.5, 13)).to.be.near(0.5, 1e-9)
			expect(RescueMarker.position(10, 1.5, 1, 10)).to.be.near(0.5, 1e-9)
		end)

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
			expect(Rescue.hitsNeeded("Common", "bar")).to.equal(2)
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
			expect(#(c.zones :: { number })).to.equal(c.hitsNeeded)
			expect(c.paws).to.equal(Config.RescuePatience)
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

		it("frees a Common from a bin in two hits", function()
			local attempt = binAttempt("Common")
			expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
			expect(attempt.stage).to.equal("bar")
			expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(true)
			expect(attempt.paws).to.equal(Config.RescuePatience)
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

	describe("the tree", function()
		local function treeAttempt(rarity: any): any
			return Rescue.newAttempt(
				Rescue.newChallenge(rarity, "tree", 0, rolls({ 0.6, 0.1, 0.8, 0.3 })),
				rarity
			)
		end

		it(
			"a Common tree takes one shake, then ends with one catch circle on the Pro Net",
			function()
				local attempt = treeAttempt("Common")
				expect(attempt.challenge.kind).to.equal("shake_catch")
				expect(attempt.challenge.hitsNeeded).to.equal(1)
				expect(Rescue.pressBar(attempt, zoneTime(attempt))).to.equal("hit")
				expect(attempt.stage).to.equal("falling")
				local now = 5
				local circle = Rescue.startCircle(attempt, now, rolls({ 0.5 }))
				expect(circle.kind).to.equal("circle")
				expect(attempt.stage).to.equal("circle")
				local windows = Circles.windowsFor(Rescue.CIRCLE_NET_LEVEL, "Common")
				expect((circle.windows :: any).good).to.equal(windows.good)
				expect((circle.windows :: any).good).to.be.near(0.1395, 1e-12) -- the Pro Net's 0.155 x 0.9 (F83)
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

		it("a Mythical's falling circle has the Pro Net's windows times 0.5 (F83)", function()
			local attempt = treeAttempt("Mythical")
			while attempt.stage == "bar" do
				Rescue.pressBar(attempt, zoneTime(attempt))
			end
			local challenge = Rescue.startCircle(attempt, 10, rolls({ 0.5 }))
			expect((challenge.windows :: any).good).to.be.near(0.0775, 1e-12)
			expect((challenge.windows :: any).perfect).to.be.near(0.0325, 1e-12)
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
			-- past Good (0.124 on the Pro Net for a Rare, F83) but before the circle's deadline: judged, and a Miss
			expect(Rescue.pressCircle(attempt, target + 0.25, target + 0.25)).to.equal("miss")
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(false)
		end)

		it("an unpressed circle runs out at its deadline", function()
			local attempt = treeAttempt("Common")
			Rescue.pressBar(attempt, zoneTime(attempt))
			local circle = Rescue.startCircle(attempt, 0, rolls({ 0.5 })).circle :: any
			local deadline = Circles.deadline(circle, Circles.windowsFor(Rescue.CIRCLE_NET_LEVEL, "Common"))
			expect(Rescue.deadline(attempt)).to.be.near(deadline, 1e-9)
			expect(Rescue.expire(attempt, deadline + 0.01)).to.equal(true)
			expect(attempt.success).to.equal(false)
			expect(Rescue.pressCircle(attempt, deadline, deadline + 0.02)).never.to.be.ok()
		end)
	end)
end
