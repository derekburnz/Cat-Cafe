--!strict
-- shared/Pity against luck-and-rare-moments.md 1h (#1572): the global slots, the night rule, the seeded pick and the
-- banner texts.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local LateTiers = require(Shared.LateTiers)
	local Pity = require(Shared.Pity)

	local every = Config.PityLegendarySeconds

	describe("slots", function()
		it("runs a slot every PityLegendarySeconds, every 4th a Mythical one", function()
			expect(every).to.equal(900) -- #2796: halved for now, was 1800
			expect(Config.PityMythicalEvery).to.equal(4)
			expect(Pity.slot(0)).to.equal(0)
			expect(Pity.slot(every - 1)).to.equal(0)
			expect(Pity.slot(every)).to.equal(1)
			expect(Pity.slot(-50)).to.equal(0)
			expect(Pity.kindOf(1)).to.equal("Legendary")
			expect(Pity.kindOf(3)).to.equal("Legendary")
			expect(Pity.kindOf(4)).to.equal("Mythical")
			expect(Pity.kindOf(8)).to.equal("Mythical")
		end)

		it("moves a slot due at night to the next sunrise (QA 4)", function()
			local movedOne = false
			for slot = 1, 400 do
				local due = Pity.dueAt(slot)
				local phase, left = Clock.phaseAt(due)
				if phase == "night" then
					movedOne = true
					expect(Pity.spawnAt(slot)).to.equal(due + left)
					expect((Clock.phaseAt(Pity.spawnAt(slot)))).to.equal("day")
				else
					expect(Pity.spawnAt(slot)).to.equal(due)
				end
			end
			expect(movedOne).to.equal(true)
		end)

		it(
			"counts down to the next Legendary within 30 min and the next Mythical within 2 h",
			function()
				for t = 0, 20000, 137 do
					local at, slot = Pity.nextAt(t, "Legendary")
					expect(at > t).to.equal(true)
					expect(Pity.kindOf(slot)).to.equal("Legendary")
					expect(at - t <= 2 * every + Config.NightLengthSeconds).to.equal(true)
					local mAt, mSlot = Pity.nextAt(t, "Mythical")
					expect(mAt > t).to.equal(true)
					expect(Pity.kindOf(mSlot)).to.equal("Mythical")
					expect(mAt - t <= 4 * every + Config.NightLengthSeconds).to.equal(true)
					local anyAt = Pity.nextAt(t)
					expect(anyAt).to.equal(math.min(at, mAt))
				end
			end
		)

		it("keeps a slot's cat out from its spawn until night", function()
			local slot = 5
			local at = Pity.spawnAt(slot)
			expect(Pity.live(at)).to.equal(slot)
			expect(Pity.live(at - 1)).never.to.equal(slot)
			local _, left = Clock.phaseAt(at)
			expect(Pity.live(at + left - 1)).to.equal(slot)
			expect(Pity.live(at + left + 1)).to.equal(nil) -- night
			expect(Pity.live(at + left + Config.NightLengthSeconds + 5)).to.equal(nil) -- the next day
			expect(Pity.live(10)).to.equal(nil) -- before the first slot
		end)
	end)

	describe("pick", function()
		it(
			"is the same for a slot every time, with a cat of the slot's rarity from its area",
			function()
				for slot = 1, 200 do
					local a, b = Pity.pick(slot), Pity.pick(slot)
					expect(a.areaId).to.equal(b.areaId)
					expect(a.catId).to.equal(b.catId)
					expect(a.kind).to.equal(Pity.kindOf(slot))
					local def = Catalog.getCat(a.catId)
					expect(def).to.be.ok()
					if def ~= nil then
						expect(def.rarity).to.equal(a.kind)
						expect(def.area).to.equal(a.areaId)
					end
				end
			end
		)

		it("lands on the areas within 1 point of the weights over 10,000 slots (QA 3)", function()
			LateTiers.setOpen(true) -- #3997: every area, the Snowy Mountain too
			local total = 0
			for _, weight in Config.PityAreaWeights do
				total += weight
			end
			local counts: { [string]: number } = {}
			local n = 10000
			for slot = 1, n do
				local area = Pity.pick(slot).areaId
				counts[area] = (counts[area] or 0) + 1
			end
			for areaId, weight in Config.PityAreaWeights do
				expect(Catalog.getArea(areaId)).to.be.ok()
				local share = 100 * (counts[areaId] or 0) / n
				expect(math.abs(share - 100 * weight / total) <= 1).to.equal(true)
			end
			LateTiers.setOpen(nil)
		end)

		it("maps a roll onto the weights in area order", function()
			-- weights 10, 15, 20, 25, 30, 35 and 40 (#2651), 175 in all while the tier8 switch is off (#3997)
			LateTiers.setOpen(false)
			expect(Pity.areaFor(135.1 / 175)).to.equal("ruins")
			expect(Pity.areaFor(0.999)).to.equal("ruins")
			-- and the Snowy Mountain's 45 on top once it is on, 220 in all
			LateTiers.setOpen(true)
			expect(Pity.areaFor(0)).to.equal("alley")
			expect(Pity.areaFor(9.9 / 220)).to.equal("alley")
			expect(Pity.areaFor(10.1 / 220)).to.equal("park")
			expect(Pity.areaFor(134.9 / 220)).to.equal("desert")
			expect(Pity.areaFor(135.1 / 220)).to.equal("ruins")
			expect(Pity.areaFor(174.9 / 220)).to.equal("ruins")
			expect(Pity.areaFor(175.1 / 220)).to.equal("snowy")
			expect(Pity.areaFor(0.999)).to.equal("snowy")
			LateTiers.setOpen(nil)
		end)
	end)

	describe("texts", function()
		it("names the area, with the tier for a player who has not opened it", function()
			expect(Pity.spawnText("Legendary", "woods")).to.equal(
				"A Legendary pity cat appeared in the Woods!"
			)
			expect(Pity.spawnText("Mythical", "woods", 4)).to.equal(
				"A Mythical pity cat appeared in the Woods! (opens at Tier 4)"
			)
			expect(Pity.caughtText("Sam")).to.equal("Sam caught the pity cat!")
			expect(Pity.claimKey(12)).to.equal("pity:12")
		end)

		it("writes the sign's countdowns", function()
			expect(Pity.countdownText(750)).to.equal("12:30")
			expect(Pity.countdownText(6130)).to.equal("1:42:10")
			expect(Pity.countdownText(0.2)).to.equal("0:01")
			expect(Pity.countdownText(-3)).to.equal("0:00")
		end)

		it("writes the sign's three lines from the clock and the Pity folder (#1753)", function()
			-- a daytime moment: count to the next of each kind with nextAt, the same on every client
			local t = Pity.spawnAt(5) + 10
			local lines = Pity.signLines(t, "", "", "")
			local legendaryAt = Pity.nextAt(t, "Legendary")
			local mythicalAt = Pity.nextAt(t, "Mythical")
			expect(lines[1]).to.equal("Legendary cat in " .. Pity.countdownText(legendaryAt - t))
			expect(lines[2]).to.equal("Mythical cat in " .. Pity.countdownText(mythicalAt - t))
			expect(lines[3]).to.equal("")
			expect(Pity.signLines(t, "out", "woods", "")[3]).to.equal("Now in the Woods!")
			expect(Pity.signLines(t, "caught", "woods", "Sam")[3]).to.equal("Caught by Sam")
			-- a half-filled folder (no area yet, no winner) leaves the line empty
			expect(Pity.signLines(t, "out", "", "")[3]).to.equal("")
			expect(Pity.signLines(t, "caught", "woods", "")[3]).to.equal("")
			expect(Pity.signLines(t, nil, nil, nil)[3]).to.equal("")
		end)
	end)

	describe("restarting timers (1i, #1946)", function()
		local legendary: any = "Legendary"
		local mythical: any = "Mythical"

		-- a daytime t with at least `room` seconds of day left
		local function dayWith(room: number): number
			for t = 0, 200000, 60 do
				local phase, left = Clock.phaseAt(t)
				if phase == "day" and left >= room then
					return t
				end
			end
			error("no day")
		end

		it("starts both on the first boot: one Legendary and one Mythical period away", function()
			expect(Config.PityMythicalSeconds).to.equal(3600) -- #2796: halved for now, was 7200
			local t = 5000
			local l = Pity.first(t, legendary)
			local m = Pity.first(t, mythical)
			expect(l.at).to.equal(t + Config.PityLegendarySeconds)
			expect(m.at).to.equal(t + Config.PityMythicalSeconds)
			expect(l.seq).to.equal(1)
			expect(m.seq).to.equal(1)
		end)

		it(
			"restarts a kind's timer a period after its cat spawned, with the next number",
			function()
				local l = Pity.restart(9000, legendary, 4)
				expect(l.at).to.equal(9000 + Config.PityLegendarySeconds)
				expect(l.seq).to.equal(5)
				local m = Pity.restart(9000, mythical, 2)
				expect(m.at).to.equal(9000 + Config.PityMythicalSeconds)
				expect(m.seq).to.equal(3)
			end
		)

		it(
			"finds the cat before a moved timer, for a server that starts while it is out (#2003)",
			function()
				local spawned = 9000
				local moved = Pity.restart(spawned, legendary, 4)
				local before = Pity.previous(moved, legendary) :: Pity.Timer
				expect(before.seq).to.equal(4)
				expect(before.at).to.equal(spawned)
				local m = Pity.previous(Pity.restart(spawned, mythical, 2), mythical) :: Pity.Timer
				expect(m.seq).to.equal(2)
				expect(m.at).to.equal(spawned)
				expect(Pity.previous(Pity.first(spawned, legendary), legendary)).to.equal(nil)
				expect(Pity.previous({ at = 100, seq = -3 }, legendary)).to.equal(nil)
			end
		)

		it("moves the stored timer once when two servers spawn the same cat", function()
			local stored = { at = 100, seq = 4 }
			expect(Pity.keepStored(stored, 4)).to.equal(false) -- the first server writes
			local moved = Pity.restart(200, legendary, 4)
			expect(Pity.keepStored(moved, 4)).to.equal(true) -- the second leaves it
			expect(Pity.keepStored(nil, 4)).to.equal(false)
		end)

		it("reads only a whole timer from the store", function()
			local read = Pity.readTimer({ at = 12.5, seq = 3 })
			expect(read).never.to.equal(nil)
			expect((read :: any).at).to.equal(12.5)
			expect(Pity.readTimer(nil)).to.equal(nil)
			expect(Pity.readTimer("x")).to.equal(nil)
			expect(Pity.readTimer({ at = 1 })).to.equal(nil)
			expect(Pity.readTimer({ at = 1, seq = 0 })).to.equal(nil)
			expect(Pity.readTimer({ at = 1, seq = 1.5 })).to.equal(nil)
			expect(Pity.readTimer({ at = 0 / 0, seq = 1 })).to.equal(nil)
		end)

		it("spawns a timer due at night at the next sunrise", function()
			local moved = false
			for due = 0, 40000, 97 do
				local phase, left = Clock.phaseAt(due)
				if phase == "night" then
					moved = true
					expect(Pity.spawnTime(due)).to.equal(due + left)
				else
					expect(Pity.spawnTime(due)).to.equal(due)
				end
			end
			expect(moved).to.equal(true)
		end)

		it("keeps a shower cat, and the word of a catch, out from its start until night", function()
			local t = dayWith(120)
			local _, left = Clock.phaseAt(t)
			expect(Pity.sameDay(t, t)).to.equal(true)
			expect(Pity.sameDay(t, t + left - 1)).to.equal(true)
			expect(Pity.sameDay(t, t + left + 1)).to.equal(false)
			expect(Pity.sameDay(t, t + left + Config.NightLengthSeconds + 5)).to.equal(false)
			expect(Pity.sameDay(t, t - 1)).to.equal(false)
		end)

		it("keeps an uncaught pity cat out through one night and the day after (#3077)", function()
			local t = dayWith(120)
			local _, left = Clock.phaseAt(t)
			local night, day = Config.NightLengthSeconds, Config.DayLengthSeconds
			expect(Pity.NIGHTS_KEPT).to.equal(1)
			expect(Pity.stillOut(t, t)).to.equal(true)
			expect(Pity.stillOut(t, t - 1)).to.equal(false)
			expect(Pity.stillOut(t, t + left - 1)).to.equal(true)
			-- the first night: it waits
			expect(Pity.stillOut(t, t + left + 1)).to.equal(true)
			expect(Pity.stillOut(t, t + left + night - 1)).to.equal(true)
			-- the day after: still there
			expect(Pity.stillOut(t, t + left + night + 5)).to.equal(true)
			expect(Pity.stillOut(t, t + left + night + day - 1)).to.equal(true)
			-- the second nightfall takes it, and it does not come back
			expect(Pity.stillOut(t, t + left + night + day + 1)).to.equal(false)
			expect(Pity.stillOut(t, t + left + 2 * night + day + 5)).to.equal(false)
		end)

		it(
			"still has a cat that came out a second before night at the next sunrise (#3077)",
			function()
				local t = dayWith(120)
				local _, left = Clock.phaseAt(t)
				local dusk = t + left
				local spawned = dusk - 1
				expect((Clock.phaseAt(spawned))).to.equal("day")
				expect((Clock.phaseAt(dusk + 1))).to.equal("night")
				-- at the nightfall's own sweep, a moment either side of dusk, it is kept
				expect(Pity.stillOut(spawned, dusk)).to.equal(true)
				expect(Pity.stillOut(spawned, dusk + 0.05)).to.equal(true)
				-- all night and at sunrise
				local sunrise = dusk + Config.NightLengthSeconds
				expect(Pity.stillOut(spawned, sunrise - 1)).to.equal(true)
				expect(Pity.stillOut(spawned, sunrise + 1)).to.equal(true)
				expect((Clock.phaseAt(sunrise + 1))).to.equal("day")
				-- a whole day to catch it, then the next night takes it
				expect(Pity.stillOut(spawned, sunrise + Config.DayLengthSeconds - 1)).to.equal(true)
				expect(Pity.stillOut(spawned, sunrise + Config.DayLengthSeconds + 1)).to.equal(
					false
				)
				-- before #3077's rule it was gone a second after it came
				expect(Pity.sameDay(spawned, dusk + 1)).to.equal(false)
			end
		)

		it("falls back to the fixed slots as timers with negative numbers", function()
			for t = 0, 20000, 311 do
				for _, kind in { legendary, mythical } do
					local timer = Pity.fixedTimer(t, kind)
					expect(timer.seq < 0).to.equal(true)
					expect(Pity.kindOf(-timer.seq)).to.equal(kind)
					expect(timer.at).to.equal(Pity.dueAt(-timer.seq))
					local live = Pity.live(t)
					if live == nil or Pity.kindOf(live) ~= kind then
						expect(Pity.spawnTime(timer.at) > t).to.equal(true)
					end
				end
			end
		end)

		it(
			"moves a started fixed slot on to the next of its kind, never one that is due already",
			function()
				for t = 0, 20000, 311 do
					for _, kind in { legendary, mythical } do
						local timer = Pity.fixedTimer(t, kind)
						local after = Pity.fixedNext(timer, kind)
						expect(-after.seq > -timer.seq).to.equal(true)
						expect(Pity.kindOf(-after.seq)).to.equal(kind)
						expect(after.at).to.equal(Pity.dueAt(-after.seq))
						expect(Pity.spawnTime(after.at) > t).to.equal(true)
						for slot = -timer.seq + 1, -after.seq - 1 do
							expect(Pity.kindOf(slot) ~= kind).to.equal(true)
						end
					end
				end
			end
		)

		it("gives each cat its own number, claim key and pick across both kinds", function()
			local seen = {}
			for seq = -20, 20 do
				if seq ~= 0 then
					for _, kind in { legendary, mythical } do
						local n = Pity.number(seq, kind)
						expect(seen[n]).to.equal(nil)
						seen[n] = true
					end
				end
			end
			expect(Pity.claimKey(3, legendary)).to.equal("pity:Legendary:3")
			expect(Pity.claimKey(3, mythical)).to.equal("pity:Mythical:3")
			local pick = Pity.pickTimer({ at = 0, seq = 3 }, mythical)
			expect(pick.kind).to.equal("Mythical")
			expect((Catalog.getCat(pick.catId) :: any).rarity).to.equal("Mythical")
			expect(Pity.pickTimer({ at = 0, seq = 3 }, legendary).kind).to.equal("Legendary")
			local fixed = Pity.pickTimer({ at = 0, seq = -5 }, legendary)
			expect(fixed.areaId).to.equal(Pity.pick(5).areaId)
			expect(fixed.catId).to.equal(Pity.pick(5).catId)
		end)

		it(
			"writes each line: a countdown, out now, any moment now, never a negative time",
			function()
				expect(Pity.timerLine(100, legendary, 850, false)).to.equal(
					"Legendary cat in 12:30"
				)
				expect(Pity.timerLine(100, mythical, 100, false)).to.equal("Mythical cat in 0:00")
				expect(Pity.timerLine(160, legendary, 100, false)).to.equal("Legendary cat in 0:00")
				expect(Pity.timerLine(161, legendary, 100, false)).to.equal(
					"Legendary cat: any moment now!"
				)
				expect(Pity.timerLine(5000, legendary, 100, true)).to.equal(
					"Legendary cat out now!"
				)
			end
		)

		it("puts the folder's timers on the sign's lines", function()
			local t = 1000
			local lines = Pity.signLines(t, "caught", "woods", "Sam", {
				Legendary = { at = t + 1800, live = false },
				Mythical = { at = t - 5, live = true },
			})
			expect(lines[1]).to.equal("Legendary cat in 30:00")
			expect(lines[2]).to.equal("Mythical cat out now!")
			expect(lines[3]).to.equal("Caught by Sam")
		end)
	end)

	describe("a pity cat caught in another server (#2567)", function()
		it("shows its banner and name only in the winner's server", function()
			expect(Pity.caughtBanner("Sam")).to.equal("Sam caught the pity cat!")
			expect(Pity.caughtBanner(nil)).to.equal(nil)
			expect(Pity.caughtBanner("")).to.equal(nil)
			-- the sign of a server that didn't win shows no "Caught by"
			expect(Pity.signLines(0, "caught", "woods", "")[3]).to.equal("")
			expect(Pity.signLines(0, "caught", "woods", nil)[3]).to.equal("")
		end)

		it("tells a beaten catcher here without naming the winner", function()
			expect(Pity.LOST_TEXT).to.equal(
				"A player in another server caught it first, so it puffed out of your net."
			)
		end)
	end)
end
