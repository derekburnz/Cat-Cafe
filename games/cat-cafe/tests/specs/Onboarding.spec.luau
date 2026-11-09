--!strict
-- Onboarding.luau against easy-start.md section 5 (#1273) and #1888: the funnel v4's 45 steps (v3's 37, then eight) and the intro funnel's 13, each
-- logged once and only in order. A step reached early is held until every step before it is logged, so a rank up
-- before bait never fakes the bait steps. A server step reaches the steps it implies first; a client step implies
-- nothing. A save from funnel v1, v2 or v3 past its first catch leaves the funnel. The time markers come at 30 s, 60 s,
-- 2, 5 and 10 minutes for a new player.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Onboarding = require(Shared.Onboarding)
	local Types = require(Shared.Types)

	local function fresh(): Types.TelemetryState
		return {
			onboardingStep = 0,
			achieved = {},
			funnel = 6,
			firstDay = 0,
			introStep = 0,
			firstHourStep = 0,
		}
	end

	-- every step a list of reach calls logs, in the order they were logged
	local function play(state: Types.TelemetryState, names: { string }): { string }
		local logged: { string } = {}
		for _, name in names do
			for _, done in Onboarding.reach(state, name :: any) do
				table.insert(logged, done)
			end
		end
		return logged
	end

	describe("steps", function()
		it(
			"are the 49 of funnel v6, logged as onboarding_v6 (and the intro's 13 still as onboarding_v4_intro)",
			function()
				expect(Onboarding.VERSION).to.equal(6)
				expect(Onboarding.FUNNEL).to.equal("onboarding_v6")
				expect(Onboarding.INTRO_FUNNEL).to.equal("onboarding_v4_intro")
				expect(Onboarding.COUNT).to.equal(49) -- #2636: v5's 50, less the two lesson steps, plus next_goal_shown
				expect(#Onboarding.V5_STEPS).to.equal(50)
				expect(#Onboarding.V4_STEPS).to.equal(46)
				-- v6 is v5 in the same order without the lesson's two steps and with next_goal_shown let in
				local kept = 0
				for _, name in Onboarding.V5_STEPS do
					if name ~= "tackle_lesson_shown" and name ~= "tackle_lesson_done" then
						expect(Onboarding.index(name) > kept).to.equal(true)
						kept = Onboarding.index(name)
					else
						expect(Onboarding.index(name)).to.equal(0)
					end
				end
				expect(Onboarding.index("next_goal_shown")).to.equal(Onboarding.index("first_checkin") + 1)
				expect(#Onboarding.V3_STEPS).to.equal(37)
				for i, name in Onboarding.V3_STEPS do
					expect(Onboarding.V4_STEPS[i]).to.equal(name) -- v3's steps are v4's first 37
				end
				-- v5 is v4 in the same order with four steps let in: every v4 name is still a step, in v4's order
				local last = 0
				for _, name in Onboarding.V4_STEPS do
					expect(Onboarding.index(name) > last).to.equal(true)
					last = Onboarding.index(name)
				end
				expect(Onboarding.GRAND_OPENING_COUNT).to.equal(
					require(Shared.GrandOpening).COUNT
				)
				expect(Onboarding.INTRO_COUNT).to.equal(13)
				-- Roblox: at most 100 steps a funnel and 10 funnels
				expect(Onboarding.COUNT <= 100).to.equal(true)
			end
		)

		it("keep the shipped names in easy-start.md section 5's order", function()
			expect(Onboarding.STEPS :: any).to.deepEqual({
				"joined",
				"loaded",
				"tut_0_shown",
				"first_move",
				"first_cannon",
				"entered_alley",
				"tut_1_shown",
				"first_stray_in_view",
				"near_stray",
				"catch_card_opened",
				"catch_started",
				"first_circle_hit",
				"first_catch",
				"carrying_first_cat",
				"first_checkin",
				"next_goal_shown",
				"first_role_assigned",
				"tut_3_shown",
				"first_customer_served",
				"second_cat",
				"first_window_opened",
				"first_table",
				"first_tip_collected",
				"tut_4_shown",
				"bowl_bought",
				"first_bait",
				"first_rescue_started",
				"first_rescue_done",
				"first_bait_resolved",
				"first_goal_done",
				"five_cats",
				"rank_up_card_seen",
				"rank_up_ready",
				"tier_2",
				"first_park_catch",
				"returned_next_day",
				"first_offline_claim",
				"tier_3",
				"grand_opening_done",
				"starter_cat",
				"first_store_open",
				"first_pass_xp",
				"first_pass_claim",
				"first_camp_collect",
				"first_equip_best",
				"pass_level_5",
				"tier_4",
				"first_robux_purchase",
				"first_wow_cat",
			})
			expect(Onboarding.INTRO_STEPS[1]).to.equal("intro_choice_made")
			expect(Onboarding.INTRO_STEPS[2]).to.equal("intro_started")
			for shot = 1, 10 do
				expect(Onboarding.INTRO_STEPS[shot + 2]).to.equal("intro_shot_" .. tostring(shot))
			end
			expect(Onboarding.INTRO_STEPS[13]).to.equal("intro_done")
		end)

		it("have unique names, and only earlier steps are implied", function()
			local seen: { [string]: boolean } = {}
			for _, name in Onboarding.STEPS do
				expect(seen[name]).never.to.be.ok()
				seen[name] = true
			end
			for name, earlier in Onboarding.IMPLIES do
				expect(Onboarding.index(name) > 0).to.equal(true)
				for _, step in earlier do
					expect(Onboarding.index(step) > 0).to.equal(true)
					expect(Onboarding.index(step) < Onboarding.index(name)).to.equal(true)
				end
			end
		end)

		it("let a client step imply nothing, and a client report only client steps", function()
			for name in Onboarding.CLIENT_STEPS do
				expect(Onboarding.index(name) > 0).to.equal(true)
				expect(Onboarding.IMPLIES[name]).never.to.be.ok()
			end
			for _, name in Onboarding.REPORTABLE do
				expect(Onboarding.CLIENT_STEPS[name]).to.equal(true)
			end
		end)
	end)

	describe("reach", function()
		it("logs the next step and advances", function()
			local state = fresh()
			expect(Onboarding.reach(state, "joined") :: any).to.deepEqual({ "joined" })
			expect(state.onboardingStep).to.equal(1)
			expect(Onboarding.furthest(state)).to.equal("joined")
			expect(Onboarding.furthest(fresh())).to.equal("none")
		end)

		it("logs a step only once", function()
			local state = fresh()
			play(state, { "joined", "loaded" })
			expect(#Onboarding.reach(state, "joined")).to.equal(0)
			expect(#Onboarding.reach(state, "loaded")).to.equal(0)
			expect(state.onboardingStep).to.equal(2)
		end)

		it("holds a client step reached early and logs it once the gap closes", function()
			local state = fresh()
			play(state, { "joined", "loaded" })
			expect(#Onboarding.reach(state, "catch_card_opened")).to.equal(0) -- step 10, held
			expect(state.achieved["10"]).to.equal(true)
			expect(play(state, { "near_stray" }) :: any).to.deepEqual({
				"tut_0_shown",
				"first_move",
				"first_cannon",
				"entered_alley",
				"tut_1_shown",
				"first_stray_in_view",
				"near_stray",
				"catch_card_opened",
			})
			expect(next(state.achieved)).never.to.be.ok()
		end)

		it("logs the first catch broken down when the server sees only the catch", function()
			local state = fresh()
			play(state, { "joined" })
			-- an old client that reports nothing: the catch proves every step of the way to it
			local logged = play(state, { "first_catch" })
			expect(#logged).to.equal(12)
			expect(logged[1]).to.equal("loaded")
			expect(logged[12]).to.equal("first_catch")
			expect(Onboarding.furthest(state)).to.equal("first_catch")
		end)

		it("never lets a client step move a server step", function()
			local state = fresh()
			play(state, { "joined" })
			-- every reportable step at once, as a client could send them
			for _, name in Onboarding.REPORTABLE do
				expect(#Onboarding.reach(state, name :: any)).to.equal(0)
			end
			expect(state.onboardingStep).to.equal(1)
			expect(Onboarding.reached(state, "first_move")).to.equal(false)
			expect(Onboarding.reached(state, "catch_started")).to.equal(false)
		end)

		it(
			"holds a later milestone, so a rank up before bait never fakes the bait steps",
			function()
				local state = fresh()
				play(state, { "joined", "first_checkin" })
				expect(Onboarding.furthest(state)).to.equal("first_checkin")
				-- tier_2 brings its card and ready steps, all held behind the cafe loop
				expect(#Onboarding.reach(state, "tier_2")).to.equal(0)
				expect(Onboarding.reached(state, "rank_up_card_seen")).to.equal(true)
				expect(Onboarding.reached(state, "first_bait")).to.equal(false)
				expect(Onboarding.furthest(state)).to.equal("first_checkin")
			end
		)

		it("runs a whole first session in order", function()
			local state = fresh()
			local logged = play(state, {
				"joined",
				"loaded",
				"tut_0_shown",
				"first_move",
				"first_cannon",
				"entered_alley",
				"tut_1_shown",
				"first_stray_in_view",
				"near_stray",
				"catch_card_opened",
				"catch_started",
				"first_circle_hit",
				"first_catch",
				"carrying_first_cat",
				"first_checkin",
				"next_goal_shown",
				"first_role_assigned",
				"tut_3_shown",
				"first_customer_served",
				"second_cat",
				"first_window_opened",
				"first_table",
				"first_tip_collected",
				"tut_4_shown",
				"bowl_bought",
				"first_bait",
				"first_rescue_started",
				"first_rescue_done",
				"first_bait_resolved",
				"first_goal_done",
			})
			expect(#logged).to.equal(30)
			for i, name in logged do
				expect(Onboarding.index(name)).to.equal(i)
			end
		end)

		it("logs next_goal_shown after the check-in, and a role reaches it unreported (#2636)", function()
			local state = fresh()
			play(state, { "joined", "first_checkin" })
			expect(Onboarding.reach(state, "next_goal_shown") :: any).to.deepEqual({ "next_goal_shown" })
			expect(Onboarding.reach(state, "first_role_assigned") :: any).to.deepEqual({
				"first_role_assigned",
			})
			-- an early report is held until the check-in and claims no check-in
			local early = fresh()
			play(early, { "joined" })
			expect(#Onboarding.reach(early, "next_goal_shown")).to.equal(0)
			expect(Onboarding.furthest(early)).to.equal("joined")
			-- a client that never reports it: the role reaches it first
			local quiet = fresh()
			play(quiet, { "joined", "first_checkin" })
			expect(Onboarding.reach(quiet, "first_role_assigned") :: any).to.deepEqual({
				"next_goal_shown",
				"first_role_assigned",
			})
			-- the lesson's old steps are no steps now
			expect(Onboarding.index("tackle_lesson_shown")).to.equal(0)
			expect(#Onboarding.reach(quiet, "tackle_lesson_done" :: any)).to.equal(0)
		end)

		it("logs every step once each and holds nothing, over 500 seeded orders", function()
			local rng = Random.new(1273)
			for _ = 1, 500 do
				local order = table.clone(Onboarding.STEPS)
				for i = #order, 2, -1 do
					local j = rng:NextInteger(1, i)
					order[i], order[j] = order[j], order[i]
				end
				local state = fresh()
				local logged: { number } = {}
				for _, step in order do
					-- every step twice in a row, as a second check-in or rank up would
					for _ = 1, 2 do
						for _, name in Onboarding.reach(state, step) do
							table.insert(logged, Onboarding.index(name))
						end
					end
				end
				expect(#logged).to.equal(Onboarding.COUNT)
				for i, step in logged do
					expect(step).to.equal(i)
				end
				expect(state.onboardingStep).to.equal(Onboarding.COUNT)
				expect(next(state.achieved)).never.to.be.ok()
			end
		end)

		it("ignores a name that is not a step and logs nothing once the funnel is done", function()
			local state = fresh()
			Onboarding.reach(state, "joined")
			expect(#Onboarding.reach(state, "saw_alley" :: any)).to.equal(0)
			expect(Onboarding.index("first_role")).to.equal(0)
			expect(state.onboardingStep).to.equal(1)
			local done = fresh()
			done.onboardingStep = Onboarding.COUNT
			for _, step in Onboarding.STEPS do
				expect(#Onboarding.reach(done, step)).to.equal(0)
			end
			expect(next(done.achieved)).never.to.be.ok()
		end)
	end)

	describe("reachIntro", function()
		it("logs each intro step once, in order, and nothing behind the furthest", function()
			local state = fresh()
			expect(Onboarding.reachIntro(state, "intro_choice_made")).to.equal(true)
			expect(Onboarding.reachIntro(state, "intro_started")).to.equal(true)
			expect(Onboarding.reachIntro(state, "intro_started")).to.equal(false)
			expect(Onboarding.reachIntro(state, "intro_shot_1")).to.equal(true)
			-- a shot left out: Roblox counts shot 2 passed once 3 logs
			expect(Onboarding.reachIntro(state, "intro_shot_3")).to.equal(true)
			expect(Onboarding.reachIntro(state, "intro_shot_2")).to.equal(false)
			expect(state.introStep).to.equal(5)
			expect(Onboarding.reachIntro(state, "intro_done")).to.equal(true)
			expect(Onboarding.reachIntro(state, "intro_shot_10")).to.equal(false)
			expect(Onboarding.reachIntro(state, "intro_x" :: any)).to.equal(false)
			-- the intro funnel never moves the main one
			expect(state.onboardingStep).to.equal(0)
		end)
	end)

	describe("fromOld (funnels v1 to v5)", function()
		it(
			"takes a save past its first catch out of the funnel, and starts any other at joined",
			function()
				expect(Onboarding.fromOld(2, 7)).to.equal(Onboarding.COUNT) -- v2 step 7 is first_catch
				expect(Onboarding.fromOld(2, 25)).to.equal(Onboarding.COUNT)
				expect(Onboarding.fromOld(2, 6)).to.equal(0)
				expect(Onboarding.fromOld(1, 3)).to.equal(Onboarding.COUNT) -- v1 step 3 is first_catch
				expect(Onboarding.fromOld(nil, 2)).to.equal(0)
				expect(Onboarding.fromOld(2, 0)).to.equal(0)
				expect(Onboarding.fromOld(3, 13)).to.equal(Onboarding.COUNT) -- v3 step 13 is first_catch
				expect(Onboarding.fromOld(3, 37)).to.equal(Onboarding.COUNT)
				expect(Onboarding.fromOld(3, 12)).to.equal(0)
				expect(Onboarding.fromOld(4, 13)).to.equal(Onboarding.COUNT) -- v4 step 13 is first_catch
				expect(Onboarding.fromOld(4, 46)).to.equal(Onboarding.COUNT)
				expect(Onboarding.fromOld(4, 12)).to.equal(0)
				expect(Onboarding.fromOld(5, 13)).to.equal(Onboarding.COUNT) -- v5 step 13 is first_catch
				expect(Onboarding.fromOld(5, 50)).to.equal(Onboarding.COUNT)
				expect(Onboarding.fromOld(5, 12)).to.equal(0)
			end
		)
	end)

	describe("fromSave (QA S72)", function()
		local function facts(over: { [string]: number }?): Onboarding.SaveFacts
			local out: Onboarding.SaveFacts =
				{ catsCaught = 0, distinctCats = 0, tables = 0, bowl = 0, tier = 1, parkCats = 0 }
			for key, value in over or {} do
				(out :: any)[key] = value
			end
			return out
		end

		it("shows nothing for a fresh save", function()
			expect(#Onboarding.fromSave(facts())).to.equal(0)
		end)

		it("lists what a save shows in step order, all of them steps", function()
			local shown = Onboarding.fromSave(
				facts({
					catsCaught = 9,
					distinctCats = 6,
					tables = 2,
					bowl = 1,
					tier = 3,
					parkCats = 1,
				})
			)
			local last = 0
			for _, name in shown do
				expect(Onboarding.index(name) > last).to.equal(true)
				last = Onboarding.index(name)
			end
			expect(#shown).to.equal(7)
		end)

		it("shows the Grand Opening in step order (#2391), and no lesson step since v6 (#2636)", function()
			local all = Onboarding.fromSave(facts({
				catsCaught = 9,
				distinctCats = 12,
				tables = 2,
				bowl = 1,
				tier = 3,
				parkCats = 1,
				goalsDone = 8,
			} :: any))
			local last = 0
			for _, name in all do
				expect(Onboarding.index(name) > last).to.equal(true)
				last = Onboarding.index(name)
			end
			expect(table.find(all, "tackle_lesson_done" :: any)).never.to.be.ok()
			for _, name in { "first_goal_done", "grand_opening_done" } do
				expect(table.find(all, name :: any)).to.be.ok()
			end
			local some = Onboarding.fromSave(facts({ goalsDone = 3 } :: any))
			expect(table.find(some, "first_goal_done" :: any)).to.be.ok()
			expect(table.find(some, "grand_opening_done" :: any)).never.to.be.ok()
		end)

		it("shows the Cafe Pass, Tier 4 and a Robux spend (#1888)", function()
			local shown = Onboarding.fromSave(facts({
				tier = 4,
				passXp = 4000,
				passClaims = 2,
				passLevel = 5,
				spent = true,
			} :: any))
			for _, name in
				{
					"first_pass_xp",
					"first_pass_claim",
					"pass_level_5",
					"tier_4",
					"first_robux_purchase",
				}
			do
				expect(table.find(shown, name :: any)).to.be.ok()
			end
			local none =
				Onboarding.fromSave(facts({ passXp = 0, passClaims = 0, passLevel = 4 } :: any))
			expect(#none).to.equal(0)
		end)

		it("logs nothing twice on the next join", function()
			local state = fresh()
			local save = facts({ catsCaught = 2, tables = 1, bowl = 1 })
			play(state, { "joined", "first_checkin", "next_goal_shown" })
			-- second_cat, first_table (and the window it implies) and bowl_bought wait behind steps 17 to 19
			expect(#play(state, Onboarding.fromSave(save) :: any)).to.equal(0)
			expect(#play(state, Onboarding.fromSave(save) :: any)).to.equal(0)
			local logged = play(state, { "first_customer_served", "tut_3_shown" })
			expect(logged :: any).to.deepEqual({
				"first_role_assigned",
				"tut_3_shown", -- first_customer_served waited for it
				"first_customer_served",
				"second_cat",
				"first_window_opened",
				"first_table",
			})
		end)
	end)

	describe("first_hour_v2 (#2391, #2636)", function()
		it("is joined then 30 seconds to 60 minutes of play, as analytics.sh reads it", function()
			expect(Onboarding.FIRST_HOUR_FUNNEL).to.equal("first_hour_v2")
			expect(Onboarding.FIRST_HOUR_STEPS :: any).to.deepEqual({
				"joined",
				"played_30s",
				"played_60s",
				"played_2m",
				"played_5m",
				"played_10m",
				"played_20m",
				"played_30m",
				"played_45m",
				"played_60m",
			})
			expect(#Onboarding.FIRST_HOUR_SECONDS).to.equal(Onboarding.FIRST_HOUR_COUNT)
			for i = 2, Onboarding.FIRST_HOUR_COUNT do
				local name = Onboarding.FIRST_HOUR_STEPS[i]
				local minutes = tonumber(string.match(name, "(%d+)m$"))
				local seconds = tonumber(string.match(name, "(%d+)s$"))
				local want = if minutes ~= nil then minutes * 60 else seconds
				expect(Onboarding.FIRST_HOUR_SECONDS[i]).to.equal(want)
			end
		end)

		it("logs each step once, as the play time reaches it", function()
			expect(Onboarding.firstHourDue(0, 0) :: any).to.deepEqual({ 1 })
			expect(Onboarding.firstHourDue(1, 29) :: any).to.deepEqual({})
			expect(Onboarding.firstHourDue(1, 30) :: any).to.deepEqual({ 2 })
			expect(Onboarding.firstHourDue(1, 120) :: any).to.deepEqual({ 2, 3, 4 })
			expect(Onboarding.firstHourDue(4, 650) :: any).to.deepEqual({ 5, 6 })
			expect(Onboarding.firstHourDue(0, 99999) :: any).to.deepEqual({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
			expect(Onboarding.firstHourDue(10, 99999) :: any).to.deepEqual({})
			expect(Onboarding.firstHourDue(1, 0 / 0) :: any).to.deepEqual({})
		end)
	end)

	describe("time markers", function()
		it("are session_30s, 60s, 2m, 5m and 10m, in order", function()
			local names: { string } = {}
			local last = 0
			for _, marker in Onboarding.MARKERS do
				expect(marker.seconds > last).to.equal(true)
				last = marker.seconds
				table.insert(names, marker.name)
			end
			expect(names :: any).to.deepEqual({
				"session_30s",
				"session_60s",
				"session_2m",
				"session_5m",
				"session_10m",
			})
		end)

		it("are due by the seconds a session lasted", function()
			expect(#Onboarding.markersBy(29)).to.equal(0)
			expect(Onboarding.markersBy(30) :: any).to.deepEqual({ "session_30s" })
			expect(Onboarding.markersBy(150) :: any).to.deepEqual({
				"session_30s",
				"session_60s",
				"session_2m",
			})
			expect(#Onboarding.markersBy(3600)).to.equal(5)
		end)

		it(
			"go to a new player only: in the first loop or on the day of their first join",
			function()
				local day = 20394
				local now = day * 86400 + 100
				expect(Onboarding.isNewPlayer(0, 0, now)).to.equal(true)
				expect(Onboarding.isNewPlayer(4, day - 3, now)).to.equal(true)
				expect(Onboarding.isNewPlayer(5, day, now)).to.equal(true)
				expect(Onboarding.isNewPlayer(5, day - 1, now)).to.equal(false)
				expect(Onboarding.isNewPlayer(5, 0, now)).to.equal(false)
			end
		)
	end)
end
