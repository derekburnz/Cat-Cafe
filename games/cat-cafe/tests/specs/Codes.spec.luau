--!strict
-- shared/Codes.luau and Catalog.codes (F65, data-model section 11d): what a typed code becomes, why a code cannot
-- pay, the wrong-code lock, the circle's open and close edges, and the launch rows.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Codes = require(Shared.Codes)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local NOW = 1_800_000_000

	local function fresh(): any
		return ProfileSchema.template(1000)
	end

	describe("the Saturday update gift (#2997), marked in codesRedeemed", function()
		local UpdateGift = require(Shared.UpdateGift)
		local CodeEntry = require(
			game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.Components.CodeEntry
		)
		local SATURDAY = 1794675600 -- 2026-11-14 17:00 UTC
		local gift: UpdateGift.Gift = { id = "2026-11-14", from = SATURDAY, fish = 15, spins = 1 }

		it("ends a gift at `to`, and a gift with no end keeps paying (#3779)", function()
			-- the launch gift's own numbers: 100 fish from 22:03 UTC Thursday 2026-11-12 to 02:00 UTC Friday
			local launch: UpdateGift.Gift =
				{ id = "2026-11-12", from = 1794520980, fish = 100, spins = 0, to = 1794535200 }
			local to = launch.to :: number
			expect(UpdateGift.due({}, launch, to - 1)).to.equal(true)
			expect(UpdateGift.due({}, launch, to)).to.equal(false)
			expect(UpdateGift.due({}, launch, to + 86400)).to.equal(false)
			-- a gift with no end still pays, and one that ends before it starts gives no notice
			expect(UpdateGift.due({}, gift, SATURDAY + 86400 * 30)).to.equal(true)
			local dead: UpdateGift.Gift =
				{ id = "x1", from = SATURDAY, fish = 5, spins = 0, to = SATURDAY - 10 }
			expect(UpdateGift.soon({}, dead, SATURDAY - 60)).to.equal(nil)
			expect(UpdateGift.due({}, dead, SATURDAY + 1)).to.equal(false)
			expect(UpdateGift.words(launch)).to.equal("Update gift! 🐟 100")
			expect(UpdateGift.prize(launch) :: any).to.deepEqual({ fish = 100 })
			-- the weekly gift keeps its words and prize
			expect(UpdateGift.words(gift)).to.equal("Update gift! 🐟 15 + 1 spin")
			expect(UpdateGift.prize(gift) :: any).to.deepEqual({ fish = 15, spins = 1 })
		end)

		it(
			"has Friday's three golden crates from 22:03 UTC on 2026-11-13 (#3535), then Saturday's weekly gift (#3497)",
			function()
				local friday, weekly = assert(Config.UpdateGift), assert(Config.UpdateGiftNext)
				expect(friday.id).to.equal("2026-11-13")
				expect(os.date("!%Y-%m-%d %H:%M %A", friday.from)).to.equal(
					"2026-11-13 22:03 Friday"
				)
				expect(friday.fish + friday.spins).to.equal(0)
				expect(UpdateGift.crateCount(friday)).to.equal(3)
				expect(UpdateGift.words(friday)).to.equal("Update gift! 3 golden crates")
				-- #3779: it ends when Saturday's weekly gift starts, so it pays nobody new after that
				expect(os.date("!%Y-%m-%d %H:%M %A", friday.to)).to.equal(
					"2026-11-14 17:00 Saturday"
				)
				local ends = friday.to :: number
				expect(UpdateGift.due({}, friday, ends - 1)).to.equal(true)
				expect(UpdateGift.due({}, friday, ends)).to.equal(false)
				-- Saturday's: 15 golden fish and a spin, for one week, and no crates
				expect(weekly.id).to.equal("2026-11-14")
				expect(weekly.from).to.equal(ends)
				expect(weekly.fish).to.equal(15)
				expect(weekly.spins).to.equal(1)
				expect(UpdateGift.crateCount(weekly)).to.equal(0)
				expect(os.date("!%Y-%m-%d %H:%M %A", weekly.to)).to.equal(
					"2026-11-21 17:00 Saturday"
				)
				expect(UpdateGift.words(weekly)).to.equal("Update gift! 🐟 15 + 1 spin")
				-- before Friday's starts nothing pays and the notice is Friday's own, in its last minutes
				local pays, notice = UpdateGift.pick(friday, weekly, friday.from - 60)
				expect(pays).to.equal(friday)
				expect(notice).to.equal(friday)
				expect(UpdateGift.due({}, pays, friday.from - 60)).to.equal(false)
				expect(UpdateGift.soon({}, notice, friday.from - 60)).to.equal(60)
				-- Friday's pays until Saturday's `from`, with Saturday's notice in the minutes before it
				pays, notice = UpdateGift.pick(friday, weekly, friday.from)
				expect(pays).to.equal(friday)
				expect(notice).to.equal(weekly)
				expect(UpdateGift.due({}, pays, friday.from)).to.equal(true)
				pays, notice = UpdateGift.pick(friday, weekly, weekly.from - 1)
				expect(pays).to.equal(friday)
				expect(notice).to.equal(weekly)
				pays, notice = UpdateGift.pick(friday, weekly, weekly.from)
				expect(pays).to.equal(weekly)
				expect(notice).to.equal(weekly)
				expect(UpdateGift.due({}, pays, weekly.from)).to.equal(true)
				-- an account paid Friday's crates still gets Saturday's
				expect(UpdateGift.due({ [UpdateGift.key(friday.id)] = 1 }, weekly, weekly.from)).to.equal(
					true
				)
				pays, notice = UpdateGift.pick(friday, nil, weekly.from)
				expect(pays).to.equal(friday)
				expect(notice).to.equal(friday)
				local coming = friday
				-- a Tier 1 player's best area is the Alleyway, whose crate the gift already names: a second Classic
				expect(UpdateGift.prize(coming, 1) :: any).to.deepEqual({
					crates = { classic_golden_crate = 2, alley_golden_crate = 1 },
				})
				-- from Tier 2 the third crate is the best open area's, always one the player can open
				expect(UpdateGift.prize(coming, 2) :: any).to.deepEqual({
					crates = {
						classic_golden_crate = 1,
						alley_golden_crate = 1,
						park_golden_crate = 1,
					},
				})
				local Catalog = require(Shared.Catalog)
				local Crates = require(Shared.Crates)
				for tier = 1, #Catalog.tiers do
					local total = 0
					for id, count in (UpdateGift.prize(coming, tier) :: any).crates do
						total += count
						local crate = assert(Catalog.getCrate(id))
						expect(crate.golden).to.equal(true)
						local profile: any = { crates = { [id] = 1 }, goldenFish = 0 }
						expect(Crates.openBlocker(profile, tier, id)).to.equal(nil)
					end
					expect(total).to.equal(3)
				end
				-- the banners
				expect(UpdateGift.banner("soon", 0, 0, 180, 3) :: any).to.deepEqual({
					title = "A gift is coming!",
					lines = { "3 golden crates for everyone", "in 3 minutes" },
				})
				expect(UpdateGift.banner("paid", 0, 0, 0, 3) :: any).to.deepEqual({
					title = "A gift for everyone!",
					lines = { "+3 golden crates", "Thanks for playing!" },
				})
				expect((UpdateGift.banner("paid", 0, 0, 0, 1) :: any).lines[1]).to.equal(
					"+1 golden crate"
				)
				expect(UpdateGift.banner("paid", 0, 0, 0, 0)).to.equal(nil)
				expect(UpdateGift.banner("paid", 0, 0, 0, 11)).to.equal(nil)
				expect(UpdateGift.banner("paid", 0, 0, 0, "3")).to.equal(nil)
			end
		)

		it(
			"gives notice once in the 5 minutes before an unpaid gift, never after (#3420)",
			function()
				local profile = fresh()
				expect(UpdateGift.soon(profile.codesRedeemed, gift, SATURDAY - 301)).to.equal(nil)
				expect(UpdateGift.soon(profile.codesRedeemed, gift, SATURDAY - 300)).to.equal(300)
				expect(UpdateGift.soon(profile.codesRedeemed, gift, SATURDAY - 1)).to.equal(1)
				expect(UpdateGift.soon(profile.codesRedeemed, gift, SATURDAY)).to.equal(nil)
				expect(UpdateGift.soon(profile.codesRedeemed, nil, SATURDAY - 60)).to.equal(nil)
				profile.codesRedeemed[UpdateGift.key(gift.id)] = SATURDAY - 500
				expect(UpdateGift.soon(profile.codesRedeemed, gift, SATURDAY - 60)).to.equal(nil)
			end
		)

		it(
			"words the two banners, and refuses anything a server would never send (#3420)",
			function()
				expect(UpdateGift.banner("soon", 100, 0, 180) :: any).to.deepEqual({
					title = "A gift is coming!",
					lines = { "100 golden fish for everyone", "in 3 minutes" },
				})
				expect((UpdateGift.banner("soon", 100, 0, 121) :: any).lines[2]).to.equal(
					"in 3 minutes"
				)
				expect((UpdateGift.banner("soon", 100, 0, 60) :: any).lines[2]).to.equal(
					"in 1 minute"
				)
				expect((UpdateGift.banner("soon", 100, 0, 0.5) :: any).lines[2]).to.equal(
					"in 1 minute"
				)
				expect(UpdateGift.banner("paid", 100, 0, 0) :: any).to.deepEqual({
					title = "A gift for everyone!",
					lines = { "+100 golden fish", "Thanks for playing!" },
				})
				expect((UpdateGift.banner("soon", 15, 1, 60) :: any).lines[1]).to.equal(
					"15 golden fish + 1 spin for everyone"
				)
				expect((UpdateGift.banner("paid", 0, 2, 0) :: any).lines[1]).to.equal("+2 spins")
				-- the launch gift's and the weekly gift's titles fit the banner's 24 characters and their lines its 36
				for _, made in
					{
						UpdateGift.banner("soon", 100, 0, 300),
						UpdateGift.banner("paid", 100, 0, 0),
						UpdateGift.banner("soon", 15, 1, 300),
						UpdateGift.banner("paid", 15, 1, 0),
					} :: { any }
				do
					expect(#made.title <= 24).to.equal(true)
					for _, line in made.lines do
						expect(#line <= 36).to.equal(true)
					end
				end
				for _, bad in
					{
						{ "other", 100, 0, 60 },
						{ "soon", 100, 0, 0 },
						{ "soon", 100, 0, 301 },
						{ "soon", 100, 0, "60" },
						{ "soon", 100, 0, 0 / 0 },
						{ "paid", 0, 0, 0 },
						{ "paid", -1, 0, 0 },
						{ "paid", 1001, 0, 0 },
						{ "paid", 1.5, 0, 0 },
						{ "paid", "100", 0, 0 },
						{ "paid", 100, 11, 0 },
						{ "paid", 0 / 0, 0, 0 },
						{ nil, nil, nil, nil },
					} :: { { any } }
				do
					expect(UpdateGift.banner(bad[1], bad[2], bad[3], bad[4])).to.equal(nil)
				end
			end
		)

		it("pays once per id, only from its start, and a new id pays again", function()
			local profile = fresh()
			expect(UpdateGift.due(profile.codesRedeemed, gift, SATURDAY - 1)).to.equal(false)
			expect(UpdateGift.due(profile.codesRedeemed, gift, SATURDAY)).to.equal(true)
			expect(UpdateGift.due(profile.codesRedeemed, nil, SATURDAY)).to.equal(false)
			profile.codesRedeemed[UpdateGift.key(gift.id)] = SATURDAY
			expect(UpdateGift.due(profile.codesRedeemed, gift, SATURDAY + 60)).to.equal(false)
			local nextWeek: UpdateGift.Gift =
				{ id = "2026-11-21", from = SATURDAY + 7 * 86400, fish = 15, spins = 1 }
			expect(UpdateGift.due(profile.codesRedeemed, nextWeek, SATURDAY + 7 * 86400)).to.equal(
				true
			)
		end)

		it(
			"survives a save and load on any server since version 9, and never looks like a code",
			function()
				local key = UpdateGift.key(gift.id)
				expect(key).to.equal("gift20261114")
				expect(#key <= Config.CodeMaxLength).to.equal(true)
				local profile = fresh()
				profile.codesRedeemed[key] = SATURDAY
				local loaded = ProfileSchema.migrate(profile, SATURDAY)
				expect(loaded.codesRedeemed[key]).to.equal(SATURDAY)
				for id in Catalog.codes do
					expect(UpdateGift.isKey(id)).to.equal(false)
				end
				-- the Store's "Codes you've used" list leaves it out
				local used =
					CodeEntry.used({ [key] = SATURDAY, playtest = SATURDAY - 10 }, Catalog.codes)
				expect(#used).to.equal(1)
				expect(used[1].id).to.equal("playtest")
			end
		)
	end)

	describe("normalize (codes are not case sensitive)", function()
		it(
			"trims spaces and lowercases, so PlayTest, playtest and PLAYTEST are one code",
			function()
				expect(Codes.normalize("PlayTest")).to.equal("playtest")
				expect(Codes.normalize("playtest")).to.equal("playtest")
				expect(Codes.normalize("  PLAYTEST \t")).to.equal("playtest")
				expect(Codes.normalize("likes1000")).to.equal("likes1000")
			end
		)

		it(
			"takes the symbols in Codes.SYMBOLS, so group! and Play-Test.2 are codes (Set 4 answer 8)",
			function()
				expect(Codes.normalize("Group!")).to.equal("group!")
				expect(Codes.normalize(" Play-Test.2 ")).to.equal("play-test.2")
				expect(Codes.normalize("cats&dogs?")).to.equal("cats&dogs?")
				expect(Codes.normalize("#1_cat*$@")).to.equal("#1_cat*$@")
				for i = 1, #Codes.SYMBOLS do
					local symbol = string.sub(Codes.SYMBOLS, i, i)
					expect(Codes.normalize("a" .. symbol)).to.equal("a" .. symbol)
				end
			end
		)

		it("refuses anything that is not 1 to CodeMaxLength letters, digits and symbols", function()
			local cases: { any } = {
				"",
				"   ",
				"play test",
				"play/test",
				"<b>code</b>",
				"code'",
				'code"',
				"(code)",
				"code%",
				"café",
				string.rep("a", Config.CodeMaxLength + 1),
				string.rep(" ", 30) .. string.rep("a", 11), -- 41 bytes before trimming
				42,
				nil,
				{ "playtest" },
			}
			for _, raw in cases do
				expect(Codes.normalize(raw)).never.to.be.ok()
			end
			expect(Codes.normalize(string.rep("a", Config.CodeMaxLength))).to.equal(
				string.rep("a", Config.CodeMaxLength)
			)
		end)
	end)

	describe("clean (the code box as a player types)", function()
		it("keeps letters, digits and symbols, case and all, and drops the rest", function()
			expect(Codes.clean("Group!")).to.equal("Group!")
			expect(Codes.clean("play test!")).to.equal("playtest!")
			expect(Codes.clean("café/<b>")).to.equal("cafb")
			expect(Codes.clean("  ")).to.equal("")
		end)

		it("cuts to CodeMaxLength, and what it keeps normalizes", function()
			local long = string.rep("a!", Config.CodeMaxLength)
			expect(#Codes.clean(long)).to.equal(Config.CodeMaxLength)
			for _, typed in { "Group!", "play test!", "#1 Cat-Cafe.", long } do
				local kept = Codes.clean(typed)
				expect(Codes.normalize(kept)).to.equal(string.lower(kept))
			end
		end)
	end)

	describe("refusal", function()
		it("pays a known active code once per player", function()
			local profile = fresh()
			expect(Codes.refusal(profile, "playtest", NOW)).never.to.be.ok()
			profile.codesRedeemed.playtest = NOW
			expect(Codes.refusal(profile, "playtest", NOW)).to.equal(Codes.USED)
		end)

		it("answers an unknown code, an inactive one and one past its endsAt", function()
			local profile = fresh()
			expect(Codes.refusal(profile, "nope", NOW)).to.equal(Codes.UNKNOWN)
			expect(Codes.refusal(profile, "launch", NOW)).to.equal(Codes.EXPIRED)
			local ended: Types.CodeDef = { id = "x", active = true, endsAt = NOW, prize = {} }
			expect(Codes.expired(ended, NOW - 1)).to.equal(false)
			expect(Codes.expired(ended, NOW)).to.equal(true)
		end)

		it(
			"the group code is open to members once Config.GroupId is set and kept unused for anyone else (#1118)",
			function()
				local profile = fresh()
				expect(Config.GroupId).to.equal(107520049) -- Creampuff Games (#999)
				expect(Codes.refusal(profile, "group", NOW, true)).to.equal(nil)
				expect(Codes.refusal(profile, "group", NOW, false)).to.equal(Codes.GROUP)
				expect(Codes.refusal(profile, "group", NOW, nil)).to.equal(Codes.GROUP)
				expect(Codes.GROUP).to.equal("Join our group to use this code!")
				local open: Types.CodeDef =
					{ id = "g", active = true, requiresGroup = true, prize = {} }
				expect(Codes.expired(open, NOW)).to.equal(false)
			end
		)
	end)

	describe("the wrong-code lock", function()
		it(
			"locks on the CodeWrongLimit-th wrong code inside the window, for CodeLockSeconds",
			function()
				local guard = Codes.newGuard()
				for i = 1, Config.CodeWrongLimit - 1 do
					expect(Codes.noteWrong(guard, 100 + i)).to.equal(false)
					expect(Codes.locked(guard, 100 + i)).to.equal(false)
				end
				expect(Codes.noteWrong(guard, 110)).to.equal(true)
				expect(Codes.locked(guard, 110 + Config.CodeLockSeconds - 1)).to.equal(true)
				expect(Codes.locked(guard, 110 + Config.CodeLockSeconds)).to.equal(false)
				-- the count starts again after a lock
				expect(Codes.noteWrong(guard, 200)).to.equal(false)
			end
		)

		it("forgets wrong codes older than the window", function()
			local guard = Codes.newGuard()
			for i = 1, Config.CodeWrongLimit - 1 do
				Codes.noteWrong(guard, i)
			end
			expect(Codes.noteWrong(guard, 1 + Config.CodeWrongWindowSeconds)).to.equal(false)
			expect(#guard.wrong).to.equal(Config.CodeWrongLimit - 1)
		end)
	end)

	describe("the circle (v0.10)", function()
		it("opens at CodesCircleRadius and closes only past CodesCircleRadius + 1", function()
			local r = Config.CodesCircleRadius
			expect(Codes.circleOpen(false, r)).to.equal(true)
			expect(Codes.circleOpen(false, r + 0.5)).to.equal(false)
			expect(Codes.circleOpen(true, r + 0.5)).to.equal(true)
			expect(Codes.circleOpen(true, r + 1)).to.equal(true)
			expect(Codes.circleOpen(true, r + 1.01)).to.equal(false)
		end)
	end)

	describe("Catalog.codes (section 11d)", function()
		it("keys every row by its own lowercase id, a code normalize takes", function()
			for key, def in Catalog.codes do
				expect(def.id).to.equal(key)
				expect(Codes.normalize(key)).to.equal(key)
			end
		end)

		it("playtest pays the friends-alpha starter pack", function()
			local def = Catalog.codes.playtest
			expect(def.active).to.equal(true)
			expect(def.prize :: any).to.deepEqual({
				coins = 5000,
				fish = 100, -- #2497: was 300
				spins = 10,
				crates = { classic_crate = 3, alley_crate = 1, classic_golden_crate = 1 },
				lures = { tuna = 3, salmon = 2, caviar = 1 },
				potions = { tip_potion = 1, lucky_potion = 1, swift_potion = 1, steady_potion = 1 },
			})
		end)

		it(
			"playtest2 gives two of each potion, for testers who redeemed playtest before F64 (11d)",
			function()
				local def = Catalog.codes.playtest2
				expect(def.active).to.equal(true)
				expect(def.id).to.equal("playtest2")
				expect(def.prize :: any).to.deepEqual({
					potions = {
						tip_potion = 2,
						lucky_potion = 2,
						swift_potion = 2,
						steady_potion = 2,
					},
				})
				for _, code in Catalog.codes do
					local potions: { [string]: number } = code.prize.potions or {}
					for potionId in potions do
						expect(Catalog.getPotion(potionId) ~= nil).to.equal(true)
					end
				end
				-- F94 (rewards-and-shops.md section 2f): the group code no longer pays a potion
				expect(Catalog.codes.group.prize.potions).never.to.be.ok()
			end
		)

		it(
			"release, playtest and playtest2 are on for everyone, case-insensitive, once each (#1118)",
			function()
				for _, id in { "release", "playtest", "playtest2" } do
					local def = Catalog.codes[id]
					expect(def).to.be.ok()
					expect(def.active).to.equal(true)
					expect(def.requiresGroup).never.to.be.ok()
					expect(def.endsAt).never.to.be.ok()
					expect(Codes.refusal(fresh(), id, NOW, false)).to.equal(nil)
				end
				expect(Codes.normalize("Release")).to.equal("release")
				expect(Codes.normalize("RELEASE")).to.equal("release")
				local used = fresh()
				used.codesRedeemed.release = NOW
				expect(Codes.refusal(used, "release", NOW, false)).to.equal(Codes.USED)
				expect(Catalog.codes.release.prize :: any).to.deepEqual({
					coins = 2000,
					coinSeconds = 600,
					fish = 60,
					potions = { tip_potion = 2 },
				})
				-- nothing random in it: no crates or spins (monetization-policy)
				expect(Catalog.codes.release.prize.crates).never.to.be.ok()
				expect(Catalog.codes.release.prize.spins).never.to.be.ok()
			end
		)

		it(
			"UPDATE1 and 500VISITS are on for everyone in any case, once each, beside release in size (#3148)",
			function()
				expect(Codes.normalize("UPDATE1")).to.equal("update1")
				expect(Codes.normalize("Update1")).to.equal("update1")
				expect(Codes.normalize(" update1 ")).to.equal("update1")
				expect(Codes.normalize("500VISITS")).to.equal("500visits")
				expect(Codes.normalize("500Visits")).to.equal("500visits")
				for _, id in { "update1", "500visits" } do
					local def = Codes.get(id)
					assert(def ~= nil, id)
					expect(def.id).to.equal(id)
					expect(def.active).to.equal(true)
					expect(def.requiresGroup).never.to.be.ok()
					expect(def.endsAt).never.to.be.ok()
					expect(Codes.refusal(fresh(), id, NOW, false)).to.equal(nil)
					local used = fresh()
					used.codesRedeemed[id] = NOW
					expect(Codes.refusal(used, id, NOW, false)).to.equal(Codes.USED)
					-- the used mark is a plain letters-and-digits id within CodeMaxLength, so every server's save
					-- cleaner keeps it, old ones too (no save version step)
					expect(string.match(id, "^%w+$")).to.be.ok()
					expect(#id <= Config.CodeMaxLength).to.equal(true)
					-- no more of the player's own income than the group code's 15 minutes: far short of a tier
					expect((def.prize.coinSeconds or 0) <= 900).to.equal(true)
					expect(def.prize.spins).never.to.be.ok()
					expect(def.prize.lures).never.to.be.ok()
				end
				expect(Catalog.codes.update1.prize :: any).to.deepEqual({
					coins = 2500,
					coinSeconds = 900,
					fish = 50,
					potions = { lucky_potion = 2 },
				})
				expect(Catalog.codes["500visits"].prize :: any).to.deepEqual({
					coins = 2000,
					coinSeconds = 600,
					fish = 40,
					crates = { classic_crate = 1 },
				})
			end
		)

		it(
			"2000VISITS and 10LIKES are on at once, UPDATE2 only from the update's hour (#3576)",
			function()
				expect(Codes.normalize("2000VISITS")).to.equal("2000visits")
				expect(Codes.normalize("10Likes")).to.equal("10likes")
				expect(Codes.normalize("UPDATE2")).to.equal("update2")
				for _, id in { "2000visits", "10likes", "update2" } do
					local def = Codes.get(id)
					assert(def ~= nil, id)
					expect(def.id).to.equal(id)
					expect(def.active).to.equal(true)
					expect(def.requiresGroup).never.to.be.ok()
					expect(def.endsAt).never.to.be.ok()
					expect(string.match(id, "^%w+$")).to.be.ok()
					expect(#id <= Config.CodeMaxLength).to.equal(true)
					expect((def.prize.coinSeconds or 0) <= 900).to.equal(true)
					expect(def.prize.spins).never.to.be.ok()
					expect(def.prize.lures).never.to.be.ok()
				end
				local at = Catalog.codes.update2.startsAt :: number
				expect(os.date("!%Y-%m-%d %H:%M", at)).to.equal("2026-11-12 22:00")
				expect(Catalog.codes["2000visits"].startsAt).never.to.be.ok()
				expect(Catalog.codes["10likes"].startsAt).never.to.be.ok()
				-- before its hour UPDATE2 reads as a code that does not exist, used or not; from it, it pays once
				expect(Codes.refusal(fresh(), "update2", at - 1, false)).to.equal(Codes.UNKNOWN)
				expect(Codes.refusal(fresh(), "update2", at, false)).to.equal(nil)
				local used = fresh()
				used.codesRedeemed.update2 = at
				expect(Codes.refusal(used, "update2", at + 1, false)).to.equal(Codes.USED)
				expect(Codes.refusal(fresh(), "2000visits", at - 86400, false)).to.equal(nil)
				expect(Codes.refusal(fresh(), "10likes", at - 86400, false)).to.equal(nil)
				expect(Catalog.codes.update2.prize :: any).to.deepEqual({
					coins = 2500,
					coinSeconds = 900,
					fish = 60,
					potions = { big_tip_potion = 2 },
				})
				expect(Catalog.codes["2000visits"].prize :: any).to.deepEqual({
					coins = 2500,
					coinSeconds = 900,
					fish = 50,
					crates = { classic_crate = 2 },
				})
				expect(Catalog.codes["10likes"].prize :: any).to.deepEqual({
					coins = 2000,
					coinSeconds = 600,
					fish = 40,
					potions = { lucky_potion = 1 },
				})
			end
		)

		it("launch waits to be switched on, and group is on but needs the group", function()
			expect(Catalog.codes.launch.active).to.equal(false)
			expect(Catalog.codes.launch.prize :: any).to.deepEqual({
				coins = 1000,
				coinSeconds = 300,
				fish = 10, -- #2497: was 25
			}) -- F94: no spins or Tuna
			expect(Catalog.codes.group.active).to.equal(true) -- #1118
			expect(Catalog.codes.group.requiresGroup).to.equal(true)
			expect(Catalog.codes.group.prize.coinSeconds).to.equal(900) -- F95: half
			expect(Catalog.codes.group.prize.coins).to.equal(2500)
			expect(Catalog.codes.group.prize :: any).to.deepEqual({
				coins = 2500,
				coinSeconds = 900,
				fish = 40, -- #2497: was 100
				crates = { classic_crate = 1 },
			}) -- F94: no spins, Caviar or potion
		end)

		it("the four launch-week codes ship off, coins only, ending 60 days on (#1937)", function()
			local DAY = 86400
			-- live: each code's day at 00:00 UTC
			local rows = {
				{ id = "opening", live = 1794441600, coins = 1000, coinSeconds = 300 }, -- 2026-11-12
				{ id = "rally", live = 1794614400, coins = 1000, coinSeconds = 300 }, -- 2026-11-14
				{ id = "cozy", live = 1795824000, coins = 1500, coinSeconds = 450 }, -- 2026-11-28
				{ id = "snowy", live = 1796428800, coins = 2000, coinSeconds = 600 }, -- 2026-12-05
			}
			for _, row in rows do
				local def = Catalog.codes[row.id]
				expect(def).to.be.ok()
				expect(def.id).to.equal(row.id)
				expect(def.active).to.equal(false)
				expect(def.requiresGroup).never.to.be.ok()
				expect(def.prize :: any).to.deepEqual({
					coins = row.coins,
					coinSeconds = row.coinSeconds,
				})
				expect(row.coinSeconds <= 600).to.equal(true) -- 10 minutes of income at most
				expect(def.endsAt).to.equal(row.live + 60 * DAY)
			end
			expect(Catalog.codes.launch.active).to.equal(false) -- left as it is, unused
		end)

		it("every prize names real crates and foods", function()
			for _, def in Catalog.codes do
				for crateId in def.prize.crates or {} do
					expect(Catalog.getCrate(crateId)).to.be.ok()
				end
				for lureId in def.prize.lures or {} do
					expect(Catalog.getLure(lureId)).to.be.ok()
				end
			end
		end)
	end)

	describe("save (version 9)", function()
		it("keeps code ids that could be codes, with a whole time, and drops the rest", function()
			local raw: any = ProfileSchema.template(1000)
			raw.version = 8
			raw.codesRedeemed = {
				playtest = 1234.9,
				oldcode = 50,
				["bad id"] = 10,
				launch = "soon",
				huge = math.huge,
			}
			local profile = ProfileSchema.migrate(raw, 2000)
			expect(profile.version).to.equal(ProfileSchema.VERSION)
			expect(profile.codesRedeemed :: any).to.deepEqual({
				playtest = 1234,
				oldcode = 50,
				huge = 0,
			})
		end)
	end)

	describe("Codes edges (QA)", function()
		local Client = game:GetService("StarterPlayer")
			:WaitForChild("StarterPlayerScripts")
			:WaitForChild("Client")
		local CodeEntry = require(
			Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CodeEntry")
		) :: any

		-- Park and Miller's generator: exact in doubles, so a run is the same everywhere
		local seed = 65
		local function uniform(): number
			seed = seed * 48271 % 2147483647
			return seed / 2147483647
		end
		local function pick<T>(list: { T }): T
			return list[1 + math.floor(uniform() * #list)]
		end

		-- Bytes a player can type or paste: letters both ways, digits, spaces and tabs, symbols a code takes and
		-- punctuation it does not, the underscore %w leaves out, a NUL, and the UTF-8 of an accent, a fullwidth
		-- letter and an emoji.
		local PIECES = {
			"a",
			"Z",
			"q",
			"7",
			"0",
			" ",
			"\t",
			"\n",
			"!",
			"-",
			"_",
			".",
			"?",
			"@",
			"/",
			"%",
			"'",
			"\0",
			"é",
			"Ａ",
			"🐱",
			"playtest",
			"PLAY",
			"launch",
		}
		local function typed(): string
			local parts: { string } = {}
			for _ = 1, math.floor(uniform() * 14) do
				table.insert(parts, pick(PIECES))
			end
			return table.concat(parts)
		end

		-- What the server must make of a raw text, worked out here: nil unless it is at most MAX_BYTES and,
		-- trimmed of whitespace, 1 to CodeMaxLength ASCII letters, digits and Codes.SYMBOLS; then those, lowercased.
		local function want(raw: string): string?
			if #raw > Codes.MAX_BYTES then
				return nil
			end
			local first, last = 1, #raw
			while first <= last and string.find(string.sub(raw, first, first), "^%s$") do
				first += 1
			end
			while last >= first and string.find(string.sub(raw, last, last), "^%s$") do
				last -= 1
			end
			local text = string.sub(raw, first, last)
			if #text < 1 or #text > Config.CodeMaxLength then
				return nil
			end
			for i = 1, #text do
				local byte = string.byte(text, i)
				local digit = byte >= 48 and byte <= 57
				local upper = byte >= 65 and byte <= 90
				local lower = byte >= 97 and byte <= 122
				local symbol = string.find(Codes.SYMBOLS, string.char(byte), 1, true) ~= nil
				if not (digit or upper or lower or symbol) then
					return nil
				end
			end
			return string.lower(text)
		end

		-- The box only sends what CodeEntry.clean keeps, so a code typed with junk around it must still reach
		-- the server as that code, and nothing the box lights Redeem for may count against the wrong-code lock
		-- as malformed.
		it("reads 3,000 seeded texts the same way in the box and on the server", function()
			-- MAX_BYTES counts before trimming: 40 bytes still reads, 41 does not
			local padded = string.rep(" ", Codes.MAX_BYTES - Config.CodeMaxLength)
				.. string.rep("a", Config.CodeMaxLength)
			expect(Codes.normalize(padded)).to.equal(string.rep("a", Config.CodeMaxLength))
			expect(Codes.normalize(" " .. padded)).to.equal(nil)
			for n = 1, 3000 do
				local raw = typed()
				local at = string.format("%d %q: ", n, raw)
				local direct = Codes.normalize(raw)
				expect(at .. tostring(direct)).to.equal(at .. tostring(want(raw)))
				local kept = Codes.clean(raw)
				expect(#kept <= Config.CodeMaxLength).to.equal(true)
				if kept ~= "" then
					expect(at .. tostring(Codes.normalize(kept))).to.equal(at .. string.lower(kept))
				end
				local sent = CodeEntry.clean(raw)
				expect(#sent <= Config.CodeMaxLength).to.equal(true)
				if CodeEntry.canRedeem(raw) then
					expect(at .. tostring(Codes.normalize(sent))).to.equal(at .. string.lower(sent))
				else
					expect(sent).to.equal("")
				end
			end
		end)

		-- since codes take symbols (Set 4 answer, 2026-11-01) a "!" is part of the code, so the junk here is a
		-- bracket, which no code can hold
		it("takes every code typed with any case, spaces and punctuation in the box", function()
			for id in pairs(Catalog.codes) do
				for _, raw in
					{
						id,
						string.upper(id),
						"  " .. id .. "  ",
						string.sub(id, 1, 1) .. " " .. string.sub(id, 2) .. ")",
						"\t" .. string.upper(string.sub(id, 1, 2)) .. string.sub(id, 3) .. "\n",
					}
				do
					local sent = CodeEntry.clean(raw)
					expect(string.format("%q %s", raw, tostring(Codes.normalize(sent)))).to.equal(
						string.format("%q %s", raw, id)
					)
				end
			end
		end)

		-- The guard against reference rules: a wrong code at t counts the wrong codes in (t - window, t] with it,
		-- and the CodeWrongLimit-th locks [t, t + CodeLockSeconds) and starts the count again; while locked a
		-- try is answered locked and counts nothing (CodeService checks the lock first).
		it("locks exactly as the rules say over 300 seeded try sequences", function()
			for run = 1, 300 do
				local guard = Codes.newGuard()
				local wrong: { number } = {}
				local lockedUntil = 0
				local t = 0
				for step = 1, 40 do
					t += pick({ 0, 0.5, 2, 2, 2, 7.5, 12, 30, 59.999, 60, 60.001 })
					local at = string.format("run %d step %d t=%s: ", run, step, tostring(t))
					local lockedNow = t < lockedUntil
					expect(at .. tostring(Codes.locked(guard, t))).to.equal(
						at .. tostring(lockedNow)
					)
					if lockedNow then
						continue
					end
					local kept: { number } = {}
					for _, before in wrong do
						if t - before < Config.CodeWrongWindowSeconds then
							table.insert(kept, before)
						end
					end
					table.insert(kept, t)
					local locks = #kept >= Config.CodeWrongLimit
					if locks then
						wrong = {}
						lockedUntil = t + Config.CodeLockSeconds
					else
						wrong = kept
					end
					expect(at .. tostring(Codes.noteWrong(guard, t))).to.equal(
						at .. tostring(locks)
					)
					if locks then
						-- the count starts again, which matters if CodeLockSeconds is ever made shorter than the window
						expect(at .. #guard.wrong).to.equal(at .. "0")
					end
				end
			end
		end)

		-- RedeemCode allows 1 try per 2 s. Guessing at that pace, no 60 s stretch may see more than
		-- CodeWrongLimit guesses reach the code table, and an hour lets through about 5 every 68 s.
		it(
			"lets at most CodeWrongLimit guesses through in any minute at the remote's limit",
			function()
				local guard = Codes.newGuard()
				local looked: { number } = {}
				for t = 0, 3600, 2 do
					if not Codes.locked(guard, t) then
						table.insert(looked, t)
						Codes.noteWrong(guard, t)
					end
				end
				for i, start in looked do
					local inside = 0
					for j = i, #looked do
						if looked[j] - start < Config.CodeWrongWindowSeconds then
							inside += 1
						end
					end
					expect(inside <= Config.CodeWrongLimit).to.equal(true)
				end
				expect(#looked <= 270).to.equal(true)
			end
		)

		-- The box must never open where RedeemCode would say "Walk up to the Codes Cat": the circle's edge sits 2 studs
		-- in front of the station's pivot (Layout and the asset; its centre 8 out at radius 6, #3112), and the box
		-- stays open to CodesCircleRadius + 1.
		it("keeps the open box inside CodesCatRange of the station", function()
			expect(2 + 2 * Config.CodesCircleRadius + 1 <= Config.CodesCatRange).to.equal(true)
		end)

		it(
			"never flickers on the circle's edge: a 2,000 step walk opens only inside and closes only past + 1",
			function()
				local open = false
				local distance = Config.CodesCircleRadius + 3
				for _ = 1, 2000 do
					distance = math.clamp(
						distance + (uniform() - 0.5) * 0.8,
						0,
						Config.CodesCircleRadius + 4
					)
					local now = Codes.circleOpen(open, distance)
					local at = string.format("%s at %.3f: ", open and "open" or "shut", distance)
					if open then
						expect(at .. tostring(now)).to.equal(
							at .. tostring(distance <= Config.CodesCircleRadius + 1)
						)
					else
						expect(at .. tostring(now)).to.equal(
							at .. tostring(distance <= Config.CodesCircleRadius)
						)
					end
					open = now
				end
			end
		)

		it("refuses in the order the box words it: unknown, used, expired, group", function()
			local profile = fresh()
			profile.codesRedeemed.launch = NOW - 10
			expect(Codes.refusal(profile, "nope", NOW, true)).to.equal(Codes.UNKNOWN)
			-- used wins over expired: an old code that has since been switched off still says it was used
			expect(Codes.refusal(profile, "launch", NOW, true)).to.equal(Codes.USED)
			expect(Codes.refusal(fresh(), "launch", NOW, true)).to.equal(Codes.EXPIRED)
			expect(Codes.refusal(fresh(), "group", NOW, false)).to.equal(Codes.GROUP)
			expect(Codes.refusal(fresh(), "playtest", NOW, false)).never.to.be.ok()
			for id, def in pairs(Catalog.codes) do
				expect(Codes.normalize(id)).to.equal(id)
				expect(def.id).to.equal(id)
			end
		end)
	end)
end
