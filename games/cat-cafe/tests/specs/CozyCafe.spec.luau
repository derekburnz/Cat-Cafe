--!strict
-- CozyCafe.luau (#2798, retention-ideas.md idea 10): staying in your own cafe brings small gift bags, a minute of
-- income with sometimes a Tuna and rarely a few golden fish, 8 a UTC day, after the first catch only.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local CozyCafe = require(Shared.CozyCafe)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = 1_800_000_000
	local DAY = 86400

	describe("CozyCafe (#2798)", function()
		it(
			"curls up after a minute, a bag every 3 minutes, 8 a day, its lure a real food",
			function()
				expect(Config.CozyStartSeconds).to.equal(60)
				expect(Config.CozyBagSeconds).to.equal(180)
				expect(Config.CozyBagsPerDay).to.equal(8)
				expect(Catalog.getLure(Config.CozyLure)).to.be.ok()
			end
		)

		it("needs the first catch and stops at the day's cap", function()
			local profile: any = ProfileSchema.template(NOW)
			expect(CozyCafe.eligible(profile, NOW)).to.equal(false)
			profile.stats.catsCaught = 1
			expect(CozyCafe.eligible(profile, NOW)).to.equal(true)
			for _ = 1, Config.CozyBagsPerDay do
				CozyCafe.note(profile.cozy, NOW)
			end
			expect(CozyCafe.bagsToday(profile.cozy, NOW)).to.equal(8)
			expect(CozyCafe.eligible(profile, NOW)).to.equal(false)
			expect(CozyCafe.eligible(profile, NOW + DAY)).to.equal(true)
			CozyCafe.note(profile.cozy, NOW + DAY)
			expect(CozyCafe.bagsToday(profile.cozy, NOW + DAY)).to.equal(1)
		end)

		it("counts the curl-up minute before the first bag only", function()
			expect(CozyCafe.secondsToBag(false, 0)).to.equal(240)
			expect(CozyCafe.secondsToBag(true, 0)).to.equal(180)
			expect(CozyCafe.secondsToBag(true, 200)).to.equal(0)
		end)

		it(
			"always pays a minute of income, a Tuna on a low roll, 1 to 3 fish on a rare one",
			function()
				expect(CozyCafe.prize(0.9, 0.9) :: any).to.deepEqual({ coinSeconds = 60 })
				expect(CozyCafe.prize(0.1, 0.9) :: any).to.deepEqual({
					coinSeconds = 60,
					lures = { tuna = 1 },
				})
				expect(CozyCafe.prize(0.9, 0).fish).to.equal(1)
				expect(CozyCafe.prize(0.9, 0.0499).fish).to.equal(3)
				for i = 0, 99 do
					local fish = CozyCafe.prize(0.9, i / 100 * Config.CozyFishChance).fish :: number
					expect(fish >= 1 and fish <= 3).to.equal(true)
				end
				expect(CozyCafe.prize(0.9, 0.05).fish).to.equal(nil)
			end
		)

		it("keeps the day's count through a load and cleans a bad one", function()
			local profile: any = ProfileSchema.template(NOW)
			CozyCafe.note(profile.cozy, NOW)
			local loaded: any = ProfileSchema.migrate(profile, NOW)
			expect(loaded.cozy).to.deepEqual({ day = CozyCafe.day(NOW), bags = 1 })
			local raw: any = ProfileSchema.template(NOW)
			raw.cozy = { day = "x", bags = 99 }
			expect(ProfileSchema.migrate(raw, NOW).cozy :: any).to.deepEqual({ day = 0, bags = 8 })
			raw.cozy = nil
			expect(ProfileSchema.migrate(raw, NOW).cozy :: any).to.deepEqual({ day = 0, bags = 0 })
		end)
	end)
end
