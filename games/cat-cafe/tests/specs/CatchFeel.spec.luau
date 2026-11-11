--!strict
-- F83's feel in numbers (QA; data-model sections 10 and 10b, v0.13.15, Derek 2026-10-28 12:15: "make the catching
-- and rescue games harder"), retuned for F93 (catch-rework.md sections 2 and 4). The design gives catch and rescue
-- chances for a player whose presses land within about 50 ms (one standard deviation, ping wobble included) and a
-- shakier one at 70 ms. These checks work the same chances out from the build's own numbers: Circles.windowsFor and
-- each rarity's circles for the net, RescueMarker.inZone over the real bar's speed (faster after every hit), zone
-- width and tolerance, Rescue.hitsNeeded and RescuePatience for a rescue. A change to any of them
-- that moves a chance by more than a point fails here, so the design's tables stay true. The F93 rescue rows are the
-- build's own figures, which the designer accepted against the spec's rounder ones (2026-11-02), eased a little on
-- 2026-11-03 when zones began waiting to be hit.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Circles = require(Shared.Circles)
	local Config = require(Shared.Config)
	local Rescue = require(Shared.Rescue)
	local RescueMarker = require(Shared.RescueMarker)
	local Types = require(Shared.Types)

	local RARITIES: { Types.Rarity } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

	-- Abramowitz and Stegun 7.1.26, within 1.5e-7
	local function erf(x: number): number
		local sign = if x < 0 then -1 else 1
		x = math.abs(x)
		local t = 1 / (1 + 0.3275911 * x)
		local y = 1
			- (
					((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736)
						* t
					+ 0.254829592
				)
				* t
				* math.exp(-x * x)
		return sign * y
	end

	-- The chance a press with normal error of `spread` seconds lands within `half` seconds of the target.
	local function within(half: number, spread: number): number
		return erf(half / (spread * math.sqrt(2)))
	end

	-- Percent of tries that net a stray (#1884, catch-rework.md 7b, 7c): worked out exactly over the trust bar, from
	-- TrustStart, each press adding Circles.trustDelta of its grade, caught at trustNeed and bolting below 0 or once
	-- Circles.ringCap rings are used. With the rarity's twists, each ring after the first is a double (two presses,
	-- two rings, while two are left) at DoubleRingChance and each after the second a paw ring (left alone: +1, no
	-- ring used; never two in a row) at PawRingChance, as Circles.ringKind rolls them.
	local function catchChance(
		netLevel: number,
		rarity: Types.Rarity,
		spread: number,
		areaId: string?
	): number
		local windows = Circles.windowsFor(netLevel, rarity, areaId)
		local perfect = within(windows.perfect, spread)
		local good = within(windows.good, spread) - perfect
		local outcomes = {
			{ Circles.trustDelta("perfect"), perfect },
			{ Circles.trustDelta("good"), good },
			{ Circles.trustDelta("miss"), 1 - perfect - good },
		}
		local def = Catalog.rarities[rarity]
		local need = def.trustNeed
		local cap = Circles.ringCap(rarity)
		local caught = 0
		-- presses from `alive` (trust -> chance), catching what fills the bar and dropping what bolts
		local function pressed(alive: { [number]: number }): { [number]: number }
			local after: { [number]: number } = {}
			for trust, chance in alive do
				for _, outcome in outcomes do
					local t = trust + outcome[1]
					local p = chance * outcome[2]
					if t >= need then
						caught += p
					elseif t >= 0 then
						after[t] = (after[t] or 0) + p
					end
				end
			end
			return after
		end
		-- state key: trust, rings used and whether the last ring was a paw ring
		local states: { [string]: { trust: number, used: number, paw: boolean, chance: number } } =
			{
				start = { trust = Config.TrustStart, used = 0, paw = false, chance = 1 },
			}
		local ring = 0
		while next(states) ~= nil do
			ring += 1
			local nextStates: { [string]: { trust: number, used: number, paw: boolean, chance: number } } =
				{}
			local function add(trust: number, usedNow: number, paw: boolean, p: number)
				if usedNow >= cap and not (trust >= need) then
					return -- out of rings: a bolt
				end
				local key = string.format("%d/%d/%s", trust, usedNow, tostring(paw))
				local state = nextStates[key]
				if state == nil then
					nextStates[key] = { trust = trust, used = usedNow, paw = paw, chance = p }
				else
					state.chance += p
				end
			end
			for _, state in states do
				local pawChance = if def.pawRings
						and ring > 2
						and not state.paw
					then Config.PawRingChance
					else 0
				local doubleChance = if def.doubleRings
						and ring > 1
						and cap - state.used >= 2
					then Config.DoubleRingChance
					else 0
				local c = state.chance
				if pawChance > 0 then
					local t = state.trust + Circles.trustDelta("left")
					if t >= need then
						caught += c * pawChance
					else
						add(t, state.used, true, c * pawChance)
					end
				end
				local single = c * (1 - pawChance) * (1 - doubleChance)
				for t, p in pressed({ [state.trust] = single }) do
					add(t, state.used + 1, false, p)
				end
				local double = c * (1 - pawChance) * doubleChance
				if double > 0 then
					for t, p in pressed(pressed({ [state.trust] = double })) do
						add(t, state.used + 2, false, p)
					end
				end
			end
			states = nextStates
		end
		return 100 * caught
	end

	-- The chance one bar press is a hit, worked out on the real marker and zone: the marker crossing a zone in the
	-- middle of the bar at `speed`, the press `e` seconds off the crossing, summed over e with the normal weights.
	local function barHit(rarity: Types.Rarity, speed: number, spread: number): number
		local width = Config.RescueZoneWidth[rarity]
		local crossing = 0.5 / speed -- from the left end at phase 0
		local step = spread / 200
		local total, weight = 0, 0
		for i = -1600, 1600 do
			local e = i * step
			local w = math.exp(-(e * e) / (2 * spread * spread))
			weight += w
			local position = RescueMarker.position(0, 0, speed, crossing + e)
			if RescueMarker.inZone(position, 0.5, width, Config.RescueTolerance) then
				total += w
			end
		end
		return total / weight
	end

	-- Percent of bar attempts that free the cat (F93): hit k is pressed with the marker at RescueBarSpeed x (1 +
	-- RescueSpeedUpPerHit)^k. A zone stays until it is hit (Derek 2026-11-03), so each miss costs a paw and the player
	-- presses again on the same zone; #2327: the miss also takes one hit away (#2219 sent it back to the start). Out of
	-- paws ends it.
	local function rescueChance(rarity: Types.Rarity, spread: number): number
		local hits = Rescue.hitsNeeded(rarity, "bar")
		local p: { number } = {}
		for k = 0, hits - 1 do
			local speed = Config.RescueBarSpeed[rarity] * (1 + Config.RescueSpeedUpPerHit) ^ k
			p[k + 1] = barHit(rarity, speed, spread)
		end
		local memo: { [number]: number } = {}
		local function from(done: number, paws: number): number
			if done == hits then
				return 1
			end
			if paws <= 0 then
				return 0
			end
			local key = done * 100 + paws
			local known = memo[key]
			if known ~= nil then
				return known
			end
			local q = p[done + 1]
			-- #2327: a miss takes one hit away (the zone and speed before); with none yet it only costs the paw
			local chance = q * from(done + 1, paws)
				+ (1 - q) * from(math.max(0, done - 1), paws - 1)
			memo[key] = chance
			return chance
		end
		return 100 * from(0, Config.RescuePatience)
	end

	local function rowMatches(label: string, got: { number }, want: { number })
		for i, rarity in RARITIES do
			if math.abs(got[i] - want[i]) > 1 then
				error(
					string.format("%s %s: %.1f%%, design says %d%%", label, rarity, got[i], want[i])
				)
			end
		end
	end

	describe(
		"F83 and F93 catch and rescue feel (QA, data-model 10 and 10b, catch-rework.md)",
		function()
			-- #1884: the trust bar's figures with the twists (catch-rework.md 7b, 7c). #2005 (Derek2 2026-11-07): Perfect
			-- +3 and Good +2, and the Mythical's window 0.68, so every catch fills faster and a Basic Net Mythical at 50 ms
			-- goes from 19% to 36% a try. The second table is the target these must stay within 5 points of.
			it(
				"nets a stray as often as the design's table, every net at 50 ms and Basic and Master at 70 ms",
				function()
					-- #2317 and #2332 (Derek2: "it should fully be only failing if the heart bar hits 0"): the rings no longer
					-- run out first, so only the bar emptying ends a try (was Basic 50 ms 98, 94, 80, 55, 36 and Basic 70 ms
					-- 84, 65, 39, 18, 8)
					local rows = {
						{
							"Basic 50 ms",
							0,
							0.05,
							{ 100, 100, 100, 99, 98 },
							{ 100, 100, 100, 99, 98 },
						},
						{
							"Sturdy 50 ms",
							1,
							0.05,
							{ 100, 100, 100, 100, 99 },
							{ 100, 100, 100, 100, 99 },
						},
						{
							"Pro 50 ms",
							2,
							0.05,
							{ 100, 100, 100, 100, 100 },
							{ 100, 100, 100, 100, 100 },
						},
						{
							"Master 50 ms",
							3,
							0.05,
							{ 100, 100, 100, 100, 100 },
							{ 100, 100, 100, 100, 100 },
						},
						{ "Basic 70 ms", 0, 0.07, { 99, 99, 97, 90, 83 }, { 99, 99, 97, 90, 83 } },
						{
							"Master 70 ms",
							3,
							0.07,
							{ 100, 100, 100, 100, 99 },
							{ 100, 100, 100, 100, 99 },
						},
					}
					for _, row in rows do
						local got = {}
						for i, rarity in RARITIES do
							got[i] = catchChance(row[2] :: number, rarity, row[3] :: number)
							expect(math.abs(got[i] - (row[5] :: { number })[i]) <= 5).to.equal(true)
						end
						rowMatches(row[1] :: string, got, row[4] :: { number })
					end
				end
			)

			-- #2322 (Derek2: "lower the difficulty of catching cats from first zone a little bit so people get used to it
			-- first"): the Alleyway's bands are 1.2 times as wide, so a shaky new player (Basic Net, 70 ms) nets more
			it(
				"makes the first area's catches a little easier than the same cat elsewhere",
				function()
					local alley = {}
					for i, rarity in RARITIES do
						local here = catchChance(0, rarity, 0.07, "alley")
						local elsewhere = catchChance(0, rarity, 0.07)
						alley[i] = here
						expect(here >= elsewhere).to.equal(true)
					end
					-- elsewhere 99, 99, 97, 90, 83 (the Basic 70 ms row above)
					rowMatches("Alleyway Basic 70 ms", alley, { 100, 100, 99, 97, 94 })
				end
			)

			it(
				"keeps a new player's Common easy and makes every better net help at every rarity",
				function()
					-- the intro's catch and a new player's first five cats are Commons: one or two tries (F93: three circles, so
					-- a shaky young player on a phone needs a second try a quarter of the time)
					expect(catchChance(0, "Common", 0.05) >= 94).to.equal(true)
					expect(catchChance(0, "Common", 0.07) >= 75).to.equal(true)
					for _, rarity in RARITIES do
						for level = 1, 3 do
							expect(
								catchChance(level, rarity, 0.05)
									> catchChance(level - 1, rarity, 0.05)
							).to.equal(true)
						end
					end
					for i = 2, #RARITIES do
						expect(
							catchChance(0, RARITIES[i], 0.05)
								< catchChance(0, RARITIES[i - 1], 0.05)
						).to.equal(true)
					end
				end
			)

			it(
				"frees a stuck cat on the bar as often as the design's table, at 50 and 70 ms",
				function()
					local at50, at70 = {}, {}
					for i, rarity in RARITIES do
						at50[i] = rescueChance(rarity, 0.05)
						at70[i] = rescueChance(rarity, 0.07)
					end
					-- Derek 2026-11-03: zones wait to be hit, so a slow press no longer costs a paw (was 100, 98, 78, 36, 9 and
					-- 100, 88, 44, 11, 2 with F93's run-out). #2219: a miss sends the bar back to the start and the
					-- Mythical's zone is 0.14 (was 100, 100, 85, 41, 11 and 100, 93, 51, 13, 2)
					-- #2320 (Derek2: "lower the difficulty for rescue missions rare and lower"): a slower marker and a wider
					-- zone for Common and Rare (was 100, 99 and 100, 85)
					-- #2327 (Derek2: "instead of resetting a rescue make it go down 1 progress bar on miss"): a miss takes
					-- one hit away (was 100, 100, 69, 20, 10 and 100, 98, 29, 4, 2)
					-- #2566 (Derek2: Rare and up 30% slower): was 100, 100, 77, 29, 17 and 100, 98, 38, 7, 3
					-- #3120 (Derek2: "make the rescue area about 10->50% smaller especially for the common->epic rescues are
					-- too easy now"): zones 0.17, 0.135, 0.105, 0.105 and 0.125 (was 100, 100, 98, 73, 59 and 100, 100, 79,
					-- 31, 19)
					-- #3223 (Derek2 2026-11-11: "rescues are wayyy to easy making bar too big and speed to slow"): the marker
					-- 18% and 22% faster for Common and Rare (was 100, 100 and 99, 98)
					rowMatches("bar 50 ms", at50, { 100, 99, 87, 62, 48 })
					rowMatches("bar 70 ms", at70, { 97, 89, 51, 23, 13 })
				end
			)

			it(
				"gives a steady player time for every hit and every spare paw inside the 15 s deadline",
				function()
					for _, rarity in RARITIES do
						local presses = Rescue.hitsNeeded(rarity, "bar") + Config.RescuePatience - 1
						-- each press waits at most one trip out and back for the marker to reach its zone
						local worst = Config.CircleLeadInSeconds
							+ presses * 2 / Config.RescueBarSpeed[rarity]
						expect(worst < Config.RescueAttemptMaxSeconds).to.equal(true)
					end
				end
			)

			it(
				"judges the tree's falling cat (RescueTreeCircle) on the Pro Net times its catchWindow, one easy circle",
				function()
					-- #2332: a net catch now ends only when the bar empties, so it can beat one circle; the falling cat's
					-- circle (off since 2026-11-03) only has to stay easy
					for _, rarity in RARITIES do
						local windows = Circles.windowsFor(Rescue.CIRCLE_NET_LEVEL, rarity)
						local falling = 100 * within(windows.good, 0.05)
						expect(falling > 85).to.equal(true) -- one circle: the shakes are the hard part
					end
				end
			)
		end
	)
end
