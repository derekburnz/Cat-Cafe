--!strict
-- UI/Components/EventLogic.luau: the Cafe Event's HUD chip, start banner and Town Square board (#2487).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local EventLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("EventLogic")
	) :: any

	local START = 1795273200
	local END = START + 7200
	local FULL = {
		days = { "rainbow", "lucky", "golden" },
		money = 2,
		luck = 0.5,
		showers = { count = 8, gapSeconds = 900, firstAfter = 600 },
		reward = { cosmeticId = "Decor_PartyBunting" },
	}

	local function attributes(changes: { [string]: any }?): { [string]: any }
		local out: { [string]: any } = {
			EventId = "party-1121",
			EventTitle = "Cafe Party",
			EventStartsAt = START,
			EventEndsAt = END,
			EventRunning = false,
			EventEffects = "FULL",
		}
		for key, value in changes or {} do
			out[key] = value
		end
		return out
	end

	local function read(changes: { [string]: any }?, data: any?): any
		local attrs = attributes(changes)
		return EventLogic.read(function(name: string): any
			return attrs[name]
		end, function(_json: string): any
			return if data ~= nil then data else FULL
		end)
	end

	local function at(unix: number, pattern: string): string
		if pattern == "%A" then
			return "Saturday"
		end
		return if unix == START then "15:00" elseif unix == END then "17:00" else "?"
	end

	describe("EventLogic.read", function()
		it("reads the attributes and is nil with no event", function()
			local view = read()
			expect(view.id).to.equal("party-1121")
			expect(view.title).to.equal("Cafe Party")
			expect(view.running).to.equal(false)
			expect(table.concat(view.effects.days, ",")).to.equal("lucky,golden,rainbow")
			expect(view.effects.reward).to.equal("Decor_PartyBunting")
			expect(read({ EventId = "" })).to.equal(nil)
			expect(read({ EventEndsAt = START })).to.equal(nil)
			expect(read({ EventStartsAt = 0 / 0 })).to.equal(nil)
		end)

		it("survives bad effects JSON", function()
			local view = read(nil, "not a table")
			expect(view.effects.money).to.equal(1)
			expect(#EventLogic.lines(view.effects)).to.equal(0)
		end)
	end)

	describe("EventLogic.lines", function()
		it("names every effect, one line each, as the design reads", function()
			expect(table.concat(EventLogic.lines(read().effects), " | ")).to.equal(
				"x2 cafe earnings | 8 rare cat showers | Lucky, Golden and Rainbow Day | +0.5 Luck | Free Party Bunting"
			)
			local one = read(
				nil,
				{ days = { "golden" }, showers = { count = 1, gapSeconds = 60, firstAfter = 30 } }
			)
			expect(table.concat(EventLogic.lines(one.effects), " | ")).to.equal(
				"1 rare cat shower | Golden Day"
			)
		end)
	end)

	describe("EventLogic clocks", function()
		it("counts h:mm:ss and m:ss, and h:mm on the chip from an hour", function()
			expect(EventLogic.clock(7180)).to.equal("1:59:40")
			expect(EventLogic.clock(552)).to.equal("9:12")
			expect(EventLogic.clock(-4)).to.equal("0:00")
			expect(EventLogic.short(10750)).to.equal("2:59")
			expect(EventLogic.short(3600)).to.equal("1:00")
			expect(EventLogic.short(3599)).to.equal("59:59")
		end)
	end)

	describe("EventLogic.chip", function()
		it("counts down from T-3h only", function()
			local view = read()
			expect(EventLogic.chip(view, nil, START - 10801)).to.equal(nil)
			local lines, kind = EventLogic.chip(view, nil, START - 10750)
			expect(kind).to.equal("soon")
			expect(lines[1]).to.equal("⏳ Cafe Party in 2:59")
			expect(EventLogic.chip(view, nil, START - 65)[1]).to.equal("⏳ Cafe Party in 1:05")
		end)

		it("turns gold while running with the end and the next shower", function()
			local view = read({ EventRunning = true })
			local lines, kind = EventLogic.chip(view, nil, START + 20)
			expect(kind).to.equal("running")
			expect(lines[1]).to.equal("⏳ Cafe Party · ends in 1:59:40")
			expect(lines[2]).to.equal("next shower 9:40")
			-- after the last shower (600 + 7 * 900 = 6900 s in) only the end shows
			local late = EventLogic.chip(view, nil, START + 7000)
			expect(#late).to.equal(1)
		end)

		it("says ended early when the server stops it before its end", function()
			local view = read({ EventRunning = true })
			local seen, started = EventLogic.follow(nil, view, START + 100)
			expect(started).to.equal(true)
			local _, again = EventLogic.follow(seen, view, START + 200)
			expect(again).to.equal(false)
			seen = EventLogic.follow(seen, nil, START + 1000)
			local lines, kind = EventLogic.chip(nil, seen, START + 1010)
			expect(kind).to.equal("ended")
			expect(lines[1]).to.equal("Cafe Party ended early")
			expect(EventLogic.chip(nil, seen, END + 1)).to.equal(nil)
		end)

		it("does not call an end on time early", function()
			local view = read({ EventRunning = true })
			local seen = EventLogic.follow(nil, view, START + 100)
			seen = EventLogic.follow(seen, nil, END)
			expect(seen.early).to.equal(false)
			expect(EventLogic.chip(nil, seen, END + 5)).to.equal(nil)
			expect(EventLogic.follow(seen, nil, END + EventLogic.AFTER_SECONDS + 1)).to.equal(nil)
		end)
	end)

	describe("EventLogic.banner", function()
		it("names the two biggest effects and the local end time", function()
			expect(EventLogic.banner(read(), "17:00")).to.equal(
				"Cafe Party! x2 cafe earnings and rare cat showers until 17:00"
			)
			expect(EventLogic.banner(read(nil, { days = { "lucky", "golden" } }), "17:00")).to.equal(
				"Cafe Party! Lucky and Golden Day until 17:00"
			)
			expect(EventLogic.banner(read(nil, { luck = 0.5 }), "17:00")).to.equal(
				"Cafe Party! +0.5 Luck until 17:00"
			)
			expect(EventLogic.banner(read(nil, {}), "17:00")).to.equal("Cafe Party! On until 17:00")
		end)

		it("stays calm: no passes, no buying", function()
			local words = string.lower(EventLogic.banner(read(), "17:00"))
			for _, line in EventLogic.lines(read().effects) do
				words ..= " " .. string.lower(line)
			end
			for _, banned in { "pass", "robux", "buy", "x4", "hurry", "last chance" } do
				expect(words:find(banned, 1, true)).to.equal(nil)
			end
		end)
	end)

	describe("EventLogic.board", function()
		it("counts down, then runs, then thanks", function()
			local soon = EventLogic.board(read(), nil, START - 10750, at)
			expect(soon.kind).to.equal("soon")
			expect(soon.heading).to.equal("Cafe Party in 2:59:10")
			expect(soon.sub).to.equal("15:00 to 17:00")
			expect(#soon.lines).to.equal(5)
			local view = read({ EventRunning = true })
			local live = EventLogic.board(view, nil, START + 20, at)
			expect(live.heading).to.equal("Cafe Party!")
			expect(live.sub).to.equal("Ends at 17:00 · 1:59:40 left")
			local seen = EventLogic.follow(nil, view, START + 20)
			seen = EventLogic.follow(seen, nil, END)
			local after = EventLogic.board(nil, seen, END + 10, at)
			expect(after.heading).to.equal("Thanks for coming!")
			expect(after.sub).to.equal(nil)
			local nextWeek = read({ EventStartsAt = START + 604800, EventEndsAt = END + 604800 })
			expect(EventLogic.board(nextWeek, seen, END + 10, at).sub).to.equal(
				"See you next Saturday"
			)
		end)

		it("shows the next event or an idle line between events", function()
			local later = EventLogic.board(read(), nil, START - 86400, at)
			expect(later.kind).to.equal("idle")
			expect(later.heading).to.equal("Next Cafe Party")
			expect(later.sub).to.equal("Saturday 15:00 to 17:00")
			local none = EventLogic.board(nil, nil, START, at)
			expect(none.sub).to.equal(EventLogic.IDLE)
		end)
	end)
end
