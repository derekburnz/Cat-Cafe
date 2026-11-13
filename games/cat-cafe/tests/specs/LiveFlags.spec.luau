--!strict
-- shared/LiveFlags.luau (#2119): the live switches `codes` and `rally` read from CatCafe_Flags. Only an explicit false
-- turns a feature off, so a missing key, a wrong type or an unreadable store never switches the game off.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local Codes = require(Shared.Codes)

	describe("parse", function()
		it("is every switch on when nothing is set", function()
			local flags = LiveFlags.parse({})
			expect(flags.codes).to.equal(true)
			expect(flags.rally).to.equal(true)
			expect(LiveFlags.parse(nil).codes).to.equal(true)
			expect(LiveFlags.parse("off").rally).to.equal(true)
		end)

		it("turns a switch off only for an explicit false", function()
			local flags = LiveFlags.parse({ codes = false })
			expect(flags.codes).to.equal(false)
			expect(flags.rally).to.equal(true)
			flags = LiveFlags.parse({ rally = false, codes = true })
			expect(flags.codes).to.equal(true)
			expect(flags.rally).to.equal(false)
		end)

		it("keeps a switch on for a value of another type", function()
			for _, value in { "false", 0, {}, "off" } do
				local flags = LiveFlags.parse({ codes = value, rally = value })
				expect(flags.codes).to.equal(true)
				expect(flags.rally).to.equal(true)
			end
		end)

		it("ignores keys it doesn't know", function()
			local flags = LiveFlags.parse({ trading = false, everything = false })
			for _, key in LiveFlags.KEYS do
				expect(flags[key]).to.equal(LiveFlags.OFF_BY_DEFAULT[key] ~= true)
			end
			expect(flags.trading).to.equal(nil)
		end)
	end)

	describe("awayNotes (#2768, on unless switched off)", function()
		it("is a live switch that only an explicit false turns off", function()
			expect(table.find(LiveFlags.KEYS, "awayNotes") ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT.awayNotes).to.equal(nil)
			expect(LiveFlags.defaults().awayNotes).to.equal(true)
			expect(LiveFlags.parse({}).awayNotes).to.equal(true)
			expect(LiveFlags.parse({ awayNotes = "false" }).awayNotes).to.equal(true)
			expect(LiveFlags.parse({ awayNotes = false }).awayNotes).to.equal(false)
		end)
	end)

	describe("starterRefill (#3049, on unless switched off)", function()
		it("is a live switch that only an explicit false turns off", function()
			expect(table.find(LiveFlags.KEYS, "starterRefill") ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT.starterRefill).to.equal(nil)
			expect(LiveFlags.defaults().starterRefill).to.equal(true)
			expect(LiveFlags.parse({}).starterRefill).to.equal(true)
			expect(LiveFlags.parse({ starterRefill = false }).starterRefill).to.equal(false)
		end)
	end)

	describe("tradeFish (#2745, off until QA and the security review pass)", function()
		it(
			"starts off, and stays off for a missing key, a wrong type or an unreadable store",
			function()
				expect(LiveFlags.defaults().tradeFish).to.equal(false)
				expect(LiveFlags.parse({}).tradeFish).to.equal(false)
				expect(LiveFlags.parse(nil).tradeFish).to.equal(false)
				for _, value in { "true", 1, {}, "on", false } do
					expect(LiveFlags.parse({ tradeFish = value }).tradeFish).to.equal(false)
				end
			end
		)

		it("turns on only for an explicit true, and leaves the other switches alone", function()
			local flags = LiveFlags.parse({ tradeFish = true })
			expect(flags.tradeFish).to.equal(true)
			expect(flags.codes).to.equal(true)
			expect(flags.tradeCrates).to.equal(true)
			expect(LiveFlags.parse({ codes = true }).tradeFish).to.equal(false)
		end)

		it(
			"starts off with nightCatch, loadingScreen, goldenDrops, traits, swiftPaws5, mouseDash, cartTier6, secretCats, luckyCharm, rareCatsTab, afkCafe, autoRejoin, binRoll, yardSaleRoll, introSplit, newKindTag, parkGateTrail, touchCatchReach, rankUpSpotlight, menuFamily, speedShoes, petCats, returnGift, picnicTreats, traitBundles and rareCustomers alone beside it",
			function()
				local count = 0
				for key in LiveFlags.OFF_BY_DEFAULT do
					count += 1
					expect(
						key == "tradeFish"
							or key == "nightCatch"
							or key == "loadingScreen"
							or key == "goldenDrops"
							or key == "traits"
							or key == "swiftPaws5"
							or key == "mouseDash"
							or key == "cartTier6"
							or key == "secretCats"
							or key == "luckyCharm"
							or key == "rareCatsTab"
							or key == "afkCafe"
							or key == "autoRejoin"
							or key == "binRoll"
							or key == "yardSaleRoll"
							or key == "introSplit"
							or key == "newKindTag"
							or key == "parkGateTrail"
							or key == "touchCatchReach"
							or key == "rankUpSpotlight"
							or key == "bagColours"
							or key == "menuFamily"
							or key == "speedShoes"
							or key == "petCats"
							or key == "returnGift"
							or key == "picnicTreats"
							or key == "traitBundles"
							or key == "rareCustomers"
					).to.equal(true)
					expect(table.find(LiveFlags.KEYS, key) ~= nil).to.equal(true)
				end
				expect(count).to.equal(28)
				-- #3462 and #3470: new saved ids stay off until every server knows them
				expect(LiveFlags.defaults().cartTier6).to.equal(false)
				expect(LiveFlags.defaults().secretCats).to.equal(false)
				expect(LiveFlags.parse({ cartTier6 = true }).cartTier6).to.equal(true)
				expect(LiveFlags.parse({ secretCats = "yes" }).secretCats).to.equal(false)
				-- #3296: no Mouse Dash until QA passes and it is switched on
				expect(LiveFlags.defaults().mouseDash).to.equal(false)
				-- Circle Streak stays until it is vaulted by an explicit false
				expect(LiveFlags.defaults().circleStreak).to.equal(true)
				expect(LiveFlags.parse({ circleStreak = false }).circleStreak).to.equal(false)
				expect(LiveFlags.parse({ mouseDash = true }).mouseDash).to.equal(true)
				-- #2912: the stuck cat's call stays on (it is live) until an explicit false hides it
				expect(LiveFlags.defaults().stuckCall).to.equal(true)
				expect(LiveFlags.parse({ stuckCall = false }).stuckCall).to.equal(false)
				expect(LiveFlags.shown("stuckCall", nil)).to.equal(true)
				expect(LiveFlags.shown("stuckCall", false)).to.equal(false)
				-- #3222: no Golden drop until it is switched on, even with a broken store
				expect(LiveFlags.defaults().goldenDrops).to.equal(false)
				expect(LiveFlags.parse(nil).goldenDrops).to.equal(false)
				expect(LiveFlags.parse({ goldenDrops = true }).goldenDrops).to.equal(true)
				-- #3196: no traits until the restart publish that ships their save fields switches them on
				expect(LiveFlags.defaults().traits).to.equal(false)
				expect(LiveFlags.parse({ traits = true }).traits).to.equal(true)
			end
		)
	end)

	describe("loadingScreen (#3179, off until switched on)", function()
		it("is off by default, with a broken store, and with anything but true", function()
			expect(LiveFlags.defaults().loadingScreen).to.equal(false)
			expect(LiveFlags.parse(nil).loadingScreen).to.equal(false)
			for _, value in { false, "true", 1, {} } :: { any } do
				expect(LiveFlags.parse({ loadingScreen = value }).loadingScreen).to.equal(false)
			end
			expect(LiveFlags.parse({ loadingScreen = true }).loadingScreen).to.equal(true)
		end)

		it("is off on a client until its attribute reads true", function()
			expect(LiveFlags.shown("loadingScreen", nil)).to.equal(false)
			expect(LiveFlags.shown("loadingScreen", false)).to.equal(false)
			expect(LiveFlags.shown("loadingScreen", "true")).to.equal(false)
			expect(LiveFlags.shown("loadingScreen", true)).to.equal(true)
		end)

		it("leaves a switch that is on by default on until its attribute reads false", function()
			expect(LiveFlags.shown("swiftPaws", nil)).to.equal(true)
			expect(LiveFlags.shown("swiftPaws", true)).to.equal(true)
			expect(LiveFlags.shown("swiftPaws", false)).to.equal(false)
		end)
	end)

	describe("nightCatch (#3035, off until switched on)", function()
		it("is on only for an explicit true", function()
			expect(LiveFlags.defaults().nightCatch).to.equal(false)
			expect(LiveFlags.parse({}).nightCatch).to.equal(false)
			expect(LiveFlags.parse(nil).nightCatch).to.equal(false)
			for _, value in { "true", 1, false } :: { any } do
				expect(LiveFlags.parse({ nightCatch = value }).nightCatch).to.equal(false)
			end
			expect(LiveFlags.parse({ nightCatch = true }).nightCatch).to.equal(true)
		end)
	end)

	describe("swiftPaws (#3063, on unless switched off)", function()
		it("is a switch, on by default and off only for an explicit false", function()
			expect(table.find(LiveFlags.KEYS, "swiftPaws") ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT.swiftPaws).to.equal(nil)
			expect(LiveFlags.defaults().swiftPaws).to.equal(true)
			expect(LiveFlags.parse({ swiftPaws = "false" }).swiftPaws).to.equal(true)
			expect(LiveFlags.parse({ swiftPaws = false }).swiftPaws).to.equal(false)
		end)
	end)

	describe("arcade (#3062, on unless switched off)", function()
		it("is a switch, on by default and off only for an explicit false", function()
			expect(table.find(LiveFlags.KEYS, "arcade") ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT.arcade).to.equal(nil)
			expect(LiveFlags.defaults().arcade).to.equal(true)
			expect(LiveFlags.parse({ arcade = false }).arcade).to.equal(false)
			expect(LiveFlags.shown("arcade", nil)).to.equal(true)
		end)
	end)

	describe("changed", function()
		it("names the switches that moved, in KEYS order", function()
			local on = LiveFlags.defaults()
			expect(#LiveFlags.changed(on, LiveFlags.parse({}))).to.equal(0)
			local moved = LiveFlags.changed(on, LiveFlags.parse({ rally = false, codes = false }))
			expect(#moved).to.equal(2)
			expect(moved[1]).to.equal("codes")
			expect(moved[2]).to.equal("rally")
		end)
	end)

	it("reads the same store as trading's kill switch, within about a minute", function()
		expect(LiveFlags.STORE).to.equal("CatCafe_Flags")
		expect(LiveFlags.CHECK_SECONDS <= 60).to.equal(true)
		expect(table.find(LiveFlags.KEYS, "codes") ~= nil).to.equal(true)
		expect(table.find(LiveFlags.KEYS, "rally") ~= nil).to.equal(true)
	end)

	it("has a player-facing answer for paused codes", function()
		expect(type(Codes.PAUSED)).to.equal("string")
		expect(Codes.PAUSED ~= Codes.UNKNOWN).to.equal(true)
	end)
end
