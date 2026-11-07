--!strict
-- The busy-server load check (#1935, docs/playtests/2026-11-07-release-gate.md section 4), pure: a full server's
-- worth of the heaviest saves, run through the work the server does for them every second for a simulated hour.
-- Caps (Gameplay-Engineer): a server holds PLAYERS players, one per cafe plot (Config.World.PlotCount); each save
-- holds CATS owned cats (there is no hard cap, so this is far past any real save), every cat in the Index, every
-- decor piece and Tier 5 with every job slot filled; each area holds at most Config.StrayLiveMax live strays.
-- It reports the numbers and fails only on what would hurt a live server: a save near the DataStore's 4 MB limit,
-- a second of work that takes a large share of the server's time, or a save that grows over the hour. The heap
-- change is only reported: Roblox's Luau can't force a collect, so it counts garbage too.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Badges = require(Shared.Badges)
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)

	local PLAYERS = Config.World.PlotCount
	local CATS = 500
	local HOUR = 1800 -- the gate's 30-minute simulated hour
	local NOW = 1_800_000_000
	local SAVE_LIMIT = 4_000_000 -- DataStore's limit for one key, in bytes
	local SAVE_BUDGET = 1_000_000 -- the heaviest save stays under a quarter of it
	-- the whole server's per-second work for all players: 5% of the server's time, loose enough for a slow CI runner
	local SECOND_BUDGET_MS = 50

	-- The length of `value` written as JSON (DataStore stores JSON), close enough to size a save.
	local function jsonLength(value: any): number
		local kind = type(value)
		if kind == "string" then
			return #value + 2
		elseif kind == "number" then
			return #tostring(value)
		elseif kind == "boolean" then
			return if value then 4 else 5
		elseif kind == "table" then
			local length = 2
			local first = true
			for key, item in value do
				if not first then
					length += 1
				end
				first = false
				length += #tostring(key) + 3 + jsonLength(item)
			end
			return length
		end
		return 4 -- null
	end

	-- The heaviest save: Tier 5, every Index cat in every coat, every decor piece, CATS owned cats on every slot.
	local function heaviest(index: number): any
		local profile: any = ProfileSchema.template(NOW)
		profile.tier = 5
		profile.coins = 1e15
		profile.lifetimeCoins = 1e16
		for _, def in Catalog.cats do
			profile.collection[def.id] = NOW
			profile.goldCollection[def.id] = NOW
			profile.rainbowCollection[def.id] = NOW
		end
		for id in Catalog.decorById do
			profile.decorOwned[id] = true
			profile.decorUnlocked[id] = true
		end
		profile.cats = {}
		for n = 1, CATS do
			local def = Catalog.cats[(n + index) % #Catalog.cats + 1]
			local uid = string.format("p%d-cat-%04d", index, n)
			local cat: any = CatStats.newInstance(uid, def.id, NOW - n, 50 + n % 50)
			cat.level = Config.CatMaxLevel
			cat.variant = if n % 3 == 0 then "gold" elseif n % 5 == 0 then "rainbow" else "base"
			cat.name = "Whiskers the " .. tostring(n)
			cat.method = "net"
			cat.locked = true
			profile.cats[uid] = cat
		end
		local spot = 0
		for _, cat in profile.cats do
			spot += 1
			if spot > #Catalog.spots then
				break
			end
			cat.spotId = Catalog.spots[spot].id
		end
		profile.stats.grabsSucceeded = 100000
		profile.stats.trades = 500
		profile.lastTick = NOW
		return profile
	end

	local profiles: { any } = {}
	for index = 1, PLAYERS do
		table.insert(profiles, heaviest(index))
	end

	-- One second of the server's per-player work: settle income and XP, and check the badges.
	local function second(now: number)
		for _, profile in profiles do
			Economy.settle(profile, now, NOW)
			Economy.incomePerSecond(profile)
			Badges.due(profile, {}, {}, now)
		end
	end

	it("names the caps: a full server and the heaviest save", function()
		local decorCount = 0
		for _ in Catalog.decorById do
			decorCount += 1
		end
		expect(PLAYERS).to.equal(8)
		expect(Config.StrayLiveMax).to.equal(16)
		expect(ProfileSchema.catCount(profiles[1])).to.equal(CATS)
		print(
			string.format(
				"[Stress] %d players, %d owned cats a save, %d Index cats, %d decor pieces, %d areas of at most %d strays",
				PLAYERS,
				CATS,
				#Catalog.cats,
				decorCount,
				#Catalog.areas,
				Config.StrayLiveMax
			)
		)
	end)

	it("keeps the heaviest save far under the DataStore limit, through a save and load", function()
		local size = jsonLength(profiles[1])
		local loaded = ProfileSchema.migrate(profiles[1], NOW)
		local after = jsonLength(loaded)
		print(
			string.format(
				"[Stress] heaviest save %.0f KB (%.0f KB after a load), limit %.0f KB",
				size / 1024,
				after / 1024,
				SAVE_LIMIT / 1024
			)
		)
		expect(size < SAVE_BUDGET).to.equal(true)
		expect(after < SAVE_BUDGET).to.equal(true)
		expect(ProfileSchema.catCount(loaded)).to.equal(CATS)
	end)

	it(
		"runs a simulated half hour of a full server inside the budget, with no save growth",
		function()
			second(NOW + 1) -- warm up
			local sizes: { number } = {}
			for i, profile in profiles do
				sizes[i] = jsonLength(profile)
			end
			local before = gcinfo()
			local started = os.clock()
			local slowest = 0
			for t = 2, HOUR do
				local tickStart = os.clock()
				second(NOW + t)
				slowest = math.max(slowest, os.clock() - tickStart)
			end
			local average = (os.clock() - started) / (HOUR - 1)
			local growth = gcinfo() - before
			local saveGrowth = 0
			for i, profile in profiles do
				saveGrowth = math.max(saveGrowth, jsonLength(profile) - sizes[i])
			end
			print(
				string.format(
					"[Stress] one second of %d players: %.2f ms average, %.2f ms slowest; heap %+.0f KB (garbage included) and the largest save %+d bytes over the half hour",
					PLAYERS,
					average * 1000,
					slowest * 1000,
					growth,
					saveGrowth
				)
			)
			expect(average * 1000 < SECOND_BUDGET_MS).to.equal(true)
			expect(saveGrowth < 1024).to.equal(true) -- an hour of play adds nothing that grows without end
			for _, profile in profiles do
				expect(profile.coins > 1e15).to.equal(true) -- the hour paid
			end
		end
	)
end
