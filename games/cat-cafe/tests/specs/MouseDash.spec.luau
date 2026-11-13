--!strict
-- shared/MouseDash.luau (#3296, mouse-dash.md): the Mouse Dash rules the server runs.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local MouseDash = require(Shared:WaitForChild("MouseDash")) :: any
	local Config = require(Shared:WaitForChild("Config")) :: any

	-- rolls from a list, the last repeated
	local function rolls(list: { number }): () -> number
		local at = 0
		return function(): number
			at = math.min(at + 1, #list)
			return list[at]
		end
	end

	-- a fixed generator, so long runs are the same every time
	local function lcg(seed: number): () -> number
		local state = seed
		return function(): number
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
	end

	-- a run in its gap with `points`, ready for a wave at t = 10
	local function runAt(points: number): any
		local run = MouseDash.begin(0, false)
		run.points = points
		run.nextAt = 10
		return run
	end

	describe("MouseDash pace", function()
		it("starts at 1.10 s and 0.50 s and reaches the floors by 70 points", function()
			expect(MouseDash.window(0)).to.be.near(1.10, 1e-6)
			expect(MouseDash.gap(0)).to.be.near(0.50, 1e-6)
			expect(MouseDash.window(MouseDash.step(25))).to.be.near(0.765, 0.01)
			expect(MouseDash.window(MouseDash.step(50))).to.be.near(0.532, 0.01)
			expect(MouseDash.window(MouseDash.step(65)) > 0.40).to.equal(true)
			expect(MouseDash.window(MouseDash.step(70))).to.equal(0.40)
			expect(MouseDash.window(MouseDash.step(100))).to.equal(0.40)
			expect(MouseDash.gap(MouseDash.step(100))).to.equal(0.25)
		end)

		it("steps every 5 points and stops at 100", function()
			expect(MouseDash.step(4)).to.equal(0)
			expect(MouseDash.step(5)).to.equal(1)
			expect(MouseDash.step(100)).to.equal(20)
			expect(MouseDash.step(500)).to.equal(20)
		end)
	end)

	describe("MouseDash.wave", function()
		it("is one grey mouse under 10 points, whatever the rolls", function()
			for _, r in { 0, 0.01, 0.5, 0.99 } do
				local run = runAt(9)
				local wave = MouseDash.wave(run, 10, rolls({ r }))
				expect(#wave.pops).to.equal(1)
				expect(wave.pops[1].kind).to.equal("mouse")
				expect(wave.pops[1].downAt - wave.pops[1].upAt).to.be.near(
					MouseDash.window(1),
					1e-6
				)
			end
		end)

		it("brings golden mice from 10, kittens from 20 and pairs from 30", function()
			local seen = { golden = math.huge, kitten = math.huge, pair = math.huge } :: any
			for points = 0, 99 do
				local roll = lcg(points + 1)
				for _ = 1, 400 do
					local run = runAt(points)
					local wave = MouseDash.wave(run, 10, roll)
					if #wave.pops == 2 then
						seen.pair = math.min(seen.pair, points)
					end
					for _, pop in wave.pops do
						if pop.kind ~= "mouse" then
							seen[pop.kind] = math.min(seen[pop.kind], points)
						end
					end
				end
			end
			expect(seen.golden).to.equal(Config.MouseDashGoldenFrom)
			expect(seen.kitten).to.equal(Config.MouseDashKittenFrom)
			expect(seen.pair).to.equal(Config.MouseDashPairFrom)
		end)

		it(
			"never uses a hole two waves running, never two kittens running, and a pair always has a mouse",
			function()
				local roll = lcg(7)
				local run = runAt(60)
				local last: { number } = {}
				local lastKitten = false
				for _ = 1, 3000 do
					local wave = MouseDash.wave(run, 10, roll)
					local kitten, mice = false, 0
					local holes: { number } = {}
					for _, pop in wave.pops do
						expect(pop.hole >= 1 and pop.hole <= MouseDash.HOLES).to.equal(true)
						expect(table.find(last, pop.hole)).never.to.be.ok()
						expect(table.find(holes, pop.hole)).never.to.be.ok()
						table.insert(holes, pop.hole)
						kitten = kitten or pop.kind == "kitten"
						mice += if pop.kind ~= "kitten" then 1 else 0
					end
					expect(kitten and lastKitten).to.equal(false)
					if #wave.pops == 2 then
						expect(mice >= 1).to.equal(true)
					end
					last, lastKitten = holes, kitten
					run.wave = nil
				end
			end
		)

		it("keeps a pair's kitten back until 40 points", function()
			local roll = lcg(11)
			for _ = 1, 3000 do
				local run = runAt(39)
				local wave = MouseDash.wave(run, 10, roll)
				if #wave.pops == 2 then
					expect(wave.pops[1].kind ~= "kitten" and wave.pops[2].kind ~= "kitten").to.equal(
						true
					)
				end
			end
		end)

		it("gives a golden mouse three quarters of the window", function()
			local run = runAt(10)
			-- no kitten under 20; the golden roll passes
			local wave = MouseDash.wave(run, 10, rolls({ 0 }))
			expect(wave.pops[1].kind).to.equal("golden")
			expect(wave.pops[1].downAt - 10).to.be.near(MouseDash.window(2) * 0.75, 1e-6)
		end)

		it("never gives a golden mouse less than the floor", function()
			local run = runAt(90)
			run.lastKitten = true -- no kitten this wave
			-- no pair, then the golden roll passes
			local wave = MouseDash.wave(run, 10, rolls({ 0.99, 0 }))
			expect(wave.pops[1].kind).to.equal("golden")
			expect(wave.pops[1].downAt - 10).to.be.near(Config.MouseDashWindowFloor, 1e-6)
		end)

		it("opens a first run with three slow mice that cannot cost a heart", function()
			local run = MouseDash.begin(0, true)
			for index = 1, Config.MouseDashFirstRunMice do
				local wave = MouseDash.wave(run, run.nextAt, rolls({ 0.3 }))
				expect(wave.safe).to.equal(true)
				expect(wave.index).to.equal(index)
				expect(wave.pops[1].downAt - wave.pops[1].upAt).to.equal(
					Config.MouseDashFirstRunWindow
				)
				local gone, over = MouseDash.settle(run, wave.pops[1].downAt + 1, 0)
				expect(#gone).to.equal(1)
				expect(gone[1].heart).to.equal(0)
				expect(over).to.equal(true)
			end
			expect(run.hearts).to.equal(Config.MouseDashHearts)
			expect(MouseDash.wave(run, run.nextAt, rolls({ 0.3 })).safe).to.equal(false)
		end)
	end)

	describe("MouseDash.tap and settle", function()
		local function mouseUp(points: number, kind: string?): (any, any)
			local run = runAt(points)
			local wave = MouseDash.wave(run, 10, rolls({ 0.99 }))
			if kind ~= nil then
				wave.pops[1].kind = kind
			end
			return run, wave
		end

		it("scores a mouse tapped in its window and starts the gap", function()
			local run, wave = mouseUp(0)
			local tap = MouseDash.tap(run, wave.index, wave.pops[1].hole, 10.3, 0)
			expect(tap.outcome).to.equal("catch")
			expect(tap.gain).to.equal(1)
			expect(tap.waveOver).to.equal(true)
			expect(run.points).to.equal(1)
			expect(run.wave).never.to.be.ok()
			expect(run.nextAt).to.be.near(10.3 + MouseDash.gap(0), 1e-6)
		end)

		it(
			"ignores a second tap on the same mouse, a wrong wave and a hole that is not one",
			function()
				local run, wave = mouseUp(0)
				local hole = wave.pops[1].hole
				expect(MouseDash.tap(run, wave.index + 1, hole, 10.2, 0).outcome).to.equal(
					"ignored"
				)
				expect(MouseDash.tap(run, wave.index, 0, 10.2, 0).outcome).to.equal("ignored")
				expect(MouseDash.tap(run, wave.index, 10, 10.2, 0).outcome).to.equal("ignored")
				expect(MouseDash.tap(run, wave.index, 1.5, 10.2, 0).outcome).to.equal("ignored")
				expect(MouseDash.tap(run, wave.index, hole, 10.2, 0).outcome).to.equal("catch")
				expect(MouseDash.tap(run, wave.index, hole, 10.25, 0).outcome).to.equal("ignored")
				expect(run.points).to.equal(1)
				expect(run.hearts).to.equal(3)
				expect(run.dizzyUntil).to.equal(0)
			end
		)

		it("takes a late tap only inside the ping allowance, and never punishes it", function()
			local run, wave = mouseUp(0)
			local pop = wave.pops[1]
			expect(MouseDash.tap(run, wave.index, pop.hole, pop.downAt + 0.2, 0.1).outcome).to.equal(
				"ignored"
			)
			expect(run.hearts).to.equal(3)
			expect(MouseDash.tap(run, wave.index, pop.hole, pop.downAt + 0.08, 0.1).outcome).to.equal(
				"catch"
			)
		end)

		it(
			"costs a heart for a tap on an empty hole, once: taps while dizzy do nothing (Derek 2026-11-12)",
			function()
				local run, wave = mouseUp(0)
				local hole = wave.pops[1].hole
				local other = if hole == 1 then 2 else 1
				local tap = MouseDash.tap(run, wave.index, other, 10.1, 0)
				expect(tap.outcome).to.equal("empty")
				expect(tap.heart).to.equal(-1)
				expect(run.hearts).to.equal(2)
				expect(run.streak).to.equal(0)
				expect(MouseDash.tap(run, wave.index, hole, 10.2, 0).outcome).to.equal("dizzy")
				expect(MouseDash.tap(run, wave.index, other, 10.25, 0).outcome).to.equal("dizzy")
				expect(run.hearts).to.equal(2) -- a slip never costs two
				expect(run.points).to.equal(0)
				expect(
					MouseDash.tap(run, wave.index, hole, 10.1 + Config.MouseDashDizzySeconds, 0).outcome
				).to.equal("catch")
			end
		)

		it("costs a heart for a mouse that gets away, and ends the run at none", function()
			local run = runAt(0)
			for lost = 1, 3 do
				local wave = MouseDash.wave(run, run.nextAt, rolls({ 0.5 }))
				local gone, over = MouseDash.settle(run, wave.pops[1].downAt - 0.01, 0)
				expect(#gone).to.equal(0)
				expect(over).to.equal(false)
				gone, over = MouseDash.settle(run, wave.pops[1].downAt + 0.01, 0)
				expect(gone[1].heart).to.equal(-1)
				expect(over).to.equal(true)
				expect(run.hearts).to.equal(3 - lost)
			end
			expect(MouseDash.over(run)).to.equal("hearts")
			expect(run.lost).to.equal(3)
		end)

		it("costs nothing for a golden mouse that gets away, and pays 3 for one caught", function()
			local run, wave = mouseUp(10, "golden")
			MouseDash.settle(run, wave.pops[1].downAt + 1, 0)
			expect(run.hearts).to.equal(3)
			run, wave = mouseUp(10, "golden")
			local tap = MouseDash.tap(run, wave.index, wave.pops[1].hole, 10.1, 0)
			expect(tap.gain).to.equal(3)
			expect(run.points).to.equal(13)
		end)

		it("costs a heart for a tapped kitten and nothing for one left alone", function()
			local run, wave = mouseUp(20, "kitten")
			local tap = MouseDash.tap(run, wave.index, wave.pops[1].hole, 10.1, 0)
			expect(tap.outcome).to.equal("kitten")
			expect(tap.heart).to.equal(-1)
			expect(tap.waveOver).to.equal(true)
			expect(run.hearts).to.equal(2)
			expect(run.points).to.equal(20)
			run, wave = mouseUp(20, "kitten")
			local gone, over = MouseDash.settle(run, wave.pops[1].downAt + 0.01, 0)
			expect(gone[1].heart).to.equal(0)
			expect(over).to.equal(true)
			expect(run.hearts).to.equal(3)
		end)

		it("gives a heart back every 10 catches in a row, never above 3", function()
			local run = runAt(0)
			run.hearts = 2
			for catch = 1, 20 do
				local wave = MouseDash.wave(run, run.nextAt, rolls({ 0.99 }))
				wave.pops[1].kind = "mouse"
				local tap =
					MouseDash.tap(run, wave.index, wave.pops[1].hole, wave.pops[1].upAt + 0.1, 0)
				expect(tap.heart).to.equal(if catch == 10 then 1 else 0)
			end
			expect(run.hearts).to.equal(3)
			expect(run.streak).to.equal(20)
		end)

		it("breaks the streak on an escape", function()
			local run, wave = mouseUp(0)
			run.streak = 9
			MouseDash.settle(run, wave.pops[1].downAt + 1, 0)
			expect(run.streak).to.equal(0)
		end)

		it("wins at 100, a golden mouse from 98 showing 100", function()
			local run, wave = mouseUp(98, "golden")
			local tap = MouseDash.tap(run, wave.index, wave.pops[1].hole, 10.1, 0)
			expect(tap.gain).to.equal(2)
			expect(run.points).to.equal(100)
			expect(MouseDash.over(run)).to.equal("win")
			-- nothing more is judged once it is over
			run.wave = wave
			wave.pops[1].done = false
			expect(MouseDash.tap(run, wave.index, wave.pops[1].hole, 10.2, 0).outcome).to.equal(
				"ignored"
			)
		end)

		it("keeps a pair up until its mice are done, then takes the kitten down with it", function()
			local run = runAt(40)
			-- pair roll passes, golden roll fails, kitten roll passes
			local wave = MouseDash.wave(run, 10, rolls({ 0.1, 0.99, 0.3, 0.05, 0.6 }))
			expect(#wave.pops).to.equal(2)
			expect(wave.pops[1].kind).to.equal("mouse")
			expect(wave.pops[2].kind).to.equal("kitten")
			expect(wave.pops[1].downAt - 10).to.be.near(
				MouseDash.window(8) * MouseDash.PAIR_WINDOW_SCALE,
				1e-6
			)
			local tap = MouseDash.tap(run, wave.index, wave.pops[1].hole, 10.2, 0)
			expect(tap.outcome).to.equal("catch")
			expect(tap.waveOver).to.equal(true)
			expect(run.hearts).to.equal(3)
		end)

		it(
			"ends on the run's clock, MouseDashRunSeconds after the first mouse can come (Derek 2026-11-12)",
			function()
				local run = runAt(0)
				local endsAt = run.startedAt + MouseDash.LEAD_IN + Config.MouseDashRunSeconds
				expect(run.endsAt).to.be.near(endsAt, 1e-9)
				expect(Config.MouseDashRunSeconds).to.equal(180)
				expect(MouseDash.over(run)).to.equal(nil)
				expect(MouseDash.over(run, endsAt - 0.01)).to.equal(nil)
				expect(MouseDash.over(run, endsAt)).to.equal("time")
				-- the server wakes for the clock even with a long window up, and a tap after it does nothing
				run.nextAt = endsAt - 0.2
				local wave = MouseDash.wave(run, run.nextAt, rolls({ 0.5 }))
				expect(MouseDash.wakeAt(run, 0.1)).to.be.near(endsAt, 1e-9)
				local late = MouseDash.tap(run, wave.index, wave.pops[1].hole, endsAt + 0.01, 0.1)
				expect(late.outcome).to.equal("ignored")
				expect(run.points).to.equal(0)
				-- a win or the last heart still names the run's end first
				run.hearts = 0
				expect(MouseDash.over(run, endsAt + 1)).to.equal("hearts")
			end
		)

		it("wakes the server at the next wave in a gap, else at the first window to end", function()
			local run = runAt(0)
			expect(MouseDash.wakeAt(run, 0.1)).to.equal(10)
			local wave = MouseDash.wave(run, 10, rolls({ 0.5 }))
			expect(MouseDash.wakeAt(run, 0.1)).to.be.near(wave.pops[1].downAt + 0.1, 1e-6)
		end)

		it("scores less for mashing every hole than for tapping the mouse", function()
			local function play(mash: boolean): number
				local roll = lcg(3)
				local run = MouseDash.begin(0, false)
				local now = run.nextAt
				for _ = 1, 40 do
					if MouseDash.over(run) ~= nil then
						break
					end
					local wave = MouseDash.wave(run, now, roll)
					local pop = wave.pops[1]
					if mash then
						-- every hole in turn, 12 taps a second
						local at = now
						for hole = 1, MouseDash.HOLES do
							at += 1 / 12
							MouseDash.tap(run, wave.index, hole, at, 0)
						end
					else
						MouseDash.tap(run, wave.index, pop.hole, now + 0.3, 0)
					end
					MouseDash.settle(run, pop.downAt + 0.01, 0)
					now = math.max(run.nextAt, pop.downAt + 0.02)
					run.wave = nil
				end
				return run.points
			end
			expect(play(true) < play(false)).to.equal(true)
		end)
	end)

	describe("MouseDash save and records", function()
		it("drops anything odd from a save", function()
			local save = MouseDash.sanitize({
				best = 250,
				bestSeconds = -4,
				runs = "x",
				mouser = 1,
				firstRunDone = true,
			})
			expect(save.best).to.equal(100)
			expect(save.bestSeconds).to.equal(0)
			expect(save.runs).to.equal(0)
			expect(save.mouser).to.equal(false)
			expect(save.firstRunDone).to.equal(true)
			expect(MouseDash.sanitize("junk").best).to.equal(0)
			expect(MouseDash.sanitize({ best = 0, bestSeconds = 40 }).bestSeconds).to.equal(0)
		end)

		it("ranks by points, then the faster run", function()
			expect(MouseDash.score(50, 40) > MouseDash.score(49, 1)).to.equal(true)
			expect(MouseDash.score(50, 40) > MouseDash.score(50, 41)).to.equal(true)
			local points, seconds = MouseDash.fromScore(MouseDash.score(73, 58))
			expect(points).to.equal(73)
			expect(seconds).to.equal(58)
			points, seconds = MouseDash.fromScore("x")
			expect(points + seconds).to.equal(0)
			expect(MouseDash.beats(0, 5, 0, 0)).to.equal(false)
			expect(MouseDash.beats(1, 5, 0, 0)).to.equal(true)
			expect(MouseDash.beats(10, 20, 10, 20)).to.equal(false)
			expect(MouseDash.beats(10, 19, 10, 20)).to.equal(true)
		end)

		it("records a run: the best, Mouser at 50 and the first run done", function()
			local save = MouseDash.fresh()
			expect(MouseDash.record(save, 12, 20, true)).to.equal(true)
			expect(save.firstRunDone).to.equal(true)
			expect(save.seenKitten).to.equal(true)
			expect(save.mouser).to.equal(false)
			expect(MouseDash.record(save, 8, 10, false)).to.equal(false)
			expect(MouseDash.record(save, Config.MouseDashMouserAt, 60, false)).to.equal(true)
			expect(save.mouser).to.equal(true)
			expect(save.runs).to.equal(3)
			expect(save.best).to.equal(50)
		end)

		it("joins two servers' saves without losing a record, a flag or a used free run", function()
			local a = MouseDash.fresh()
			a.best, a.bestSeconds, a.runs, a.freeDay, a.mouser = 60, 70, 4, 20000, true
			local b = MouseDash.fresh()
			b.best, b.bestSeconds, b.runs, b.freeDay, b.seenKitten = 60, 65, 9, 20001, true
			local out = MouseDash.merge(a, b)
			expect(out.best).to.equal(60)
			expect(out.bestSeconds).to.equal(65)
			expect(out.runs).to.equal(9)
			expect(out.freeDay).to.equal(20001)
			expect(out.mouser).to.equal(true)
			expect(out.seenKitten).to.equal(true)
		end)

		it("gives one free run each UTC day", function()
			local save = MouseDash.fresh()
			local now = 20000 * 86400 + 5
			expect(MouseDash.freeToday(save, now)).to.equal(true)
			expect(MouseDash.useFree(save, now)).to.equal(true)
			expect(MouseDash.useFree(save, now + 100)).to.equal(false)
			expect(MouseDash.freeToday(save, now + 86400)).to.equal(true)
			expect(MouseDash.playText(true)).to.equal("Play (free)")
			expect(MouseDash.playText(false)).to.equal("Play (1 golden fish)")
		end)

		it("lists the board's top rows and marks the viewer", function()
			local rows = {
				{ userId = 1, name = "A", value = MouseDash.score(90, 80) },
				{ userId = 2, name = "B", value = MouseDash.score(40, 30) },
				{ userId = 3, name = "C", value = 0 },
			} :: any
			local top = MouseDash.topRows(rows, 2)
			expect(#top).to.equal(2)
			expect(top[1].points).to.equal(90)
			expect(top[2].me).to.equal(true)
			expect(top[2].seconds).to.equal(30)
		end)
	end)

	describe("MouseDash whole runs", function()
		it(
			"a perfect player wins in about 60 to 100 seconds and a player who never taps lasts three mice",
			function()
				local roll = lcg(21)
				local run = MouseDash.begin(0, false)
				local now = run.nextAt
				while MouseDash.over(run) == nil do
					local wave = MouseDash.wave(run, now, roll)
					local at = now
					for _, pop in wave.pops do
						if pop.kind ~= "kitten" then
							at += 0.3
							MouseDash.tap(run, wave.index, pop.hole, math.min(at, pop.downAt), 0)
						end
					end
					MouseDash.settle(run, at + 2, 0)
					now = math.max(run.nextAt, at)
				end
				expect(MouseDash.over(run)).to.equal("win")
				expect(run.hearts).to.equal(3)
				local seconds = MouseDash.seconds(run, now)
				expect(seconds >= 40 and seconds <= 110).to.equal(true)

				local idle = MouseDash.begin(0, false)
				now = idle.nextAt
				local waves = 0
				while MouseDash.over(idle) == nil do
					local wave = MouseDash.wave(idle, now, roll)
					waves += 1
					MouseDash.settle(idle, wave.pops[1].downAt + 0.01, 0)
					now = idle.nextAt
				end
				expect(waves).to.equal(3)
				expect(idle.points).to.equal(0)
			end
		)
	end)
end
