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

	-- QA edges: what TipSeen, the save and ClearTips do with input nobody planned for.
	describe("edges (QA)", function()
		-- TipSeen goes through the server's Guard.id first (lowercase letters, digits, _ and -, 1 to MaxIdLength),
		-- so an id outside it could never be saved.
		it("every id TipSeen takes passes the server's id guard", function()
			local ids: { string } =
				{ Tips.LIKE_ASK, Tips.FAVORITE_ASK, Tips.NOTIFY_ASK, Tips.FEEDBACK_ASK, Tips.STUCK_HELP }
			for _, def in Tips.LIST do
				table.insert(ids, def.id)
			end
			for _, id in ids do
				expect(#id >= 1 and #id <= Config.MaxIdLength).to.equal(true)
				expect(id:match("^[%l%d_%-]+$")).to.equal(id)
			end
		end)

		it("refuses names a table lookup could fake and near misses of real ids", function()
			for _, id in { "LIST", "get", "seenId", "due", "FACES", "__index", "Bowl", "bowl ", "", "like_asks" } do
				expect(Tips.seenId(id)).to.equal(false)
			end
		end)

		it("a saved tipsSeen drops the asks kept elsewhere, values not true and keys not text", function()
			local raw: any = {
				feedback_ask = true,
				stuck_help = true,
				bowl = "true",
				night = 1,
				potion = false,
				[5] = true,
				free_coins = true,
			}
			expect(next(Tips.sanitizeSeen(raw, false))).never.to.be.ok()
			for _, junk in { nil, 5, "bowl", true } :: { any } do
				expect(next(Tips.sanitizeSeen(junk, false))).never.to.be.ok()
			end
			-- a veteran sees every tip but is still owed the one like ask
			local veteran = Tips.sanitizeSeen(raw, true)
			local count = 0
			for key in veteran do
				count += 1
				expect(Tips.get(key)).to.be.ok()
			end
			expect(count).to.equal(#Tips.LIST)
			expect(veteran[Tips.LIKE_ASK]).never.to.be.ok()
		end)

		it("a saved stuckHelpShown keeps only steps 0 to 5 marked true", function()
			local raw: any = { ["-1"] = true, ["6"] = true, ["1.5"] = true, ["2"] = "yes", ["3"] = true, [4] = true }
			expect(Tips.sanitizeHelp(raw) :: any).to.deepEqual({ ["3"] = true })
			expect(next(Tips.sanitizeHelp(nil))).never.to.be.ok()
		end)

		it("Show tips again on a veteran's save leaves nothing, so every tip can show again", function()
			expect(next(Tips.cleared(Tips.sanitizeSeen(nil, true)))).never.to.be.ok()
		end)
	end)

	describe("the asks (F96, starter-cat.md section 3)", function()
		local Catalog = require(Shared.Catalog)
		local NOW = 100 * 86400 -- os.time(), UTC day 100
		local TODAY = 100

		local function legendaryId(): string
			for _, def in Catalog.cats do
				if def.rarity == "Legendary" then
					return def.id
				end
			end
			error("no Legendary cat")
		end

		-- past the first loop on its first day, nothing done that an ask waits for
		local function settled(): any
			local profile = fresh()
			profile.tutorialStep = 5
			profile.telemetry.firstDay = TODAY
			return profile
		end

		-- every ask's moment has come
		local function ready(): any
			local profile = settled()
			profile.stats.baitsTamed = 1
			profile.tier = 2
			profile.collection[legendaryId()] = NOW
			return profile
		end

		it("are the notification, favorite and like asks, in that order, each taken on TipSeen", function()
			expect(Tips.ASKS :: any).to.deepEqual({ "notify_ask", "favorite_ask", "like_ask" })
			for _, id in Tips.ASKS do
				expect(Tips.isAsk(id)).to.equal(true)
				expect(Tips.seenId(id)).to.equal(true)
				expect(Tips.get(id)).never.to.be.ok()
			end
			for _, id in { Tips.FEEDBACK_ASK, Tips.STUCK_HELP, "bowl", "notify", "" } do
				expect(Tips.isAsk(id)).to.equal(false)
			end
		end)

		it("asks nothing before the first loop is done, whatever is due", function()
			local profile = ready()
			profile.tutorialStep = 4
			expect(Tips.dueAsk(profile, NOW, TODAY + 3)).to.equal(nil)
			expect(Tips.dueAsk(settled(), NOW, TODAY)).to.equal(nil)
		end)

		it("offers one ask at a time in order, and nothing once all three are seen", function()
			local profile = ready()
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(Tips.NOTIFY_ASK)
			profile.tipsSeen[Tips.NOTIFY_ASK] = true
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(Tips.FAVORITE_ASK)
			profile.tipsSeen[Tips.FAVORITE_ASK] = true
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(Tips.LIKE_ASK)
			profile.tipsSeen[Tips.LIKE_ASK] = true
			expect(Tips.dueAsk(profile, NOW, TODAY + 9)).to.equal(nil)
		end)

		it("asks for notifications after the first bait cat is tamed, and once more 30 days after", function()
			local profile = settled()
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(nil)
			profile.stats.baitsTamed = 1
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(Tips.NOTIFY_ASK)
			-- shown once and dismissed: it waits the 30 days
			profile.notifyAskAt = NOW
			expect(Tips.NOTIFY_RETRY_SECONDS).to.equal(30 * 86400)
			expect(Tips.dueAsk(profile, NOW + Tips.NOTIFY_RETRY_SECONDS - 1, TODAY)).to.equal(nil)
			expect(Tips.dueAsk(profile, NOW + Tips.NOTIFY_RETRY_SECONDS, TODAY)).to.equal(Tips.NOTIFY_ASK)
			-- the second showing puts it away
			profile.tipsSeen[Tips.NOTIFY_ASK] = true
			expect(Tips.dueAsk(profile, NOW + 99 * 86400, TODAY)).to.equal(nil)
		end)

		it("asks for a favorite from Tier 2", function()
			local profile = settled()
			profile.tier = 1
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(nil)
			profile.tier = 2
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(Tips.FAVORITE_ASK)
		end)

		it("asks for a like after a first Legendary or better, or on a later day than the first", function()
			local profile = settled()
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(nil)
			expect(Tips.dueAsk(profile, NOW + 86400, TODAY + 1)).to.equal(Tips.LIKE_ASK)
			profile.collection[legendaryId()] = NOW
			expect(Tips.dueAsk(profile, NOW, TODAY)).to.equal(Tips.LIKE_ASK)
			local mythical = settled()
			for _, def in Catalog.cats do
				if def.rarity == "Mythical" then
					mythical.collection[def.id] = NOW
					break
				end
			end
			expect(Tips.dueAsk(mythical, NOW, TODAY)).to.equal(Tips.LIKE_ASK)
		end)

		it("keeps the asks through a save and through Show tips again", function()
			local raw: any = { notify_ask = true, favorite_ask = true, like_ask = true, bowl = true }
			expect(Tips.sanitizeSeen(raw, false) :: any).to.deepEqual(raw)
			expect(Tips.cleared(raw) :: any).to.deepEqual({
				notify_ask = true,
				favorite_ask = true,
				like_ask = true,
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
