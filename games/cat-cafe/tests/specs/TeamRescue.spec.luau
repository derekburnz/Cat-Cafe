--!strict
-- Team Rescue (F92, playing-together.md section 3) in shared/Rescue: one helper an attempt, five more seconds, a
-- helper's hit counts and a helper's miss costs no paw, the helper's copy of the bar runs where the rescuer's does, and
-- the helper's tip (60 s of their own day rate, twice between pals, once per 120 s).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Rescue = require(Shared.Rescue)
	local RescueMarker = require(Shared.RescueMarker)

	local function rolls(list: { number }): () -> number
		local i = 0
		return function()
			i = i % #list + 1
			return list[i]
		end
	end

	local function fresh(): Rescue.Attempt
		local challenge = Rescue.newChallenge(
			"Legendary",
			"trash_bin",
			100,
			rolls({ 0.3, 0.7, 0.5, 0.2, 0.9, 0.6 })
		)
		return Rescue.newAttempt(challenge, "Legendary")
	end

	-- The first server time at or after the attempt's last press (or the marker's start) when its marker is at `x` on
	-- its way out from the left end (as in Rescue.spec).
	local function timeAt(attempt: any, x: number): number
		local from = math.max(attempt.lastPressAt, attempt.markerAt)
		local phase =
			RescueMarker.phaseAt(attempt.markerAt, attempt.markerPhase, attempt.speed, from)
		return from + ((x - phase) % 2) / attempt.speed
	end

	-- A spot on the bar well clear of the zone to hit now.
	local function clearOfZone(attempt: Rescue.Attempt): number
		local centre = Rescue.currentZone(attempt) :: number
		return if centre > 0.5 then 0.02 else 0.98
	end

	describe("a helper's press", function()
		it("counts a hit toward the rescue like the rescuer's", function()
			local attempt = fresh()
			local centre = Rescue.currentZone(attempt) :: number
			expect(Rescue.pressBar(attempt, timeAt(attempt, centre), true)).to.equal("hit")
			expect(attempt.hits).to.equal(1)
			expect(attempt.zone).to.equal(2)
		end)

		it("costs no paw on a miss, where the rescuer's costs one", function()
			local helped = fresh()
			local paws = helped.paws
			expect(Rescue.pressBar(helped, timeAt(helped, clearOfZone(helped)), true)).to.equal(
				"miss"
			)
			expect(helped.paws).to.equal(paws)
			expect(helped.hits).to.equal(0)
			expect(helped.stage).to.equal("bar")

			local alone = fresh()
			expect(Rescue.pressBar(alone, timeAt(alone, clearOfZone(alone)))).to.equal("miss")
			expect(alone.paws).to.equal(paws - 1)
		end)

		it("can never end the attempt, however many it misses", function()
			local attempt = fresh()
			local t = timeAt(attempt, clearOfZone(attempt))
			for _ = 1, 20 do
				expect(Rescue.pressBar(attempt, t, true)).to.equal("miss")
			end
			expect(attempt.paws).to.equal(Config.RescuePatience)
			expect(attempt.stage).to.equal("bar")
		end)
	end)

	describe("joining", function()
		it(
			"takes one helper an attempt and moves the deadline TeamRescueExtraSeconds later",
			function()
				local attempt = fresh()
				local endsAt = attempt.challenge.endsAt :: number
				expect(Rescue.addHelper(attempt)).to.equal(true)
				expect(attempt.helped).to.equal(true)
				expect(attempt.challenge.endsAt).to.equal(endsAt + Config.TeamRescueExtraSeconds)
				expect(Rescue.barState(attempt).endsAt).to.equal(
					endsAt + Config.TeamRescueExtraSeconds
				)
				-- a second helper, or the first one back, is refused and adds nothing
				expect(Rescue.addHelper(attempt)).to.equal(false)
				expect(attempt.challenge.endsAt).to.equal(endsAt + Config.TeamRescueExtraSeconds)
			end
		)

		it("is refused once the bar is over", function()
			local attempt = fresh()
			Rescue.abandon(attempt)
			expect(Rescue.addHelper(attempt)).to.equal(false)
			expect(attempt.helped).to.equal(nil)
		end)

		it("hands the helper the bar as it runs now", function()
			local attempt = fresh()
			local centre = Rescue.currentZone(attempt) :: number
			expect(Rescue.pressBar(attempt, timeAt(attempt, centre))).to.equal("hit")
			Rescue.addHelper(attempt)
			local copy = Rescue.helperChallenge(attempt)
			expect(copy.helper).to.equal(true)
			expect(copy.hits).to.equal(1)
			expect(copy.zone).to.equal(2)
			expect(copy.zoneEndsAt).to.equal(attempt.zoneEndsAt)
			expect(copy.paws).to.equal(attempt.paws)
			expect(copy.endsAt).to.equal(attempt.challenge.endsAt)
			expect(copy.hitsNeeded).to.equal(attempt.challenge.hitsNeeded)
			expect(copy.kind).to.equal(attempt.challenge.kind)
			expect(#(copy.zones or {})).to.equal(#(attempt.challenge.zones or {}))
			-- the helper's marker is where the rescuer's is, now and later
			for _, later in { 0, 0.37, 1.2, 2.9 } do
				local t = attempt.markerAt + later
				expect(Rescue.markerAt(copy, t)).to.be.near(Rescue.marker(attempt, t), 1e-9)
			end
		end)
	end)

	describe("the helper's tip", function()
		it("is HelperTipSeconds of the helper's own day rate, twice that between pals", function()
			expect(Config.HelperTipSeconds).to.equal(60)
			expect(Rescue.helperTip(10, false)).to.equal(600)
			expect(Rescue.helperTip(10, true)).to.equal(1200)
			expect(Rescue.helperTip(2.5, false)).to.equal(150)
			expect(Rescue.helperTip(0.01, false)).to.equal(0)
			expect(Rescue.helperTip(-5, true)).to.equal(0)
		end)

		it("pays at most once per TeamRescueTipCooldown a player", function()
			expect(Config.TeamRescueTipCooldown).to.equal(120)
			expect(Rescue.helperTipReady(nil, 0)).to.equal(true)
			expect(Rescue.helperTipReady(1000, 1000)).to.equal(false)
			expect(Rescue.helperTipReady(1000, 1119.9)).to.equal(false)
			expect(Rescue.helperTipReady(1000, 1120)).to.equal(true)
		end)
	end)
end
