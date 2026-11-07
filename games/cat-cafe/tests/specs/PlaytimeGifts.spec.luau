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

	describe("when each is due (section 2)", function()
		it("pays nothing before 10 minutes, the like at 10 and the favourite at 30", function()
			local profile = fresh()
			expect(Config.LikeGiftMinutes).to.equal(10)
			expect(Config.FavGiftMinutes).to.equal(30)
			expect(PlaytimeGifts.due(profile, 0)).to.equal(nil)
			expect(PlaytimeGifts.due(profile, 5 * MINUTE)).to.equal(nil)
			expect(PlaytimeGifts.due(profile, 10 * MINUTE - 1)).to.equal(nil)
			expect(PlaytimeGifts.due(profile, 10 * MINUTE)).to.equal("like")
			PlaytimeGifts.mark(profile, "like")
			expect(PlaytimeGifts.due(profile, 29 * MINUTE)).to.equal(nil)
			expect(PlaytimeGifts.due(profile, 30 * MINUTE)).to.equal("fav")
			PlaytimeGifts.mark(profile, "fav")
			expect(PlaytimeGifts.due(profile, 600 * MINUTE)).to.equal(nil)
		end)

		it("pays the like first for a save already past both marks", function()
			local profile = fresh()
			expect(PlaytimeGifts.due(profile, 90 * MINUTE)).to.equal("like")
			PlaytimeGifts.mark(profile, "like")
			expect(PlaytimeGifts.due(profile, 90 * MINUTE)).to.equal("fav")
			expect(PlaytimeGifts.GAP_SECONDS > 0).to.equal(true)
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
