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
		targetSafe = false,
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
			expect(cooldown).to.equal(8)
			expect(Shove.tackleRefusal(press({ sinceTackle = cooldown - 0.01 }))).to.be.ok()
			expect(Shove.tackleRefusal(press({ sinceTackle = cooldown }))).never.to.be.ok()
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

		it("passes through a player near their own cafe", function()
			expect(Shove.targetRefusal(target({ targetSafe = true }))).to.be.ok()
		end)

		it("BumpSameTargetSeconds before this tackler hits the same player again", function()
			local wait = Config.BumpSameTargetSeconds
			expect(Shove.targetRefusal(target({ sinceShoveTarget = wait - 0.01 }))).to.be.ok()
			expect(Shove.targetRefusal(target({ sinceShoveTarget = wait }))).never.to.be.ok()
		end)

		it("nobody hits a player for ShoveTargetImmuneSeconds after any hit lands on them (S45)", function()
			local immune = Config.ShoveTargetImmuneSeconds
			expect(Shove.targetRefusal(target({ sinceTargetShoved = immune - 0.01 }))).to.be.ok()
			expect(Shove.targetRefusal(target({ sinceTargetShoved = immune }))).never.to.be.ok()
		end)
	end)

	describe("the lunge's reach (inReach)", function()
		local START = Vector3.new(0, 3, 0)
		local AHEAD = Vector3.new(0, 0, -1)
		local reach = Config.TackleHitRadiusStuds + Config.TackleHitSlackStuds

		it("hits a player within the radius plus the slack of the tackler, wherever it is on the lunge", function()
			local at = START + AHEAD * 8
			expect(Shove.inReach(START, AHEAD, at, at + AHEAD * reach)).to.equal(true)
			expect(Shove.inReach(START, AHEAD, at, at + AHEAD * (reach + 0.01))).to.equal(false)
			expect(Shove.inReach(START, AHEAD, at, at + Vector3.new(reach, 0, 0))).to.equal(true)
		end)

		it("never someone behind where the lunge started", function()
			expect(Shove.inReach(START, AHEAD, START, START - AHEAD * 1)).to.equal(false)
			expect(Shove.inReach(START, AHEAD, START, START + Vector3.new(2, 0, 0))).to.equal(true)
		end)

		it("a tackler seen farther than the lunge plus the slack from the start reaches nobody (teleports)", function()
			local edge = Config.TackleLungeStuds + Config.TackleHitSlackStuds
			local far = START + AHEAD * edge
			expect(Shove.inReach(START, AHEAD, far, far)).to.equal(true)
			local beyond = START + AHEAD * (edge + 0.01)
			expect(Shove.inReach(START, AHEAD, beyond, beyond)).to.equal(false)
		end)

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

		it("never in the first BumpGraceSeconds of a carry", function()
			local grace = Config.BumpGraceSeconds
			expect(Shove.canKnockLoose(carry(100), 100 + grace - 0.01)).to.equal(false)
			expect(Shove.canKnockLoose(carry(100), 100 + grace)).to.equal(true)
		end)

		it("a picked-up cat's carry is like any other: no BumpImmune once the grace passes (v0.8 F56)", function()
			local grace = Config.BumpGraceSeconds
			expect(Shove.canKnockLoose(carry(1000), 1000 + grace - 0.01)).to.equal(false)
			expect(Shove.canKnockLoose(carry(1000), 1000 + grace)).to.equal(true)
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
		it("reaches players within CatchBurstRadiusStuds of the catcher, root to root, and no farther", function()
			local at = Vector3.new(10, 3, 10)
			local r = Config.CatchBurstRadiusStuds
			expect(Shove.inBurst(at, at + Vector3.new(r - 0.1, 0, 0))).to.equal(true)
			expect(Shove.inBurst(at, at + Vector3.new(0, 0, r))).to.equal(true)
			expect(Shove.inBurst(at, at + Vector3.new(r + 0.1, 0, 0))).to.equal(false)
			expect(Shove.inBurst(at, at + Vector3.new(6, 9, 0))).to.equal(false) -- a roof above is out of reach
			expect(Shove.inBurst(at, at)).to.equal(true)
		end)
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
		it("DroppedMinStaySeconds is gone: dusk checks a dropped cat in for its carrier (v0.9, F66)", function()
			expect((Config :: any).DroppedMinStaySeconds).never.to.be.ok()
			expect((Shove :: any).leavesWithWave).never.to.be.ok()
		end)

		it("the owner window and the shover bar are gone (v0.8 F56)", function()
			expect((Config :: any).DropOwnerPrioritySeconds).never.to.be.ok()
			expect((Shove :: any).grabRefusal).never.to.be.ok()
			expect((Shove :: any).sprintsAfterMiss).never.to.be.ok()
		end)

		it("the F56 acceptance tug of war ends on the same-target wait", function()
			-- t = 0: A shoves carrier B and the cat drops; A picks it up at 0.6.
			local pickedUp = 0.6
			-- B shoves A once A's carry is BumpGraceSeconds (3) old: B never shoved before, nobody shoved A.
			local backAt = pickedUp + Config.BumpGraceSeconds
			local carryA: Shove.CarryState = { startedAt = pickedUp, immuneUntil = 0 }
			expect(Shove.tackleRefusal(press())).never.to.be.ok()
			expect(Shove.targetRefusal(target())).never.to.be.ok()
			expect(Shove.canKnockLoose(carryA, backAt - 0.01)).to.equal(false)
			expect(Shove.canKnockLoose(carryA, backAt)).to.equal(true)
			-- B picks it back up. At 12 s A is off TackleCooldownSeconds (8) but hit B at 0, so the lunge passes
			-- through B until 20 s.
			expect(Shove.tackleRefusal(press({ sinceTackle = 12 }))).never.to.be.ok()
			local again = target({ sinceShoveTarget = 12, sinceTargetShoved = 12 })
			expect(Shove.targetRefusal(again)).to.equal("Give them a break")
			local wait = Config.BumpSameTargetSeconds
			expect(Shove.targetRefusal(target({ sinceShoveTarget = wait, sinceTargetShoved = wait }))).never.to.be.ok()
		end)

		it("the same-target wait is longer than the tackler's cooldown", function()
			expect(Config.BumpSameTargetSeconds > Config.TackleCooldownSeconds).to.equal(true)
		end)
	end)

	describe("edges (QA)", function()
		-- Each rule broken on its own, in the order Shove checks them (v0.11 F74 split the shove's list into the press
		-- and the target).
		local pressBroken: { { [string]: any } } = {
			{ carrying = true },
			{ busy = true },
			{ area = NONE },
			{ areaUnlocked = false },
			{ areasClosed = true },
			{ sinceTackle = 0 },
		}
		local targetBroken: { { [string]: any } } = {
			{ self = true },
			{ sameArea = false },
			{ targetBusy = true },
			{ targetSafe = true },
			{ sinceShoveTarget = 0 },
			{ sinceTargetShoved = 0 },
		}

		local function merged(first: { [string]: any }, second: { [string]: any }): { [string]: any }
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
					expect(Shove.tackleRefusal(press(both))).to.equal(Shove.tackleRefusal(press(pressBroken[first])))
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
		it("a lunge never reaches behind its start or past 18 studs from it, whatever the facing", function()
			local rng = Random.new(74)
			local slack = Config.TackleHitSlackStuds
			local radius = Config.TackleHitRadiusStuds + slack
			local cap = Config.TackleLungeStuds + slack
			local hits = 0
			for _ = 1, 2000 do
				local start = Vector3.new(rng:NextNumber(-500, 500), rng:NextNumber(0, 40), rng:NextNumber(-500, 500))
				local angle = rng:NextNumber(0, 2 * math.pi)
				local facing = Vector3.new(math.sin(angle), 0, math.cos(angle))
				local at = start + Vector3.new(rng:NextNumber(-16, 16), rng:NextNumber(-3, 3), rng:NextNumber(-16, 16))
				local victim = at + Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-3, 3), rng:NextNumber(-6, 6))
				local ahead = Vector3.new(victim.X - start.X, 0, victim.Z - start.Z):Dot(facing)
				local want = (at - start).Magnitude <= cap and (victim - at).Magnitude <= radius and ahead >= 0
				local hit = Shove.inReach(start, facing, at, victim)
				expect(hit).to.equal(want)
				if hit then
					hits += 1
					expect((victim - start).Magnitude <= cap + radius).to.equal(true)
				end
			end
			expect(cap + radius).to.equal(18)
			expect(hits > 100 and hits < 1900).to.equal(true)
		end)
	end)
end
