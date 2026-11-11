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

		it("says yes or no against the cost, na when maxed", function()
			expect(FirstFive.afford("tables", 150, 150)).to.equal("yes")
			expect(FirstFive.afford("tables", 149, 150)).to.equal("no")
			expect(FirstFive.afford("tables", 999, nil)).to.equal("na")
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
