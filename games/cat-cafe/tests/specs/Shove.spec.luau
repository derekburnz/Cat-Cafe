--!strict
-- shared/Shove.luau against data-model section 10c (F29's carry bumps as v0.5 F41 and v0.5.1): every protection on
-- a shove, the knock-loose roll on a carrier, and the pick up of a Dropped cat (v0.8 F56: a shove always drops it,
-- anyone picks it up with no owner window; v0.9 F66 checks a dropped cat in for its carrier at dusk, which replaces
-- S32's minimum stay). The "edges (QA)" block is QA's; F56 replaced its owner window and scurry cases with the pick
-- up's.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local Shove = require(Shared.Shove)

	-- A table literal drops nil fields, so NONE stands for "set this field to nil".
	local NONE = table.freeze({})
	local function changed<T>(base: T, changes: { [string]: any }): T
		local check = table.clone(base :: any)
		for key, value in changes do
			check[key] = if value == NONE then nil else value
		end
		return check :: T
	end

	-- A press that lunges: in the Alleyway, unlocked, open, free hands, never tackled before.
	local PRESS: Shove.TackleCheck = {
		carrying = false,
		busy = false,
		area = "alley",
		areaUnlocked = true,
		areasClosed = false,
		sinceTackle = nil,
	}
	local function press(changes: { [string]: any }?): Shove.TackleCheck
		return changed(PRESS, changes or {})
	end

	-- A player in reach the lunge hits: someone else in the same area, free, away from their cafe, never hit.
	local TARGET: Shove.TargetCheck = {
		self = false,
		sameArea = true,
		targetBusy = false,
		sinceShoveTarget = nil,
		sinceTargetShoved = nil,
	}
	local function target(changes: { [string]: any }?): Shove.TargetCheck
		return changed(TARGET, changes or {})
	end

	describe("a Tackle press (v0.11 F74, section 10c)", function()
		it("lunges in an unlocked, open area with free hands and no cooldown", function()
			expect(Shove.tackleRefusal(press())).never.to.be.ok()
		end)

		it("a carrier cannot tackle", function()
			expect(Shove.tackleRefusal(press({ carrying = true }))).to.be.ok()
		end)

		it("nobody tackles from a catch or rescue (N85)", function()
			expect(Shove.tackleRefusal(press({ busy = true }))).to.be.ok()
		end)

		it(
			"a newcomer cannot tackle either: the shield works both ways (F87, review N300)",
			function()
				expect(Shove.tackleRefusal(press({ newcomer = true }))).to.equal(
					"Check in your first cat before you tackle"
				)
			end
		)

		it("only inside a catching area", function()
			expect(Shove.tackleRefusal(press({ area = NONE }))).to.be.ok()
		end)

		it("only in an area the tackler's tier opens", function()
			expect(Shove.tackleRefusal(press({ areaUnlocked = false }))).to.be.ok()
		end)

		it("never at night, when the areas are closed (v0.9, F66)", function()
			expect(Shove.tackleRefusal(press({ areasClosed = true }))).to.equal(Clock.CLOSED_TEXT)
		end)

		it("TackleCooldownSeconds between presses, from the press, hit or miss", function()
			local cooldown = Config.TackleCooldownSeconds
			expect(cooldown).to.equal(5)
			expect(Shove.tackleRefusal(press({ sinceTackle = cooldown - 0.01 }))).to.be.ok()
			expect(Shove.tackleRefusal(press({ sinceTackle = cooldown }))).never.to.be.ok()
			-- #2324: the refusal is the seconds left, rounded up
			expect(Shove.tackleRefusal(press({ sinceTackle = 0.5 }))).to.equal("Cooling down 5s")
			expect(Shove.tackleRefusal(press({ sinceTackle = cooldown - 0.01 }))).to.equal(
				"Cooling down 1s"
			)
		end)

		it("the hit window is the lunge plus the grace for lag", function()
			expect(Shove.window()).to.be.near(0.6, 1e-9)
		end)
	end)

	describe("who the lunge hits (section 10c rules on the target)", function()
		it("another player in the same area, free and away from their cafe", function()
			expect(Shove.targetRefusal(target())).never.to.be.ok()
		end)

		it("never the tackler", function()
			expect(Shove.targetRefusal(target({ self = true }))).to.be.ok()
		end)

		it("only someone in the tackler's area: the street and the next area are safe", function()
			expect(Shove.targetRefusal(target({ sameArea = false }))).to.be.ok()
		end)

		it("passes through a player inside a catch or rescue minigame", function()
			expect(Shove.targetRefusal(target({ targetBusy = true }))).to.be.ok()
		end)

		it(
			"hits a player by their own cafe or in a camp: no safe spots but a minigame (Derek2 2026-11-07)",
			function()
				expect(Shove.targetRefusal(target({ targetSafe = true }))).never.to.be.ok()
				expect(Shove.targetRefusal(target({ targetInCamp = true }))).never.to.be.ok()
				expect(Shove.tackleRefusal(press({ inCamp = true }))).never.to.be.ok()
			end
		)

		it(
			"passes through a player who has not checked in a cat yet, carrying or not (F87 newcomer)",
			function()
				expect(Shove.targetRefusal(target({ targetNewcomer = true }))).to.equal(
					"They're new here"
				)
				expect(Shove.targetRefusal(target({ targetNewcomer = false }))).never.to.be.ok()
			end
		)

		it(
			"passes through a player in their first minutes on the server (#3342 join shield)",
			function()
				expect(Shove.targetRefusal(target({ targetShielded = true }))).to.equal(
					Shove.SHIELDED
				)
				expect(Shove.targetRefusal(target({ targetShielded = false }))).never.to.be.ok()
			end
		)

		it("shields a join for TackleShieldSeconds, 5 minutes (#3342)", function()
			local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
			expect(Config.TackleShieldSeconds).to.equal(300)
			local untilAt = Shove.shieldUntil(1000)
			expect(untilAt).to.equal(1300)
			expect(Shove.shielded(untilAt, 1000)).to.equal(true)
			expect(Shove.shielded(untilAt, 1299.9)).to.equal(true)
			expect(Shove.shielded(untilAt, 1300)).to.equal(false)
			expect(Shove.shielded(nil, 1000)).to.equal(false)
		end)

		it("passes through a player with a trade open (#2568, trading from anywhere)", function()
			expect(Shove.targetRefusal(target({ targetTrading = true }))).to.equal(
				"They're trading"
			)
			expect(Shove.targetRefusal(target({ targetTrading = false }))).never.to.be.ok()
		end)

		it(
			"no timed immunity: a player hit a moment ago, by this tackler or anyone, is hit again (#2193)",
			function()
				expect(Config.BumpSameTargetSeconds).to.equal(0)
				expect(Config.ShoveTargetImmuneSeconds).to.equal(0)
				expect(Shove.targetRefusal(target({ sinceShoveTarget = 0 }))).never.to.be.ok()
				expect(Shove.targetRefusal(target({ sinceTargetShoved = 0 }))).never.to.be.ok()
				expect(Shove.targetRefusal(target({ sinceShoveTarget = 0, sinceTargetShoved = 0 }))).never.to.be.ok()
			end
		)

		it("the timed rules still read their settings when they are tuned up again", function()
			local config = Config :: any
			local same, immune = config.BumpSameTargetSeconds, config.ShoveTargetImmuneSeconds
			config.BumpSameTargetSeconds, config.ShoveTargetImmuneSeconds = 20, 4
			local sameWait = Shove.targetRefusal(target({ sinceShoveTarget = 19.99 }))
			local sameDone = Shove.targetRefusal(target({ sinceShoveTarget = 20 }))
			local immuneWait = Shove.targetRefusal(target({ sinceTargetShoved = 3.99 }))
			local immuneDone = Shove.targetRefusal(target({ sinceTargetShoved = 4 }))
			config.BumpSameTargetSeconds, config.ShoveTargetImmuneSeconds = same, immune
			expect(sameWait).to.equal("Give them a break")
			expect(sameDone).never.to.be.ok()
			expect(immuneWait).to.equal("They were just tackled")
			expect(immuneDone).never.to.be.ok()
		end)
	end)

	describe("the lunge's reach (inReach)", function()
		local START = Vector3.new(0, 3, 0)
		local AHEAD = Vector3.new(0, 0, -1)
		local reach = Config.TackleHitRadiusStuds + Config.TackleHitSlackStuds

		it(
			"hits a player within the radius plus the slack of the tackler, wherever it is on the lunge",
			function()
				local at = START + AHEAD * 8
				expect(Shove.inReach(START, AHEAD, at, at + AHEAD * reach)).to.equal(true)
				expect(Shove.inReach(START, AHEAD, at, at + AHEAD * (reach + 0.01))).to.equal(false)
				expect(Shove.inReach(START, AHEAD, at, at + Vector3.new(reach, 0, 0))).to.equal(
					true
				)
			end
		)

		it("never someone behind where the lunge started", function()
			expect(Shove.inReach(START, AHEAD, START, START - AHEAD * 1)).to.equal(false)
			expect(Shove.inReach(START, AHEAD, START, START + Vector3.new(2, 0, 0))).to.equal(true)
		end)

		it(
			"a tackler seen farther than the lunge plus the slack from the start reaches nobody (teleports)",
			function()
				local edge = Config.TackleLungeStuds + Config.TackleHitSlackStuds
				local far = START + AHEAD * edge
				expect(Shove.inReach(START, AHEAD, far, far)).to.equal(true)
				local beyond = START + AHEAD * (edge + 0.01)
				expect(Shove.inReach(START, AHEAD, beyond, beyond)).to.equal(false)
			end
		)

		it("a lunge of 12 studs in 0.35 s, never on E or Space (the button's key is Q)", function()
			expect(Config.TackleLungeStuds).to.equal(12)
			expect(Config.TackleLungeSeconds).to.equal(0.35)
		end)
	end)

	describe("knocking a carried cat loose", function()
		local function carry(startedAt: number, immuneUntil: number?): Shove.CarryState
			return { startedAt = startedAt, immuneUntil = immuneUntil or 0 }
		end

		it("rolls only on a carrier", function()
			expect(Shove.canKnockLoose(nil, 100)).to.equal(false)
		end)

		it(
			"from the first moment of a carry: a landed tackle always drops the cat (#2193, no grace)",
			function()
				expect(Config.BumpGraceSeconds).to.equal(0)
				expect(Shove.canKnockLoose(carry(100), 100)).to.equal(true)
				expect(Shove.canKnockLoose(carry(100), 100.01)).to.equal(true)
			end
		)

		it("a picked-up cat's carry is like any other: no BumpImmune (v0.8 F56)", function()
			expect(Shove.canKnockLoose(carry(1000), 1000)).to.equal(true)
		end)

		it("never while the held immunity lasts (BumpChance below 1 only)", function()
			expect(Shove.canKnockLoose(carry(0, 100), 99.9)).to.equal(false)
			expect(Shove.canKnockLoose(carry(0, 100), 100)).to.equal(true)
			expect(Shove.HELD_IMMUNE_SECONDS).to.equal(3)
		end)

		it("always knocks it loose: BumpChance is 1.0 (v0.8 F56)", function()
			expect(Config.BumpChance).to.equal(1)
			for _, roll in { 0, 0.5, 0.999999 } do
				expect(Shove.landsLoose(roll)).to.equal(true)
			end
		end)

		it("the cat no longer scurries: it lands where the carrier stood (v0.8 F56)", function()
			expect((Shove :: any).scurryStuds).never.to.be.ok()
			expect((Shove :: any).SCURRY_MIN).never.to.be.ok()
			expect((Shove :: any).SCURRY_MAX).never.to.be.ok()
		end)

		it("the push points from the shover to the target, flat", function()
			local d =
				Shove.direction(Vector3.new(0, 5, 0), Vector3.new(3, 0, 4), Vector3.new(1, 0, 0))
			expect(d.X).to.be.near(0.6, 1e-6)
			expect(d.Y).to.equal(0)
			expect(d.Z).to.be.near(0.8, 1e-6)
		end)

		it("on top of each other, the push takes the fallback", function()
			local d =
				Shove.direction(Vector3.new(1, 0, 1), Vector3.new(1, 3, 1), Vector3.new(0, 0, -1))
			expect(d.Z).to.equal(-1)
		end)
	end)

	describe("the getaway burst (v0.8 F55)", function()
		it(
			"reaches players within CatchBurstRadiusStuds of the catcher, root to root, and no farther",
			function()
				local at = Vector3.new(10, 3, 10)
				local r = Config.CatchBurstRadiusStuds
				expect(Shove.inBurst(at, at + Vector3.new(r - 0.1, 0, 0))).to.equal(true)
				expect(Shove.inBurst(at, at + Vector3.new(0, 0, r))).to.equal(true)
				expect(Shove.inBurst(at, at + Vector3.new(r + 0.1, 0, 0))).to.equal(false)
				expect(Shove.inBurst(at, at + Vector3.new(6, 9, 0))).to.equal(false) -- a roof above is out of reach
				expect(Shove.inBurst(at, at)).to.equal(true)
			end
		)
	end)

	-- A pick up that starts the carry: a Dropped stray next to an idle player in an open, unlocked area.
	local function pickUp(): Shove.PickUpCheck
		return {
			dropped = true,
			carrying = false,
			busy = false,
			areaUnlocked = true,
			areasClosed = false,
			distance = 4,
			sinceGrab = nil,
		}
	end

	local function pickUpWith(changes: { [string]: any }): Shove.PickUpCheck
		local check = pickUp() :: any
		for key, value in changes do
			check[key] = if value == NONE then nil else value
		end
		return check :: Shove.PickUpCheck
	end

	describe("a Dropped cat (v0.8 F56)", function()
		it("records its last carrier and the shover, with no owner window (S25)", function()
			local drop = Shove.newDrop(11, 22, 100) :: any
			expect(drop.owner).to.equal(11)
			expect(drop.shover).to.equal(22)
			expect(drop.droppedAt).to.equal(100)
			expect(drop.ownerUntil).never.to.be.ok()
		end)

		it(
			"anyone picks it up: the shover, the last carrier and everyone else are the same check",
			function()
				expect(Shove.pickUpRefusal(pickUp())).never.to.be.ok()
			end
		)

		it("only a Dropped stray: any other needs the circles", function()
			expect(Shove.pickUpRefusal(pickUpWith({ dropped = false }))).to.be.ok()
		end)

		it("not while carrying a cat", function()
			expect(Shove.pickUpRefusal(pickUpWith({ carrying = true }))).to.be.ok()
		end)

		it("not while holding a catch or rescue lock", function()
			expect(Shove.pickUpRefusal(pickUpWith({ busy = true }))).to.be.ok()
		end)

		it("only in an area the caller's tier opens", function()
			expect(Shove.pickUpRefusal(pickUpWith({ areaUnlocked = false }))).to.be.ok()
		end)

		it("never at night, when the areas are closed (v0.9, F66)", function()
			expect(Shove.pickUpRefusal(pickUpWith({ areasClosed = true }))).to.equal(
				Clock.CLOSED_TEXT
			)
		end)

		it("range is GrabRangeStuds plus the usual 2 studs of slack", function()
			local edge = Config.GrabRangeStuds + Shove.RANGE_SLACK
			expect(Shove.pickUpRefusal(pickUpWith({ distance = edge }))).never.to.be.ok()
			expect(Shove.pickUpRefusal(pickUpWith({ distance = edge + 0.01 }))).to.be.ok()
			expect(Shove.pickUpRefusal(pickUpWith({ distance = NONE }))).to.be.ok()
		end)

		it("GrabCooldownSeconds after the caller's last catch or pick up", function()
			local cooldown = Config.GrabCooldownSeconds
			expect(Shove.pickUpRefusal(pickUpWith({ sinceGrab = cooldown - 0.01 }))).to.be.ok()
			expect(Shove.pickUpRefusal(pickUpWith({ sinceGrab = cooldown }))).never.to.be.ok()
		end)
	end)

	describe("section 10c numbers", function()
		it(
			"DroppedMinStaySeconds is gone: dusk checks a dropped cat in for its carrier (v0.9, F66)",
			function()
				expect((Config :: any).DroppedMinStaySeconds).never.to.be.ok()
				expect((Shove :: any).leavesWithWave).never.to.be.ok()
			end
		)

		it("the owner window and the shover bar are gone (v0.8 F56)", function()
			expect((Config :: any).DropOwnerPrioritySeconds).never.to.be.ok()
			expect((Shove :: any).grabRefusal).never.to.be.ok()
			expect((Shove :: any).sprintsAfterMiss).never.to.be.ok()
		end)

		it(
			"the F56 acceptance tug of war goes on, each tackler on their own cooldown (#2193)",
			function()
				-- t = 0: A shoves carrier B and the cat drops; A picks it up at 0.6.
				local pickedUp = 0.6
				-- B shoves A straight back (#2193: no grace): B never shoved before, nobody shoved A.
				local backAt = pickedUp + 0.1
				local carryA: Shove.CarryState = { startedAt = pickedUp, immuneUntil = 0 }
				expect(Shove.tackleRefusal(press())).never.to.be.ok()
				expect(Shove.targetRefusal(target())).never.to.be.ok()
				expect(Shove.canKnockLoose(carryA, backAt)).to.equal(true)
				-- B picks it back up at 1.3. A hit B at 0, so A waits only TackleCooldownSeconds (5) from that press, and
				-- then the lunge hits B, who carries, though A hit them 5 s ago and B was hit 0.7 s before that pick up.
				local cooldown = Config.TackleCooldownSeconds
				expect(Shove.tackleRefusal(press({ sinceTackle = cooldown - 0.01 }))).to.be.ok()
				expect(Shove.tackleRefusal(press({ sinceTackle = cooldown }))).never.to.be.ok()
				expect(
					Shove.targetRefusal(
						target({ sinceShoveTarget = cooldown, sinceTargetShoved = cooldown })
					)
				).never.to.be.ok()
				local carryB: Shove.CarryState = { startedAt = 1.3, immuneUntil = 0 }
				expect(Shove.canKnockLoose(carryB, cooldown)).to.equal(true)
			end
		)
	end)

	describe("edges (QA)", function()
		-- Each rule broken on its own, in the order Shove checks them (v0.11 F74 split the shove's list into the press
		-- and the target).
		local pressBroken: { { [string]: any } } = {
			{ carrying = true },
			{ busy = true },
			{ newcomer = true }, -- F87
			{ area = NONE },
			{ areaUnlocked = false },
			{ areasClosed = true },
			{ sinceTackle = 0 },
		}
		local targetBroken: { { [string]: any } } = {
			{ self = true },
			{ sameArea = false },
			{ targetBusy = true },
			{ targetFlying = true }, -- F84
			{ targetNewcomer = true }, -- F87
			{ targetShielded = true }, -- #3342
			-- sinceShoveTarget and sinceTargetShoved break nothing since #2193 (both waits are 0); the tuned-up test
			-- in "who the lunge hits" keeps their words apart
		}

		local function merged(
			first: { [string]: any },
			second: { [string]: any }
		): { [string]: any }
			local both: { [string]: any } = {}
			for key, value in second do
				both[key] = value
			end
			for key, value in first do
				both[key] = value
			end
			return both
		end

		it("every rule has its own words, so the tackler can tell them apart", function()
			local seen: { [string]: boolean } = {}
			for _, changes in pressBroken do
				local reason = Shove.tackleRefusal(press(changes)) :: string
				expect(type(reason)).to.equal("string")
				expect(seen[reason]).never.to.be.ok()
				seen[reason] = true
			end
			for _, changes in targetBroken do
				local reason = Shove.targetRefusal(target(changes)) :: string
				expect(type(reason)).to.equal("string")
				expect(seen[reason]).never.to.be.ok()
				seen[reason] = true
			end
		end)

		it("with two rules broken, the earlier one names the refusal", function()
			for first = 1, #pressBroken do
				for second = first + 1, #pressBroken do
					local both = merged(pressBroken[first], pressBroken[second])
					expect(Shove.tackleRefusal(press(both))).to.equal(
						Shove.tackleRefusal(press(pressBroken[first]))
					)
				end
			end
			for first = 1, #targetBroken do
				for second = first + 1, #targetBroken do
					local both = merged(targetBroken[first], targetBroken[second])
					expect(Shove.targetRefusal(target(both))).to.equal(
						Shove.targetRefusal(target(targetBroken[first]))
					)
				end
			end
		end)

		-- Each pick up rule broken on its own, in Shove.pickUpRefusal's order (v0.8 F56).
		local pickUpBroken: { { [string]: any } } = {
			{ dropped = false },
			{ carrying = true },
			{ busy = true },
			{ inCamp = true }, -- F84
			{ areaUnlocked = false },
			{ areasClosed = true },
			{ distance = 50 },
			{ sinceGrab = 0 },
		}

		it("every pick up rule has its own words", function()
			local seen: { [string]: boolean } = {}
			for _, changes in pickUpBroken do
				local reason = Shove.pickUpRefusal(pickUpWith(changes)) :: string
				expect(type(reason)).to.equal("string")
				expect(#reason > 0).to.equal(true)
				expect(seen[reason]).never.to.be.ok()
				seen[reason] = true
			end
		end)

		it("with two pick up rules broken, the earlier one names the refusal", function()
			for first = 1, #pickUpBroken do
				for second = first + 1, #pickUpBroken do
					local both: { [string]: any } = {}
					for key, value in pickUpBroken[second] do
						both[key] = value
					end
					for key, value in pickUpBroken[first] do
						both[key] = value
					end
					expect(Shove.pickUpRefusal(pickUpWith(both))).to.equal(
						Shove.pickUpRefusal(pickUpWith(pickUpBroken[first]))
					)
				end
			end
		end)

		it("the push is flat and one stud long whatever the heights", function()
			local d = Shove.direction(
				Vector3.new(0, -40, 0),
				Vector3.new(10, 90, 0),
				Vector3.new(0, 0, 1)
			)
			expect(d.Y).to.equal(0)
			expect(d.Magnitude).to.be.near(1, 1e-9)
		end)

		-- 2,000 seeded lunges in every direction and at any height against the reach rule said another way (v0.11
		-- F74): never a player behind the start, never one past the lunge plus the hit radius and both slacks, and
		-- a tackler the server sees past the lunge plus the slack reaches nobody.
		it(
			"a lunge never reaches behind its start or past 18 studs from it, whatever the facing",
			function()
				local rng = Random.new(74)
				local slack = Config.TackleHitSlackStuds
				local radius = Config.TackleHitRadiusStuds + slack
				local cap = Config.TackleLungeStuds + slack
				local hits = 0
				for _ = 1, 2000 do
					local start = Vector3.new(
						rng:NextNumber(-500, 500),
						rng:NextNumber(0, 40),
						rng:NextNumber(-500, 500)
					)
					local angle = rng:NextNumber(0, 2 * math.pi)
					local facing = Vector3.new(math.sin(angle), 0, math.cos(angle))
					local at = start
						+ Vector3.new(
							rng:NextNumber(-16, 16),
							rng:NextNumber(-3, 3),
							rng:NextNumber(-16, 16)
						)
					local victim = at
						+ Vector3.new(
							rng:NextNumber(-6, 6),
							rng:NextNumber(-3, 3),
							rng:NextNumber(-6, 6)
						)
					local ahead = Vector3.new(victim.X - start.X, 0, victim.Z - start.Z):Dot(facing)
					local want = (at - start).Magnitude <= cap
						and (victim - at).Magnitude <= radius
						and ahead >= 0
					local hit = Shove.inReach(start, facing, at, victim)
					expect(hit).to.equal(want)
					if hit then
						hits += 1
						expect((victim - start).Magnitude <= cap + radius).to.equal(true)
					end
				end
				expect(cap + radius).to.equal(18)
				expect(hits > 100 and hits < 1900).to.equal(true)
			end
		)
	end)
	describe("lag-tolerant reach (#2193)", function()
		local start = Vector3.new(0, 3, 0)
		local facing = Vector3.new(0, 0, -1)
		it(
			"hits a target the server saw in reach a moment ago, though it has run on since",
			function()
				local at = Vector3.new(0, 3, -10)
				local now = Vector3.new(6, 3, -10) -- ran out of the radius
				local before = Vector3.new(2, 3, -10) -- where the server had them a tick or two back
				expect(Shove.inReach(start, facing, at, now)).to.equal(false)
				expect(Shove.inReachAny(start, facing, at, { now, before })).to.equal(before)
			end
		)

		it(
			"misses when none of the recent positions is in reach, or all are behind the start",
			function()
				local at = Vector3.new(0, 3, -10)
				expect(
					Shove.inReachAny(
						start,
						facing,
						at,
						{ Vector3.new(9, 3, -10), Vector3.new(8, 3, -10) }
					)
				).to.equal(nil)
				expect(Shove.inReachAny(start, facing, start, { Vector3.new(0, 3, 2) })).to.equal(
					nil
				)
				expect(Shove.inReachAny(start, facing, at, {})).to.equal(nil)
			end
		)

		it("looks back a short time only", function()
			expect(Shove.LAG_SECONDS > 0 and Shove.LAG_SECONDS <= 0.5).to.equal(true)
		end)
	end)
end
