--!strict
-- NightPass.luau (#2692): a beginner before their first check-in is untouched by the night.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local NightPass = require(Shared.NightPass)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("NightPass", function()
		it(
			"holds until the first check-in moves the tutorial to TutorialGuaranteedStrayStep",
			function()
				expect(Config.TutorialGuaranteedStrayStep).to.equal(2)
				expect(NightPass.has(0)).to.equal(true)
				expect(NightPass.has(1)).to.equal(true)
				expect(NightPass.has(2)).to.equal(false)
				expect(NightPass.has(5)).to.equal(false)
			end
		)

		it("opens the areas for its holder only", function()
			expect(NightPass.open(true, false)).to.equal(true)
			expect(NightPass.open(true, true)).to.equal(true)
			expect(NightPass.open(false, true)).to.equal(true)
			expect(NightPass.open(false, false)).to.equal(false)
		end)

		it(
			"keeps a Tier 1 save in its first session, only while the nightCatch switch is on (#3035)",
			function()
				expect(NightPass.first(1, 1, true)).to.equal(true)
				expect(NightPass.first(1, 0, true)).to.equal(true)
				expect(NightPass.first(1, 1, false)).to.equal(false) -- the switch off: today's night
				expect(NightPass.first(2, 1, true)).to.equal(false) -- ranked up
				expect(NightPass.first(1, 2, true)).to.equal(false) -- a returning player
			end
		)

		it("holds for a beginner whatever the switch, and for the first session with it", function()
			expect(NightPass.holds(0, 1, 1, false)).to.equal(true)
			expect(NightPass.holds(1, 3, 9, false)).to.equal(true)
			expect(NightPass.holds(2, 1, 1, false)).to.equal(false)
			expect(NightPass.holds(2, 1, 1, true)).to.equal(true)
			expect(NightPass.holds(5, 1, 1, true)).to.equal(true)
			expect(NightPass.holds(5, 2, 1, true)).to.equal(false)
			expect(NightPass.holds(5, 1, 2, true)).to.equal(false)
		end)

		it("reads a save's tier and session count", function()
			local profile: any = ProfileSchema.template(1700000000)
			profile.tutorialStep = 3
			profile.stats.sessions = 1
			expect(Economy.tier(profile)).to.equal(1)
			expect(NightPass.of(profile, true)).to.equal(true)
			expect(NightPass.firstOf(profile, true)).to.equal(true)
			expect(NightPass.of(profile, false)).to.equal(false)
			profile.stats.sessions = 2
			expect(NightPass.of(profile, true)).to.equal(false)
			profile.tutorialStep = 0 -- a beginner again: the #2692 pass, not the first-session one
			expect(NightPass.of(profile, false)).to.equal(true)
			expect(NightPass.firstOf(profile, false)).to.equal(false)
		end)

		it("names the switch and the two analytics markers", function()
			expect(NightPass.FLAG).to.equal("nightCatch")
			expect(table.find(LiveFlags.KEYS, NightPass.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[NightPass.FLAG]).to.equal(true)
			expect(NightPass.CAUGHT).to.equal("night_catch_first")
			expect(NightPass.LEFT_SUFFIX).to.equal("_nc")
		end)

		it("names the player attribute the client reads", function()
			expect(NightPass.ATTRIBUTE).to.equal("NightPass")
		end)
	end)
end
