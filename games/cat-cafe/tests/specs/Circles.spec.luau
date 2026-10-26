--!strict
-- Circles.luau against data-model v0.3.1 section 10 (the net as closing circles) and the reviewer's S23 and S24.
-- F26 done-when: all Perfect catches at 100%, all Good at 50%; a forged early or late press scores 0; a Mythical
-- with a Basic Net shows uneven circle speeds.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Circles = require(Shared.Circles)
	local Config = require(Shared.Config)

	-- Park-Miller generator: deterministic rolls in (0, 1) without Roblox Random.
	local function lcg(seed: number): () -> number
		local state = seed
		return function()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
	end

	local function constant(value: number): () -> number
		return function()
			return value
		end
	end

	local NOW = 1000

	-- An attempt over a fresh schedule, plus its circles for convenience.
	local function attemptFor(rarity: string, netLevel: number, seed: number?)
		local circles = Circles.schedule(rarity :: any, netLevel, NOW, lcg(seed or 11))
		return Circles.newAttempt(circles, Circles.windows(netLevel)), circles
	end

	describe("net windows (section 10 table)", function()
		local expected = {
			[0] = { 0.045, 0.11, 0.30 },
			[1] = { 0.055, 0.13, 0.20 },
			[2] = { 0.065, 0.155, 0.10 },
			[3] = { 0.08, 0.18, 0 },
		}

		it("Basic, Sturdy, Pro and Master match the table", function()
			for level, row in pairs(expected) do
				local windows = Circles.windows(level)
				expect(windows.perfect).to.be.near(row[1], 1e-9)
				expect(windows.good).to.be.near(row[2], 1e-9)
				expect(windows.jitter).to.be.near(row[3], 1e-9)
			end
		end)

		it("a better net widens both windows and steadies the circles", function()
			for level = 1, 3 do
				local lower, higher = Circles.windows(level - 1), Circles.windows(level)
				expect(higher.perfect > lower.perfect).to.equal(true)
				expect(higher.good > lower.good).to.equal(true)
				expect(higher.jitter < lower.jitter).to.equal(true)
			end
		end)

		it("perfect sits inside good at every level", function()
			for level = 0, 3 do
				local windows = Circles.windows(level)
				expect(windows.perfect < windows.good).to.equal(true)
			end
		end)

		it("clamps the net level to 0 to 3 and floors it", function()
			expect(Circles.windows(-2)).to.equal(Circles.windows(0))
			expect(Circles.windows(7)).to.equal(Circles.windows(3))
			expect(Circles.windows(1.9)).to.equal(Circles.windows(1))
		end)

		it("CatchSchedule sends only perfect and good", function()
			expect(Circles.publicWindows(Circles.windows(2)) :: any).to.deepEqual({ perfect = 0.065, good = 0.155 })
		end)
	end)

	describe("schedule (section 10 flow step 1)", function()
		it("has circles[rarity] circles: 1 for a Common up to 5 for a Mythical", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local circles = Circles.schedule(rarity, 0, NOW, lcg(3))
				expect(#circles).to.equal(Catalog.rarities[rarity].circles)
			end
		end)

		it("the first circle starts CircleLeadInSeconds (0.6) after GrabBegin", function()
			expect(Config.CircleLeadInSeconds).to.be.near(0.6, 1e-9)
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local circles = Circles.schedule(rarity, 1, NOW, lcg(5))
				expect(circles[1].startsAt).to.be.near(NOW + 0.6, 1e-9)
			end
		end)

		it("shrink times stay within shrinkSeconds x (1 +/- jitter) for every net", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local base = Catalog.rarities[rarity].shrinkSeconds
				for level = 0, 3 do
					local jitter = Circles.windows(level).jitter
					for seed = 1, 20 do
						for _, circle in ipairs(Circles.schedule(rarity, level, NOW, lcg(seed))) do
							expect(circle.shrinkSeconds >= base * (1 - jitter) - 1e-9).to.equal(true)
							expect(circle.shrinkSeconds <= base * (1 + jitter) + 1e-9).to.equal(true)
						end
					end
				end
			end
		end)

		it("the extreme rolls hit the ends of the jitter and gap ranges", function()
			local low = Circles.schedule("Rare", 0, NOW, constant(0))
			expect(low[1].shrinkSeconds).to.be.near(1.15 * 0.7, 1e-9)
			expect(low[2].startsAt - Circles.target(low[1])).to.be.near(Config.CircleGapMin, 1e-9)
			local high = Circles.schedule("Rare", 0, NOW, constant(0.999999))
			expect(high[1].shrinkSeconds).to.be.near(1.15 * 1.3, 1e-5)
			expect(high[2].startsAt - Circles.target(high[1])).to.be.near(Config.CircleGapMax, 1e-5)
		end)

		it("circles are separated by a gap of CircleGapMin to CircleGapMax (0.40 to 0.75 s)", function()
			expect(Config.CircleGapMin).to.be.near(0.40, 1e-9)
			expect(Config.CircleGapMax).to.be.near(0.75, 1e-9)
			for seed = 1, 50 do
				local circles = Circles.schedule("Mythical", 0, NOW, lcg(seed))
				for i = 2, #circles do
					local gap = circles[i].startsAt - Circles.target(circles[i - 1])
					expect(gap >= Config.CircleGapMin - 1e-9).to.equal(true)
					expect(gap <= Config.CircleGapMax + 1e-9).to.equal(true)
				end
			end
		end)

		it("a Master Net shrinks every circle at exactly the rarity's speed", function()
			for seed = 1, 10 do
				for _, circle in ipairs(Circles.schedule("Mythical", 3, NOW, lcg(seed))) do
					expect(circle.shrinkSeconds).to.be.near(Catalog.rarities.Mythical.shrinkSeconds, 1e-9)
				end
			end
		end)

		it("a Mythical with a Basic Net shows uneven circle speeds (F26 done-when)", function()
			local circles = Circles.schedule("Mythical", 0, NOW, lcg(42))
			local slowest, fastest = 0, math.huge
			for _, circle in ipairs(circles) do
				slowest = math.max(slowest, circle.shrinkSeconds)
				fastest = math.min(fastest, circle.shrinkSeconds)
			end
			expect(slowest - fastest > 0.05).to.equal(true)
		end)

		it("circles sit on screen between 0.25 and 0.75 across and 0.3 and 0.7 down", function()
			for seed = 1, 30 do
				for _, circle in ipairs(Circles.schedule("Legendary", 1, NOW, lcg(seed))) do
					expect(circle.x >= 0.25 and circle.x <= 0.75).to.equal(true)
					expect(circle.y >= 0.3 and circle.y <= 0.7).to.equal(true)
				end
			end
		end)

		it("the same rolls give the same schedule", function()
			local a = Circles.schedule("Epic", 1, NOW, lcg(9))
			local b = Circles.schedule("Epic", 1, NOW, lcg(9))
			expect(a :: any).to.deepEqual(b)
		end)
	end)

	describe("targets, deadlines and the lock", function()
		it("target is startsAt + shrinkSeconds; the deadline adds good and the latency cap", function()
			local circle = { startsAt = 10, shrinkSeconds = 1.4, x = 0.5, y = 0.5 }
			local windows = Circles.windows(0)
			expect(Circles.target(circle)).to.be.near(11.4, 1e-9)
			expect(Circles.deadline(circle, windows)).to.be.near(11.4 + 0.11 + 0.15, 1e-9)
		end)

		it("the attempt ends at the last deadline and the lock lasts to the last target + good + 1 s", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local circles = Circles.schedule(rarity, 2, NOW, lcg(4))
				local windows = Circles.windows(2)
				local last = circles[#circles]
				expect(Circles.endsAt(circles, windows)).to.be.near(Circles.deadline(last, windows), 1e-9)
				expect(Circles.lockUntil(circles, windows)).to.be.near(Circles.target(last) + windows.good + 1, 1e-9)
				-- nobody else can take the stray before every circle is judged
				expect(Circles.lockUntil(circles, windows) > Circles.endsAt(circles, windows)).to.equal(true)
			end
		end)

		it("S24: every next circle starts after the previous circle's deadline, for every net", function()
			for level = 0, 3 do
				local windows = Circles.windows(level)
				for seed = 1, 30 do
					local circles = Circles.schedule("Mythical", level, NOW, lcg(seed))
					for i = 2, #circles do
						expect(circles[i].startsAt > Circles.deadline(circles[i - 1], windows)).to.equal(true)
					end
				end
			end
		end)
	end)

	describe("latency (section 10 flow step 3)", function()
		it("takes off half the round trip, capped at CatchLatencyCapSeconds (0.15)", function()
			expect(Config.CatchLatencyCapSeconds).to.be.near(0.15, 1e-9)
			expect(Circles.latency(0)).to.equal(0)
			expect(Circles.latency(0.1)).to.be.near(0.05, 1e-9)
			expect(Circles.latency(0.3)).to.be.near(0.15, 1e-9)
			expect(Circles.latency(2)).to.be.near(0.15, 1e-9)
		end)

		it("a bad ping counts as none", function()
			expect(Circles.latency(-1)).to.equal(0)
			expect(Circles.latency(0 / 0)).to.equal(0)
			expect(Circles.latency(("0.2" :: any) :: number)).to.equal(0)
		end)
	end)

	describe("grade (section 10 flow step 4)", function()
		it("within perfect scores 1.0, within good 0.5, else 0, early or late alike", function()
			local windows = Circles.windows(0)
			local cases: { { any } } = {
				{ 0, "perfect", 1.0 },
				{ 0.045, "perfect", 1.0 },
				{ -0.045, "perfect", 1.0 },
				{ 0.046, "good", 0.5 },
				{ -0.1, "good", 0.5 },
				{ 0.11, "good", 0.5 },
				{ -0.11, "good", 0.5 },
				{ 0.111, "miss", 0 },
				{ -0.2, "miss", 0 },
				{ 5, "miss", 0 },
			}
			for _, case in ipairs(cases) do
				local grade, score = Circles.grade(case[1], windows)
				expect(grade).to.equal(case[2])
				expect(score).to.equal(case[3])
			end
		end)

		it("scores come from Config: CircleScorePerfect 1.0, CircleScoreGood 0.5", function()
			expect(Config.CircleScorePerfect).to.equal(1.0)
			expect(Config.CircleScoreGood).to.equal(0.5)
		end)
	end)

	describe("press and expire (section 10 flow step 4)", function()
		it("all Perfect catches at 100% and all Good at 50% (F26 done-when)", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				for _, offset in ipairs({ 0, 0.1 }) do
					local attempt, circles = attemptFor(rarity, 0)
					for i, circle in ipairs(circles) do
						local at = Circles.target(circle) + offset
						expect(Circles.press(attempt, i, at, at + 0.05)).to.equal(if offset == 0 then "perfect" else "good")
					end
					expect(Circles.isDone(attempt)).to.equal(true)
					expect(Circles.chance(attempt.scores)).to.be.near(if offset == 0 then 1 else 0.5, 1e-9)
					expect(Circles.perfectCount(attempt)).to.equal(if offset == 0 then #circles else 0)
				end
			end
		end)

		it("records the signed timing error of each judged press", function()
			local attempt, circles = attemptFor("Rare", 1)
			Circles.press(attempt, 1, Circles.target(circles[1]) - 0.02, Circles.target(circles[1]))
			expect(attempt.errors[1]).to.be.near(-0.02, 1e-9)
		end)

		it("a press before its circle starts is ignored and the circle can still be judged", function()
			local attempt, circles = attemptFor("Common", 0)
			local early = circles[1].startsAt - 0.01
			expect(Circles.press(attempt, 1, early, early)).never.to.be.ok()
			expect(attempt.nextIndex).to.equal(1)
			local at = Circles.target(circles[1])
			expect(Circles.press(attempt, 1, at, at)).to.equal("perfect")
		end)

		it("a forged early press after the start but far from the target scores 0 (F26 done-when)", function()
			local attempt, circles = attemptFor("Common", 3)
			local at = circles[1].startsAt + 0.01
			expect(Circles.press(attempt, 1, at, at)).to.equal("miss")
			expect(attempt.scores[1]).to.equal(0)
			expect(Circles.chance(attempt.scores)).to.equal(0)
		end)

		it("only the first press per index counts", function()
			local attempt, circles = attemptFor("Epic", 1)
			local miss = circles[1].startsAt + 0.01
			expect(Circles.press(attempt, 1, miss, miss)).to.equal("miss")
			local perfect = Circles.target(circles[1])
			expect(Circles.press(attempt, 1, perfect, perfect)).never.to.be.ok()
			expect(attempt.scores[1]).to.equal(0)
		end)

		it("presses must come in index order: skipping ahead is ignored", function()
			local attempt, circles = attemptFor("Legendary", 0)
			local at = Circles.target(circles[1])
			expect(Circles.press(attempt, 2, at, at)).never.to.be.ok()
			expect(Circles.press(attempt, 0, at, at)).never.to.be.ok()
			expect(Circles.press(attempt, 99, at, at)).never.to.be.ok()
			expect(Circles.press(attempt, -1, at, at)).never.to.be.ok()
			expect(Circles.press(attempt, 1.5, at, at)).never.to.be.ok()
			expect(Circles.press(attempt, 0 / 0, at, at)).never.to.be.ok()
			expect(attempt.nextIndex).to.equal(1)
			expect(Circles.press(attempt, 1, at, at)).to.equal("perfect")
		end)

		it("a circle with no press by its deadline is a Miss that ends the attempt (v0.4)", function()
			local attempt, circles = attemptFor("Rare", 0)
			local windows = Circles.windows(0)
			local second = Circles.target(circles[2])
			-- the press for circle 2 arrives after circle 1's deadline, so circle 1 expires first and nothing follows
			expect(second > Circles.deadline(circles[1], windows)).to.equal(true)
			expect(Circles.press(attempt, 2, second, second)).never.to.be.ok()
			expect(attempt.scores[1]).to.equal(0)
			expect(attempt.grades[1]).to.equal("miss")
			expect(attempt.errors[1]).never.to.be.ok()
			expect(attempt.grades[2]).never.to.be.ok()
			expect(Circles.isDone(attempt)).to.equal(true)
			expect(Circles.succeeded(attempt)).to.equal(false)
		end)

		it("a late press for an expired circle is ignored, not scored on the next one", function()
			local attempt, circles = attemptFor("Rare", 3)
			local windows = Circles.windows(3)
			local tooLate = Circles.deadline(circles[1], windows) + 0.01
			expect(Circles.press(attempt, 1, tooLate - Config.CatchLatencyCapSeconds, tooLate)).never.to.be.ok()
			expect(attempt.scores[1]).to.equal(0)
			expect(attempt.nextIndex).to.equal(2)
			expect(attempt.scores[2]).never.to.be.ok()
		end)

		it("a late press within the deadline is judged on its corrected time", function()
			local attempt, circles = attemptFor("Common", 0)
			local windows = Circles.windows(0)
			local target = Circles.target(circles[1])
			-- arrives 0.2 s late with 0.15 s of latency taken off: a 0.05 s error, just outside Perfect
			local arrival = target + 0.2
			expect(arrival <= Circles.deadline(circles[1], windows)).to.equal(true)
			expect(Circles.press(attempt, 1, arrival - Circles.latency(0.3), arrival)).to.equal("good")
			expect(attempt.errors[1]).to.be.near(0.05, 1e-9)
		end)

		it("expire marks only the first overdue circle a Miss, which ends the attempt (v0.4)", function()
			local attempt, circles = attemptFor("Mythical", 0)
			local windows = Circles.windows(0)
			expect(Circles.expire(attempt, circles[1].startsAt)).to.equal(0)
			expect(Circles.isDone(attempt)).to.equal(false)
			expect(Circles.expire(attempt, Circles.deadline(circles[2], windows) + 0.001)).to.equal(1)
			expect(attempt.nextIndex).to.equal(2)
			expect(Circles.isDone(attempt)).to.equal(true)
			expect(Circles.expire(attempt, Circles.endsAt(circles, windows) + 1)).to.equal(0)
			expect(Circles.chance(attempt.scores)).to.equal(0)
			local at = Circles.endsAt(circles, windows) + 2
			expect(Circles.press(attempt, 2, at, at)).never.to.be.ok()
		end)

		it("the first Miss ends a mixed run: Perfect, Good, miss judges three and fails (v0.4)", function()
			local attempt, circles = attemptFor("Mythical", 0, 7)
			local offsets = { 0, 0.08, 0.5, -0.01, -0.1 }
			for i, circle in ipairs(circles) do
				local at = Circles.target(circle) + offsets[i]
				Circles.press(attempt, i, at, at)
			end
			expect(attempt.grades :: any).to.deepEqual({ "perfect", "good", "miss" })
			expect(Circles.succeeded(attempt)).to.equal(false)
			expect(Circles.charmGain(attempt)).to.equal(0)
			expect(Circles.perfectCount(attempt)).to.equal(1)
		end)

		it("chance of no scores is 0", function()
			expect(Circles.chance({})).to.equal(0)
		end)
	end)

	describe("scripted press check (reviewer S23)", function()
		it("keeps only the last 50 judged circles", function()
			local history = {}
			for i = 1, 70 do
				Circles.pushHistory(history, i > 20)
			end
			expect(#history).to.equal(50)
			for _, perfect in ipairs(history) do
				expect(perfect).to.equal(true)
			end
		end)

		it("flags a full window that is more than 95% Perfect, never a partial one", function()
			expect(Circles.AUTO_PRESS_WINDOW).to.equal(50)
			expect(Circles.AUTO_PRESS_RATE).to.be.near(0.95, 1e-9)
			local function history(perfect: number, total: number): { boolean }
				local out = {}
				for i = 1, total do
					table.insert(out, i <= perfect)
				end
				return out
			end
			expect(Circles.looksScripted(history(49, 49))).to.equal(false)
			expect(Circles.looksScripted(history(50, 50))).to.equal(true)
			expect(Circles.looksScripted(history(48, 50))).to.equal(true) -- 96%
			expect(Circles.looksScripted(history(47, 50))).to.equal(false) -- 94%
			expect(Circles.looksScripted({})).to.equal(false)
		end)
	end)
end
