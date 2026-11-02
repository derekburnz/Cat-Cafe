--!strict
-- Context tips and the feedback values (F87, easy-start.md sections 3, 4 and 6; shared/Tips).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Tips = require(Shared.Tips)

	local DAY: Tips.Moment = { duskWarning = false, night = false }

	local function fresh(): any
		local profile: any = ProfileSchema.template(1000)
		return profile
	end

	describe("the tip table (section 3)", function()
		it("lists the 14 tips in the design's order with their kind", function()
			local got: { string } = {}
			for _, def in Tips.LIST do
				table.insert(got, def.id .. ":" .. def.kind)
			end
			expect(got :: any).to.deepEqual({
				"bowl:cut",
				"second_cat:card",
				"stuck_cat:card",
				"tackle:card",
				"dropped:card",
				"night:card",
				"rank_up:cut",
				"golden_fish:cut",
				"potion:card",
				"dealer:cut",
				"spin_wheel:cut",
				"codes_cat:card",
				"luck:card",
				"offline:card",
			})
		end)

		it("leaves to the client only what it alone can see", function()
			local client: { string } = {}
			for _, def in Tips.LIST do
				if def.by == "client" then
					table.insert(client, def.id)
				end
			end
			expect(client :: any).to.deepEqual({ "stuck_cat", "codes_cat", "luck", "offline" })
		end)

		it("takes the tips and the three asks on TipSeen, nothing else", function()
			for _, def in Tips.LIST do
				expect(Tips.seenId(def.id)).to.equal(true)
				expect(Tips.get(def.id)).to.equal(def)
			end
			expect(Tips.seenId(Tips.LIKE_ASK)).to.equal(true)
			expect(Tips.seenId(Tips.FEEDBACK_ASK)).to.equal(true)
			expect(Tips.seenId(Tips.STUCK_HELP)).to.equal(true)
			expect(Tips.seenId("free_coins")).to.equal(false)
			expect(Tips.get(Tips.LIKE_ASK)).never.to.be.ok()
		end)

		it("shows the offline line after 10 minutes away", function()
			expect(Tips.OFFLINE_SECONDS).to.equal(600)
		end)
	end)

	describe("due", function()
		it("has nothing for a new player by day", function()
			expect(#Tips.due(fresh(), DAY)).to.equal(0)
		end)

		it("shows the bowl cut with food and an empty bowl, and not with the bowl full", function()
			local profile = fresh()
			profile.upgradeLevels.lure_bowl = 1
			profile.lures = { kibble = 2 }
			expect(Tips.due(profile, DAY) :: any).to.deepEqual({ "bowl" })
			profile.bait = { lureId = "kibble", placedAt = 0, readyAt = 10 }
			expect(#Tips.due(profile, DAY)).to.equal(0)
			profile.bait = nil
			profile.lures = { kibble = 0 }
			expect(#Tips.due(profile, DAY)).to.equal(0)
		end)

		it("shows night in the dusk warning and the dealer at night from Tier 2", function()
			local profile = fresh()
			expect(Tips.due(profile, { duskWarning = true, night = false }) :: any).to.deepEqual({
				"night",
			})
			profile.tier = 2
			expect(#Tips.due(profile, DAY)).to.equal(0)
			expect(Tips.due(profile, { duskWarning = false, night = true }) :: any).to.deepEqual({
				"dealer",
			})
		end)

		it("shows golden fish, potion and spin wheel from the save, in table order", function()
			local profile = fresh()
			profile.goldenFish = 3
			profile.potions = { tip_potion = 1 }
			profile.tutorialStep = 5
			expect(Tips.due(profile, DAY) :: any).to.deepEqual({
				"golden_fish",
				"potion",
				"spin_wheel",
			})
		end)

		it("never lists a tip already seen", function()
			local profile = fresh()
			profile.goldenFish = 3
			profile.tipsSeen = { golden_fish = true }
			expect(#Tips.due(profile, DAY)).to.equal(0)
		end)

		it("lists only server tips", function()
			local profile = fresh()
			profile.goldenFish = 3
			profile.tier = 2
			profile.tutorialStep = 5
			profile.potions = { tip_potion = 1 }
			for _, id in Tips.due(profile, { duskWarning = true, night = true }) do
				local def = Tips.get(id)
				assert(def ~= nil, id)
				expect(def.by).to.equal("server")
			end
		end)
	end)

	describe("saved state (section 6)", function()
		it("keeps only known tips and the like ask, each true", function()
			expect(
				Tips.sanitizeSeen(
					{ bowl = true, like_ask = true, feedback_ask = true, night = 1, x = true },
					false
				) :: any
			).to.deepEqual({
				bowl = true,
				like_ask = true,
			})
			expect(next(Tips.sanitizeSeen("junk", false))).never.to.be.ok()
		end)

		it("marks every tip seen for a veteran and keeps what it had", function()
			local seen = Tips.sanitizeSeen({ like_ask = true }, true)
			for _, def in Tips.LIST do
				expect(seen[def.id]).to.equal(true)
			end
			expect(seen[Tips.LIKE_ASK]).to.equal(true)
		end)

		it("keeps the help card's steps 0 to 5", function()
			expect(
				Tips.sanitizeHelp({ ["0"] = true, ["5"] = true, ["6"] = true, ["2"] = "yes" }) :: any
			).to.deepEqual({
				["0"] = true,
				["5"] = true,
			})
			expect(next(Tips.sanitizeHelp(nil))).never.to.be.ok()
		end)

		it("Show tips again forgets the tips but never the like ask", function()
			expect(Tips.cleared({ bowl = true, night = true, like_ask = true }) :: any).to.deepEqual({
				like_ask = true,
			})
			expect(next(Tips.cleared({ bowl = true }))).never.to.be.ok()
		end)
	end)

	describe("feedback (section 4)", function()
		it("has the three faces and six chips as short fixed values", function()
			expect(Tips.FACES :: any).to.deepEqual({ "love", "ok", "no" })
			expect(Tips.CHIPS :: any).to.deepEqual({
				"too_hard",
				"confusing",
				"boring",
				"laggy",
				"more_cats",
				"other",
			})
		end)
	end)

	describe("constants (section 6)", function()
		it("matches the design's timings", function()
			expect(Config.StuckNudgeSeconds).to.equal(40)
			expect(Config.StuckHelpSeconds).to.equal(90)
			expect(Config.TipGapSeconds).to.equal(60)
			expect(Config.TipCutMaxSeconds).to.equal(4)
			expect(Config.FeedbackAskMinutes).to.equal(12)
			expect(Config.FeedbackSessionLimit).to.equal(5)
		end)
	end)
end
