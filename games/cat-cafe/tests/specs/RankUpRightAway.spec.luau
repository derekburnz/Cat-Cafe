--!strict
-- #5031: after the first check-in the Rank Up is put in front of a new player (shared/RankUpRightAway).

return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared:WaitForChild("Catalog"))
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local Onboarding = require(Shared:WaitForChild("Onboarding"))
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema"))
	local RankUpRightAway = require(Shared:WaitForChild("RankUpRightAway"))

	-- a Tier 1 save past its first check-in, holding `n` plain cats that count toward Tier 2
	local function checkedIn(n: number): any
		local profile = ProfileSchema.template(1000) :: any
		profile.cats = {}
		profile.collection = {}
		local plain: { string } = {}
		for _, def in Catalog.cats do
			if def.exclusive ~= true and def.area == "alley" and def.rarity == "Common" then
				table.insert(plain, def.id)
			end
		end
		for i = 1, n do
			local catId = plain[((i - 1) % #plain) + 1]
			profile.collection[catId] = true
			profile.cats["u" .. i] = { uid = "u" .. i, catId = catId }
		end
		profile.telemetry.onboardingStep =
			table.find(Onboarding.STEPS :: { any }, "first_checkin") :: number
		return profile
	end

	local function again(o: { [string]: any }): boolean
		local base =
			{ on = true, ready = true, pressed = false, closes = 1, reopened = 0, landed = true }
		for key, value in o do
			(base :: any)[key] = value
		end
		return RankUpRightAway.againDue(base :: any)
	end

	describe("RankUpRightAway", function()
		it("is a live switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, RankUpRightAway.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[RankUpRightAway.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[RankUpRightAway.FLAG]).to.equal(false)
		end)

		it("counts Tier 2's cats still short after the first check-in, and only then", function()
			local need = (Catalog.getTier(2) :: any).distinctCats
			expect(RankUpRightAway.catsShort(checkedIn(need - 1))).to.equal(1)
			expect(RankUpRightAway.catsShort(checkedIn(need))).to.equal(0)
			local before = checkedIn(need - 1)
			before.telemetry.onboardingStep = table.find(
				Onboarding.STEPS :: { any },
				"first_checkin"
			) :: number - 1
			before.telemetry.achieved = {}
			expect(RankUpRightAway.catsShort(before)).to.equal(0)
			local tier2 = checkedIn(1)
			tier2.tier = 2
			expect(RankUpRightAway.catsShort(tier2)).to.equal(0)
		end)

		it("has a stray wait only with the switch on and a cat short", function()
			local need = (Catalog.getTier(2) :: any).distinctCats
			expect(RankUpRightAway.strayWaits(checkedIn(need - 1), true)).to.equal(true)
			expect(RankUpRightAway.strayWaits(checkedIn(need - 1), false)).to.equal(false)
			expect(RankUpRightAway.strayWaits(checkedIn(need), true)).to.equal(false)
		end)

		it("opens a closed window again on landing, once a close and at most twice", function()
			expect(again({})).to.equal(true)
			expect(again({ on = false })).to.equal(false)
			expect(again({ ready = false })).to.equal(false)
			expect(again({ pressed = true })).to.equal(false)
			expect(again({ landed = false })).to.equal(false)
			expect(again({ closes = 0 })).to.equal(false)
			expect(again({ closes = 1, reopened = 1 })).to.equal(false) -- reopened already for this close
			expect(again({ closes = 2, reopened = 1 })).to.equal(true)
			expect(again({ closes = 3, reopened = 2 })).to.equal(false) -- REOPENS used up
		end)

		it("words the goal card's lines", function()
			expect(RankUpRightAway.shortTitle(1)).to.equal("Catch 1 more cat to rank up")
			expect(RankUpRightAway.shortTitle(2)).to.equal("Catch 2 more cats to rank up")
			expect(RankUpRightAway.READY_TITLE).to.equal("Rank up now! Your cafe is ready")
		end)
	end)
end
