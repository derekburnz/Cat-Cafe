--!strict
-- #2116 save safety drill, part 1: a save written by any older version from 3 up loads with nothing lost. One full
-- save (cats, decor, money, the Index, quests' claims, achievements, settings, store receipts and the Thank You
-- board choice) is labelled with each older version in turn and migrated; what the player owns must come through
-- unchanged, and migrating twice must change nothing more. Versions 1 and 2 have their own refund specs
-- (ProfileSchema.spec), since 2 to 3 reprices upgrades on purpose.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = 1_800_000_000

	local function copy(value: any): any
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for k, v in value do
			out[k] = copy(v)
		end
		return out
	end

	local function keys(t: { [string]: any }): { string }
		local out = {}
		for k in t do
			table.insert(out, k)
		end
		table.sort(out)
		return out
	end

	-- A well played save at the current version: everything the drill checks is filled in.
	local function fullSave(): any
		local save: any = ProfileSchema.template(NOW - 86400 * 30)
		save.coins = 1_234_567
		save.lifetimeCoins = 98_765_432
		save.goldenFish = 321
		save.lifetimeGoldenFish = 999
		save.tier = 3
		save.lastSeen = NOW - 3600
		save.lastTick = NOW - 3600
		-- cats: the starter and two more, one of them gold
		local starterUid = next(save.cats)
		local starter = save.cats[starterUid]
		local added = 0
		for _, def in Catalog.cats do
			if added >= 2 then
				break
			end
			if def.id ~= starter.catId then
				added += 1
				local cat = copy(starter)
				cat.uid = "drill_" .. added
				cat.catId = def.id
				cat.spotId = nil
				if added == 2 then
					cat.variant = "gold"
				end
				save.cats[cat.uid] = cat
				save.collection[def.id] = NOW - 86400 * added
			end
		end
		-- decor: two shop pieces owned, one out
		save.decorOwned[Catalog.decor[1].id] = true
		save.decorOwned[Catalog.decor[2].id] = true
		save.decorPlaced[Catalog.decor[1].id] = true
		-- an achievement claimed, the stats behind badges, a setting changed, store receipts and the credit choice
		save.achievements[Catalog.achievements[1].id] = true
		save.stats.sessions = 42
		save.stats.playtimeSeconds = 36_000
		save.settings.sessionRecap = false
		save.receipts = { "receipt_a", "receipt_b" }
		save.hideCredit = true
		return save
	end

	-- What the player owns, in a form two saves can be compared by.
	local function owned(profile: any): { [string]: any }
		local cats = {}
		for uid, cat in profile.cats do
			cats[uid] = cat.catId .. "/" .. tostring(cat.variant)
		end
		return {
			coins = profile.coins,
			lifetimeCoins = profile.lifetimeCoins,
			goldenFish = profile.goldenFish,
			lifetimeGoldenFish = profile.lifetimeGoldenFish,
			tier = profile.tier,
			cats = cats,
			collection = keys(profile.collection),
			decorOwned = keys(profile.decorOwned),
			decorPlaced = keys(profile.decorPlaced),
			achievements = keys(profile.achievements),
			sessions = profile.stats.sessions,
			playtime = profile.stats.playtimeSeconds,
			sessionRecap = profile.settings.sessionRecap,
		}
	end

	describe("save safety drill (#2116)", function()
		it("loads a save from every version from 3 to the current one with nothing lost", function()
			local want = owned(ProfileSchema.migrate(fullSave(), NOW))
			for version = 3, ProfileSchema.VERSION do
				local save = fullSave()
				save.version = version
				local got = owned(ProfileSchema.migrate(save, NOW))
				for field, value in want do
					local ok, err = pcall(function()
						expect(got[field]).to.deepEqual(value)
					end)
					if not ok then
						error(
							string.format("version %d lost %s: %s", version, field, tostring(err))
						)
					end
				end
			end
		end)

		it(
			"keeps the store receipts and the Thank You board choice from the versions that have them",
			function()
				local migrated: any = ProfileSchema.migrate(fullSave(), NOW)
				expect(migrated.receipts).to.deepEqual({ "receipt_a", "receipt_b" })
				expect(migrated.hideCredit).to.equal(true)
			end
		)

		it(
			"is the current version after migrating, and a second migration changes nothing",
			function()
				for version = 3, ProfileSchema.VERSION do
					local save = fullSave()
					save.version = version
					local once = ProfileSchema.migrate(save, NOW)
					expect(once.version).to.equal(ProfileSchema.VERSION)
					local twice = ProfileSchema.migrate(copy(once), NOW)
					expect(twice).to.deepEqual(once)
				end
			end
		)

		it("never loads a damaged save as an empty one when parts of it are good", function()
			local save = fullSave()
			save.cats["broken"] = "not a cat"
			save.decorOwned[123] = true
			save.coins = "lots"
			local migrated: any = ProfileSchema.migrate(save, NOW)
			expect(migrated.cats.broken).to.equal(nil)
			expect(#keys(migrated.cats)).to.equal(3)
			expect(migrated.decorOwned[Catalog.decor[2].id]).to.equal(true)
			expect(migrated.lifetimeCoins).to.equal(98_765_432)
		end)
	end)
end
