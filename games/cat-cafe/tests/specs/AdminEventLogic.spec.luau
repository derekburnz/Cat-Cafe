--!strict
-- Effects/AdminEventLogic (#4195): the admin event's attributes as a view, the warning and start beats (each once an
-- event), the two banners' words, the HUD timer line and its place on the Cafe Event chip; plus the two admin kinds
-- of Effects/EventBanner.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local AdminEventLogic = require(Effects:WaitForChild("AdminEventLogic")) :: any
	local EventBanner = require(Effects:WaitForChild("EventBanner")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local CafeEvents =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").CafeEvents)

	local NOW = 1800000000
	local START = NOW + 120
	local END = START + 900

	local function attributes(overrides: { [string]: any }?): (name: string) -> any
		local names = CafeEvents.ADMIN_ATTRIBUTES
		local values: { [string]: any } = {
			[names.id] = "owner-admin-1",
			[names.title] = "Bowl Frenzy",
			[names.startsAt] = START,
			[names.endsAt] = END,
			[names.effects] = "bowl4",
			[names.running] = false,
		}
		for key, value in overrides or {} do
			values[key] = value
		end
		return function(name: string): any
			return values[name]
		end
	end

	-- the spec's own decoder: the cloud runner has no HttpService
	local function decode(json: string): any
		if json == "bowl4" then
			return { bowlSpeed = 4 }
		elseif json == "empty" then
			return {}
		elseif json == "odd" then
			return { bowlSpeed = "fast" }
		end
		error("bad json")
	end

	local function view(overrides: { [string]: any }?): any
		return AdminEventLogic.read(attributes(overrides), decode)
	end

	describe("AdminEventLogic.read", function()
		it("reads the attributes EventService sets", function()
			expect(view()).to.deepEqual({
				id = "owner-admin-1",
				title = "Bowl Frenzy",
				startsAt = START,
				endsAt = END,
				running = false,
				bowlSpeed = 4,
			})
			expect(view({ AdminEventRunning = true }).running).to.equal(true)
		end)

		it("is nil with none, and for attributes that make no sense", function()
			expect(view({ AdminEventId = "" })).to.equal(nil)
			expect(view({ AdminEventId = 5 })).to.equal(nil)
			expect(view({ AdminEventTitle = "" })).to.equal(nil)
			expect(view({ AdminEventStartsAt = "soon" })).to.equal(nil)
			expect(view({ AdminEventEndsAt = START })).to.equal(nil)
			expect(view({ AdminEventEndsAt = 0 / 0 })).to.equal(nil)
			expect(AdminEventLogic.read(function(): any
				return nil
			end, decode)).to.equal(nil)
		end)

		it("keeps the event with effects it cannot read, as one that speeds nothing", function()
			for _, json in { "empty", "odd", "broken", "" } do
				local read = view({ AdminEventEffects = json })
				expect(read.bowlSpeed).to.equal(1)
				expect(#AdminEventLogic.effectLines(read)).to.equal(0)
			end
		end)
	end)

	describe("AdminEventLogic.follow", function()
		it("warns once, starts once, then stays quiet", function()
			local seen, beat = AdminEventLogic.follow(nil, view(), NOW)
			expect(beat).to.equal("soon")
			seen, beat = AdminEventLogic.follow(seen, view(), NOW + 1)
			expect(beat).to.equal(nil)
			local running = view({ AdminEventRunning = true })
			seen, beat = AdminEventLogic.follow(seen, running, START)
			expect(beat).to.equal("start")
			seen, beat = AdminEventLogic.follow(seen, running, START + 1)
			expect(beat).to.equal(nil)
			expect(seen.id).to.equal("owner-admin-1")
		end)

		it("goes straight to the start for a player who joins while it runs", function()
			local seen, beat =
				AdminEventLogic.follow(nil, view({ AdminEventRunning = true }), START + 300)
			expect(beat).to.equal("start")
			expect(seen.warned).to.equal(true)
		end)

		it("waits out the second between the clock's start and the server's", function()
			local seen, beat = AdminEventLogic.follow(nil, view(), NOW)
			seen, beat = AdminEventLogic.follow(seen, view(), START + 0.5)
			expect(beat).to.equal(nil)
			-- a first sight in that second neither warns late nor starts early
			local late, lateBeat = AdminEventLogic.follow(nil, view(), START + 0.5)
			expect(lateBeat).to.equal(nil)
			local _, startBeat =
				AdminEventLogic.follow(late, view({ AdminEventRunning = true }), START + 1)
			expect(startBeat).to.equal("start")
		end)

		it("forgets a finished event and treats the next id as new", function()
			local running = view({ AdminEventRunning = true })
			local seen = AdminEventLogic.follow(nil, running, START)
			local over, beat = AdminEventLogic.follow(seen, running, END)
			expect(over).to.equal(nil)
			expect(beat).to.equal(nil)
			local none, noBeat = AdminEventLogic.follow(seen, nil, START + 5)
			expect(none).to.equal(nil)
			expect(noBeat).to.equal(nil)
			local nextView = view({ AdminEventId = "owner-admin-2" })
			local _, again = AdminEventLogic.follow(seen, nextView, NOW)
			expect(again).to.equal("soon")
		end)
	end)

	describe("the admin event's words", function()
		it("counts down in minutes and seconds", function()
			expect(AdminEventLogic.clock(899)).to.equal("14:59")
			expect(AdminEventLogic.clock(119.2)).to.equal("2:00")
			expect(AdminEventLogic.clock(5)).to.equal("0:05")
			expect(AdminEventLogic.clock(3725)).to.equal("1:02:05")
			expect(AdminEventLogic.clock(-3)).to.equal("0:00")
		end)

		it("names the effect plainly", function()
			expect(AdminEventLogic.effectLines(view())).to.deepEqual({
				"Bait bowls lure cats 4x faster",
			})
			local half = view()
			half.bowlSpeed = 1.5
			expect(AdminEventLogic.effectLines(half)[1]).to.equal(
				"Bait bowls lure cats 1.5x faster"
			)
			expect(AdminEventLogic.badge(view())).to.equal("4x")
			expect(AdminEventLogic.badge(view({ AdminEventEffects = "empty" }))).to.equal("!")
		end)

		it("writes a warning card and a start card the banner takes whole", function()
			local soon = AdminEventLogic.soonBanner(view(), NOW)
			expect(soon).to.deepEqual({
				kind = "adminSoon",
				title = "Bowl Frenzy soon!",
				lines = { "Starts in 2:00", "Bait bowls lure cats 4x faster" },
				badge = "!",
			})
			local start = AdminEventLogic.startBanner(view({ AdminEventRunning = true }), START)
			expect(start).to.deepEqual({
				kind = "admin",
				title = "Bowl Frenzy!",
				lines = { "Bait bowls lure cats 4x faster", "Ends in 15:00" },
				badge = "4x",
			})
			for _, banner: any in { soon, start } :: { any } do
				local plan = EventBanner.plan(banner)
				expect(plan ~= nil).to.equal(true)
				expect(plan.title).to.equal(banner.title)
				expect(plan.lines).to.deepEqual(banner.lines)
				expect(plan.badge).to.equal(banner.badge)
			end
			-- the longest title an event may have still fits the card with its ending
			local long = view({ AdminEventTitle = string.rep("W", CafeEvents.TITLE_MAX) })
			local cut = EventBanner.plan(AdminEventLogic.soonBanner(long, NOW))
			expect(utf8.len(cut.title) <= Presets.eventBanner.titleLength).to.equal(true)
		end)

		it("says the cards' words as one chat line, safe for rich text", function()
			local soon = AdminEventLogic.soonBanner(view(), NOW)
			expect(AdminEventLogic.chatLine(soon)).to.equal(
				'<font color="#FF6B81"><b>⚡ Bowl Frenzy soon! Starts in 2:00. '
					.. "Bait bowls lure cats 4x faster.</b></font>"
			)
			local odd = view({ AdminEventTitle = "<b>A & B</b>", AdminEventRunning = true })
			local line = AdminEventLogic.chatLine(AdminEventLogic.startBanner(odd, START))
			expect(string.find(line, "&lt;b&gt;A &amp; B&lt;/b&gt;!", 1, true) ~= nil).to.equal(
				true
			)
			expect(select(2, string.gsub(line, "<b>", ""))).to.equal(1)
			local rose = Presets.palette.neonPink
			expect(AdminEventLogic.CHAT_COLOUR).to.equal(
				string.format(
					"#%02X%02X%02X",
					math.round(rose.R * 255),
					math.round(rose.G * 255),
					math.round(rose.B * 255)
				)
			)
		end)

		it("shows a timer line before and during, and none after", function()
			expect(AdminEventLogic.stripLine(view(), NOW + 1)).to.equal("⚡ Bowl Frenzy in 1:59")
			local running = view({ AdminEventRunning = true })
			expect(AdminEventLogic.stripLine(running, START + 1)).to.equal("⚡ Bowl Frenzy 14:59")
			expect(AdminEventLogic.stripLine(running, END)).to.equal(nil)
			expect(AdminEventLogic.stripLine(view(), START + 0.5)).to.equal(nil)
			expect(AdminEventLogic.stripLine(nil, NOW)).to.equal(nil)
		end)

		it("goes first on the Cafe Event chip and leaves it alone with none", function()
			local lines = { "⏳ Cafe Party · ends in 1:59:40", "next shower 9:12" }
			local strip = { "⏳ Cafe Party 1:59:40", "Shower 9:12" }
			local sameLines, sameKind, sameStrip = AdminEventLogic.merge(lines, "soon", strip, nil)
			expect(sameLines).to.equal(lines)
			expect(sameKind).to.equal("soon")
			expect(sameStrip).to.equal(strip)
			local admin = "⚡ Bowl Frenzy 14:59"
			local card, kind, short = AdminEventLogic.merge(lines, "soon", strip, admin)
			expect(card).to.deepEqual({ admin, lines[1], lines[2] })
			expect(kind).to.equal("running")
			expect(short).to.deepEqual({ admin, strip[1] })
			-- with no Cafe Event at all, the chip is the admin line alone
			card, kind, short = AdminEventLogic.merge(nil, nil, nil, admin)
			expect(card).to.deepEqual({ admin })
			expect(kind).to.equal("running")
			expect(short).to.deepEqual({ admin })
			-- the caller's tables are never changed
			expect(#lines).to.equal(2)
			expect(#strip).to.equal(2)
		end)
	end)

	describe("EventBanner's admin kinds", function()
		it("takes both, with a short badge on them only", function()
			local p = Presets.eventBanner
			local plan = EventBanner.plan({ kind = "admin", title = "Bowl Frenzy!", badge = "4x" })
			expect(plan.kind).to.equal("admin")
			expect(plan.badge).to.equal("4x")
			expect(EventBanner.plan({ kind = "adminSoon", title = "Soon" }).badge).to.equal(nil)
			local cut = EventBanner.plan({ kind = "admin", title = "A", badge = "12345" })
			expect(utf8.len(cut.badge)).to.equal(p.badgeLength)
			expect(EventBanner.plan({ kind = "admin", title = "A", badge = "  " }).badge).to.equal(
				nil
			)
			expect(EventBanner.plan({ kind = "admin", title = "A", badge = 4 }).badge).to.equal(nil)
			expect(EventBanner.plan({ kind = "party", title = "A", badge = "4x" }).badge).to.equal(
				nil
			)
		end)

		it(
			"gives the start the full burst and the warning the small one, none with Reduce Motion",
			function()
				local p = Presets.eventBanner
				expect((EventBanner.counts("admin", false, false))).to.equal(p.confetti)
				expect((EventBanner.counts("adminSoon", false, false))).to.equal(p.confettiSoon)
				expect((EventBanner.counts("admin", true, false))).to.equal(
					math.ceil(p.confetti / 2)
				)
				local sparkles, fish = EventBanner.counts("admin", false, true)
				expect(sparkles).to.equal(0)
				expect(fish).to.equal(0)
				expect(select(2, EventBanner.counts("admin", false, false))).to.equal(0)
			end
		)

		it("runs the start card wider than the others, inside the screen", function()
			local p = Presets.eventBanner
			expect(p.adminWidthScale > p.widthScale and p.adminWidthScale <= 1).to.equal(true)
			expect(p.adminMaxWidth > p.maxWidth).to.equal(true)
			expect(EventBanner.height("admin", 2)).to.equal(EventBanner.height("party", 2))
			-- both may wait in line together, and a second of the same kind is dropped
			expect(EventBanner.accepts("adminSoon", {}, "admin", p.queue)).to.equal(true)
			expect(EventBanner.accepts("admin", {}, "admin", p.queue)).to.equal(false)
		end)
	end)
end
