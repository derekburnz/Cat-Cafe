--!strict
-- shared/Rally.luau and the Rescue Rally's Catalog and save rows (F101, rescue-rally.md): the weekend window, the
-- goal, the steps a score passes, the points per play, the save's laps and who a step pays (QA checks 1, 3, 4 and 6).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Rally = require(Shared.Rally)

	local HOUR, DAY = 3600, 86400
	local WEEK = 7 * DAY
	local SAT = 1793404800 -- Saturday 2026-10-31 00:00 UTC
	local TUESDAY = SAT + 3 * DAY + 10 * HOUR

	describe("the Rally weekend (section 1)", function()
		it("starts on Saturday 00:00 UTC and runs 48 hours", function()
			expect(((SAT // DAY) + 4) % 7).to.equal(6) -- the epoch was a Thursday: this is a Saturday
			expect(Rally.weekStart(SAT)).to.equal(SAT)
			expect(Rally.inWindow(SAT)).to.equal(true)
			expect(Rally.inWindow(SAT - 1)).to.equal(false)
			expect(Rally.inWindow(SAT + 48 * HOUR - 1)).to.equal(true)
			expect(Rally.inWindow(SAT + 48 * HOUR)).to.equal(false) -- Monday 00:00
			expect(Rally.inWindow(TUESDAY)).to.equal(false)
			expect(Rally.inWindow(SAT + WEEK + 1)).to.equal(true)
		end)

		it("numbers each week from its Saturday, so Friday is still the week before", function()
			local this = Rally.weekend(SAT)
			expect(Rally.weekend(SAT - 1)).to.equal(this - 1)
			expect(Rally.weekend(TUESDAY)).to.equal(this)
			expect(Rally.weekend(SAT + WEEK - 1)).to.equal(this)
			expect(Rally.weekend(SAT + WEEK)).to.equal(this + 1)
			expect(Rally.weekStart(TUESDAY)).to.equal(SAT)
		end)

		it("says when it ends and when the next starts, and runs at any time when forced", function()
			expect(Rally.endsAt(SAT + HOUR, false)).to.equal(SAT + 48 * HOUR)
			expect(Rally.endsAt(TUESDAY, false)).to.equal(0)
			expect(Rally.endsAt(TUESDAY, true)).to.equal(SAT + WEEK) -- the real one takes over
			expect(Rally.startsAt(SAT - HOUR)).to.equal(SAT)
			expect(Rally.startsAt(SAT + HOUR)).to.equal(SAT)
			expect(Rally.startsAt(TUESDAY)).to.equal(SAT + WEEK)
			expect(Rally.isActive(TUESDAY, false)).to.equal(false)
			expect(Rally.isActive(TUESDAY, true)).to.equal(true)
			expect(Rally.isActive(SAT + HOUR, false)).to.equal(true)
			expect(Config.RallyForce).to.equal(false)
		end)
	end)

	describe("the bar (section 2)", function()
		it("sets the goal at 30 a player, never under three players' worth (QA check 1)", function()
			expect(Rally.goal(0)).to.equal(90)
			expect(Rally.goal(1)).to.equal(90)
			expect(Rally.goal(2)).to.equal(90)
			expect(Rally.goal(3)).to.equal(90)
			expect(Rally.goal(8)).to.equal(240)
		end)

		it("scores 1 for a check-in or a tame and 3 for a rescue or a Team Rescue helper", function()
			expect(Config.RallyPoints :: any).to.deepEqual({ checkIn = 1, tame = 1, rescue = 3, teamRescue = 3 })
			for _, kind in Rally.KINDS do
				expect(Rally.pointsFor(kind) > 0).to.equal(true)
			end
			expect(Rally.pointsFor("rescue")).to.equal(3)
			expect(Rally.pointsFor("teamRescue")).to.equal(3)
			expect(Rally.pointsFor("checkIn")).to.equal(1)
			expect(Rally.pointsFor("tame")).to.equal(1)
			expect(Rally.pointsFor("crate")).to.equal(0)
			expect(Rally.pointsFor("")).to.equal(0)
		end)

		it("names each step a score passes, once, rounding a share up", function()
			expect(Rally.stepAt(1, 90)).to.equal(23)
			expect(Rally.stepAt(2, 90)).to.equal(45)
			expect(Rally.stepAt(3, 90)).to.equal(90)
			expect(Rally.stepAt(1, 240)).to.equal(60)
			expect(Rally.stepsCrossed(0, 22, 90) :: any).to.deepEqual({})
			expect(Rally.stepsCrossed(22, 23, 90) :: any).to.deepEqual({ 1 })
			expect(Rally.stepsCrossed(20, 50, 90) :: any).to.deepEqual({ 1, 2 })
			expect(Rally.stepsCrossed(45, 46, 90) :: any).to.deepEqual({})
			expect(Rally.stepsCrossed(88, 91, 90) :: any).to.deepEqual({ 3 })
			expect(Rally.stepsCrossed(0, 90, 90) :: any).to.deepEqual({ 1, 2, 3 })
			expect(Rally.stepsCrossed(0, 10, 0) :: any).to.deepEqual({})
		end)

		it("fills a 90 point bar with every step once, one point at a time", function()
			local seen: { number } = {}
			for points = 1, 90 do
				for _, index in Rally.stepsCrossed(points - 1, points, 90) do
					table.insert(seen, index)
				end
			end
			expect(seen :: any).to.deepEqual({ 1, 2, 3 })
		end)
	end)

	describe("the prizes (section 3)", function()
		it("pays 5 fish, then 10 and a Money Potion, then a Rally Crate and 15", function()
			expect(#Catalog.rallySteps).to.equal(3)
			expect(Catalog.rallySteps[1] :: any).to.deepEqual({ share = 0.25, prize = { fish = 5 } })
			expect(Catalog.rallySteps[2] :: any).to.deepEqual({
				share = 0.5,
				prize = { fish = 10, potions = { tip_potion = 1 } },
			})
			expect(Catalog.rallySteps[3] :: any).to.deepEqual({
				share = 1,
				prize = { fish = 15, crates = { rally_crate = 1 } },
			})
			expect(Catalog.getCrate("rally_crate")).to.be.ok()
			local potionKnown = false
			for _, potion in Catalog.potions do
				potionKnown = potionKnown or potion.id == "tip_potion"
			end
			expect(potionKnown).to.equal(true)
		end)

		it("pays nobody under 3 points this lap, so a late joiner with 1 point gets nothing (QA check 3)", function()
			local save = Rally.fresh(SAT + HOUR)
			expect(Rally.pays(save, SAT + HOUR, 0, false)).to.equal(false)
			expect(Rally.pays(save, SAT + HOUR, 1, false)).to.equal(false)
			expect(Rally.pays(save, SAT + HOUR, 2, true)).to.equal(false)
			expect(save.laps).to.equal(0)
			expect(Rally.pays(save, SAT + HOUR, 3, false)).to.equal(true)
			expect(save.laps).to.equal(1)
			-- the same lap's later steps pay without counting it again
			expect(Rally.pays(save, SAT + HOUR, 5, true)).to.equal(true)
			expect(save.laps).to.equal(1)
		end)

		it("pays from four laps a weekend, then says so, and starts again the next weekend (QA checks 4 and 6)", function()
			local now = SAT + 5 * HOUR
			local save = Rally.fresh(now)
			for lap = 1, Config.RallyMaxLaps do
				expect(Rally.lapsDone(save, now, false)).to.equal(false)
				expect(Rally.pays(save, now, 10, false)).to.equal(true)
				expect(save.laps).to.equal(lap)
			end
			expect(Rally.pays(save, now, 10, false)).to.equal(false) -- a fifth lap pays nothing
			expect(save.laps).to.equal(Config.RallyMaxLaps)
			expect(Rally.lapsDone(save, now, false)).to.equal(true)
			expect(Rally.lapsDone(save, now, true)).to.equal(false) -- the fourth lap's later steps still pay
			expect(Rally.pays(save, now, 10, true)).to.equal(true)
			local following = SAT + WEEK + HOUR
			expect(Rally.lapsDone(save, following, false)).to.equal(false)
			expect(save.laps).to.equal(0)
			expect(save.weekend).to.equal(Rally.weekend(following))
			expect(Rally.pays(save, following, 3, false)).to.equal(true)
			expect(save.laps).to.equal(1)
		end)
	end)

	describe("the save (section 5, version 26)", function()
		it("keeps whole laps up to the cap and never a weekend from the future", function()
			local now = TUESDAY
			local this = Rally.weekend(now)
			expect(Rally.sanitize(nil, now) :: any).to.deepEqual({ weekend = this, laps = 0 })
			expect(Rally.sanitize("rally", now) :: any).to.deepEqual({ weekend = this, laps = 0 })
			expect(Rally.sanitize({ weekend = this, laps = 2.7 }, now) :: any).to.deepEqual({
				weekend = this,
				laps = 2,
			})
			expect(Rally.sanitize({ weekend = this, laps = 9 }, now).laps).to.equal(Config.RallyMaxLaps)
			expect(Rally.sanitize({ weekend = this, laps = -1 }, now).laps).to.equal(0)
			expect(Rally.sanitize({ weekend = this - 3, laps = 4 }, now) :: any).to.deepEqual({
				weekend = this - 3,
				laps = 4,
			})
			expect(Rally.sanitize({ weekend = this + 1, laps = 2 }, now) :: any).to.deepEqual({
				weekend = this,
				laps = 0,
			})
			expect(Rally.sanitize({ weekend = 0 / 0, laps = 1 }, now) :: any).to.deepEqual({
				weekend = this,
				laps = 0,
			})
			expect(Rally.sanitize({ weekend = this, laps = 0 / 0 }, now) :: any).to.deepEqual({
				weekend = this,
				laps = 0,
			})
		end)

		it("starts a new save and an older one at no laps this weekend, and keeps a saved one", function()
			local now = SAT + 2 * HOUR
			local fresh = ProfileSchema.template(now)
			expect(fresh.rally :: any).to.deepEqual({ weekend = Rally.weekend(now), laps = 0 })
			local raw: any = ProfileSchema.template(now)
			raw.version = 25
			raw.rally = nil
			local profile = ProfileSchema.migrate(raw, now)
			expect(profile.version).to.equal(ProfileSchema.VERSION)
			expect(profile.rally :: any).to.deepEqual({ weekend = Rally.weekend(now), laps = 0 })
			local kept: any = ProfileSchema.template(now)
			kept.rally = { weekend = Rally.weekend(now), laps = 3 }
			expect(ProfileSchema.migrate(kept, now).rally.laps).to.equal(3)
			-- migrating twice changes nothing
			local again = ProfileSchema.migrate(ProfileSchema.migrate(kept, now), now)
			expect(again.rally :: any).to.deepEqual({ weekend = Rally.weekend(now), laps = 3 })
		end)
	end)
end
