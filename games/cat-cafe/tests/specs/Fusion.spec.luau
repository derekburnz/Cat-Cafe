--!strict
-- Fusion.luau (#4104, fusion-observatory.md section 5): five copies of one cat in one coat make one in the next coat,
-- the refusals, the kept level, XP, name and trait, collect and the Index, the times and the save.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Fusion = require(Shared.Fusion)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Traits = require(Shared.Traits)

	local T = 1794787200
	local TIER = Config.FusionTier

	local function firstCat(rarity: string): string
		for _, def in Catalog.cats do
			if def.rarity == rarity and def.exclusive ~= true then
				return def.id
			end
		end
		error("no " .. rarity .. " cat")
	end
	local MYTH = firstCat("Mythical")
	local COMMON = firstCat("Common")

	local function cat(uid: string, catId: string, variant: string?, level: number?): any
		return {
			uid = uid,
			catId = catId,
			variant = variant or "base",
			level = level or 1,
			xp = 0,
			charm = 50,
		}
	end

	-- `n` copies of `catId` in `variant`, uids a1..an, levels 1..n
	local function profileWith(n: number, catId: string?, variant: string?): any
		local profile = ProfileSchema.template(T)
		profile.cats = {}
		for i = 1, n do
			local uid = "a" .. i
			profile.cats[uid] = cat(uid, catId or MYTH, variant, i)
		end
		return profile
	end

	local FIVE = { "a1", "a2", "a3", "a4", "a5" }

	describe("rules", function()
		it("makes gold from base and rainbow from gold, and nothing from rainbow", function()
			expect(Fusion.nextCoat("base")).to.equal("gold")
			expect(Fusion.nextCoat(nil)).to.equal("gold")
			expect(Fusion.nextCoat("gold")).to.equal("rainbow")
			expect(Fusion.nextCoat("rainbow")).to.equal(nil)
			expect(Fusion.COPIES).to.equal(5)
		end)

		it(
			"takes 10 minutes into gold and an hour into rainbow, 25% less with Elder Lore",
			function()
				expect(Fusion.seconds("gold")).to.equal(600)
				expect(Fusion.seconds("rainbow")).to.equal(3600)
				expect(Fusion.seconds("gold", true)).to.equal(450)
				expect(Fusion.seconds("rainbow", true)).to.equal(2700)
				local profile = profileWith(0)
				expect(Fusion.hasElderLore(profile)).to.equal(false)
				profile.dragon.slots = { "", Fusion.ELDER_LORE }
				expect(Fusion.hasElderLore(profile)).to.equal(true)
			end
		)

		it("opens at Tier 8", function()
			expect(Fusion.open(TIER - 1)).to.equal(false)
			expect(Fusion.open(TIER)).to.equal(true)
			expect(Fusion.startBlocker(profileWith(5), TIER - 1, FIVE, nil, false)).to.equal(
				Fusion.Messages.shut
			)
		end)
	end)

	describe("startBlocker (QA 3)", function()
		it("starts with exactly five free copies of one cat in one coat", function()
			expect(Fusion.startBlocker(profileWith(5), TIER, FIVE, nil, false)).to.equal(nil)
		end)

		it("refuses 4 or 6 uids and a uid twice", function()
			local profile = profileWith(6)
			expect(Fusion.startBlocker(profile, TIER, { "a1", "a2", "a3", "a4" }, nil, false)).to.equal(
				Fusion.Messages.count
			)
			expect(
				Fusion.startBlocker(
					profile,
					TIER,
					{ "a1", "a2", "a3", "a4", "a5", "a6" },
					nil,
					false
				)
			).to.equal(Fusion.Messages.count)
			expect(Fusion.startBlocker(profile, TIER, { "a1", "a2", "a3", "a4", "a4" }, nil, false)).to.equal(
				Fusion.Messages.count
			)
		end)

		it("refuses mixed cats, mixed coats and rainbow copies", function()
			local profile = profileWith(5)
			profile.cats.a5.catId = COMMON
			expect(Fusion.startBlocker(profile, TIER, FIVE, nil, false)).to.equal(
				Fusion.Messages.mixed
			)
			profile = profileWith(5)
			profile.cats.a5.variant = "gold"
			expect(Fusion.startBlocker(profile, TIER, FIVE, nil, false)).to.equal(
				Fusion.Messages.mixed
			)
			profile = profileWith(5, MYTH, "rainbow")
			expect(Fusion.startBlocker(profile, TIER, FIVE, nil, false)).to.equal(
				Fusion.Messages.top
			)
		end)

		it("refuses a locked, working, spa, pending or trading copy", function()
			local profile = profileWith(5)
			profile.cats.a2.locked = true
			expect(Fusion.startBlocker(profile, TIER, FIVE, nil, false)).to.equal(
				Fusion.Messages.locked
			)
			profile = profileWith(5)
			profile.cats.a2.spotId = "barista_1"
			expect(Fusion.startBlocker(profile, TIER, FIVE, nil, false)).to.equal(
				Fusion.Messages.working
			)
			profile = profileWith(5)
			profile.traits.pending = { uid = "a3" } :: any
			expect(Fusion.startBlocker(profile, TIER, FIVE, nil, false)).to.equal(
				Fusion.Messages.pending
			)
			profile = profileWith(5)
			expect(Fusion.startBlocker(profile, TIER, FIVE, nil, true)).to.equal(
				Fusion.Messages.inTrade
			)
		end)

		it(
			"refuses another player's or a made-up uid, and a second start while the dome is busy",
			function()
				local profile = profileWith(5)
				expect(
					Fusion.startBlocker(profile, TIER, { "a1", "a2", "a3", "a4", "zz" }, nil, false)
				).to.equal(Fusion.Messages.notOwned)
				Fusion.start(profile, FIVE, nil, T)
				for i = 6, 10 do
					profile.cats["a" .. i] = cat("a" .. i, MYTH)
				end
				expect(
					Fusion.startBlocker(
						profile,
						TIER,
						{ "a6", "a7", "a8", "a9", "a10" },
						nil,
						false
					)
				).to.equal(Fusion.Messages.busy)
			end
		)

		it("keeps a trait only from one of the five that has one", function()
			local trait = Traits.ofRarity(Traits.rarities()[1].id)[1]
			local profile = profileWith(6)
			expect(Fusion.startBlocker(profile, TIER, FIVE, "a1", false)).to.equal(
				Fusion.Messages.trait
			)
			profile.cats.a6.trait = { id = trait.id }
			expect(Fusion.startBlocker(profile, TIER, FIVE, "a6", false)).to.equal(
				Fusion.Messages.trait
			)
			profile.cats.a1.trait = { id = trait.id }
			expect(Fusion.startBlocker(profile, TIER, FIVE, "a1", false)).to.equal(nil)
		end)
	end)

	describe("start and collect (QA 1, 2, 4 and 5)", function()
		it(
			"takes the five out, keeps the best level, its XP and name, and collects one gold after 10 minutes",
			function()
				local profile = profileWith(5)
				profile.cats.a4.level = 40
				profile.cats.a4.xp = 123
				profile.cats.a4.name = "Biscuit"
				profile.goldCollection[MYTH] = nil
				expect(Fusion.start(profile, FIVE, nil, T)).to.equal("gold")
				for _, uid in FIVE do
					expect(profile.cats[uid]).to.equal(nil)
				end
				local running = profile.fusion.running :: any
				expect(running.level).to.equal(40)
				expect(running.xp).to.equal(123)
				expect(running.name).to.equal("Biscuit")
				expect(running.doneAt).to.equal(T + 600)
				expect(Fusion.collectBlocker(profile.fusion, T + 599)).to.equal(
					Fusion.Messages.notReady
				)
				expect(Fusion.collectBlocker(profile.fusion, T + 600)).to.equal(nil)
				local made, first = Fusion.collect(profile, "new1", T + 9999) -- offline time counts too
				expect(first).to.equal(true)
				expect(made.variant).to.equal("gold")
				expect(made.catId).to.equal(MYTH)
				expect(made.level).to.equal(40)
				expect(made.locked).to.equal(nil)
				expect(made.spotId).to.equal(nil)
				expect(profile.cats.new1).to.equal(made)
				expect(profile.goldCollection[MYTH]).to.equal(T + 9999)
				expect(profile.fusion.made.gold).to.equal(1)
				-- collecting twice gives one cat
				expect(Fusion.collectBlocker(profile.fusion, T + 10000)).to.equal(
					Fusion.Messages.empty
				)
			end
		)

		it("makes a rainbow from five gold after an hour, lighting its Index entry once", function()
			local profile = profileWith(5, MYTH, "gold")
			profile.rainbowCollection[MYTH] = nil
			expect(Fusion.start(profile, FIVE, nil, T)).to.equal("rainbow")
			expect((profile.fusion.running :: any).doneAt).to.equal(T + 3600)
			local _, first = Fusion.collect(profile, "r1", T + 3600)
			expect(first).to.equal(true)
			expect(profile.rainbowCollection[MYTH]).to.equal(T + 3600)
			for i = 1, 5 do
				profile.cats["b" .. i] = cat("b" .. i, MYTH, "gold")
			end
			Fusion.start(profile, { "b1", "b2", "b3", "b4", "b5" }, nil, T + 4000)
			local _, again = Fusion.collect(profile, "r2", T + 9000)
			expect(again).to.equal(false)
			expect(profile.rainbowCollection[MYTH]).to.equal(T + 3600)
			expect(profile.fusion.made.rainbow).to.equal(2)
		end)

		it("keeps the picked trait, or with none picked the rarest", function()
			local list = Traits.rarities()
			local low = Traits.ofRarity(list[1].id)[1]
			local high = Traits.ofRarity(list[#list - 1].id)[1]
			local profile = profileWith(5)
			profile.cats.a1.trait = { id = low.id }
			profile.cats.a2.trait = { id = high.id }
			Fusion.start(profile, FIVE, "a1", T)
			expect(((profile.fusion.running :: any).trait).id).to.equal(low.id)
			profile = profileWith(5)
			profile.cats.a1.trait = { id = low.id }
			profile.cats.a2.trait = { id = high.id }
			Fusion.start(profile, FIVE, nil, T)
			expect(((profile.fusion.running :: any).trait).id).to.equal(high.id)
			profile = profileWith(5)
			Fusion.start(profile, FIVE, nil, T)
			expect((profile.fusion.running :: any).trait).to.equal(nil)
		end)

		it("picks the best copy and the four weakest by default", function()
			local profile = profileWith(8) -- levels 1 to 8
			local pick = Fusion.defaultPick(profile, MYTH, "base")
			table.sort(pick)
			expect(pick).to.deepEqual({ "a1", "a2", "a3", "a4", "a8" })
			profile.cats.a1.locked = true
			pick = Fusion.defaultPick(profile, MYTH, "base")
			table.sort(pick)
			expect(pick).to.deepEqual({ "a2", "a3", "a4", "a5", "a8" })
			expect(#Fusion.defaultPick(profileWith(3), MYTH, "base")).to.equal(3)
		end)
	end)

	describe("the save", function()
		it("starts empty and keeps a good running fusion through a save round trip", function()
			local profile = ProfileSchema.template(T)
			expect(profile.fusion.running).to.equal(nil)
			expect(profile.fusion.made).to.deepEqual({ gold = 0, rainbow = 0 })
			expect(ProfileSchema.VERSION >= 50).to.equal(true)
			profile = profileWith(5)
			profile.cats.a5.name = "Biscuit"
			Fusion.start(profile, FIVE, nil, T)
			local back = ProfileSchema.migrate(profile, T + 1)
			expect(back.fusion.running).to.deepEqual(profile.fusion.running)
		end)

		it("drops a running fusion with an unknown cat, a bad coat or a doneAt too late", function()
			local good = {
				catId = MYTH,
				coat = "gold",
				startedAt = T,
				doneAt = T + 600,
				level = 3,
				xp = 1,
				charm = 50,
			}
			expect(Fusion.sanitize({ running = good }).running).never.to.equal(nil)
			local bad = table.clone(good)
			bad.catId = "nope"
			expect(Fusion.sanitize({ running = bad }).running).to.equal(nil)
			bad = table.clone(good)
			bad.coat = "base"
			expect(Fusion.sanitize({ running = bad }).running).to.equal(nil)
			bad = table.clone(good)
			bad.doneAt = T + 3601
			expect(Fusion.sanitize({ running = bad }).running).to.equal(nil)
			expect(Fusion.sanitize("junk")).to.deepEqual(Fusion.fresh())
			expect(Fusion.sanitize({ made = { gold = -4, rainbow = 2.7 } }).made).to.deepEqual({
				gold = 0,
				rainbow = 2,
			})
		end)
	end)

	describe("view", function()
		it("shows the dome, ready once done, and the times after Elder Lore", function()
			local profile = profileWith(5)
			local view = Fusion.view(profile.fusion, T, false)
			expect(view.running).to.equal(nil)
			expect(view.ready).to.equal(false)
			expect(view.goldSeconds).to.equal(600)
			Fusion.start(profile, FIVE, nil, T, true)
			view = Fusion.view(profile.fusion, T + 449, true)
			expect((view.running :: any).catId).to.equal(MYTH)
			expect(view.ready).to.equal(false)
			expect(view.goldSeconds).to.equal(450)
			expect(Fusion.view(profile.fusion, T + 450, true).ready).to.equal(true)
		end)
	end)
end
