--!strict
-- shared/LiveFlags.luau (#2119): the live switches `codes` and `rally` read from CatCafe_Flags. Only an explicit false
-- turns a feature off, so a missing key, a wrong type or an unreadable store never switches the game off.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local Codes = require(Shared.Codes)

	describe("the first read, before the client takes a switch once (#4613)", function()
		local function fake(readyAfter: number?)
			local now = 0
			local holder = {
				GetAttribute = function(_self: any, name: string): any
					if name ~= LiveFlags.READY_ATTRIBUTE then
						return nil
					end
					return if readyAfter ~= nil and now >= readyAfter then true else nil
				end,
			}
			local function clock(): number
				return now
			end
			local function sleep(seconds: number)
				now += seconds
			end
			return holder, clock, sleep
		end

		it("goes on at once when the server has read its switches", function()
			local holder, clock, sleep = fake(0)
			local ready, waited = LiveFlags.awaitReady(holder, 8, clock, sleep)
			expect(ready).to.equal(true)
			expect(waited).to.equal(0)
		end)

		it("waits for the server's first read", function()
			local holder, clock, sleep = fake(2.5)
			local ready, waited = LiveFlags.awaitReady(holder, 8, clock, sleep, 0.5)
			expect(ready).to.equal(true)
			expect(waited).to.be.near(2.5, 1e-9)
		end)

		it("gives up at the cap so a stuck store never holds the game", function()
			local holder, clock, sleep = fake(nil)
			local ready, waited =
				LiveFlags.awaitReady(holder, LiveFlags.CLIENT_WAIT_SECONDS, clock, sleep, 0.5)
			expect(ready).to.equal(false)
			expect(waited >= LiveFlags.CLIENT_WAIT_SECONDS).to.equal(true)
			expect(waited < LiveFlags.CLIENT_WAIT_SECONDS + 0.5 + 1e-9).to.equal(true)
		end)

		it("an off-by-default switch reads off until the server has copied it out", function()
			expect(LiveFlags.shown("goldenDrops", nil)).to.equal(false)
			expect(LiveFlags.shown("goldenDrops", true)).to.equal(true)
		end)
	end)

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
			"starts off with nightCatch, loadingScreen, goldenDrops, luckyCharm, introSplit, parkGateTrail, rareCustomers, updateFeature, starterSuggest, ticketBooth, deviceFixes, afkButton, autoBowl, mailbox, giftCard, storeGuard, noIntro, fxOneAdded, rankUpRightAway, parkRingEarly, tier3Path, parkTrailBack, areaOnly, cafeGrows, palDay, fxAfterLoad, tomorrowCard, cannonCue, harvestPieLow, tablesSpread, strayWalkSlow, stationCut, firstRankLock, likeAskEarly and nightSlice alone beside it",
			function()
				local count = 0
				for key in LiveFlags.OFF_BY_DEFAULT do
					count += 1
					expect(
						key == "tradeFish"
							or key == "nightCatch"
							or key == "townFast" -- #5584
							or key == "perfectFlagged" -- #5379
							or key == "decorNoBang" -- #5574
							or key == "loadingScreen"
							or key == "feedInstant" -- #5578
							or key == "walkUpCarry" -- #5415
							or key == "goldenDrops"
							or key == "richInside" -- #5582
							or key == "areaCannonRings" -- #5416
							or key == "luckyCharm"
							or key == "introSplit"
							or key == "parkGateTrail"
							or key == "ticketBooth"
							or key == "rareCustomers"
							or key == "starterSuggest"
							or key == "updateFeature"
							or key == "autoBowl"
							or key == "padControls"
							or key == "afkButton" -- #4346
							or key == "cannonReturnNow" -- #5417
							or key == "areasKept" -- #5381
							or key == "areasKeptBig" -- Sync 2026-11-19
							or key == "deviceFixes"
							or key == "areasKeptRecent" -- Derek 2026-11-19
							or key == "mailbox" -- #4249
							or key == "earlyKindBonus" -- #4624
							or key == "returnHookEarly" -- #4626
							or key == "journeys" -- #4544
							or key == "giftCard" -- #4527
							or key == "storeGuard" -- #4472
							or key == "noIntro" -- #4929
							or key == "firstFlightQuick" -- #4920
							or key == "backdropsNear" -- #4857
							or key == "catNames" -- #5586
							or key == "fxOneAdded" -- #5000
							or key == "picnicParty" -- #5572
							or key == "cherryGrove" -- #5339
							or key == "rankUpRightAway" -- #5031
							or key == "parkRingEarly" -- #5034
							or key == "tier3Path" -- #5038
							or key == "parkTrailBack" -- #5045
							or key == "palDay" -- #4913
							or key == "areaOnly" -- #5026
							or key == "harvestPieLow" -- #4251
							or key == "secretDouble" -- #5418
							or key == "walkUpRetry" -- #5386
							or key == "cafeGrows" -- #4543
							or key == "fxAfterLoad" -- #5068
							or key == "tomorrowCard" -- #3951
							or key == "cannonCue" -- #5097
							or key == "tablesSpread" -- #4763
							or key == "strayWalkSlow" -- #4601
							or key == "stationCut" -- #5112
							or key == "firstRankLock" -- Derek 2026-11-17
							or key == "rankSpotPlain" -- Derek 2026-11-18
							or key == "townRings" -- Derek 2026-11-18
							or key == "likeAskEarly" -- #5152
							or key == "nightSlice" -- #5164
							or key == "spinCat" -- #5171
							or key == "nightSpread" -- #5164
							or key == "netTiers" -- #5170
							or key == "tablesEight" -- #5441
							or key == "nightLine" -- #5330
							or key == "companionMenu" -- #5296
							or key == "companionTraits" -- #5303
							or key == "perfectCatch" -- #5300
							or key == "easyKeep" -- #5311
							or key == "bangFixedText" -- #5390
							or key == "afkQuick" -- #5310
							or key == "afkStay" -- #5322
							or key == "strayMeets" -- onboarding_v9
							or key == "bigTreats" -- Derek 2026-11-18
							or key == "tomorrowBoard" -- #5449
							or key == "walkUpCardWait" -- Derek 2026-11-19
							or key == "bigNet" -- #5309
							or key == "cannonReturn" -- #5304
							or key == "cheapTiers" -- #5249
							or key == "tier4Easy" -- #5285 E
							or key == "companionNudge" -- #5364
							or key == "plushSecret" -- #5414
							or key == "keepLook" -- #5433
							or key == "bowlLockBig" -- #5455
							or key == "shieldNoBump" -- #5476
							or key == "parkFirstCalm" -- #5496
							or key == "missKeepsCommon" -- #5500
							or key == "orderSplit" -- #5498
							or key == "dailyGifts" -- #5506
							or key == "awayPromise" -- #5505
							or key == "holdout" -- #5499
							or key == "catchLostLog" -- #5500
							or key == "tier3TripLog" -- #5517
							or key == "returnMoment" -- #5505
							or key == "rankCueLog" -- #5516
							or key == "hoodTrail" -- #5517
							or key == "rankTapLog" -- #5516
							or key == "mutationBoost" -- #5493
							or key == "bowlOptionsButton" -- #5488
							or key == "bowlOptionsList" -- #5472
							or key == "companionBetter" -- #5457
							or key == "tier3Easy" -- #5467
							or key == "tiersEasy" -- Derek 2026-11-19
							or key == "freeStart" -- #5533
							or key == "streetCats" -- #5533
							or key == "goalChip" -- #5533
							or key == "coinsOnly" -- #5533
							or key == "secretTraitTile" -- #5445
							or key == "oneLadderRow" -- #5254
							or key == "noRankOpens" -- #5258
							or key == "kingCatInfo" -- #5260
							or key == "foodByRarity" -- #5264
							or key == "bowlTicks" -- #5263
							or key == "rankUpSteps" -- #5218
							or key == "rankSpotStay" -- #5516
							or key == "goalNeedLine" -- #5331
							or key == "catFollower" -- #5172
							or key == "cardFollow" -- #5296
							or key == "companionScene" -- #5284
							or key == "parkRankPoint" -- #5163
							or key == "catchCurve" -- #5392
							or key == "parkFirstEasy" -- #5182
							or key == "areaWhole" -- Derek 2026-11-18
							or key == "crateUnstick" -- #5394
							or key == "cannonAnywhere" -- #5382
							or key == "nextGoalBeat" -- #5202
							or key == "milestoneFunnel" -- #5291
							or key == "topTraitCompanion" -- #5445
							or key == "topTraitsMore" -- #5445
							or key == "townGround" -- #5357
							or key == "tipPileOldest" -- #5422
							or key == "decorChipIcons" -- #5366
							or key == "bowlHintRetry" -- #5438
							or key == "giftBangMine" -- #5576
							or key == "rankOneTap" -- #5533
							or key == "rankTapLook" -- #5592
							or key == "askClean" -- #5597
							or key == "chipPickedWord" -- #5406
							or key == "bowlWalkQuiet" -- #5436
							or key == "bowlNoPops" -- #5571
							or key == "tameCannonPoint" -- #5245
							or key == "parkLead" -- #5248
							or key == "promptsAfter5" -- #5251
							or key == "upgradesInstant" -- #5253
							or key == "nightBright" -- #5240
							or key == "frontDoors" -- #5385
							or key == "ringSolid" -- #5256
							or key == "phoneSmooth" -- #5285
							or key == "quickFirstRings" -- #5232
							or key == "firstCatchWow" -- #5285
							or key == "gemsShrink" -- Derek 2026-11-18
							or key == "christmasEvent" -- snowglobe-village-spec
							or key == "adventCalendar" -- #5502
							or key == "keepNoEvent" -- #5428
							or key == "cannonCloudsEarly" -- #5370
							or key == "catsArrowOff" -- #5485
							or key == "baitCutQuick" -- #5548
							or key == "firstCatchCoins" -- #5596
							or key == "stallGlow" -- #5533
							or key == "cannonGlow" -- #5533
							or key == "rankPicker" -- #5599
							or key == "cutsQuick" -- #5550
							or key == "steadySoft" -- #5601
							or key == "pawsInFloor" -- #5471
							or key == "firstCatArrow" -- #5594
							or key == "guideArrow" -- #5465
							or key == "codesRingTown" -- #5605
							or key == "lockedRingsHidden" -- #5463
							or key == "parkCatchNormal" -- Derek 2026-11-20
							or key == "picnicCardFix" -- Derek 2026-11-20
							or key == "bowlAutoFree" -- Derek 2026-11-20
							or key == "bowlPassOptions" -- #5606
							or key == "nightLineNoArrow" -- #5459
							or key == "spawnAlley" -- #5616
							or key == "tier3Up" -- #5617
							or key == "spotHeld" -- #5622
							or key == "secondCatQuiet" -- #5620
							or key == "catNamesLow" -- #5620
							or key == "catNamesTop" -- #5633
							or key == "rankLeftLog" -- Growth
							or key == "padSkip" -- #5624
							or key == "padHud" -- #5624
							or key == "rankDimTwo" -- #5609
							or key == "secretCompanionBig" -- #5431
					).to.equal(true)
					expect(table.find(LiveFlags.KEYS, key) ~= nil).to.equal(true)
				end
				-- 2026-11-18 train (Review-QA): a minimum, so parallel switch PRs stop clashing on one number; 83 with the
				-- train (cardFollow, bigTreats, bigNet, rankUpSteps, companionScene, phoneSmooth, #5301, cannonReturn, #5313)
				expect(count >= 84).to.equal(true) -- strayMeets; christmasEvent; #5232 quickFirstRings; #5256 ringSolid; #5263 bowlTicks; #5264 foodByRarity; #5260 kingCatInfo; #5258 noRankOpens; #5254 oneLadderRow; #5249 cheapTiers; #5240 nightBright; #5245 tameCannonPoint; #5248 parkLead; Derek 2026-11-18: townRings; #5251 promptsAfter5; #5253 upgradesInstant; #5240 nightBright; Derek 2026-11-18: rankSpotPlain; Derek 2026-11-18: less tradeSpot (removed); #5202 nextGoalBeat; Derek 2026-11-18 areaWhole; #4656: less goldTone; #5182 parkFirstEasy; #5163 parkRankPoint; #5172 catFollower; #5170 netTiers; #5164 nightSpread; #5171 spinCat; #5164 nightSlice; #5158 tradeSpot; #5152 likeAskEarly; firstRankLock (Derek 2026-11-17); #5112 stationCut; #4601 strayWalkSlow; #4763 tablesSpread; #3572: less storeRework; #5097 cannonCue; #4251 harvestPieLow; #3951 tomorrowCard; #5068 fxAfterLoad; #4543 cafeGrows; #5026 areaOnly; #5045 parkTrailBack; #5038 tier3Path; #5031 rankUpRightAway, #5034 parkRingEarly; #4913 palDay; #4654: less swiftPaws10; #5000 fxOneAdded; #4857 backdropsNear; #4920 firstFlightQuick; #4929 noIntro; #4654: 56 less the 12 shipped switches retired in batches 1 to 3 and riftRun, plus giftCard (#4527) and storeGuard (#4472), less menuFamily (#4657), plus journeys (#4544), less the 13 in batches 4 to 10
				-- #4654: the shipped stuckCall and fxLite switches are gone
				expect(table.find(LiveFlags.KEYS, "stuckCall")).to.equal(nil)
				expect(table.find(LiveFlags.KEYS, "fxLite")).to.equal(nil)
				-- #3222: no Golden drop until it is switched on, even with a broken store
				expect(LiveFlags.defaults().goldenDrops).to.equal(false)
				expect(LiveFlags.parse(nil).goldenDrops).to.equal(false)
				expect(LiveFlags.parse({ goldenDrops = true }).goldenDrops).to.equal(true)
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
