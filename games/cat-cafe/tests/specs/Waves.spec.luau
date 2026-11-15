--!strict
-- QA (F35, v3.1 nooks, F81 deep spots, #2210 and the Great Oak's top): whole sunrise waves on the real layout,
-- placed the way CatService.spawnWave places them: the wave rolled, the rarest first, each stray through Catching.spawnPool
-- and Catching.spreadPick with the strays already standing in the area (a cat let go at night keeps its point).
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local Layout = require(ServerScriptService.Server.World.Layout)

	-- the zones the rarest keep to, each with the rarest it holds (#2210: deep holds Mythicals only, was Epic and up;
	-- #3170: the Alleyway's nooks no longer hold its Epic and up)
	local KEEP: { [string]: string } = { deep = "Mythical" }

	type Placed = { rarity: string, point: number }

	local function rank(rarity: string): number
		return Catalog.rarityRank[rarity]
	end

	-- whether a zone holds a stray of `rarity` to it
	local function holds(zone: string?, rarity: string): boolean
		local floor = if zone ~= nil then KEEP[zone] else nil
		return floor ~= nil and rank(rarity) >= rank(floor)
	end

	-- the zones of an area's points
	local zoneCache: { [string]: { string? } } = {}
	local function zonesOf(areaId: string): { string? }
		local cached = zoneCache[areaId]
		if cached == nil then
			local zones: { string? } = {}
			for i, point in Layout.areas[areaId].spawnPoints do
				zones[i] = point.zone
			end
			cached = zones
			zoneCache[areaId] = zones
		end
		return cached :: { string? }
	end

	-- whether the area has any point whose zone holds a stray of `rarity` to it
	local function keepsFor(areaId: string, rarity: string): boolean
		for _, zone in zonesOf(areaId) do
			if holds(zone, rarity) then
				return true
			end
		end
		return false
	end

	local vectorsOf: { [string]: { Vector3 } } = {}

	-- #4070 shared `total` runs out over however many areas there are; #4184 also gives an area of more than 100
	-- points fewer runs in step (a run costs about its points), since the Castle's 192 points ran the state out of
	-- memory at a full share. Never under 10 runs.
	local function runsFor(total: number, areaId: string): number
		local points = #Layout.areas[areaId].spawnPoints
		return math.max(10, (total // #Catalog.areas) * 100 // math.max(100, points))
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
		local zones = zonesOf(areaId)
		-- #4184: each point's Vector3 is made once an area, not once a stray; ten areas of up to 192 points ran the
		-- test state out of memory otherwise
		local vectors = vectorsOf[areaId]
		if vectors == nil then
			vectors = {}
			for i, p in spec.spawnPoints do
				vectors[i] = Vector3.new(p.x, p.y, p.z)
			end
			vectorsOf[areaId] = vectors
		end
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
				table.insert(points, vectors[index])
			end
			local taken: { Vector3 } = {}
			for index in occupied do
				table.insert(taken, vectors[index])
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
					elseif not keepsFor(areaId, rarity) or holds(zone, rarity) then
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
		local zone = zonesOf(areaId)[placed.point]
		if zone == Catching.RARE_ZONE and rank(placed.rarity) < rank("Rare") then
			error(
				string.format(
					"%s: a %s took the rare point %d",
					areaId,
					placed.rarity,
					placed.point
				)
			)
		end
		if keepsFor(areaId, placed.rarity) then
			if not holds(zone, placed.rarity) and zone ~= Catching.RARE_ZONE then
				error(
					string.format(
						"%s: a %s took point %d (%s)",
						areaId,
						placed.rarity,
						placed.point,
						tostring(zone)
					)
				)
			end
		end
	end

	it(
		"a fresh sunrise places the whole wave, Mythicals deep (#2210), the Alleyway's Epic and up anywhere (#3170)",
		function()
			local rng = Random.new(2810)
			for _, area in Catalog.areas do
				-- #2651: 110 a area over seven areas, about the 800 waves of five at 160, so the batch's memory holds;
				-- #4070: the same 770 shared out over however many areas there are, since nine at 110 ran out of it
				for run = 1, runsFor(770, area.id) do
					local rarities = rollWave(area, rng, run % 2 == 0)
					local uniform = run % 2 == 0
					local placed, waiting = wave(area.id, rarities, {}, rng)
					if uniform then
						-- #2557: an 11-stray Alleyway wave rolled with every rarity equally likely can hold more Epic
						-- and up than the area has nooks; a stray only waits when no legal point is left for it
						for _, allowed in waiting do
							expect(allowed).to.equal(0)
						end
						expect(#placed + #waiting).to.equal(area.waveSize)
					else
						expect(#waiting).to.equal(0)
						expect(#placed).to.equal(area.waveSize)
					end
					for _, entry in placed do
						checkZone(area.id, entry)
					end
				end
			end
		end
	)

	it(
		"the Woods' oak top goes to the wave's rarest stray when it is Rare or better, and is left empty otherwise",
		function()
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
			-- town-layout-v3 8d: at the real odds most Woods waves hold a Rare or better up there (#1452: Common 54%)
			expect(realFilled / real).to.be.near(
				1 - (woods.odds.Common / 100) ^ woods.waveSize,
				0.1
			)
		end
	)

	it(
		"with points still held from the night, a stray waits only when no point its rarity may take is free",
		function()
			local rng = Random.new(2812)
			local waited = 0
			for _, area in Catalog.areas do
				local count = #Layout.areas[area.id].spawnPoints
				-- #2651: about the 600 runs of five areas at 120, over seven (#4070: shared out over every area)
				for run = 1, runsFor(595, area.id) do
					local held: { [number]: boolean } = {}
					-- from a few held points up to all but one
					local share = rng:NextNumber()
					for i = 1, count do
						if rng:NextNumber() < share then
							held[i] = true
						end
					end
					local placed, waiting =
						wave(area.id, rollWave(area, rng, run % 2 == 0), held, rng)
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
		end
	)
end
