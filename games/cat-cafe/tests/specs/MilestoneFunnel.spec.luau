--!strict
-- shared/MilestoneFunnel.luau (#5291): milestones_v1's steps, who is in, what a save has reached and what is due.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
	local MilestoneFunnel = require(ReplicatedStorage.Shared.MilestoneFunnel)
	local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)

	local function stepOf(name: string): number
		return table.find(MilestoneFunnel.STEPS, name) :: number
	end

	describe("MilestoneFunnel", function()
		it("has twelve steps, joined first, behind an off by default switch", function()
			expect(MilestoneFunnel.COUNT).to.equal(12)
			expect(MilestoneFunnel.STEPS[1]).to.equal("joined")
			expect(MilestoneFunnel.FULL).to.equal(4095)
			expect(MilestoneFunnel.STEPS[MilestoneFunnel.AREA_STEP]).to.equal("second_area_entered")
			expect(LiveFlags.OFF_BY_DEFAULT[MilestoneFunnel.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, MilestoneFunnel.FLAG) ~= nil).to.equal(true)
		end)

		it("takes in only accounts first seen early", function()
			expect(MilestoneFunnel.entry(0)).to.equal(0)
			expect(MilestoneFunnel.entry(MilestoneFunnel.ENTRY_SECONDS)).to.equal(0)
			expect(MilestoneFunnel.entry(MilestoneFunnel.ENTRY_SECONDS + 1)).to.equal(
				MilestoneFunnel.OUT
			)
		end)

		it("marks and reads the mask", function()
			local mask = MilestoneFunnel.mark(0, 1)
			mask = MilestoneFunnel.mark(mask, 7)
			expect(MilestoneFunnel.has(mask, 1)).to.equal(true)
			expect(MilestoneFunnel.has(mask, 7)).to.equal(true)
			expect(MilestoneFunnel.has(mask, 2)).to.equal(false)
			expect(MilestoneFunnel.mark(MilestoneFunnel.OUT, 3)).to.equal(MilestoneFunnel.OUT)
			expect(MilestoneFunnel.has(MilestoneFunnel.OUT, 1)).to.equal(false)
		end)

		it("cleans a saved mask", function()
			expect(MilestoneFunnel.sanitize(nil)).to.equal(nil)
			expect(MilestoneFunnel.sanitize("5")).to.equal(nil)
			expect(MilestoneFunnel.sanitize(0 / 0)).to.equal(nil)
			expect(MilestoneFunnel.sanitize(-7)).to.equal(MilestoneFunnel.OUT)
			expect(MilestoneFunnel.sanitize(9.6)).to.equal(9)
			expect(MilestoneFunnel.sanitize(1e9)).to.equal(MilestoneFunnel.FULL)
		end)

		it("ProfileSchema keeps the mask the same way", function()
			local raw: any = ProfileSchema.template(1000)
			raw.telemetry.milestoneMask = 37
			expect(ProfileSchema.migrate(raw, 1000).telemetry.milestoneMask).to.equal(37)
			raw.telemetry.milestoneMask = -3
			expect(ProfileSchema.migrate(raw, 1000).telemetry.milestoneMask).to.equal(-1)
			raw.telemetry.milestoneMask = 99999
			expect(ProfileSchema.migrate(raw, 1000).telemetry.milestoneMask).to.equal(4095)
			raw.telemetry.milestoneMask = nil
			expect(ProfileSchema.migrate(raw, 1000).telemetry.milestoneMask).to.equal(nil)
		end)

		it("reads a fresh save as joined only", function()
			local profile = ProfileSchema.template(1000)
			local got = MilestoneFunnel.reached(profile)
			expect(got[1]).to.equal(true)
			for step = 2, MilestoneFunnel.COUNT do
				expect(got[step]).to.equal(nil)
			end
			expect(table.concat(MilestoneFunnel.due(0, got), " ")).to.equal("1")
		end)

		it("reads nets, stations, tiers, the companion and a later landing", function()
			local profile = ProfileSchema.template(1000)
			profile.upgradeLevels.net = 2
			profile.tier = 3
			profile.follower.uid = "cat_1"
			local got = MilestoneFunnel.reached(profile, true)
			expect(got[stepOf("net_1")]).to.equal(true)
			expect(got[stepOf("net_2")]).to.equal(true)
			expect(got[stepOf("net_3")]).to.equal(nil)
			expect(got[stepOf("first_rank_up")]).to.equal(true)
			expect(got[stepOf("tier_3")]).to.equal(true)
			expect(got[stepOf("companion_picked")]).to.equal(true)
			expect(got[stepOf("second_area_entered")]).to.equal(true)
			expect(MilestoneFunnel.reached(profile)[stepOf("second_area_entered")]).to.equal(nil)
		end)

		it("logs each step once, in step order, even when one comes early", function()
			local reached = { [1] = true, [7] = true, [3] = true }
			expect(table.concat(MilestoneFunnel.due(0, reached), " ")).to.equal("1 3 7")
			local mask =
				MilestoneFunnel.mark(MilestoneFunnel.mark(MilestoneFunnel.mark(0, 1), 3), 7)
			expect(table.concat(MilestoneFunnel.due(mask, reached), " ")).to.equal("")
			reached[2] = true
			expect(table.concat(MilestoneFunnel.due(mask, reached), " ")).to.equal("2")
			expect(table.concat(MilestoneFunnel.due(MilestoneFunnel.OUT, reached), " ")).to.equal(
				""
			)
		end)

		it("knows which landings are after the Alleyway", function()
			expect(MilestoneFunnel.isLaterArrival("arrived_park")).to.equal(true)
			expect(MilestoneFunnel.isLaterArrival("arrived_castle")).to.equal(true)
			expect(MilestoneFunnel.isLaterArrival("arrived_alley")).to.equal(false)
			expect(MilestoneFunnel.isLaterArrival("launch")).to.equal(false)
		end)

		it("marks minutes in a short list", function()
			expect(MilestoneFunnel.minuteMark(0)).to.equal("0")
			expect(MilestoneFunnel.minuteMark(59 * 60 + 59)).to.equal("59")
			expect(MilestoneFunnel.minuteMark(63 * 60)).to.equal("60")
			expect(MilestoneFunnel.minuteMark(179 * 60)).to.equal("175")
			expect(MilestoneFunnel.minuteMark(500 * 60)).to.equal("180+")
		end)
	end)
end
