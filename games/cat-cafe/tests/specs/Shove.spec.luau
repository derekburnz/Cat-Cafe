--!strict
-- shared/Shove.luau against data-model section 10c (F29's carry bumps as v0.5 F41 and v0.5.1): every protection on
-- a shove, the knock-loose roll on a carrier, and the rules of a knocked-loose cat (owner window, shover barred,
-- still during the window per N86, kept through an early night wave per S32).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
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

		it("nobody shoves a player for ShoveTargetImmuneSeconds after any shove lands on them (S45)", function()
			local immune = Config.ShoveTargetImmuneSeconds
			expect(Shove.refusal(with({ sinceTargetShoved = immune - 0.01 }))).to.be.ok()
			expect(Shove.refusal(with({ sinceTargetShoved = immune }))).never.to.be.ok()
		end)

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
		local function carry(startedAt: number, immune: boolean?, immuneUntil: number?): Shove.CarryState
			return { startedAt = startedAt, immune = immune == true, immuneUntil = immuneUntil or 0 }
		end

		it("rolls only on a carrier", function()
			expect(Shove.canKnockLoose(nil, 100)).to.equal(false)
		end)

		it("never in the first BumpGraceSeconds of a carry", function()
			local grace = Config.BumpGraceSeconds
			expect(Shove.canKnockLoose(carry(100), 100 + grace - 0.01)).to.equal(false)
			expect(Shove.canKnockLoose(carry(100), 100 + grace)).to.equal(true)
		end)

		it("never on whoever re-caught a knocked-loose cat, for the whole carry", function()
			expect(Shove.canKnockLoose(carry(0, true), 1000)).to.equal(false)
		end)

		it("never while the held immunity lasts", function()
			expect(Shove.canKnockLoose(carry(0, false, 100), 99.9)).to.equal(false)
			expect(Shove.canKnockLoose(carry(0, false, 100), 100)).to.equal(true)
			expect(Shove.HELD_IMMUNE_SECONDS).to.equal(3)
		end)

		it("knocks it loose BumpChance of the time", function()
			expect(Shove.landsLoose(0)).to.equal(true)
			expect(Shove.landsLoose(Config.BumpChance - 0.001)).to.equal(true)
			expect(Shove.landsLoose(Config.BumpChance)).to.equal(false)
			expect(Shove.landsLoose(0.999)).to.equal(false)
		end)

		it("the cat scurries 6 to 10 studs", function()
			expect(Shove.scurryStuds(0)).to.equal(6)
			expect(Shove.scurryStuds(1)).to.equal(10)
			expect(Shove.scurryStuds(0.5)).to.equal(8)
			expect(Shove.scurryStuds(-1)).to.equal(6)
		end)

		it("the push points from the shover to the target, flat", function()
			local d = Shove.direction(Vector3.new(0, 5, 0), Vector3.new(3, 0, 4), Vector3.new(1, 0, 0))
			expect(d.X).to.be.near(0.6, 1e-6)
			expect(d.Y).to.equal(0)
			expect(d.Z).to.be.near(0.8, 1e-6)
		end)

		it("on top of each other, the push takes the fallback", function()
			local d = Shove.direction(Vector3.new(1, 0, 1), Vector3.new(1, 3, 1), Vector3.new(0, 0, -1))
			expect(d.Z).to.equal(-1)
		end)
	end)

	describe("a knocked-loose cat", function()
		local drop = Shove.newDrop(11, 22, 100)

		it("records its old carrier, the shover and the owner window (S25)", function()
			expect(drop.owner).to.equal(11)
			expect(drop.shover).to.equal(22)
			expect(drop.droppedAt).to.equal(100)
			expect(drop.ownerUntil).to.be.near(100 + Config.DropOwnerPrioritySeconds, 1e-9)
		end)

		it("only its old carrier may try during the window", function()
			local reason, retry = Shove.grabRefusal(drop, 33, 104)
			expect(reason).to.be.ok()
			expect(retry).to.equal(true)
			expect((Shove.grabRefusal(drop, 11, 104))).never.to.be.ok()
		end)

		it("anyone but the shover may try after the window", function()
			expect((Shove.grabRefusal(drop, 33, 108))).never.to.be.ok()
			expect((Shove.grabRefusal(drop, 11, 108))).never.to.be.ok()
		end)

		it("the shover never may, and their prompt closes", function()
			for _, now in { 100, 104, 108, 10000 } do
				local reason, retry = Shove.grabRefusal(drop, 22, now)
				expect(reason).to.be.ok()
				expect(retry).to.equal(false)
			end
		end)

		it("a drop by nobody (Studio's hook) bars nobody", function()
			local free = Shove.newDrop(11, 0, 100)
			expect((Shove.grabRefusal(free, 0, 200))).never.to.be.ok()
			expect((Shove.grabRefusal(free, 33, 200))).never.to.be.ok()
		end)

		it("an ordinary stray refuses nobody", function()
			expect((Shove.grabRefusal(nil, 33, 0))).never.to.be.ok()
		end)

		it("stays put after a miss while the owner window runs, then sprints like any stray (N86)", function()
			expect(Shove.sprintsAfterMiss(drop, 107.9)).to.equal(false)
			expect(Shove.sprintsAfterMiss(drop, 108)).to.equal(true)
			expect(Shove.sprintsAfterMiss(nil, 0)).to.equal(true)
		end)

		it("survives a night wave that starts within DroppedMinStaySeconds of the drop (S32)", function()
			local stay = Config.DroppedMinStaySeconds
			expect(Shove.leavesWithWave(drop, 100 + stay - 0.01)).to.equal(false)
			expect(Shove.leavesWithWave(drop, 100 + stay)).to.equal(true)
			expect(Shove.leavesWithWave(nil, 0)).to.equal(true)
		end)
	end)

	describe("section 10c numbers", function()
		it("the owner window is shorter than the minimum stay, so a wave never eats the window", function()
			expect(Config.DropOwnerPrioritySeconds < Config.DroppedMinStaySeconds).to.equal(true)
		end)

		it("the same-target wait is longer than the shover's cooldown", function()
			expect(Config.BumpSameTargetSeconds > Config.BumpCooldownSeconds).to.equal(true)
		end)
	end)
end
