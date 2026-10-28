--!strict
-- QA (F35, v3.1 nooks, F81 deep spots and the Great Oak's top): whole sunrise waves on the real layout, placed the
-- way CatService.spawnWave places them: the wave rolled, the rarest first, each stray through Catching.spawnPool
-- and Catching.spreadPick with the strays already standing in the area (a cat let go at night keeps its point).
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local Layout = require(ServerScriptService.Server.World.Layout)

	local KEEP: { [string]: boolean } = { nook = true, deep = true }

	type Placed = { rarity: string, point: number }

	local function rank(rarity: string): number
		return Catalog.rarityRank[rarity]
	end

	-- the zones of an area's points, and whether it has any nook or deep ones
	local zoneCache: { [string]: { zones: { string? }, keeps: boolean } } = {}
	local function zonesOf(areaId: string): ({ string? }, boolean)
		local cached = zoneCache[areaId]
		if cached == nil then
			local zones: { string? } = {}
			local keeps = false
			for i, point in Layout.areas[areaId].spawnPoints do
				zones[i] = point.zone
				keeps = keeps or (point.zone ~= nil and KEEP[point.zone :: string] == true)
			end
			cached = { zones = zones, keeps = keeps }
			zoneCache[areaId] = cached
		end
		local entry = cached :: { zones: { string? }, keeps: boolean }
		return entry.zones, entry.keeps
	end

	-- One wave of `rarities` over `areaId` with the points in `held` taken. Each stray that finds no point is
	-- returned in `waiting` with the free points it could have used by the zone rule, which should be none.
	local function wave(
		areaId: string,
		rarities: { string },
		held: { [number]: boolean },
		rng: Random
	): ({ Placed }, { number })
		local spec = Layout.areas[areaId]
		local zones, keeps = zonesOf(areaId)
		local occupied = table.clone(held)
		local order = table.clone(rarities)
		table.sort(order, function(a, b)
			return rank(a) > rank(b)
		end)
		local placed: { Placed } = {}
		local waiting: { number } = {}
		for _, rarity in order do
			local slots: { Catching.SpawnSlot } = {}
			for i in spec.spawnPoints do
				slots[i] = { zone = zones[i], free = occupied[i] == nil }
			end
			local pool = Catching.spawnPool(slots, rarity :: any)
			local points: { Vector3 } = {}
			for _, index in pool do
				local p = spec.spawnPoints[index]
				table.insert(points, Vector3.new(p.x, p.y, p.z))
			end
			local taken: { Vector3 } = {}
			for index in occupied do
				local p = spec.spawnPoints[index]
				table.insert(taken, Vector3.new(p.x, p.y, p.z))
			end
			local pick = Catching.spreadPick(points, taken, rng:NextNumber())
			if pick ~= nil then
				local index = pool[pick]
				occupied[index] = true
				table.insert(placed, { rarity = rarity, point = index })
			else
				-- the free points the zone rule allows this stray, counted by hand
				local allowed = 0
				for i in spec.spawnPoints do
					local zone = zones[i]
					if occupied[i] ~= nil then
						continue
					end
					if zone == Catching.RARE_ZONE then
						if rank(rarity) >= rank("Rare") then
							allowed += 1
						end
					elseif rank(rarity) < rank("Epic") or not keeps or (zone ~= nil and KEEP[zone :: string]) then
						allowed += 1
					end
				end
				table.insert(waiting, allowed)
			end
		end
		return placed, waiting
	end

	local function rollWave(area: any, rng: Random, uniform: boolean): { string }
		local rarities: { string } = {}
		for _ = 1, area.waveSize do
			local rarity = if uniform
				then Catalog.rarityOrder[rng:NextInteger(1, #Catalog.rarityOrder)]
				else Catching.pickRarity(area.odds, rng:NextNumber())
			table.insert(rarities, rarity)
		end
		return rarities
	end

	-- the zone rule for one placed stray
	local function checkZone(areaId: string, placed: Placed)
		local zones, keeps = zonesOf(areaId)
		local zone = zones[placed.point]
		if zone == Catching.RARE_ZONE and rank(placed.rarity) < rank("Rare") then
			error(string.format("%s: a %s took the rare point %d", areaId, placed.rarity, placed.point))
		end
		if keeps and rank(placed.rarity) >= rank("Epic") then
			if zone == nil or (KEEP[zone :: string] ~= true and zone ~= Catching.RARE_ZONE) then
				error(string.format("%s: a %s took point %d (%s)", areaId, placed.rarity, placed.point, tostring(zone)))
			end
		end
	end

	it("a fresh sunrise places the whole wave in every area, Epic and rarer only on nook, deep or rare points", function()
		local rng = Random.new(2810)
		for _, area in Catalog.areas do
			for run = 1, 160 do
				local rarities = rollWave(area, rng, run % 2 == 0)
				local placed, waiting = wave(area.id, rarities, {}, rng)
				expect(#waiting).to.equal(0)
				expect(#placed).to.equal(area.waveSize)
				for _, entry in placed do
					checkZone(area.id, entry)
				end
			end
		end
	end)

	it("the Woods' oak top goes to the wave's rarest stray when it is Rare or better, and is left empty otherwise", function()
		local rng = Random.new(2811)
		local zones = zonesOf("woods")
		local woods = Catalog.areas[4]
		expect(woods.id).to.equal("woods")
		local filled, real, realFilled = 0, 0, 0
		for run = 1, 300 do
			local uniform = run % 2 == 0
			local rarities = rollWave(woods, rng, uniform)
			local best = 0
			for _, rarity in rarities do
				best = math.max(best, rank(rarity))
			end
			local placed = wave("woods", rarities, {}, rng)
			local onTop: string? = nil
			for _, entry in placed do
				if zones[entry.point] == Catching.RARE_ZONE then
					onTop = entry.rarity
				end
			end
			if best >= rank("Rare") then
				expect(onTop).to.be.ok()
				expect(rank(onTop :: string)).to.equal(best)
				filled += 1
			else
				expect(onTop).never.to.be.ok()
			end
			if not uniform then
				real += 1
				realFilled += if onTop ~= nil then 1 else 0
			end
		end
		expect(filled > 50).to.equal(true)
		-- town-layout-v3 8d: at the real odds about 73% of Woods waves of four hold a Rare or better up there
		expect(realFilled / real).to.be.near(1 - 0.72 ^ woods.waveSize, 0.1)
	end)

	it("with points still held from the night, a stray waits only when no point its rarity may take is free", function()
		local rng = Random.new(2812)
		local waited = 0
		for _, area in Catalog.areas do
			local count = #Layout.areas[area.id].spawnPoints
			for run = 1, 120 do
				local held: { [number]: boolean } = {}
				-- from a few held points up to all but one
				local share = rng:NextNumber()
				for i = 1, count do
					if rng:NextNumber() < share then
						held[i] = true
					end
				end
				local placed, waiting = wave(area.id, rollWave(area, rng, run % 2 == 0), held, rng)
				for _, entry in placed do
					expect(held[entry.point]).never.to.be.ok()
					checkZone(area.id, entry)
				end
				for _, allowed in waiting do
					expect(allowed).to.equal(0)
					waited += 1
				end
			end
		end
		-- the busy runs do leave some strays waiting, so the check above ran
		expect(waited > 0).to.equal(true)
	end)
end
