--!strict
-- shared/ReturnHook (#2123, first-hour.md section 6a): one reason to come back, bait first, then the Daily Treat,
-- then the daily quests, at the end of a session ("recap") and on a rejoin ("join").
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local DailyTreat = require(Shared.DailyTreat)
	local ProfileSchema = require(Shared.ProfileSchema)
	local ReturnHook = require(Shared.ReturnHook)
	local Spin = require(Shared.Spin)

	local DAY = 86400
	local NOW = 1_800_000_000 + 12 * 3600 -- midday UTC

	local function fresh(): any
		local profile: any = ProfileSchema.template(NOW - DAY)
		profile.lastSeen = NOW - 60
		return profile
	end

	local function bait(readyAt: number?): any
		return {
			lureId = "kibble",
			placedAt = NOW - 100,
			readyAt = readyAt,
			catId = "tabby",
			variant = "base",
			charm = 1,
		}
	end

	describe("at the end of a session (recap)", function()
		it("names a bait cat still on its way first", function()
			local profile = fresh()
			profile.bait = bait(NOW + 300)
			profile.dailyTreat = { stamp = 2, lastDay = Spin.day(NOW) } -- claimed today: a treat would follow
			local hook = ReturnHook.pick(profile, NOW, "recap")
			expect(hook and hook.kind).to.equal("bait")
		end)

		it("counts the second bowl too, and a save from before readyAt", function()
			local profile = fresh()
			profile.bait2 = bait(NOW + 300)
			expect((ReturnHook.pick(profile, NOW, "recap") :: any).kind).to.equal("bait")
			local old = fresh()
			old.bait = bait(nil) -- waits LureWaitSeconds from placedAt
			expect((ReturnHook.pick(old, NOW, "recap") :: any).kind).to.equal("bait")
			expect(Config.LureWaitSeconds > 100).to.equal(true)
		end)

		it("skips a bait cat that has already come (it is there now, not tomorrow)", function()
			local profile = fresh()
			profile.bait = bait(NOW - 1)
			profile.dailyTreat = { stamp = 2, lastDay = Spin.day(NOW) }
			expect((ReturnHook.pick(profile, NOW, "recap") :: any).kind).to.equal("treat")
		end)

		it("names tomorrow's Daily Treat day once today's stamp is claimed", function()
			local profile = fresh()
			profile.dailyTreat = { stamp = 3, lastDay = Spin.day(NOW) }
			local hook = ReturnHook.pick(profile, NOW, "recap") :: any
			expect(hook.kind).to.equal("treat")
			expect(hook.day).to.equal(4)
			profile.dailyTreat = { stamp = DailyTreat.DAYS, lastDay = Spin.day(NOW) }
			expect((ReturnHook.pick(profile, NOW, "recap") :: any).day).to.equal(1) -- a full card starts again
		end)

		it("falls back to new daily quests, never nothing", function()
			local profile = fresh() -- today's treat not claimed yet: tomorrow's day is not certain
			local hook = ReturnHook.pick(profile, NOW, "recap") :: any
			expect(hook.kind).to.equal("quests")
			expect(hook.day).to.equal(nil)
		end)
	end)

	describe("on a rejoin (join)", function()
		it("names a bait cat that has come first", function()
			local profile = fresh()
			profile.bait = bait(NOW - 5)
			expect((ReturnHook.pick(profile, NOW, "join") :: any).kind).to.equal("bait")
			profile.bait = bait(NOW + 300) -- still cooking: not ready yet
			profile.lastSeen = NOW - 60
			profile.dailyTreat = { stamp = 1, lastDay = Spin.day(NOW) }
			expect(ReturnHook.pick(profile, NOW, "join")).to.equal(nil)
		end)

		it("names the Daily Treat day that is due", function()
			local profile = fresh()
			profile.dailyTreat = { stamp = 1, lastDay = Spin.day(NOW) - 1 }
			local hook = ReturnHook.pick(profile, NOW, "join") :: any
			expect(hook.kind).to.equal("treat")
			expect(hook.day).to.equal(2)
		end)

		it("names new daily quests after a new UTC day, and nothing within the same day", function()
			local profile = fresh()
			profile.dailyTreat = { stamp = 1, lastDay = Spin.day(NOW) }
			profile.lastSeen = NOW - DAY
			expect((ReturnHook.pick(profile, NOW, "join") :: any).kind).to.equal("quests")
			profile.lastSeen = NOW - 60
			expect(ReturnHook.pick(profile, NOW, "join")).to.equal(nil)
		end)

		it("only ever names one of the four kinds", function()
			for _, kind in ReturnHook.KINDS do
				expect(kind == "gift" or kind == "bait" or kind == "treat" or kind == "quests").to.equal(true)
			end
			expect(#ReturnHook.KINDS).to.equal(4)
		end)

		it("names the welcome back gift first at a recap when it pays tomorrow, never on a join (#3772)", function()
			local profile = fresh()
			profile.bait = bait(NOW + 600)
			expect((ReturnHook.pick(profile, NOW, "recap", true) :: any).kind).to.equal("gift")
			expect((ReturnHook.pick(profile, NOW, "recap", false) :: any).kind).to.equal("bait")
			expect((ReturnHook.pick(profile, NOW, "recap") :: any).kind).to.equal("bait")
			profile.bait = bait(NOW - 600)
			expect((ReturnHook.pick(profile, NOW, "join", true) :: any).kind).to.equal("bait")
		end)
	end)
end
