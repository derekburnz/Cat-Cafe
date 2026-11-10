--!strict
-- shared/SecondCat (#3022): from the first customer served until the second cat is checked in.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Onboarding = require(Shared.Onboarding)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SecondCat = require(Shared.SecondCat)

	local NOW = 1_800_000_000

	local function alleyCommon(): any
		for _, def in Catalog.cats do
			if def.area == "alley" and def.rarity == "Common" and def.exclusive ~= true then
				return def
			end
		end
		error("no alley Common")
	end

	-- a new save (the starter Tabby works barista_1) with `cats` cats checked in, the first on waiter_1 as Auto Equip
	-- places it, and the first customer served or not
	local function save(cats: number, served: boolean): any
		local profile: any = ProfileSchema.template(NOW - 3600)
		local def = alleyCommon()
		for n = 1, cats do
			local uid = "c" .. n
			profile.cats[uid] = {
				uid = uid,
				catId = def.id,
				variant = "base",
				caughtAt = NOW - 60,
				spotId = if n == 1 then "waiter_1" else nil,
				level = 1,
				xp = 0,
				charm = 50,
			}
		end
		profile.stats.catsCaught = cats
		if served then
			Onboarding.reach(profile.telemetry, "first_customer_served")
		end
		return profile
	end

	-- the same with the first catch resting, so waiter_1 is free
	local function withFreeSlot(): any
		local profile = save(1, true)
		profile.cats.c1.spotId = nil
		return profile
	end

	local function count(cats: any): number
		local n = 0
		for _ in cats do
			n += 1
		end
		return n
	end

	describe("SecondCat.waiting", function()
		it("starts at the first customer served and ends at the second cat", function()
			expect(SecondCat.waiting(save(1, false))).to.equal(false)
			expect(SecondCat.waiting(save(1, true))).to.equal(true)
			expect(SecondCat.waiting(save(2, true))).to.equal(false)
			expect(SecondCat.waiting(save(5, true))).to.equal(false)
		end)

		it("is off for a new save", function()
			expect(SecondCat.waiting(ProfileSchema.template(NOW) :: any)).to.equal(false)
			expect(SecondCat.view(ProfileSchema.template(NOW) :: any)).to.equal(nil)
		end)
	end)

	describe("SecondCat.preview", function()
		it("is the same rate twice in a new cafe, whose two Tier 1 jobs are taken", function()
			local profile = save(1, true)
			local now, with = SecondCat.preview(profile)
			expect(now).to.equal(Economy.incomePerSecond(profile))
			expect(now > 0).to.equal(true)
			expect(with).to.equal(now)
		end)

		it("is more with a second cat when a job is free", function()
			local profile = withFreeSlot()
			local now, with = SecondCat.preview(profile)
			expect(now).to.equal(Economy.incomePerSecond(profile))
			expect(with > now).to.equal(true)
		end)

		it("never promises more than a plain Common in the free job brings", function()
			local profile = withFreeSlot()
			local _, with = SecondCat.preview(profile)
			-- every alley Common, level 1 with middle charm, in Tier 1's other job earns at least that
			for _, def in Catalog.cats do
				if def.area == "alley" and def.rarity == "Common" and def.exclusive ~= true then
					local copy: any = table.clone(profile)
					copy.cats = table.clone(profile.cats)
					copy.cats.extra = {
						uid = "extra",
						catId = def.id,
						variant = "base",
						caughtAt = NOW,
						spotId = "waiter_1",
						level = 1,
						xp = 0,
						charm = 50,
					}
					expect(Economy.incomePerSecond(copy) >= with - 1e-9).to.equal(true)
				end
			end
		end)

		it("leaves the save as it was", function()
			local profile = withFreeSlot()
			local before = count(profile.cats)
			SecondCat.preview(profile)
			expect(count(profile.cats)).to.equal(before)
			expect(profile.cats.__second_cat).to.equal(nil)
		end)
	end)

	describe("SecondCat.view", function()
		it("carries the two rates and the cats so far", function()
			local profile = save(1, true)
			local view: any = SecondCat.view(profile)
			local now, with = SecondCat.preview(profile)
			expect(view.now).to.equal(now)
			expect(view.with).to.equal(with)
			expect(view.cats).to.equal(1)
			expect(view.bonus).to.equal(Catalog.rarities.Common.firstCatchReward)
			expect(view.bonus > 0).to.equal(true)
		end)

		it("is nil once the second cat is in", function()
			expect(SecondCat.view(save(2, true))).to.equal(nil)
		end)
	end)

	describe("the waiting stray", function()
		local PAD = Vector3.new(100, 3, -40)

		it("is looked for within SEARCH_STUDS of the landing, on the flat", function()
			expect(SecondCat.SEARCH_STUDS).to.equal(60)
			expect(SecondCat.inSearch(PAD + Vector3.new(59, 9, 0), PAD)).to.equal(true)
			expect(SecondCat.inSearch(PAD + Vector3.new(0, 0, -61), PAD)).to.equal(false)
		end)

		it("lets a plain Common or Rare wait, never a rarer cat or a special coat", function()
			expect(SecondCat.fits("Common", "base")).to.equal(true)
			expect(SecondCat.fits("Rare", "base")).to.equal(true)
			expect(SecondCat.fits("Epic", "base")).to.equal(false)
			expect(SecondCat.fits("Legendary", "base")).to.equal(false)
			expect(SecondCat.fits("Mythical", "base")).to.equal(false)
			expect(SecondCat.fits("Common", "gold")).to.equal(false)
			expect(SecondCat.fits("Common", "rainbow")).to.equal(false)
			expect(SecondCat.fits("Nonsense", "base")).to.equal(false)
		end)

		it(
			"keeps a near home and pulls a far one in, so a wander stays within LEASH_STUDS",
			function()
				local radius = Config.StrayWanderRadius
				local near = PAD + Vector3.new(10, 0.5, 5)
				expect(SecondCat.leash(near, PAD, radius)).to.equal(near)
				local far = PAD + Vector3.new(50, 0.5, 0)
				local home = SecondCat.leash(far, PAD, radius)
				expect(home.Y).to.equal(far.Y)
				-- the furthest corner of the wander square
				local corner = home + Vector3.new(radius, 0, radius)
				local flat = Vector3.new(corner.X - PAD.X, 0, corner.Z - PAD.Z)
				expect(flat.Magnitude <= SecondCat.LEASH_STUDS + 1e-3).to.equal(true)
				expect(home.X > PAD.X).to.equal(true) -- on the side it came from
			end
		)

		it("counts the player as following once they are near it", function()
			expect(SecondCat.followed(PAD + Vector3.new(24, 5, 0), PAD)).to.equal(true)
			expect(SecondCat.followed(PAD + Vector3.new(26, 0, 0), PAD)).to.equal(false)
		end)

		it("names its attribute and its three step_time events", function()
			expect(SecondCat.ATTRIBUTE).to.equal("WaitsFor")
			expect(SecondCat.STEPS :: any).to.deepEqual({
				"second_cat_trail_shown",
				"second_cat_trail_followed",
				"second_cat_caught",
			})
		end)
	end)
end
