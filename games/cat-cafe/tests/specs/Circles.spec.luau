--!strict
-- Circles.luau against data-model v0.3.1 section 10 (the net as closing circles) and the reviewer's S23 and S24.
-- Written by the engineer while QA is paused for the playtest push; QA owns this file from here.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Circles = require(Shared.Circles)
	local Config = require(Shared.Config)

	-- A roll function that returns the given values in turn, then repeats the last one.
	local function rolls(values: { number }): () -> number
		local i = 0
		return function()
			i = math.min(i + 1, #values)
			return values[i]
		end
	end

	local function half(): number
		return 0.5
	end

	describe("windows", function()
		it("reads Config.NetWindows and clamps the net level", function()
			expect(Circles.windows(0)).to.equal(Config.NetWindows[0])
			expect(Circles.windows(2)).to.equal(Config.NetWindows[2])
			expect(Circles.windows(-3)).to.equal(Config.NetWindows[0])
			expect(Circles.windows(99)).to.equal(Config.NetWindows[3])
			expect(Circles.windows(1.7)).to.equal(Config.NetWindows[1])
		end)

		it("publicWindows sends only the two band widths, never the jitter", function()
			local public = Circles.publicWindows(Config.NetWindows[0]) :: any
			expect(public.perfect).to.equal(Config.NetWindows[0].perfect)
			expect(public.good).to.equal(Config.NetWindows[0].good)
			expect(public.jitter).never.to.be.ok()
		end)
	end)

	describe("schedule", function()
		it("has one circle per the rarity's circles count", function()
			for rarity, def in Catalog.rarities do
				expect(#Circles.schedule(rarity :: any, 0, 100, half)).to.equal(def.circles)
			end
		end)

		it(
			"the first circle starts after the lead-in and later ones after a gap from the last target",
			function()
				local circles = Circles.schedule("Legendary", 3, 100, half)
				expect(circles[1].startsAt).to.be.near(100 + Config.CircleLeadInSeconds, 1e-9)
				local midGap = (Config.CircleGapMin + Config.CircleGapMax) / 2
				for i = 2, #circles do
					expect(circles[i].startsAt).to.be.near(
						Circles.target(circles[i - 1]) + midGap,
						1e-9
					)
				end
			end
		)

		it("gaps stay within CircleGapMin to CircleGapMax for extreme rolls", function()
			for _, r in { 0, 0.999999 } do
				local circles = Circles.schedule("Mythical", 0, 0, rolls({ r }))
				for i = 2, #circles do
					local gap = circles[i].startsAt - Circles.target(circles[i - 1])
					expect(gap >= Config.CircleGapMin - 1e-9).to.equal(true)
					expect(gap <= Config.CircleGapMax + 1e-9).to.equal(true)
				end
			end
		end)

		it("shrink time is the rarity's, jittered by the net: none on the Pro net", function()
			local base = Catalog.rarities.Epic.shrinkSeconds
			for _, r in { 0, 0.5, 0.999999 } do
				for _, circle in Circles.schedule("Epic", 3, 0, rolls({ r })) do
					expect(circle.shrinkSeconds).to.be.near(base, 1e-9)
				end
			end
			local jitter = Config.NetWindows[0].jitter
			for _, circle in Circles.schedule("Epic", 0, 0, rolls({ 0 })) do
				expect(circle.shrinkSeconds).to.be.near(base * (1 - jitter), 1e-9)
			end
		end)

		it("circles stay inside the middle of the screen", function()
			for _, r in { 0, 0.999999 } do
				for _, circle in Circles.schedule("Mythical", 1, 0, rolls({ r })) do
					expect(circle.x >= 0.25 and circle.x <= 0.75).to.equal(true)
					expect(circle.y >= 0.3 and circle.y <= 0.7).to.equal(true)
				end
			end
		end)

		it("S24: every deadline passes before the next circle starts", function()
			for level = 0, 3 do
				local windows = Circles.windows(level)
				local circles = Circles.schedule("Mythical", level, 0, rolls({ 0 }))
				for i = 2, #circles do
					expect(Circles.deadline(circles[i - 1], windows) < circles[i].startsAt).to.equal(
						true
					)
				end
			end
		end)

		it("the lock outlasts the last deadline", function()
			local windows = Circles.windows(0)
			local circles = Circles.schedule("Rare", 0, 0, half)
			expect(Circles.lockUntil(circles, windows) > Circles.endsAt(circles, windows)).to.equal(
				true
			)
		end)
	end)

	describe("latency", function()
		it("takes off half the ping, capped, and ignores nonsense", function()
			expect(Circles.latency(0.1)).to.be.near(0.05, 1e-9)
			expect(Circles.latency(2)).to.equal(Config.CatchLatencyCapSeconds)
			expect(Circles.latency(-1)).to.equal(0)
			expect(Circles.latency(0 / 0)).to.equal(0)
		end)
	end)

	describe("grade", function()
		local windows = Config.NetWindows[0]

		it("Perfect inside the perfect window either side, Good inside good, else Miss", function()
			local grade, score = Circles.grade(0, windows)
			expect(grade).to.equal("perfect")
			expect(score).to.equal(Config.CircleScorePerfect)
			grade, score = Circles.grade(-windows.perfect, windows)
			expect(grade).to.equal("perfect")
			grade, score = Circles.grade(windows.perfect + 0.001, windows)
			expect(grade).to.equal("good")
			expect(score).to.equal(Config.CircleScoreGood)
			grade, score = Circles.grade(-windows.good, windows)
			expect(grade).to.equal("good")
			grade, score = Circles.grade(windows.good + 0.001, windows)
			expect(grade).to.equal("miss")
			expect(score).to.equal(0)
		end)
	end)

	describe("press and expire", function()
		local function attemptFor(rarity: any)
			local windows = Circles.windows(0)
			local circles = Circles.schedule(rarity, 0, 0, half)
			return Circles.newAttempt(circles, windows), circles
		end

		it("judges presses in order and finishes after the last circle", function()
			local attempt, circles = attemptFor("Epic")
			for i, circle in circles do
				local t = Circles.target(circle)
				expect(Circles.press(attempt, i, t, t)).to.equal("perfect")
			end
			expect(Circles.isDone(attempt)).to.equal(true)
			expect(Circles.chance(attempt.scores)).to.equal(1)
			expect(Circles.perfectCount(attempt)).to.equal(#circles)
		end)

		it(
			"ignores a press for the wrong circle, a repeat, and a press before the circle starts",
			function()
				local attempt, circles = attemptFor("Rare")
				local first = circles[1]
				expect(Circles.press(attempt, 2, Circles.target(circles[2]), first.startsAt)).never.to.be.ok()
				expect(Circles.press(attempt, 1, first.startsAt - 0.01, first.startsAt)).never.to.be.ok()
				expect(attempt.nextIndex).to.equal(1)
				local t = Circles.target(first)
				expect(Circles.press(attempt, 1, t, t)).to.equal("perfect")
				expect(Circles.press(attempt, 1, t, t)).never.to.be.ok()
				expect(attempt.nextIndex).to.equal(2)
			end
		)

		it(
			"a circle nobody presses scores 0 once its deadline passes, and the next press moves on",
			function()
				local attempt, circles = attemptFor("Rare")
				local late = Circles.deadline(circles[1], attempt.windows) + 0.01
				expect(Circles.expire(attempt, late)).to.equal(1)
				expect(attempt.scores[1]).to.equal(0)
				expect(attempt.grades[1]).to.equal("miss")
				local t = Circles.target(circles[2])
				expect(Circles.press(attempt, 2, t, t)).to.equal("perfect")
				expect(Circles.chance(attempt.scores)).to.be.near(0.5, 1e-9)
			end
		)
	end)

	describe("chance", function()
		it("is the mean score, 0 with no circles", function()
			expect(Circles.chance({})).to.equal(0)
			expect(Circles.chance({ 1, 0.5, 0 })).to.be.near(0.5, 1e-9)
			expect(Circles.chance({ 0.5, 0.5 })).to.equal(0.5)
		end)
	end)

	describe("S23 scripted presses", function()
		it("flags only a full window of more than 95% Perfect", function()
			local history: { boolean } = {}
			for _ = 1, Circles.AUTO_PRESS_WINDOW - 1 do
				Circles.pushHistory(history, true)
			end
			expect(Circles.looksScripted(history)).to.equal(false)
			Circles.pushHistory(history, true)
			expect(Circles.looksScripted(history)).to.equal(true)
			for _ = 1, 3 do
				Circles.pushHistory(history, false)
			end
			expect(#history).to.equal(Circles.AUTO_PRESS_WINDOW)
			expect(Circles.looksScripted(history)).to.equal(false)
		end)
	end)
end
