--!strict
-- shared/DailyGifts.luau (#5506): ten gifts for minutes played today.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local DailyGifts = require(Shared.DailyGifts)
	local LiveFlags = require(Shared.LiveFlags)
	local PlaytimeGifts = require(Shared.PlaytimeGifts)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("DailyGifts", function()
		it("has the spec's ten steps in minute order", function()
			local minutes = {}
			for _, step in DailyGifts.STEPS do
				table.insert(minutes, step.minutes)
			end
			expect(table.concat(minutes, ",")).to.equal("1,3,5,8,12,16,20,30,45,60")
		end)

		it("pays the spec's totals over a full day", function()
			local coinSeconds, fish, spins = 0, 0, 0
			for _, step in DailyGifts.STEPS do
				local prize: any = step.prize
				coinSeconds += prize.coinSeconds or 0
				fish += prize.fish or 0
				spins += prize.spins or 0
			end
			expect(coinSeconds).to.equal(540) -- 9 minutes of income
			expect(fish).to.equal(20)
			expect(spins).to.equal(3)
		end)

		it("names only crates that exist", function()
			for _, step in DailyGifts.STEPS do
				for id in (step.prize :: any).crates or {} do
					local found = false
					for _, crate in (Catalog :: any).crates or {} do
						if crate.id == id then
							found = true
						end
					end
					if (Catalog :: any).crates ~= nil then
						expect(found).to.equal(true)
					end
				end
			end
		end)

		it("is due only once a step's minutes are played, one at a time and in order", function()
			local state = DailyGifts.fresh(nil, 100)
			expect(DailyGifts.due(state)).to.equal(nil)
			state = DailyGifts.add(state, 100, 59)
			expect(DailyGifts.due(state)).to.equal(nil)
			state = DailyGifts.add(state, 100, 1)
			expect(DailyGifts.due(state)).to.equal(1)
			state = DailyGifts.add(state, 100, 600) -- 11 minutes: steps 2 to 4 are ready but come one at a time
			expect(DailyGifts.due(state)).to.equal(1)
			state.claimed = 1
			expect(DailyGifts.due(state)).to.equal(2)
			state.claimed = 4
			expect(DailyGifts.due(state)).to.equal(nil)
			state.claimed = #DailyGifts.STEPS
			state.seconds = 86400
			expect(DailyGifts.due(state)).to.equal(nil)
		end)

		it(
			"starts again at 0 on a new UTC day and keeps the day's minutes on the same day",
			function()
				local state = DailyGifts.add(DailyGifts.fresh(nil, 100), 100, 300)
				state.claimed = 3
				local same = DailyGifts.fresh(state, 100)
				expect(same.seconds).to.equal(300)
				expect(same.claimed).to.equal(3)
				local next = DailyGifts.fresh(state, 101)
				expect(next.day).to.equal(101)
				expect(next.seconds).to.equal(0)
				expect(next.claimed).to.equal(0)
				expect(DailyGifts.day(101 * 86400 + 5)).to.equal(101)
			end
		)

		it("puts the next steps on the account's play clock for the Rewards tile", function()
			local state = DailyGifts.add(DailyGifts.fresh(nil, 100), 100, 90)
			state.claimed = 1
			local rows = DailyGifts.upcoming(state, 5000, 2)
			expect(#rows).to.equal(2)
			expect(rows[1].id).to.equal("d3")
			expect(rows[1].at).to.equal(5000 + 90)
			expect(rows[2].id).to.equal("d5")
			expect(rows[2].at).to.equal(5000 + 210)
			state.claimed = #DailyGifts.STEPS
			expect(#DailyGifts.upcoming(state, 5000, 2)).to.equal(0)
		end)

		it("makes a save's field safe", function()
			expect(DailyGifts.sanitize(nil)).to.equal(nil)
			expect(DailyGifts.sanitize({ day = "x" })).to.equal(nil)
			local clean = DailyGifts.sanitize({ day = 100.5, seconds = -4, claimed = 99 }) :: any
			expect(clean.day).to.equal(100)
			expect(clean.seconds).to.equal(0)
			expect(clean.claimed).to.equal(#DailyGifts.STEPS)
			local profile: any = ProfileSchema.template(1700000000)
			profile.dailyGifts = { day = 100, seconds = 120, claimed = 1 }
			local kept = ProfileSchema.migrate(profile, 1700000000).dailyGifts :: any
			expect(kept.seconds).to.equal(120)
			expect(kept.claimed).to.equal(1)
		end)

		it("leaves only the like and favourite on the account ladder while it is on", function()
			local profile: any = ProfileSchema.template(1700000000)
			expect(PlaytimeGifts.due(profile, 2 * 60)).to.equal("m2")
			expect(PlaytimeGifts.due(profile, 2 * 60, true)).to.equal(nil)
			local like = PlaytimeGifts.due(profile, 24 * 60 * 60, true)
			expect(like).to.equal("like")
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[DailyGifts.FLAG]).to.equal(true)
		end)
	end)
end
