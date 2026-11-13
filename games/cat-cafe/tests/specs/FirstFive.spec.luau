--!strict
-- shared/FirstFive.luau (#3098): the 2 to 5 minute funnel's buckets, awaited step and afford field.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local FirstFive = require(Shared.FirstFive)
	local Onboarding = require(Shared.Onboarding)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function stateAt(stepName: string)
		local profile = ProfileSchema.template(100)
		profile.telemetry.onboardingStep = Onboarding.index(stepName)
		profile.telemetry.achieved = {} -- a save from before #3660, which had its first table to buy
		return profile.telemetry
	end

	describe("idleBucket", function()
		it("splits idle seconds into the plan's four buckets", function()
			expect(FirstFive.idleBucket(0)).to.equal("0-5")
			expect(FirstFive.idleBucket(4.9)).to.equal("0-5")
			expect(FirstFive.idleBucket(5)).to.equal("5-15")
			expect(FirstFive.idleBucket(15)).to.equal("15-60")
			expect(FirstFive.idleBucket(60)).to.equal("60+")
			expect(FirstFive.idleBucket(900)).to.equal("60+")
		end)
	end)

	describe("snapScreen", function()
		it("names the plan's screens and folds the rest into other", function()
			expect(FirstFive.snapScreen("none")).to.equal("none")
			expect(FirstFive.snapScreen("Store")).to.equal("store")
			expect(FirstFive.snapScreen("Upgrades")).to.equal("upgrades")
			expect(FirstFive.snapScreen("Collection")).to.equal("index")
			expect(FirstFive.snapScreen("Settings")).to.equal("settings")
			expect(FirstFive.snapScreen("Spin")).to.equal("other")
		end)
	end)

	describe("awaited and newStalls", function()
		it("waits on the step after the furthest, nil past the last", function()
			expect(FirstFive.awaited(Onboarding.index("first_customer_served"))).to.equal(
				"second_cat"
			)
			expect(FirstFive.awaited(Onboarding.COUNT)).to.equal(nil)
		end)

		it("reports each stall bucket once, in order", function()
			local logged: { [number]: boolean } = {}
			expect(#FirstFive.newStalls(29, logged)).to.equal(0)
			local first = FirstFive.newStalls(61, logged)
			expect(#first).to.equal(2)
			expect(first[1]).to.equal(30)
			expect(first[2]).to.equal(60)
			logged[30] = true
			logged[60] = true
			expect(#FirstFive.newStalls(90, logged)).to.equal(0)
			local last = FirstFive.newStalls(120, logged)
			expect(#last).to.equal(1)
			expect(last[1]).to.equal(120)
		end)
	end)

	describe("nextBuy and afford", function()
		it("has no buy due before the first customer", function()
			expect(FirstFive.nextBuy(stateAt("first_catch"))).to.equal(nil)
			expect(FirstFive.afford(nil, 999, 10)).to.equal("na")
		end)

		it("is the first table, then the bait bowl", function()
			expect(FirstFive.nextBuy(stateAt("first_customer_served"))).to.equal("tables")
			expect(FirstFive.nextBuy(stateAt("first_table"))).to.equal("lure_bowl")
			expect(FirstFive.nextBuy(stateAt("bowl_bought"))).to.equal(nil)
		end)

		it(
			"is the bait bowl straight away for a new save, which starts with its table (#3660)",
			function()
				local telemetry = ProfileSchema.template(100).telemetry
				telemetry.onboardingStep = Onboarding.index("first_customer_served")
				expect(FirstFive.nextBuy(telemetry)).to.equal("lure_bowl")
			end
		)

		it("says yes or no against the cost, na when maxed", function()
			expect(FirstFive.afford("tables", 150, 150)).to.equal("yes")
			expect(FirstFive.afford("tables", 149, 150)).to.equal("no")
			expect(FirstFive.afford("tables", 999, nil)).to.equal("na")
		end)
	end)

	describe("P2 buckets", function()
		it("buckets ping and memory", function()
			expect(FirstFive.pingBucket(40)).to.equal("lt100")
			expect(FirstFive.pingBucket(100)).to.equal("100-250")
			expect(FirstFive.pingBucket(400)).to.equal("250+")
			expect(FirstFive.memoryBucket(500)).to.equal("lt800")
			expect(FirstFive.memoryBucket(1200)).to.equal("800-1500")
			expect(FirstFive.memoryBucket(3000)).to.equal("1500+")
		end)

		it("buckets the minutes away and the session number", function()
			expect(FirstFive.awayBucket(0)).to.equal("0-10")
			expect(FirstFive.awayBucket(10)).to.equal("10-30")
			expect(FirstFive.awayBucket(59)).to.equal("30-60")
			expect(FirstFive.sessionBucket(2)).to.equal("2")
			expect(FirstFive.sessionBucket(3)).to.equal("3")
			expect(FirstFive.sessionBucket(9)).to.equal("4+")
		end)

		it("buckets the cafe left behind", function()
			local fields = FirstFive.cafeFields(0, 0, 0)
			expect(table.concat(fields, ",")).to.equal("0,0,1")
			expect(table.concat(FirstFive.cafeFields(2, 1, 3), ",")).to.equal("2,1,3")
			expect(table.concat(FirstFive.cafeFields(7, 4, 12), ",")).to.equal("3+,2+,4+")
		end)
	end)

	describe("scene (P1b)", function()
		local function facts(over: { [string]: any }): any
			local out: { [string]: any } = {
				loaded = true,
				introSeen = true,
				introShot = 0,
				launching = false,
				carrying = false,
				furthest = "first_move",
				where = "none",
			}
			for key, value in over do
				out[key] = value
			end
			return out
		end

		it(
			"is loading before the client reports, then the intro shot while the intro runs",
			function()
				expect(FirstFive.scene(facts({ loaded = false }))).to.equal("loading")
				expect(FirstFive.scene(facts({ introSeen = false, introShot = 4 }))).to.equal(
					"intro_shot_4"
				)
				expect(FirstFive.scene(facts({ introSeen = false, introShot = 0 }))).to.equal(
					"intro_start"
				)
				expect(FirstFive.scene(facts({ introSeen = false, introShot = 11 }))).to.equal(
					"intro_start"
				)
				expect(FirstFive.scene(facts({ introSeen = true, introShot = 4, where = "cafe" }))).to.equal(
					"cafe"
				)
			end
		)

		it("names every intro shot the cutscene has", function()
			local Intro = require(Shared.Intro)
			expect(FirstFive.INTRO_SHOTS >= Intro.SHOTS).to.equal(true)
		end)

		it("buckets the wait for the first scene", function()
			expect(FirstFive.firstSceneBucket(3)).to.equal("0-10")
			expect(FirstFive.firstSceneBucket(10)).to.equal("10-20")
			expect(FirstFive.firstSceneBucket(25)).to.equal("20-40")
			expect(FirstFive.firstSceneBucket(90)).to.equal("40+")
		end)

		it(
			"prefers a flight, then a carry, then the catch, then a tutorial card, then the place",
			function()
				expect(FirstFive.scene(facts({ launching = true, carrying = true }))).to.equal(
					"cannon_flight"
				)
				expect(FirstFive.scene(facts({ carrying = true, furthest = "catch_started" }))).to.equal(
					"carry"
				)
				expect(FirstFive.scene(facts({ furthest = "first_circle_hit" }))).to.equal(
					"circle_open"
				)
				expect(FirstFive.scene(facts({ furthest = "catch_card_opened" }))).to.equal(
					"catch_prompt"
				)
				expect(FirstFive.scene(facts({ furthest = "tut_3_shown", where = "cafe" }))).to.equal(
					"tut_3"
				)
				expect(FirstFive.scene(facts({ where = "alley" }))).to.equal("alley")
				expect(FirstFive.scene(facts({ where = "cafe" }))).to.equal("cafe")
				expect(FirstFive.scene(facts({ where = "park" }))).to.equal("other")
			end
		)

		it("only ever names a listed scene", function()
			for _, where in { "none", "cafe", "alley", "park" } do
				local scene = FirstFive.scene(facts({ where = where }))
				expect(table.find(FirstFive.SCENES, scene) ~= nil).to.equal(true)
			end
		end)

		it("buckets the seconds", function()
			expect(FirstFive.secondsBucket(10)).to.equal("0-30")
			expect(FirstFive.secondsBucket(30)).to.equal("30-60")
			expect(FirstFive.secondsBucket(90)).to.equal("60-120")
			expect(FirstFive.secondsBucket(200)).to.equal("120-300")
			expect(FirstFive.secondsBucket(301)).to.equal("300+")
		end)
	end)

	describe("secondCatDue", function()
		it("is due from the first check-in until the second cat", function()
			expect(FirstFive.secondCatDue(stateAt("first_catch"))).to.equal(false)
			expect(FirstFive.secondCatDue(stateAt("first_checkin"))).to.equal(true)
			expect(FirstFive.secondCatDue(stateAt("first_customer_served"))).to.equal(true)
			expect(FirstFive.secondCatDue(stateAt("second_cat"))).to.equal(false)
		end)
	end)
end
