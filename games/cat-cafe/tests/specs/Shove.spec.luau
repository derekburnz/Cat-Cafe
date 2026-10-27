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

	-- A shove that lands: both in the Alleyway, close, nobody busy, nothing shoved before.
	local function ok(): Shove.Check
		return {
			self = false,
			shoverCarrying = false,
			shoverBusy = false,
			shoverArea = "alley",
			targetArea = "alley",
			areaUnlocked = true,
			areasClosed = false,
			distance = 3,
			targetBusy = false,
			targetSafe = false,
			sinceShove = nil,
			sinceShoveTarget = nil,
			sinceTargetShoved = nil,
		}
	end

	-- A table literal drops nil fields, so NONE stands for "set this field to nil".
	local NONE = table.freeze({})
	local function with(changes: { [string]: any }): Shove.Check
		local check = ok() :: any
		for key, value in changes do
			check[key] = if value == NONE then nil else value
		end
		return check :: Shove.Check
	end

	describe("refusal (section 10c)", function()
		it("a shove between two players in one unlocked area, in range, lands", function()
			expect(Shove.refusal(ok())).never.to.be.ok()
		end)

		it("nobody shoves themselves", function()
			expect(Shove.refusal(with({ self = true }))).to.be.ok()
		end)

		it("a carrier cannot shove", function()
			expect(Shove.refusal(with({ shoverCarrying = true }))).to.be.ok()
		end)

		it("nobody shoves from a catch or rescue (N85)", function()
			expect(Shove.refusal(with({ shoverBusy = true }))).to.be.ok()
		end)

		it("only inside one catching area: not on the street, not across two areas", function()
			expect(Shove.refusal(with({ shoverArea = NONE, targetArea = NONE }))).to.be.ok()
			expect(Shove.refusal(with({ targetArea = NONE }))).to.be.ok()
			expect(Shove.refusal(with({ shoverArea = NONE }))).to.be.ok()
			expect(Shove.refusal(with({ targetArea = "park" }))).to.be.ok()
		end)

		it("only in an area the shover's tier opens", function()
			expect(Shove.refusal(with({ areaUnlocked = false }))).to.be.ok()
		end)

		it("never at night, when the areas are closed (v0.9, F66)", function()
			expect(Shove.refusal(with({ areasClosed = true }))).to.equal(Clock.CLOSED_TEXT)
		end)

		it("range is BumpRangeStuds plus the usual 2 studs of slack", function()
			local edge = Config.BumpRangeStuds + Shove.RANGE_SLACK
			expect(Shove.refusal(with({ distance = edge }))).never.to.be.ok()
			expect(Shove.refusal(with({ distance = edge + 0.01 }))).to.be.ok()
			expect(Shove.refusal(with({ distance = NONE }))).to.be.ok()
		end)

		it("never on a player inside a catch or rescue minigame", function()
			expect(Shove.refusal(with({ targetBusy = true }))).to.be.ok()
		end)

		it("never near the target's own cafe", function()
			expect(Shove.refusal(with({ targetSafe = true }))).to.be.ok()
		end)

		it("the shover waits BumpCooldownSeconds between shoves", function()
			local cooldown = Config.BumpCooldownSeconds
			expect(Shove.refusal(with({ sinceShove = cooldown - 0.01 }))).to.be.ok()
			expect(Shove.refusal(with({ sinceShove = cooldown }))).never.to.be.ok()
		end)

		it("and BumpSameTargetSeconds before shoving the same player again", function()
			local wait = Config.BumpSameTargetSeconds
			expect(Shove.refusal(with({ sinceShoveTarget = wait - 0.01 }))).to.be.ok()
			expect(Shove.refusal(with({ sinceShoveTarget = wait }))).never.to.be.ok()
		end)

		it(
			"nobody shoves a player for ShoveTargetImmuneSeconds after any shove lands on them (S45)",
			function()
				local immune = Config.ShoveTargetImmuneSeconds
				expect(Shove.refusal(with({ sinceTargetShoved = immune - 0.01 }))).to.be.ok()
				expect(Shove.refusal(with({ sinceTargetShoved = immune }))).never.to.be.ok()
			end
		)

		it("every reason is words for the shover", function()
			local cases: { { [string]: any } } = {
				{ self = true },
				{ shoverCarrying = true },
				{ shoverBusy = true },
				{ targetArea = "park" },
				{ areaUnlocked = false },
				{ distance = 50 },
				{ targetBusy = true },
				{ targetSafe = true },
				{ sinceShove = 0 },
				{ sinceShoveTarget = 0 },
				{ sinceTargetShoved = 0 },
			}
			for _, changes in cases do
				local reason = Shove.refusal(with(changes))
				expect(type(reason)).to.equal("string")
				expect(#(reason :: string) > 0).to.equal(true)
			end
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
			expect(Shove.refusal(ok())).never.to.be.ok()
			expect(Shove.canKnockLoose(carryA, backAt - 0.01)).to.equal(false)
			expect(Shove.canKnockLoose(carryA, backAt)).to.equal(true)
			-- B picks it back up. A is off BumpCooldownSeconds (8) at 12 s but shoved B at 0, so waits 20 s.
			local again = with({ sinceShove = 12, sinceShoveTarget = 12, sinceTargetShoved = 12 })
			expect(Shove.refusal(again)).to.equal("Give them a break")
			local wait = Config.BumpSameTargetSeconds
			local later = with({ sinceShove = wait, sinceShoveTarget = wait, sinceTargetShoved = wait })
			expect(Shove.refusal(later)).never.to.be.ok()
		end)

		it("the same-target wait is longer than the shover's cooldown", function()
			expect(Config.BumpSameTargetSeconds > Config.BumpCooldownSeconds).to.equal(true)
		end)
	end)

	describe("edges (QA)", function()
		-- Each rule broken on its own, in the order section 10c lists them.
		local broken: { { [string]: any } } = {
			{ self = true },
			{ shoverCarrying = true },
			{ shoverBusy = true },
			{ targetArea = "park" },
			{ areaUnlocked = false },
			{ distance = 50 },
			{ targetBusy = true },
			{ targetSafe = true },
			{ sinceShove = 0 },
			{ sinceShoveTarget = 0 },
			{ sinceTargetShoved = 0 },
		}

		it("every rule has its own words, so the shover can tell them apart", function()
			local seen: { [string]: boolean } = {}
			for _, changes in broken do
				local reason = Shove.refusal(with(changes)) :: string
				expect(seen[reason]).never.to.be.ok()
				seen[reason] = true
			end
		end)

		it("with two rules broken, the earlier one in section 10c names the refusal", function()
			for first = 1, #broken do
				for second = first + 1, #broken do
					local both: { [string]: any } = {}
					for key, value in broken[second] do
						both[key] = value
					end
					for key, value in broken[first] do
						both[key] = value
					end
					expect(Shove.refusal(with(both))).to.equal(Shove.refusal(with(broken[first])))
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
	end)
end
