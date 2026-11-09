--!strict
-- PlaytimeGifts.luau against like-prompts.md section 2 with Set 10 Q3 (#1947): the like gift at 10 minutes of play
-- and the favourite at 30, once each per account, like first; what each pays; the save flags; and the report read.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local PlaytimeGifts = require(Shared.PlaytimeGifts)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = 1_800_000_000
	local MINUTE = 60

	local function fresh(): any
		return ProfileSchema.template(NOW)
	end

	-- pays every step due at `played` in turn, returning the ids in order
	local function payAll(profile: any, played: number): { string }
		local out = {}
		while true do
			local step = PlaytimeGifts.due(profile, played)
			if step == nil then
				return out
			end
			table.insert(out, step)
			PlaytimeGifts.mark(profile, step)
		end
	end

	describe("when each is due (section 2, #2791's ladder)", function()
		it("pays 2, 4 and 6 minutes, the like at 10, then 15, 20 and the favourite at 30", function()
			local profile = fresh()
			expect(Config.LikeGiftMinutes).to.equal(10)
			expect(Config.FavGiftMinutes).to.equal(30)
			expect(PlaytimeGifts.due(profile, 0)).to.equal(nil)
			expect(PlaytimeGifts.due(profile, 2 * MINUTE - 1)).to.equal(nil)
			expect(payAll(profile, 2 * MINUTE) :: any).to.deepEqual({ "m2" })
			expect(payAll(profile, 6 * MINUTE) :: any).to.deepEqual({ "m4", "m6" })
			expect(PlaytimeGifts.due(profile, 10 * MINUTE - 1)).to.equal(nil)
			expect(PlaytimeGifts.due(profile, 10 * MINUTE)).to.equal("like")
			PlaytimeGifts.mark(profile, "like")
			expect(payAll(profile, 29 * MINUTE) :: any).to.deepEqual({ "m15", "m20" })
			expect(PlaytimeGifts.due(profile, 30 * MINUTE)).to.equal("fav")
			PlaytimeGifts.mark(profile, "fav")
			expect(PlaytimeGifts.due(profile, 600 * MINUTE)).to.equal(nil)
			expect(#PlaytimeGifts.upcoming(profile, 2)).to.equal(0)
		end)

		it("pays a fresh save past every mark one step at a time, in order", function()
			local profile = fresh()
			expect(payAll(profile, 90 * MINUTE) :: any).to.deepEqual({ "m2", "m4", "m6", "like", "m15", "m20", "fav" })
			expect(PlaytimeGifts.GAP_SECONDS > 0).to.equal(true)
		end)

		it("skips the steps before a step already paid, so an older account gets no 2 to 6 minute steps", function()
			local profile = fresh()
			PlaytimeGifts.mark(profile, "like")
			expect(payAll(profile, 25 * MINUTE) :: any).to.deepEqual({ "m15", "m20" })
			local done = fresh()
			PlaytimeGifts.mark(done, "like")
			PlaytimeGifts.mark(done, "fav")
			expect(payAll(done, 600 * MINUTE) :: any).to.deepEqual({})
		end)

		it("upcoming lists the next steps with when they pay and what", function()
			local profile = fresh()
			local next2 = PlaytimeGifts.upcoming(profile, 2)
			expect(#next2).to.equal(2)
			expect(next2[1].id).to.equal("m2")
			expect(next2[1].at).to.equal(2 * MINUTE)
			expect(next2[1].prize :: any).to.deepEqual({ coinSeconds = 60 })
			expect(next2[2].id).to.equal("m4")
			PlaytimeGifts.mark(profile, "m2")
			PlaytimeGifts.mark(profile, "m4")
			PlaytimeGifts.mark(profile, "m6")
			expect(PlaytimeGifts.upcoming(profile, 1)[1].id).to.equal("like")
			expect(PlaytimeGifts.upcoming(profile, 1)[1].at).to.equal(10 * MINUTE)
		end)
	end)

	describe("the small steps (#2791, retention-ideas.md 5a)", function()
		it("pay a minute of income, a Tuna, a spin, 5 golden fish and a Swift Potion, with a toast", function()
			local want = {
				m2 = { coinSeconds = 60 },
				m4 = { lures = { tuna = 1 } },
				m6 = { spins = 1 },
				m15 = { fish = 5 },
				m20 = { potions = { swift_potion = 1 } },
			}
			local seen = 0
			for _, step in PlaytimeGifts.STEPS do
				if PlaytimeGifts.isCard(step.id) then
					expect(step.id == "like" or step.id == "fav").to.equal(true)
				else
					seen += 1
					expect(PlaytimeGifts.prize(step.id) :: any).to.deepEqual(want[step.id])
					expect(step.minutes).to.equal(tonumber(string.sub(step.id, 2)))
				end
			end
			expect(seen).to.equal(5)
		end)

		it("keeps the paid steps through a load, and only the known ones", function()
			local profile = fresh()
			expect(next(profile.giftSteps)).never.to.be.ok()
			PlaytimeGifts.mark(profile, "m2")
			PlaytimeGifts.mark(profile, "nope")
			local raw: any = table.clone(profile)
			raw.giftSteps = { m2 = true, m4 = 1, nope = true }
			local loaded: any = ProfileSchema.migrate(raw, NOW)
			expect(loaded.giftSteps).to.deepEqual({ m2 = true })
			expect(PlaytimeGifts.paid(loaded, "m2")).to.equal(true)
		end)
	end)

	describe("what each pays (Set 10 Q3)", function()
		it("gives the like 15 minutes of income and a Tip Potion", function()
			expect(PlaytimeGifts.prize("like") :: any).to.deepEqual({
				coinSeconds = 15 * MINUTE,
				potions = { tip_potion = 1 },
			})
		end)

		it(
			"gives the favourite 30 minutes of income and a Tip, a Lucky and a Swift Potion",
			function()
				expect(PlaytimeGifts.prize("fav") :: any).to.deepEqual({
					coinSeconds = 30 * MINUTE,
					potions = { tip_potion = 1, lucky_potion = 1, swift_potion = 1 },
				})
			end
		)

		it("has no fish, spins, crates or anything random", function()
			for _, kind in PlaytimeGifts.KINDS do
				local prize = PlaytimeGifts.prize(kind)
				expect(prize.fish).never.to.be.ok()
				expect(prize.spins).never.to.be.ok()
				expect(prize.crates).never.to.be.ok()
			end
		end)
	end)

	describe("the save (version 42)", function()
		it("starts with neither gift and keeps both flags through a load", function()
			local profile = fresh()
			expect(profile.likeGift).to.equal(false)
			expect(profile.favGift).to.equal(false)
			PlaytimeGifts.mark(profile, "like")
			local loaded: any = ProfileSchema.migrate(profile, NOW)
			expect(loaded.likeGift).to.equal(true)
			expect(loaded.favGift).to.equal(false)
			PlaytimeGifts.mark(loaded, "fav")
			local again: any = ProfileSchema.migrate(loaded, NOW)
			expect(again.favGift).to.equal(true)
		end)

		it("reads an older save as no gifts, and anything but true as not paid", function()
			local old: any = fresh()
			old.version = 41
			old.likeGift = nil
			old.favGift = "yes"
			local loaded: any = ProfileSchema.migrate(old, NOW)
			expect(loaded.likeGift).to.equal(false)
			expect(loaded.favGift).to.equal(false)
		end)
	end)

	describe("the button report (analytics only)", function()
		it("reads each gift and button, and nothing else", function()
			for _, kind in PlaytimeGifts.KINDS do
				for _, button in PlaytimeGifts.BUTTONS do
					local gift, pressed = PlaytimeGifts.report(kind .. ":" .. button)
					expect(gift).to.equal(kind)
					expect(pressed).to.equal(button)
				end
			end
			local gift, pressed = PlaytimeGifts.report("like:gotit") -- #2705
			expect(gift).to.equal("like")
			expect(pressed).to.equal("gotit")
			for _, bad in
				{ "like", "like:", ":close", "fav:buy", "spin:close", "like:close:x", 3, "" }
			do
				local gift, pressed = PlaytimeGifts.report(bad)
				expect(gift).to.equal(nil)
				expect(pressed).to.equal(nil)
			end
		end)
	end)
end
