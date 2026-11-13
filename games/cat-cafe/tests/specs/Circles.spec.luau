--!strict
-- Circles.luau against data-model v0.3.1 section 10 (the net as closing circles) and the reviewer's S23 and S24.
-- F26 done-when: all Perfect catches at 100%, all Good at 50%; a forged early or late press scores 0; a Mythical
-- with a Basic Net shows uneven circle speeds. #1884 (catch-rework.md 7b): a net catch keeps a trust bar, so a Miss
-- costs trust and the try goes on until the bar fills, drops below 0 or the rings run out.
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

	-- An attempt over a fresh schedule with the rarity's trust bar (#1884), plus its circles for convenience. The
	-- bands are the net's own (not times catchWindow), so the offsets below grade the same on every rarity.
	local function attemptFor(rarity: string, netLevel: number, seed: number?)
		local circles = Circles.schedule(rarity :: any, netLevel, NOW, lcg(seed or 11))
		return Circles.newAttempt(
			circles,
			Circles.windows(netLevel),
			Circles.trustFor(rarity :: any)
		),
			circles
	end

	-- The same with every ring a plain "single": rolls of 0.5 never pass a twist's chance (#1884, 7c).
	local function plainFor(rarity: string, netLevel: number)
		local circles = Circles.schedule(rarity :: any, netLevel, NOW, constant(0.5))
		return Circles.newAttempt(
			circles,
			Circles.windows(netLevel),
			Circles.trustFor(rarity :: any)
		),
			circles
	end

	-- The rings of a schedule a ring cap counts: every circle but a paw ring (a double's halves count one each).
	local function used(circles: { any }): number
		local n = 0
		for _, circle in circles do
			if circle.kind ~= "paw" then
				n += 1
			end
		end
		return n
	end

	describe("net windows (section 10 table)", function()
		local expected = {
			[0] = { 0.045, 0.11 },
			[1] = { 0.055, 0.13 },
			[2] = { 0.065, 0.155 },
			[3] = { 0.08, 0.18 },
		}

		it(
			"Basic, Sturdy, Pro and Master match the table, with no jitter of their own (F93)",
			function()
				for level, row in pairs(expected) do
					local windows = Circles.windows(level)
					expect(windows.perfect).to.be.near(row[1], 1e-9)
					expect(windows.good).to.be.near(row[2], 1e-9)
					expect((windows :: any).jitter).never.to.be.ok()
				end
			end
		)

		it("a better net widens both windows", function()
			for level = 1, 3 do
				local lower, higher = Circles.windows(level - 1), Circles.windows(level)
				expect(higher.perfect > lower.perfect).to.equal(true)
				expect(higher.good > lower.good).to.equal(true)
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
			expect(Circles.publicWindows(Circles.windows(2)) :: any).to.deepEqual({
				perfect = 0.065,
				good = 0.155,
			})
		end)
	end)

	describe("windows by rarity (v0.13.15 F83)", function()
		it("a stray's perfect and good are its net's times its rarity's catchWindow", function()
			for level = 0, 3 do
				local net = Circles.windows(level)
				for _, rarity in Catalog.rarityOrder do
					local scale = Catalog.rarities[rarity].catchWindow
					local windows = Circles.windowsFor(level, rarity)
					expect(windows.perfect).to.be.near(net.perfect * scale, 1e-12)
					expect(windows.good).to.be.near(net.good * scale, 1e-12)
					expect(windows.perfect < windows.good).to.equal(true)
				end
			end
		end)

		it(
			"a Basic Net Mythical's bands are 0.68 of the net's, and the net's own table is untouched (#1884, #2005)",
			function()
				local mythical = Circles.windowsFor(0, "Mythical")
				expect(mythical.perfect).to.be.near(0.0306, 1e-12)
				expect(mythical.good).to.be.near(0.0748, 1e-12)
				-- the widest Good of all, a Master Net Common, still clears CircleGapMin with the latency cap (S24)
				expect(Circles.windowsFor(3, "Common").good).to.be.near(0.207, 1e-12)
				expect(0.207 + Config.CatchLatencyCapSeconds < Config.CircleGapMin).to.equal(true)
				expect(Circles.windows(0).good).to.equal(0.11)
			end
		)

		it(
			"the first area's bands are 1.2 times as wide, and no other area's change (#2322)",
			function()
				expect((Catalog.getArea("alley") :: any).catchWindowScale).to.equal(1.2)
				for _, area in Catalog.areas do
					for level = 0, 3 do
						for _, rarity in Catalog.rarityOrder do
							local plain = Circles.windowsFor(level, rarity)
							local here = Circles.windowsFor(level, rarity, area.id)
							local scale = if area.id == "alley" then 1.2 else 1
							expect(here.perfect).to.be.near(plain.perfect * scale, 1e-12)
							expect(here.good).to.be.near(plain.good * scale, 1e-12)
						end
					end
				end
				-- the widest Good, a Master Net Common in the Alleyway, still clears CircleGapMin with the latency cap (S24)
				local widest = Circles.windowsFor(3, "Common", "alley").good
				expect(widest + Config.CatchLatencyCapSeconds < Config.CircleGapMin).to.equal(true)
				expect(Circles.windowsFor(0, "Common", "nowhere").good).to.equal(
					Circles.windowsFor(0, "Common").good
				)
			end
		)

		-- #3140 (Derek2 2026-11-10: "speed up commons/rare in further maps slightly like tier 5+ it becomes to boring
		-- to wait", "speed up the circles")
		it(
			"Common and Rare rings close quicker in the Sewer, Desert and Ruins, and nowhere else (#3140)",
			function()
				expect(Config.QuickRingTier).to.equal(5)
				expect(Config.QuickRingScale.Common).to.equal(0.80)
				expect(Config.QuickRingScale.Rare).to.equal(0.85)
				for _, area in Catalog.areas do
					local late = area.tier >= 5
					for _, rarity in Catalog.rarityOrder do
						local quick = late and (rarity == "Common" or rarity == "Rare")
						local want = if quick then Config.QuickRingScale[rarity] else 1
						expect(Circles.ringSpeed(rarity, area.id)).to.equal(want)
						-- the same rolls give the same rings, each one's shrink time scaled and nothing else
						local plain = Circles.schedule(rarity, 0, NOW, lcg(7))
						local here = Circles.schedule(rarity, 0, NOW, lcg(7), area.id)
						expect(#here).to.equal(#plain)
						for index, circle in here do
							expect(circle.shrinkSeconds).to.be.near(
								plain[index].shrinkSeconds * want,
								1e-12
							)
							expect(circle.kind).to.equal(plain[index].kind)
							expect(circle.x).to.equal(plain[index].x)
						end
					end
				end
				for _, id in { "sewer", "desert", "ruins" } do
					local area = Catalog.getArea(id)
					assert(area ~= nil, id)
					expect(area.tier >= 5).to.equal(true)
				end
				expect(Circles.ringSpeed("Common", nil)).to.equal(1)
				expect(Circles.ringSpeed("Common", "nowhere")).to.equal(1)
				-- a quick Rare ring is still slower than an Epic one, and a quick Common than a quick Rare
				local rarities = Catalog.rarities
				local common = rarities.Common.shrinkSeconds * Config.QuickRingScale.Common
				local rare = rarities.Rare.shrinkSeconds * Config.QuickRingScale.Rare
				expect(common).to.be.near(0.96, 1e-9)
				expect(rare).to.be.near(0.85, 1e-9)
				expect(common > rare).to.equal(true)
				expect(rare > rarities.Epic.shrinkSeconds).to.equal(true)
			end
		)

		it(
			"a quick ring's bands are as many seconds wide, and its beat still clears the gap (#3140)",
			function()
				for level = 0, 3 do
					for _, rarity in { "Common", "Rare" } do
						-- the bands come from the net, the rarity, the area and the coat, never the ring's speed
						local windows = Circles.windowsFor(level, rarity :: any, "ruins")
						local shortest = Catalog.rarities[rarity].shrinkSeconds
							* Config.QuickRingScale[rarity]
							* (1 - Config.CircleJitter)
						-- the whole Good band fits inside the quickest ring's closing time with room to see it come
						expect(windows.good < shortest / 2).to.equal(true)
						expect(windows.good + Config.CatchLatencyCapSeconds < Config.CircleGapMin).to.equal(
							true
						)
					end
				end
				-- rings stay a steady beat: each starts the one before's shrink time plus CircleGapMin later
				local circles = Circles.schedule("Common", 0, NOW, constant(0.5), "sewer")
				for index = 2, #circles do
					local before = circles[index - 1]
					expect(circles[index].startsAt).to.be.near(
						before.startsAt + before.shrinkSeconds + Config.CircleGapMin,
						1e-9
					)
				end
			end
		)

		-- #3135 (Derek2 2026-11-10: "check if mutated cats gold/rainbow increase difficulty of catch and if thats not
		-- added add it"): it was not, so a gold stray's bands are 0.90 and a rainbow's 0.80 times as wide
		it(
			"a gold cat's bands are a little narrower and a rainbow's narrower still (#3135)",
			function()
				expect(Config.CoatDifficulty.gold).to.equal(0.90)
				expect(Config.CoatDifficulty.rainbow).to.equal(0.80)
				for level = 0, 3 do
					for _, rarity in Catalog.rarityOrder do
						local plain = Circles.windowsFor(level, rarity, "woods")
						local base = Circles.windowsFor(level, rarity, "woods", "base")
						local gold = Circles.windowsFor(level, rarity, "woods", "gold")
						local rainbow = Circles.windowsFor(level, rarity, "woods", "rainbow")
						expect(base.perfect).to.equal(plain.perfect)
						expect(base.good).to.equal(plain.good)
						expect(gold.perfect).to.be.near(plain.perfect * 0.90, 1e-12)
						expect(gold.good).to.be.near(plain.good * 0.90, 1e-12)
						expect(rainbow.perfect).to.be.near(plain.perfect * 0.80, 1e-12)
						expect(rainbow.good).to.be.near(plain.good * 0.80, 1e-12)
					end
				end
				-- on top of the first area's wider bands, and a coat the table does not know changes nothing
				expect(Circles.windowsFor(0, "Common", "alley", "gold").good).to.be.near(
					Circles.windowsFor(0, "Common").good * 1.2 * 0.90,
					1e-12
				)
				expect(Circles.windowsFor(0, "Common", nil, "plaid").good).to.equal(
					Circles.windowsFor(0, "Common").good
				)
			end
		)

		it("leaves the tutorial stray's bands alone whatever its coat (#3135)", function()
			-- CatService uses tutorialWindows for a beginner's own stray, which takes no coat
			local tutorial = Circles.tutorialWindows(0)
			expect(tutorial.good > Circles.windowsFor(0, "Common", "alley", "rainbow").good).to.equal(
				true
			)
		end)

		it("rarer is never wider, at every net", function()
			for level = 0, 3 do
				for i = 2, #Catalog.rarityOrder do
					local lower = Circles.windowsFor(level, Catalog.rarityOrder[i - 1])
					local higher = Circles.windowsFor(level, Catalog.rarityOrder[i])
					expect(higher.good < lower.good).to.equal(true)
					expect(higher.perfect < lower.perfect).to.equal(true)
				end
			end
		end)
	end)

	describe("schedule (section 10 flow step 1)", function()
		it(
			"has the rarity's ring cap: 5 to 11 all-Good rings plus CatchSpareRings 16, on every net (#1884, #2332)",
			function()
				local want = { Common = 21, Rare = 22, Epic = 24, Legendary = 25, Mythical = 27 }
				expect(Config.CatchSpareRings).to.equal(16)
				for _, rarity in ipairs(Catalog.rarityOrder) do
					expect(Circles.ringCap(rarity)).to.equal(want[rarity])
					for level = 0, 3 do
						local circles = Circles.schedule(rarity, level, NOW, lcg(3))
						expect(used(circles)).to.equal(want[rarity])
						expect(#Circles.schedule(rarity, level, NOW, constant(0.5))).to.equal(
							want[rarity]
						)
						expect(#circles <= Circles.maxCircles()).to.equal(true)
					end
				end
			end
		)

		it(
			"rings come on a steady beat: each shrink time plus CircleGapMin after the last (#1884)",
			function()
				for seed = 1, 10 do
					local circles = Circles.schedule("Epic", 0, NOW, lcg(seed))
					for i = 2, #circles do
						if circles[i].half == 2 then
							expect(circles[i].startsAt - circles[i - 1].startsAt).to.be.near(
								Config.DoubleRingGap,
								1e-9
							)
						else
							expect(circles[i].startsAt - Circles.target(circles[i - 1])).to.be.near(
								Config.CircleGapMin,
								1e-9
							)
						end
					end
				end
			end
		)

		it("the first circle starts CircleLeadInSeconds (0.6) after GrabBegin", function()
			expect(Config.CircleLeadInSeconds).to.be.near(0.6, 1e-9)
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local circles = Circles.schedule(rarity, 1, NOW, lcg(5))
				expect(circles[1].startsAt).to.be.near(NOW + 0.6, 1e-9)
			end
		end)

		it(
			"shrink times stay within shrinkSeconds x (1 +/- CircleJitter 0.10) for every net (F93)",
			function()
				expect(Config.CircleJitter).to.be.near(0.10, 1e-12)
				for _, rarity in ipairs(Catalog.rarityOrder) do
					local base = Catalog.rarities[rarity].shrinkSeconds
					for level = 0, 3 do
						local jitter = Config.CircleJitter
						for seed = 1, 20 do
							for _, circle in ipairs(Circles.schedule(rarity, level, NOW, lcg(seed))) do
								expect(circle.shrinkSeconds >= base * (1 - jitter) - 1e-9).to.equal(
									true
								)
								expect(circle.shrinkSeconds <= base * (1 + jitter) + 1e-9).to.equal(
									true
								)
							end
						end
					end
				end
			end
		)

		it("the extreme rolls hit the ends of the jitter and gap ranges", function()
			local low = Circles.schedule("Rare", 0, NOW, constant(0))
			expect(low[1].shrinkSeconds).to.be.near(1.00 * 0.9, 1e-9)
			expect(low[2].startsAt - Circles.target(low[1])).to.be.near(Config.CircleGapMin, 1e-9)
			local high = Circles.schedule("Rare", 0, NOW, constant(0.999999))
			expect(high[1].shrinkSeconds).to.be.near(1.00 * 1.1, 1e-5)
			expect(high[2].startsAt - Circles.target(high[1])).to.be.near(Config.CircleGapMin, 1e-5) -- #1884
		end)

		it(
			"circles are separated by a gap of CircleGapMin to CircleGapMax (0.55 to 0.75 s; #2060)",
			function()
				expect(Config.CircleGapMin).to.be.near(0.55, 1e-9)
				expect(Config.CircleGapMax).to.be.near(0.75, 1e-9)
				for seed = 1, 50 do
					local circles = Circles.schedule("Mythical", 0, NOW, lcg(seed))
					for i = 2, #circles do
						if circles[i].half == 2 then
							continue -- a double's second half follows its first by DoubleRingGap (#1884)
						end
						local gap = circles[i].startsAt - Circles.target(circles[i - 1])
						expect(gap >= Config.CircleGapMin - 1e-9).to.equal(true)
						expect(gap <= Config.CircleGapMax + 1e-9).to.equal(true)
					end
				end
			end
		)

		it(
			"the net never changes the rhythm: the same rolls give the same circles on every net (F93)",
			function()
				for _, rarity in ipairs(Catalog.rarityOrder) do
					for seed = 1, 10 do
						local basic = Circles.schedule(rarity, 0, NOW, lcg(seed))
						for level = 1, 3 do
							expect(Circles.schedule(rarity, level, NOW, lcg(seed)) :: any).to.deepEqual(
								basic
							)
						end
					end
				end
			end
		)

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
		it(
			"target is startsAt + shrinkSeconds; the deadline adds good and the latency cap",
			function()
				local circle: any = { startsAt = 10, shrinkSeconds = 1.4, x = 0.5, y = 0.5 }
				local windows = Circles.windows(0)
				expect(Circles.target(circle)).to.be.near(11.4, 1e-9)
				expect(Circles.deadline(circle, windows)).to.be.near(11.4 + 0.11 + 0.15, 1e-9)
			end
		)

		it(
			"the attempt ends at the last deadline and the lock lasts to the last target + good + 1 s",
			function()
				for _, rarity in ipairs(Catalog.rarityOrder) do
					local circles = Circles.schedule(rarity, 2, NOW, lcg(4))
					local windows = Circles.windows(2)
					local last = circles[#circles]
					expect(Circles.endsAt(circles, windows)).to.be.near(
						Circles.deadline(last, windows),
						1e-9
					)
					expect(Circles.lockUntil(circles, windows)).to.be.near(
						Circles.target(last) + windows.good + 1,
						1e-9
					)
					-- nobody else can take the stray before every circle is judged
					expect(Circles.lockUntil(circles, windows) > Circles.endsAt(circles, windows)).to.equal(
						true
					)
				end
			end
		)

		it(
			"S24: every next ring starts after the previous ring's deadline, for every net",
			function()
				for level = 0, 3 do
					local windows = Circles.windows(level)
					for seed = 1, 30 do
						local circles = Circles.schedule("Mythical", level, NOW, lcg(seed))
						for i = 2, #circles do
							if circles[i].half == 2 then
								continue -- #1884: a double's halves overlap on purpose
							end
							expect(circles[i].startsAt > Circles.deadline(circles[i - 1], windows)).to.equal(
								true
							)
						end
					end
				end
			end
		)
	end)

	describe("the tutorial stray (F87, easy-start.md section 2b)", function()
		it("is one circle shrinking for TutorialShrinkSeconds with no jitter", function()
			for seed = 1, 20 do
				local circles = Circles.tutorialSchedule(NOW, lcg(seed))
				expect(#circles).to.equal(1)
				expect(circles[1].shrinkSeconds).to.equal(Config.TutorialShrinkSeconds)
				expect(circles[1].startsAt).to.be.near(NOW + Config.CircleLeadInSeconds, 1e-9)
				expect(circles[1].x >= 0.25 and circles[1].x <= 0.75).to.equal(true)
				expect(circles[1].y >= 0.3 and circles[1].y <= 0.7).to.equal(true)
			end
		end)

		it("is slower than a Common's circles", function()
			local common = Catalog.rarities.Common.shrinkSeconds * (1 + Config.CircleJitter)
			expect(Config.TutorialShrinkSeconds > common).to.equal(true)
		end)

		it("doubles a Common's bands on every net", function()
			for level = 0, 3 do
				local common = Circles.windowsFor(level, "Common")
				local tutorial = Circles.tutorialWindows(level)
				expect(Config.TutorialWindowScale).to.equal(2)
				expect(tutorial.perfect).to.be.near(common.perfect * 2, 1e-9)
				expect(tutorial.good).to.be.near(common.good * 2, 1e-9)
			end
		end)

		it("catches on a press 0.2 s off on a Basic Net, which misses a Common", function()
			local circles = Circles.tutorialSchedule(NOW, constant(0.5))
			local attempt = Circles.newAttempt(circles, Circles.tutorialWindows(0))
			local at = Circles.target(circles[1]) + 0.2
			expect(Circles.press(attempt, 1, at, at)).to.equal("good")
			expect(Circles.succeeded(attempt)).to.equal(true)
			local common = Circles.windowsFor(0, "Common")
			expect(Circles.grade(0.2, common)).to.equal("miss")
		end)
	end)

	-- #2920: a player's very first catch holds its ring on the target until the press.
	describe("the held first ring (#2920)", function()
		local function held(): (Circles.Attempt, number)
			local circles = Circles.tutorialSchedule(NOW, constant(0.5), true)
			return Circles.newAttempt(circles, Circles.tutorialWindows(0)),
				Circles.target(circles[1])
		end

		it("marks the ring and sends how long it waits", function()
			local circles = Circles.tutorialSchedule(NOW, constant(0.5), true)
			expect(circles[1].hold).to.equal(true)
			expect(circles[1].holdSeconds).to.equal(Config.FirstRingHoldSeconds)
			expect(Config.FirstRingHoldSeconds).to.equal(60)
			local plain = Circles.tutorialSchedule(NOW, constant(0.5))
			expect(plain[1].hold).to.equal(nil)
			expect(plain[1].holdSeconds).to.equal(nil)
		end)

		it("ignores every press before the target, so the first ring can't be missed", function()
			local attempt, target = held()
			local windows = Circles.tutorialWindows(0)
			local startsAt = target - Config.TutorialShrinkSeconds
			expect(Circles.press(attempt, 1, startsAt + 0.1, startsAt + 0.1)).to.equal(nil)
			local early = target - windows.good - 0.01
			expect(Circles.press(attempt, 1, early, early)).to.equal(nil)
			expect(attempt.nextIndex).to.equal(1)
			expect(Circles.isDone(attempt)).to.equal(false)
		end)

		it(
			"grades any press from the target to the end of the hold a Perfect, and catches",
			function()
				for _, after in { 0, 0.3, 5, 59 } do
					local attempt, target = held()
					expect(Circles.press(attempt, 1, target + after, target + after)).to.equal(
						"perfect"
					)
					expect(attempt.errors[1]).to.equal(0)
					expect(Circles.succeeded(attempt)).to.equal(true)
				end
				-- a press just before the target (the clock between the client's freeze and the server) counts too
				local attempt, target = held()
				expect(Circles.press(attempt, 1, target - 0.05, target - 0.05)).to.equal("perfect")
			end
		)

		it("waits the whole hold before a Miss, and locks the stray as long", function()
			local attempt, target = held()
			local windows = Circles.tutorialWindows(0)
			local deadline = Circles.deadline(attempt.circles[1], windows)
			expect(deadline).to.be.near(target + 60 + Config.CatchLatencyCapSeconds, 1e-9)
			expect(Circles.expire(attempt, target + 30)).to.equal(0)
			expect(Circles.expire(attempt, deadline + 0.01)).to.equal(1)
			expect(attempt.grades[1]).to.equal("miss")
			expect(Circles.lockUntil(attempt.circles, windows)).to.be.near(deadline + 1, 1e-9)
		end)
	end)

	-- QA edges on the F87 tutorial circle (easy-start.md section 2b and QA check 2).
	describe("tutorial edges (QA)", function()
		local RANK: { [string]: number } = { miss = 0, good = 1, perfect = 2 }

		it(
			"is never stricter than a Common's: every offset on every net grades as well or better",
			function()
				for level = 0, 3 do
					local common = Circles.windowsFor(level, "Common")
					local tutorial = Circles.tutorialWindows(level)
					for step = 0, 60 do
						local offset = step / 100
						for _, err in { offset, -offset } do
							local easy = RANK[Circles.grade(err, tutorial)]
							expect(easy >= RANK[Circles.grade(err, common)]).to.equal(true)
						end
					end
				end
			end
		)

		it(
			"can still be missed (so the retry happens): a press as the circle starts misses",
			function()
				for level = 0, 3 do
					local circles = Circles.tutorialSchedule(NOW, constant(0.5))
					local attempt = Circles.newAttempt(circles, Circles.tutorialWindows(level))
					local at = circles[1].startsAt + 0.01
					expect(Circles.press(attempt, 1, at, at)).to.equal("miss")
					expect(Circles.succeeded(attempt)).to.equal(false)
					expect(Circles.isDone(attempt)).to.equal(true)
				end
			end
		)

		it(
			"an unpressed circle ends missed at its deadline, and the lock outlasts that deadline",
			function()
				for level = 0, 3 do
					local circles = Circles.tutorialSchedule(NOW, lcg(level + 1))
					local windows = Circles.tutorialWindows(level)
					local attempt = Circles.newAttempt(circles, windows)
					local deadline = Circles.deadline(circles[1], windows)
					Circles.expire(attempt, deadline)
					expect(Circles.isDone(attempt)).to.equal(false)
					Circles.expire(attempt, deadline + 0.01)
					expect(Circles.isDone(attempt)).to.equal(true)
					expect(Circles.succeeded(attempt)).to.equal(false)
					expect(Circles.lockUntil(circles, windows) > deadline).to.equal(true)
				end
			end
		)
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
		it("all Perfect scores 100% and all Good 50% (F26 done-when)", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local count = Catalog.rarities[rarity].circles
				for _, offset in ipairs({ 0, 0.1 }) do
					local attempt, circles = attemptFor(rarity, 0)
					for i, circle in ipairs(circles) do
						if Circles.isDone(attempt) then
							break
						end
						local at = Circles.target(circle) + offset
						expect(Circles.press(attempt, i, at, at + 0.05)).to.equal(
							if offset == 0 then "perfect" else "good"
						)
					end
					expect(Circles.isDone(attempt)).to.equal(true)
					expect(Circles.chance(attempt.scores)).to.be.near(
						if offset == 0 then 1 else 0.5,
						1e-9
					)
					expect(Circles.perfectCount(attempt)).to.equal(if offset == 0 then count else 0)
				end
			end
		end)

		it("records the signed timing error of each judged press", function()
			local attempt, circles = attemptFor("Rare", 1)
			Circles.press(attempt, 1, Circles.target(circles[1]) - 0.02, Circles.target(circles[1]))
			expect(attempt.errors[1]).to.be.near(-0.02, 1e-9)
		end)

		it(
			"a press before its circle starts is ignored and the circle can still be judged",
			function()
				local attempt, circles = attemptFor("Common", 0)
				local early = circles[1].startsAt - 0.01
				expect(Circles.press(attempt, 1, early, early)).never.to.be.ok()
				expect(attempt.nextIndex).to.equal(1)
				local at = Circles.target(circles[1])
				expect(Circles.press(attempt, 1, at, at)).to.equal("perfect")
			end
		)

		it(
			"a forged early press after the start but far from the target scores 0 (F26 done-when)",
			function()
				local attempt, circles = attemptFor("Common", 3)
				local at = circles[1].startsAt + 0.01
				expect(Circles.press(attempt, 1, at, at)).to.equal("miss")
				expect(attempt.scores[1]).to.equal(0)
				expect(Circles.chance(attempt.scores)).to.equal(0)
			end
		)

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

		it(
			"a circle with no press by its deadline is a Miss that costs trust, and the try goes on (#1884)",
			function()
				local attempt, circles = attemptFor("Rare", 0)
				local windows = Circles.windows(0)
				local second = Circles.target(circles[2])
				-- the press for circle 2 arrives after circle 1's deadline, so circle 1 expires first, then 2 is judged
				expect(second > Circles.deadline(circles[1], windows)).to.equal(true)
				expect(Circles.press(attempt, 2, second, second)).to.equal("perfect")
				expect(attempt.scores[1]).to.equal(0)
				expect(attempt.grades[1]).to.equal("miss")
				expect(attempt.errors[1]).never.to.be.ok()
				expect(attempt.trust).to.equal(2 - 2 + 3)
				expect(Circles.isDone(attempt)).to.equal(false)
			end
		)

		it(
			"without a trust bar (a rescue's tree circle) the first Miss still ends the attempt (v0.4)",
			function()
				local circles = Circles.schedule("Rare", 0, NOW, lcg(11))
				local attempt = Circles.newAttempt(circles, Circles.windows(0))
				local second = Circles.target(circles[2])
				expect(Circles.press(attempt, 2, second, second)).never.to.be.ok()
				expect(attempt.grades[1]).to.equal("miss")
				expect(Circles.isDone(attempt)).to.equal(true)
				expect(Circles.succeeded(attempt)).to.equal(false)
			end
		)

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
			expect(Circles.press(attempt, 1, arrival - Circles.latency(0.3), arrival)).to.equal(
				"good"
			)
			expect(attempt.errors[1]).to.be.near(0.05, 1e-9)
		end)

		it(
			"expire marks every overdue circle a Miss; two from the start take trust below 0 and bolt (#1884)",
			function()
				local attempt, circles = attemptFor("Mythical", 0)
				local windows = Circles.windows(0)
				expect(Circles.expire(attempt, circles[1].startsAt)).to.equal(0)
				expect(Circles.isDone(attempt)).to.equal(false)
				expect(Circles.expire(attempt, Circles.deadline(circles[2], windows) + 0.001)).to.equal(
					2
				)
				expect(attempt.nextIndex).to.equal(3)
				expect(attempt.trust).to.equal(-2)
				expect(Circles.isDone(attempt)).to.equal(true)
				expect(Circles.finish(attempt)).to.equal("bolt")
				expect(Circles.expire(attempt, Circles.endsAt(circles, windows) + 1)).to.equal(0)
				expect(Circles.chance(attempt.scores)).to.equal(0)
				local at = Circles.endsAt(circles, windows) + 2
				expect(Circles.press(attempt, 2, at, at)).never.to.be.ok()
			end
		)

		it(
			"a run with a Miss can still fill the bar: Perfect +3, Miss -2, caught at trustNeed (#1884, #2005)",
			function()
				local attempt, circles = plainFor("Mythical", 0)
				local offsets = { 0, 0, 0.5, 0, 0, 0, 0, 0, 0 }
				for i, circle in ipairs(circles) do
					local at = Circles.target(circle) + (offsets[i] or 0)
					Circles.press(attempt, i, at, at)
				end
				-- 2 + 3 + 3 - 2 + 6 x 3 = 24, past the Mythical's need of 23, on the ninth ring
				expect(attempt.grades[3]).to.equal("miss")
				expect(#attempt.grades).to.equal(9)
				expect(attempt.trust).to.equal(24)
				expect(Circles.succeeded(attempt)).to.equal(true)
				expect(Circles.finish(attempt)).to.equal("great")
				expect(Circles.perfectCount(attempt)).to.equal(8)
				-- #2332: two Misses no longer run out of rings: 2 + 3 - 2 - 2 + 6 x 3 = 19 after nine, 25 on the eleventh
				local long, longCircles = plainFor("Mythical", 0)
				local longOffsets = { 0, 0.5, 0.5 }
				for i, circle in ipairs(longCircles) do
					local at = Circles.target(circle) + (longOffsets[i] or 0)
					Circles.press(long, i, at, at)
				end
				expect(#long.grades).to.equal(11)
				expect(long.trust).to.equal(25)
				expect(Circles.succeeded(long)).to.equal(true)
			end
		)

		it("chance of no scores is 0", function()
			expect(Circles.chance({})).to.equal(0)
		end)
	end)

	describe("catching stakes (v0.4, F34, data-model section 10 step 5)", function()
		-- Presses circle i at target + offsets[i]. At a Basic Net 0 is Perfect, 0.08 Good, -0.3 a pressed Miss (after
		-- the circle starts, outside Good) and 0.5 a Miss by expiry (past the deadline, so the press is ignored).
		local function run(rarity: string, offsets: { number })
			local attempt, circles = attemptFor(rarity, 0)
			for i, offset in ipairs(offsets) do
				local at = Circles.target(circles[i]) + offset
				Circles.press(attempt, i, at, at)
			end
			return attempt, circles
		end

		local function same(value: number, count: number): { number }
			local out = {}
			for i = 1, count do
				out[i] = value
			end
			return out
		end

		it(
			"all Perfect catches in the rarity's `circles` rings, a PURRFECT, for every rarity (#1884)",
			function()
				for _, rarity in ipairs(Catalog.rarityOrder) do
					local count = Catalog.rarities[rarity].circles
					local attempt = run(rarity, same(0, count))
					expect(Circles.isDone(attempt)).to.equal(true)
					expect(Circles.succeeded(attempt)).to.equal(true)
					expect(#attempt.grades).to.equal(count)
					expect(Circles.finish(attempt)).to.equal("purrfect")
				end
			end
		)

		it(
			"one Good is GREAT, two or more NICE; all Good catches every rarity (#1884 7d, #2005, #2317)",
			function()
				local great = run("Common", { 0.08, 0, 0, 0 }) -- 4, 7, 10, 13
				expect(Circles.finish(great)).to.equal("great")
				local nice = run("Common", { 0.08, 0.08, 0, 0, 0 }) -- 4, 6, 9, 12
				expect(Circles.finish(nice)).to.equal("nice")
				expect(#nice.grades).to.equal(4)
				local slow = run("Common", same(0.08, 5)) -- 4 to 12 over all five rings, past 11 on the last
				expect(Circles.succeeded(slow)).to.equal(true)
				expect(Circles.finish(slow)).to.equal("nice")
				expect(#slow.grades).to.equal(5)
				-- #2317: an Epic all Good was 4 to 16 over its seven rings and bolted short of 17; now the eighth fills it
				local epic = run("Epic", same(0.08, 8))
				expect(#epic.grades).to.equal(8)
				expect(Circles.succeeded(epic)).to.equal(true)
				expect(Circles.finish(epic)).to.equal("nice")
				for _, rarity in Catalog.rarityOrder do
					local need = Catalog.rarities[rarity :: any].trustNeed
					local goods = math.ceil((need - Config.TrustStart) / Config.TrustGood)
					local all = run(rarity, same(0.08, goods))
					expect(Circles.succeeded(all)).to.equal(true)
				end
			end
		)

		it(
			"one early Miss on a Rare is won back; two in a row from the start bolt (7f check 3)",
			function()
				local back = run("Rare", { -0.3, 0, 0, 0, 0, 0 }) -- 0, then 3 to 15
				expect(Circles.succeeded(back)).to.equal(true)
				expect(Circles.finish(back)).to.equal("great")
				local bolted = run("Rare", { -0.3, -0.3 })
				expect(Circles.isDone(bolted)).to.equal(true)
				expect(Circles.succeeded(bolted)).to.equal(false)
				expect(bolted.trust).to.equal(-2)
			end
		)

		it("takes its trust steps from Config (#1884)", function()
			expect(Circles.trustDelta("perfect")).to.equal(Config.TrustPerfect)
			expect(Circles.trustDelta("good")).to.equal(Config.TrustGood)
			expect(Circles.trustDelta("miss")).to.equal(Config.TrustMiss)
			expect(Circles.trustFor("Epic").start).to.equal(Config.TrustStart)
			expect(Circles.trustFor("Epic", 1).start).to.equal(Config.TrustStart + 1)
			expect(Circles.trustFor("Epic").need).to.equal(Catalog.rarities.Epic.trustNeed)
			-- the tutorial stray: one Good or Perfect still catches it
			local tutorial = Circles.tutorialTrust()
			expect(tutorial.start + Config.TrustGood >= tutorial.need).to.equal(true)
			expect(tutorial.start + Config.TrustMiss < tutorial.need).to.equal(true)
		end)

		it(
			"a run that is not over has not succeeded yet, and its next deadline is the waiting circle's",
			function()
				local attempt, circles = run("Rare", { 0 })
				expect(Circles.isDone(attempt)).to.equal(false)
				expect(Circles.succeeded(attempt)).to.equal(false)
				expect(Circles.nextDeadline(attempt)).to.be.near(
					Circles.deadline(circles[2], attempt.windows),
					1e-9
				)
				local fresh, freshCircles = attemptFor("Epic", 0)
				expect(Circles.nextDeadline(fresh)).to.be.near(
					Circles.deadline(freshCircles[1], fresh.windows),
					1e-9
				)
			end
		)

		it(
			"a bolt ends the attempt at once: no deadline left and later circles are ignored",
			function()
				local attempt, circles = run("Epic", { -0.3, -0.3 })
				expect(attempt.errors[2]).to.be.near(-0.3, 1e-9) -- judged as a press, not expired
				expect(attempt.grades :: any).to.deepEqual({ "miss", "miss" })
				expect(Circles.isDone(attempt)).to.equal(true)
				expect(Circles.nextDeadline(attempt)).never.to.be.ok()
				local at = Circles.target(circles[3])
				expect(Circles.press(attempt, 3, at, at)).never.to.be.ok()
				expect(Circles.expire(attempt, Circles.endsAt(circles, attempt.windows) + 1)).to.equal(
					0
				)
				expect(#attempt.grades).to.equal(2)
			end
		)

		it("nothing is left to expire after a sure catch", function()
			local attempt, circles = run("Legendary", same(0, 6))
			expect(Circles.nextDeadline(attempt)).never.to.be.ok()
			expect(Circles.expire(attempt, Circles.endsAt(circles, attempt.windows) + 1)).to.equal(
				0
			)
			expect(Circles.succeeded(attempt)).to.equal(true)
		end)

		it("charm: 4 per Perfect, doubled for a PURRFECT", function()
			expect(Circles.charmGain((run("Common", same(0, 3))))).to.equal(24)
			expect(Circles.charmGain((run("Legendary", same(0, 6))))).to.equal(48)
			expect(Circles.charmGain((run("Mythical", same(0, 7))))).to.equal(56)
			expect(Circles.charmGain((run("Epic", { 0, 0.08, 0, 0.08, 0, 0 })))).to.equal(16)
			expect(Circles.charmGain((run("Rare", { 0, -0.08, 0, 0, 0 })))).to.equal(16)
			expect(Circles.charmGain((run("Rare", same(0.08, 4))))).to.equal(0) -- not over yet
			expect(Circles.charmGain((run("Rare", same(0.08, 6))))).to.equal(0) -- out of rings
			expect(Circles.charmGain((run("Epic", { 0, 0, 0 })))).to.equal(0) -- not over yet: no charm
		end)

		it(
			"charm: nothing for a failed or unfinished catch, however many Perfects came first",
			function()
				expect(Circles.charmGain((run("Mythical", { 0, 0, 0, 0, 0.5 })))).to.equal(0)
				expect(Circles.charmGain((run("Rare", { 0 })))).to.equal(0)
				local attempt, circles = attemptFor("Common", 0)
				Circles.expire(attempt, Circles.deadline(circles[1], attempt.windows) + 0.01)
				expect(Circles.charmGain(attempt)).to.equal(0)
			end
		)
	end)

	describe("rarity twists (#1884, catch-rework.md 7c)", function()
		local function kindsOf(rarity: string, seeds: number): { [string]: number }
			local counts = { single = 0, double = 0, paw = 0 }
			for seed = 1, seeds do
				for _, circle in Circles.schedule(rarity :: any, 0, NOW, lcg(seed)) do
					counts[circle.kind :: string] += 1
				end
			end
			return counts
		end

		it(
			"Commons and Rares keep plain rings; Epics get doubles, Legendaries and Mythicals paw rings too",
			function()
				for _, rarity in { "Common", "Rare" } do
					local counts = kindsOf(rarity, 200)
					expect(counts.double + counts.paw).to.equal(0)
				end
				local epic = kindsOf("Epic", 200)
				expect(epic.double > 0).to.equal(true)
				expect(epic.paw).to.equal(0)
				for _, rarity in { "Legendary", "Mythical" } do
					local counts = kindsOf(rarity, 200)
					expect(counts.double > 0 and counts.paw > 0).to.equal(true)
				end
			end
		)

		it(
			"a double is two circles on one spot DoubleRingGap (0.35 s) apart, half 1 then 2, never the first ring",
			function()
				expect(Config.DoubleRingGap).to.be.near(0.35, 1e-12)
				expect(Config.DoubleRingChance).to.be.near(0.25, 1e-12)
				for seed = 1, 100 do
					local circles = Circles.schedule("Mythical", 0, NOW, lcg(seed))
					expect(circles[1].kind ~= "double").to.equal(true)
					for i, circle in circles do
						if circle.kind == "double" and circle.half == 1 then
							local second = circles[i + 1]
							expect(second.kind).to.equal("double")
							expect(second.half).to.equal(2)
							expect(second.startsAt - circle.startsAt).to.be.near(0.35, 1e-9)
							expect(second.shrinkSeconds).to.equal(circle.shrinkSeconds)
							expect(second.x == circle.x and second.y == circle.y).to.equal(true)
						end
					end
				end
			end
		)

		it("a paw ring comes after the second ring and never twice in a row", function()
			expect(Config.PawRingChance).to.be.near(1 / 6, 1e-12)
			for seed = 1, 200 do
				local circles = Circles.schedule("Legendary", 0, NOW, lcg(seed))
				local ring = 0
				for i, circle in circles do
					if circle.half ~= 2 then
						ring += 1
					end
					if circle.kind == "paw" then
						expect(ring > 2).to.equal(true)
						expect(circles[i - 1].kind ~= "paw").to.equal(true)
					end
				end
			end
		end)

		it("the twists roll at about their chances", function()
			local rings, doubles = 0, 0
			for seed = 1, 400 do
				local circles = Circles.schedule("Epic", 0, NOW, lcg(seed))
				for i, circle in circles do
					if i > 1 and circle.half ~= 2 then
						rings += 1
						if circle.kind == "double" then
							doubles += 1
						end
					end
				end
			end
			-- a double needs two rings left, so the last ring is always single: a little under a quarter
			expect(doubles / rings > 0.17 and doubles / rings < 0.27).to.equal(true)
		end)

		it(
			"a paw ring left alone is judged left, +1 trust; tapped it is a Miss, -2 (7c)",
			function()
				local circles = {
					{ startsAt = NOW, shrinkSeconds = 0.6, x = 0.5, y = 0.5, kind = "paw" },
					{ startsAt = NOW + 1.6, shrinkSeconds = 0.6, x = 0.5, y = 0.5, kind = "paw" },
				} :: { any }
				local windows = Circles.windows(0)
				local left = Circles.newAttempt(circles, windows, Circles.trustFor("Legendary"))
				expect(Circles.expire(left, Circles.deadline(circles[1], windows) + 0.01)).to.equal(
					1
				)
				expect(left.grades[1]).to.equal("left")
				expect(left.trust).to.equal(Config.TrustStart + Config.TrustPawLeft)
				expect(Circles.trustDelta("left")).to.equal(1)
				local tapped = Circles.newAttempt(circles, windows, Circles.trustFor("Legendary"))
				local at = Circles.target(circles[1])
				expect(Circles.press(tapped, 1, at, at)).to.equal("miss")
				expect(tapped.trust).to.equal(Config.TrustStart + Config.TrustMiss)
			end
		)

		it("a paw ring left alone keeps a PURRFECT; a tapped one does not (7d)", function()
			local circles = {} :: { any }
			for i = 1, 7 do
				table.insert(circles, {
					startsAt = NOW + (i - 1) * 2,
					shrinkSeconds = 0.6,
					x = 0.5,
					y = 0.5,
					kind = if i == 3 then "paw" else "single",
				})
			end
			local windows = Circles.windows(0)
			local attempt = Circles.newAttempt(circles, windows, Circles.trustFor("Legendary"))
			for i, circle in circles do
				if circle.kind ~= "paw" then
					local at = Circles.target(circle)
					Circles.press(attempt, i, at, at)
				end
			end
			-- 2 + 2 + 2 + 1 (left) + 2 x 3 = 13 after six, then 15 on the seventh: caught
			expect(attempt.grades[3]).to.equal("left")
			expect(Circles.succeeded(attempt)).to.equal(true)
			expect(Circles.finish(attempt)).to.equal("purrfect")
		end)

		it(
			"a press for a double's second half judges an unpressed first half once its Good band is past",
			function()
				local circles = {
					{
						startsAt = NOW,
						shrinkSeconds = 0.6,
						x = 0.5,
						y = 0.5,
						kind = "double",
						half = 1,
					},
					{
						startsAt = NOW + 0.18,
						shrinkSeconds = 0.6,
						x = 0.5,
						y = 0.5,
						kind = "double",
						half = 2,
					},
					{ startsAt = NOW + 2, shrinkSeconds = 0.6, x = 0.5, y = 0.5, kind = "single" },
				} :: { any }
				local windows = Circles.windows(0)
				local attempt = Circles.newAttempt(circles, windows, Circles.trustFor("Epic"))
				-- too soon: half 1 could still be hit
				local soon = Circles.target(circles[1]) + 0.05
				expect(Circles.press(attempt, 2, soon, soon)).never.to.be.ok()
				expect(attempt.nextIndex).to.equal(1)
				-- on half 2's target, before half 1's deadline (which allows for ping): half 1 a Miss, half 2 Perfect
				local at = Circles.target(circles[2])
				expect(at < Circles.deadline(circles[1], windows)).to.equal(true)
				expect(Circles.press(attempt, 2, at, at)).to.equal("perfect")
				expect(attempt.grades[1]).to.equal("miss")
				expect(attempt.trust).to.equal(
					Config.TrustStart + Config.TrustMiss + Config.TrustPerfect
				)
			end
		)

		it(
			"a paw ring uses none of the ring cap, so no schedule is ever short of rings (7f check 7)",
			function()
				for _, rarity in ipairs(Catalog.rarityOrder) do
					for seed = 1, 100 do
						local circles = Circles.schedule(rarity, 0, NOW, lcg(seed))
						expect(used(circles)).to.equal(Circles.ringCap(rarity))
						-- all Perfect, paw rings left alone, always fills the bar
						local attempt = Circles.newAttempt(
							circles,
							Circles.windows(0),
							Circles.trustFor(rarity)
						)
						for i, circle in circles do
							if Circles.isDone(attempt) then
								break
							end
							if circle.kind ~= "paw" then
								local at = Circles.target(circle)
								Circles.press(attempt, i, at, at)
							end
						end
						Circles.expire(attempt, Circles.endsAt(circles, Circles.windows(0)) + 1)
						expect(Circles.finish(attempt)).to.equal("purrfect")
					end
				end
			end
		)
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

		it(
			"clears only on a full window at or below 85% Perfect, never a partial one (v0.4, reviewer N46)",
			function()
				expect(Circles.AUTO_PRESS_CLEAR_RATE).to.be.near(0.85, 1e-9)
				expect(Circles.AUTO_PRESS_RATE).to.equal(Config.AutoPressFlagRate)
				expect(Circles.AUTO_PRESS_CLEAR_RATE).to.equal(Config.AutoPressClearRate)
				local function history(perfect: number, total: number): { boolean }
					local out = {}
					for i = 1, total do
						table.insert(out, i <= perfect)
					end
					return out
				end
				expect(Circles.looksHonest(history(0, 49))).to.equal(false) -- a rejoin's short history
				expect(Circles.looksHonest(history(0, 50))).to.equal(true)
				expect(Circles.looksHonest(history(42, 50))).to.equal(true) -- 84%
				expect(Circles.looksHonest(history(43, 50))).to.equal(false) -- 86%
				expect(Circles.looksHonest(history(85, 100))).to.equal(true) -- exactly 85%
				expect(Circles.looksHonest({})).to.equal(false)
			end
		)

		it("between 85% and 95% Perfect the flag neither sets nor clears", function()
			local history = {}
			for i = 1, 50 do
				table.insert(history, i <= 45)
			end
			expect(Circles.looksScripted(history)).to.equal(false)
			expect(Circles.looksHonest(history)).to.equal(false)
		end)
	end)

	describe("the first missed ring for catch_circles (#2913)", function()
		it("reads early, late or no press from the first Miss, nil with none", function()
			local windows = Circles.windowsFor(0, "Common")
			local function attemptOf(): any
				return Circles.newAttempt(Circles.tutorialSchedule(NOW, constant(0.5)), windows)
			end
			local early = attemptOf()
			local target = Circles.target(early.circles[1])
			expect(Circles.firstMiss(early)).never.to.be.ok() -- nothing judged yet
			local tooSoon = target - windows.good - 0.05
			expect(Circles.press(early, 1, tooSoon, tooSoon)).to.equal("miss")
			expect(Circles.firstMiss(early)).to.equal("missed_early")
			local late = attemptOf()
			local tooLate = target + windows.good + 0.05
			expect(Circles.press(late, 1, tooLate, tooLate)).to.equal("miss")
			expect(Circles.firstMiss(late)).to.equal("missed_late")
			local none = attemptOf()
			Circles.expire(none, Circles.deadline(none.circles[1], windows) + 1)
			expect(none.grades[1]).to.equal("miss")
			expect(Circles.firstMiss(none)).to.equal("missed_none")
			local hit = attemptOf()
			expect(Circles.press(hit, 1, target, target)).to.equal("perfect")
			expect(Circles.firstMiss(hit)).never.to.be.ok()
		end)
	end)
	-- #3062: the Cat Arcade's Circle Streak (shared/Arcade), the catch's circles with no stray. Here, not in a spec
	-- file of its own, since the cloud checker holds a fixed number of spec files.
	describe("the Cat Arcade's Circle Streak (#3062)", function()
		local Arcade = require(Shared.Arcade)
		local DAY = 86400
		local NOW = 20400 * DAY + 3600 -- 1 a.m. UTC on a day

		it(
			"pays fish, foods, crates and a potion every 10 points, much more from 60 (2026-11-13), nothing sold",
			function()
				local list = Arcade.milestones()
				expect(#list).to.equal(10)
				local fish = 0
				for i, m in list do
					expect(m.at).to.equal(i * 10)
					expect(type(m.name)).to.equal("string")
					fish += m.prize.fish or 0
					expect(m.prize.coins).to.equal(nil) -- the arcade pays no coins
				end
				expect(fish).to.equal(238) -- Derek 2026-11-13: bigger from 60 (58 before); under TradeFishPerDay
				expect(fish < Config.TradeFishPerDay).to.equal(true)
				expect(assert(Arcade.milestoneAt(10)).prize.fish).to.equal(5) -- Derek2 17:41
				expect(assert(assert(Arcade.milestoneAt(60)).prize.crates).classic_golden_crate).to.equal(
					1
				)
				expect(Config.ArcadeCostFish).to.equal(1)
			end
		)

		it("scores Perfect +2 and Good +1, a Miss nothing, clamped at 100", function()
			expect(Arcade.add(0, "perfect")).to.equal(2)
			expect(Arcade.add(0, "good")).to.equal(1)
			expect(Arcade.add(5, "miss")).to.equal(5)
			expect(Arcade.add(99, "perfect")).to.equal(100)
		end)

		it("steps every 5 points, stopping at the 20th (100 points) (#3359)", function()
			expect(Arcade.step(0)).to.equal(0)
			expect(Arcade.step(4)).to.equal(0)
			expect(Arcade.step(5)).to.equal(1)
			expect(Arcade.step(57)).to.equal(11)
			expect(Arcade.step(99)).to.equal(19)
			expect(Arcade.step(100)).to.equal(20)
			expect(Arcade.step(500)).to.equal(20)
		end)

		it(
			"starts at twice a Common's pace with its windows and keeps getting harder (#3359)",
			function()
				local start = Arcade.windows(0)
				local common = Circles.windowsFor(1, "Common")
				expect(start.perfect).to.be.near(common.perfect, 1e-9)
				expect(start.good).to.be.near(common.good, 1e-9)
				expect(Arcade.shrink(0)).to.be.near(Catalog.rarities.Common.shrinkSeconds / 2, 1e-9)
				expect(Arcade.shrink(6)).to.be.near(0.60 * 0.96 ^ 6, 1e-9) -- about 0.47 s at 30 points
				expect(Arcade.shrink(20) / Arcade.shrink(0)).to.be.near(0.96 ^ 20, 1e-9) -- about 0.44
				expect(Arcade.windows(20).good / start.good).to.be.near(0.97 ^ 20, 1e-9)
				expect(Arcade.gap(0)).to.be.near(Config.CircleGapMax, 1e-9)
				expect(Arcade.gap(Arcade.MAX_STEP)).to.be.near(Config.CircleGapMin, 1e-9)
				expect(Arcade.jitter(0)).to.be.near(Config.CircleJitter, 1e-9)
				expect(Arcade.jitter(Arcade.MAX_STEP)).to.be.near(Config.ArcadeJitterMax, 1e-9)
				for step = 1, Arcade.MAX_STEP do
					expect(Arcade.shrink(step) < Arcade.shrink(step - 1)).to.equal(true)
					expect(Arcade.windows(step).perfect < Arcade.windows(step - 1).perfect).to.equal(
						true
					)
				end
			end
		)

		it(
			"builds blocks of 10 on screen, never close enough for a late press to land on the next (S24)",
			function()
				local roll = lcg(7)
				for step = 0, Arcade.MAX_STEP do
					local circles = Arcade.block(step, 1000, roll)
					expect(#circles).to.equal(Arcade.BLOCK)
					expect(circles[1].startsAt).to.equal(1000)
					local windows = Arcade.windows(step)
					for i, circle in circles do
						expect(circle.kind).to.equal("single")
						expect(circle.x >= 0.25 and circle.x <= 0.75).to.equal(true)
						expect(circle.y >= 0.3 and circle.y <= 0.7).to.equal(true)
						-- #3359: never under the floor, else within the step's wobble
						expect(circle.shrinkSeconds >= Config.ArcadeShrinkFloorSeconds).to.equal(
							true
						)
						if circle.shrinkSeconds > Config.ArcadeShrinkFloorSeconds then
							local wobble = circle.shrinkSeconds / Arcade.shrink(step) - 1
							expect(math.abs(wobble) <= Arcade.jitter(step) + 1e-9).to.equal(true)
						end
						local nextOne = circles[i + 1]
						if nextOne ~= nil then
							local gap = nextOne.startsAt - Circles.target(circle)
							expect(gap).to.be.near(Arcade.gap(step), 1e-9)
							expect(gap > windows.good + Config.CatchLatencyCapSeconds).to.equal(
								true
							)
						end
					end
				end
			end
		)

		it(
			"plays a whole block through the catch's judge: all Perfect is 20 points, a Miss ends it",
			function()
				local circles = Arcade.block(0, 1000, lcg(3))
				local attempt = Circles.newAttempt(circles, Arcade.windows(0))
				local points = 0
				for i, circle in circles do
					local grade =
						Circles.press(attempt, i, Circles.target(circle), Circles.target(circle))
					points = Arcade.add(points, grade :: any)
				end
				expect(points).to.equal(20)
				expect(Circles.isDone(attempt)).to.equal(true)
				expect(attempt.missed).to.equal(false)
				local second = Circles.newAttempt(Arcade.block(2, 2000, lcg(4)), Arcade.windows(2))
				local late = Circles.target(second.circles[1]) + Arcade.windows(2).good + 0.01
				expect(Circles.press(second, 1, late, late)).to.equal("miss")
				expect(Circles.isDone(second)).to.equal(true)
				expect(second.missed).to.equal(true)
			end
		)

		it("pays a milestone a +2 skips over, and each one once per UTC day", function()
			expect(Arcade.crossed(9, 11) :: any).to.deepEqual({ 10 })
			expect(Arcade.crossed(10, 11) :: any).to.deepEqual({})
			expect(Arcade.crossed(0, 100) :: any).to.deepEqual({
				10,
				20,
				30,
				40,
				50,
				60,
				70,
				80,
				90,
				100,
			})
			local save = Arcade.fresh()
			expect(Arcade.claim(save, 0, 21, NOW) :: any).to.deepEqual({ 10, 20 })
			expect(Arcade.claim(save, 0, 31, NOW + 60) :: any).to.deepEqual({ 30 })
			expect(Arcade.claim(save, 0, 31, NOW + 120) :: any).to.deepEqual({})
			-- the next UTC day pays them again
			expect(Arcade.claim(save, 0, 12, NOW + DAY) :: any).to.deepEqual({ 10 })
			expect(save.paid :: any).to.deepEqual({ 10 })
		end)

		local EPOCH = Arcade.BOARD_EPOCH -- #3378: a best counts only with the board's epoch

		it("reads a save back safely, and yesterday's milestones are open again", function()
			local junk = Arcade.sanitize({
				best = 250,
				bestCircles = -3,
				paid = { 10, 15, "x", 10 },
				day = 20400,
				epoch = EPOCH,
			}, NOW)
			expect(junk.best).to.equal(100)
			expect(junk.bestCircles).to.equal(0)
			expect(junk.paid :: any).to.deepEqual({ 10 })
			expect(
				Arcade.sanitize({ paid = { 10, 20 }, day = 20399, legend = true }, NOW).paid :: any
			).to.deepEqual({})
			expect(Arcade.sanitize({ legend = true }, NOW).legend).to.equal(true)
			expect(Arcade.sanitize("nope", NOW) :: any).to.deepEqual(Arcade.fresh() :: any)
		end)

		it(
			"joins a late write with the stored save, so a server hop can't pay a milestone twice (#3251 review)",
			function()
				local stored = Arcade.sanitize({
					best = 40,
					bestCircles = 30,
					epoch = EPOCH,
					day = 20400,
					paid = { 10, 20 },
					legend = false,
					runs = 6,
				}, NOW)
				local mine = Arcade.sanitize({
					best = 40,
					bestCircles = 28,
					epoch = EPOCH,
					day = 20400,
					paid = { 10, 30 },
					legend = true,
					runs = 4,
				}, NOW)
				local joined = Arcade.merge(stored, mine)
				expect(joined.paid :: any).to.deepEqual({ 10, 20, 30 })
				expect(joined.best).to.equal(40)
				expect(joined.bestCircles).to.equal(28)
				expect(joined.runs).to.equal(6)
				expect(joined.legend).to.equal(true)
				-- a higher best wins whatever its circles; yesterday's paid list is left out
				local old = Arcade.fresh()
				old.best, old.bestCircles, old.day, old.paid = 52, 60, 20399, { 10, 20, 30, 40, 50 }
				local new = Arcade.merge(old, mine)
				expect(new.best).to.equal(52)
				expect(new.bestCircles).to.equal(60)
				expect(new.paid :: any).to.deepEqual({ 10, 30 })
			end
		)

		it(
			"ranks records by points, then fewest circles, and 100 earns the title for good",
			function()
				expect(Arcade.score(100, 58)).to.equal(100941)
				expect(Arcade.beats(100, 58, 100, 60)).to.equal(true)
				expect(Arcade.beats(100, 60, 100, 58)).to.equal(false)
				expect(Arcade.beats(37, 30, 0, 0)).to.equal(true)
				expect(Arcade.beats(0, 1, 0, 0)).to.equal(false)
				local save = Arcade.fresh()
				expect(Arcade.record(save, 37, 30)).to.equal(true)
				expect(Arcade.record(save, 20, 15)).to.equal(false)
				expect(save.best).to.equal(37)
				expect(save.legend).to.equal(false)
				expect(Arcade.record(save, 100, 58)).to.equal(true)
				expect(save.legend).to.equal(true)
				expect(save.runs).to.equal(3)
			end
		)

		it("words the card and why a game can't start", function()
			expect(Arcade.words(37, 30)).to.equal("37")
			expect(Arcade.words(100, 58)).to.equal("100 in 58 circles")
			local line = Arcade.cardLine({
				points = 37,
				circles = 30,
				win = false,
				best = 52,
				bestCircles = 40,
				newBest = false,
				serverBest = 61,
				serverCircles = 45,
				serverName = "Sam",
				paid = {},
				today = {},
				legend = false,
			})
			expect(line).to.equal("Score 37 · Best 52 · Server best 61 (Sam)")
			expect(Arcade.startBlocker(5, nil, false, true)).to.equal(nil)
			expect(Arcade.startBlocker(0, nil, false, true)).to.equal(
				"You need 1 golden fish 🐟 to play"
			)
			expect(Arcade.startBlocker(5, "Finish this catch first", false, true)).to.equal(
				"Finish this catch first"
			)
			expect(Arcade.startBlocker(5, nil, true, true)).to.equal("Finish this game first")
			expect(type(Arcade.startBlocker(5, nil, false, false))).to.equal("string")
		end)

		it("gives one free game each UTC day (#3296)", function()
			local save = Arcade.fresh()
			expect(Arcade.freeToday(save, NOW)).to.equal(true)
			expect(Arcade.startBlocker(0, nil, false, true, true)).to.equal(nil)
			expect(Arcade.playText(true)).to.equal("Play (free)")
			expect(Arcade.playText(false)).to.equal("Play (1 🐟)")
			expect(Arcade.useFree(save, NOW)).to.equal(true)
			expect(Arcade.freeToday(save, NOW)).to.equal(false)
			expect(Arcade.useFree(save, NOW)).to.equal(false)
			expect(Arcade.startBlocker(0, nil, false, true, false)).to.equal(
				"You need 1 golden fish 🐟 to play"
			)
			-- the next UTC day it's back
			expect(Arcade.freeToday(save, NOW + Arcade.DAY_SECONDS)).to.equal(true)
			-- kept through a save read and a join with another server's older save
			local read = Arcade.sanitize(save, NOW)
			expect(read.freeDay).to.equal(Arcade.day(NOW))
			local joined = Arcade.merge(Arcade.fresh(), read)
			expect(Arcade.freeToday(joined, NOW)).to.equal(false)
			expect(Arcade.freeToday(Arcade.merge(read, Arcade.fresh()), NOW)).to.equal(false)
			expect(Arcade.sanitize({ freeDay = "x" }, NOW).freeDay).to.equal(0)
		end)
	end)

	describe("Circles.earlyScale (#2913 follow-up)", function()
		it("widens a new player's first catches by hand, then stops", function()
			expect(Circles.earlyScale(0)).to.equal(Config.EarlyCatchWindowScale)
			expect(Circles.earlyScale(Config.EarlyCatchCount - 1)).to.equal(
				Config.EarlyCatchWindowScale
			)
			expect(Circles.earlyScale(Config.EarlyCatchCount)).to.equal(1)
			expect(Circles.earlyScale(500)).to.equal(1)
			expect(Config.EarlyCatchWindowScale > 1 and Config.EarlyCatchWindowScale <= 1.5).to.equal(
				true
			)
		end)

		it("scales both bands", function()
			local w = Circles.scaled({ perfect = 0.05, good = 0.1 }, 1.3)
			expect(math.abs(w.perfect - 0.065) < 1e-9).to.equal(true)
			expect(math.abs(w.good - 0.13) < 1e-9).to.equal(true)
		end)
	end)
end
