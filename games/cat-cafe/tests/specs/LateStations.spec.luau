--!strict
-- #2651 part 4 (late-stations.md): the Oasis Spa and the Relic Museum's rules (shared/LateStations) and the guards
-- that keep a spa cat out of work, sales, trades and the Collector.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Catalog = require(Shared.Catalog)
	local Collector = require(Shared.Collector)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local EquipBest = require(Shared.EquipBest)
	local IndexRewards = require(Shared.IndexRewards)
	local LateStations = require(Shared.LateStations)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local NOW = 1_800_000_000

	local function profileAt(tier: number): Types.PlayerProfile
		local profile = ProfileSchema.template(NOW)
		profile.tier = tier
		return profile
	end

	local function add(
		profile: Types.PlayerProfile,
		uid: string,
		catId: string,
		level: number?
	): Types.CatInstance
		local instance = CatStats.newInstance(uid, catId, NOW)
		instance.level = level or 1
		profile.cats[uid] = instance
		return instance
	end

	local function roomOf(area: string): LateStations.Room
		for _, room in LateStations.rooms do
			if room.area == area then
				return room
			end
		end
		error("no room " .. area)
	end

	describe("Late stations (#2651 part 4)", function()
		it("keeps the spec's numbers", function()
			expect(Config.SpaSeconds).to.equal(3600)
			expect(#Config.SpaSlotPrices).to.equal(3)
			expect(Config.SpaSlotPrices[1]).to.equal(0)
			expect(Config.SpaSlotPrices[2]).to.equal(100)
			expect(Config.SpaSlotPrices[3]).to.equal(250)
			expect(Config.MuseumRoomTipBonus).to.equal(0.05) -- #2908: all 7 rooms give +35%
			expect(LateStations.tierOf(LateStations.SPA)).to.equal(6)
			expect(LateStations.tierOf(LateStations.MUSEUM)).to.equal(7)
		end)

		it(
			"has one room per area, each its Index cats, 80 exhibits in all (#3997: the Snowy Mountain's ten)",
			function()
				expect(#LateStations.rooms).to.equal(#Catalog.areas)
				local total = 0
				for _, room in LateStations.rooms do
					expect(#room.cats).to.equal(10)
					for _, catId in room.cats do
						local def = Catalog.getCat(catId) :: Types.CatDef
						expect(def.area).to.equal(room.area)
						expect(def.exclusive).never.to.equal(true)
					end
					total += #room.cats
				end
				expect(total).to.equal(80)
				expect(LateStations.EXHIBITS).to.equal(80)
				-- no shop, starter or spare cat has an exhibit
				for _, def in Catalog.cats do
					if def.exclusive == true or Catalog.getArea(def.area) == nil then
						expect(LateStations.exhibitArea[def.id]).to.equal(nil)
					end
				end
			end
		)

		it("starts a new save with one free slot and an empty museum", function()
			local profile = ProfileSchema.template(NOW)
			expect(profile.spa.slots).to.equal(1)
			expect(next(profile.spa.soaking)).to.equal(nil)
			expect(next(profile.museum)).to.equal(nil)
			expect(ProfileSchema.VERSION >= 46).to.equal(true) -- 46 added the slots; #2814 is 47
		end)

		it(
			"sanitizes the spa: owned cats only, once each, open slots, never a future start",
			function()
				local cats: { [string]: Types.CatInstance } = {
					a = CatStats.newInstance("a", "tabby", NOW),
					b = CatStats.newInstance("b", "tabby", NOW),
				}
				local spa = LateStations.sanitizeSpa({
					slots = 9,
					soaking = {
						["1"] = { uid = "a", at = NOW + 500 },
						["2"] = { uid = "a", at = NOW - 10 }, -- the same cat twice
						["3"] = { uid = "ghost", at = NOW - 10 },
					},
				}, cats, NOW)
				expect(spa.slots).to.equal(3)
				expect(spa.soaking["1"].uid).to.equal("a")
				expect(spa.soaking["1"].at).to.equal(NOW)
				expect(spa.soaking["2"]).to.equal(nil)
				expect(spa.soaking["3"]).to.equal(nil)
				-- a slot that is not open drops its cat
				local shut = LateStations.sanitizeSpa({
					slots = 1,
					soaking = { ["2"] = { uid = "b", at = NOW - 10 } },
				}, cats, NOW)
				expect(shut.soaking["2"]).to.equal(nil)
				expect(LateStations.sanitizeSpa("junk", cats, NOW).slots).to.equal(1)
			end
		)

		it("sanitizes the museum to known exhibits and coats", function()
			local museum = LateStations.sanitizeMuseum({
				tabby = "gold",
				tuxedo = "sparkly",
				nope = "base",
				[1] = "base",
			})
			expect(museum.tabby).to.equal("gold")
			expect(museum.tuxedo).to.equal(nil)
			expect(museum.nope).to.equal(nil)
		end)

		it("keeps the spa and museum through a migrate", function()
			local profile = profileAt(7)
			add(profile, "c1", "tabby", 12)
			LateStations.put(profile, 1, "c1", NOW - 100)
			profile.museum.tuxedo = "base"
			local again = ProfileSchema.migrate(profile, NOW)
			expect(again.spa.soaking["1"].uid).to.equal("c1")
			expect(again.spa.soaking["1"].at).to.equal(NOW - 100)
			expect(again.museum.tuxedo).to.equal("base")
		end)

		describe("Oasis Spa", function()
			it(
				"opens at Tier 6 and refuses a cat at the top level, an open trade or a taken slot",
				function()
					local profile = profileAt(5)
					add(profile, "c1", "tabby", 10)
					add(profile, "top", "tabby", Config.CatMaxLevel)
					expect(LateStations.putBlocker(profile, 5, 1, "c1", false)).to.equal(
						LateStations.Messages.spaShut
					)
					profile.tier = 6
					expect(LateStations.putBlocker(profile, 6, 1, "c1", false)).to.equal(nil)
					expect(LateStations.putBlocker(profile, 6, 1, "top", false)).to.equal(
						LateStations.Messages.maxLevel
					)
					expect(LateStations.putBlocker(profile, 6, 1, "c1", true)).to.equal(
						LateStations.Messages.inTrade
					)
					expect(LateStations.putBlocker(profile, 6, 2, "c1", false)).to.equal(
						LateStations.Messages.slotShut
					)
					expect(LateStations.putBlocker(profile, 6, 1, "someone_elses", false)).to.equal(
						LateStations.Messages.notOwned
					)
					LateStations.put(profile, 1, "c1", NOW)
					expect(LateStations.putBlocker(profile, 6, 1, "c1", false)).to.equal(
						LateStations.Messages.slotTaken
					)
				end
			)

			it("takes a working cat off its role and keeps it out of Equip Best", function()
				local profile = profileAt(6)
				local cat = add(profile, "c1", "tabby", 20)
				cat.spotId = "barista_1"
				LateStations.put(profile, 1, "c1", NOW)
				expect(cat.spotId).to.equal(nil)
				expect(CatStats.atSpa(profile, "c1")).to.equal(true)
				local plan = EquipBest.plan(profile)
				expect(plan.placements.c1).to.equal(nil)
			end)

			it(
				"gives one level after an hour, offline too, keeping the XP toward the next",
				function()
					local profile = profileAt(6)
					local cat = add(profile, "c1", "tabby", 37)
					cat.xp = 55
					LateStations.put(profile, 1, "c1", NOW)
					expect(#LateStations.collect(profile, NOW + 3599)).to.equal(0)
					expect(profile.spa.soaking["1"]).to.be.ok()
					local relaxed = LateStations.collect(profile, NOW + 3600)
					expect(#relaxed).to.equal(1)
					expect(relaxed[1].from).to.equal(37)
					expect(relaxed[1].to).to.equal(38)
					expect(cat.level).to.equal(38)
					expect(cat.xp).to.equal(55)
					expect(profile.spa.soaking["1"]).to.equal(nil)
					expect(CatStats.atSpa(profile, "c1")).to.equal(false)
					-- a collected cat is out: a second collect a day later gives nothing more
					expect(#LateStations.collect(profile, NOW + 86400)).to.equal(0)
				end
			)

			it("gives a level per hour, up to 24, never past CatMaxLevel (#2904)", function()
				local function soakFor(level: number, seconds: number): number
					local profile = profileAt(6)
					local cat = add(profile, "c1", "tabby", level)
					LateStations.put(profile, 1, "c1", NOW)
					LateStations.collect(profile, NOW + seconds)
					return cat.level
				end
				expect(Config.SpaMaxHours).to.equal(24)
				expect(soakFor(10, 3599)).to.equal(10) -- under an hour: still soaking
				expect(soakFor(10, 5 * 3600 + 1800)).to.equal(15)
				expect(soakFor(10, 24 * 3600)).to.equal(34)
				expect(soakFor(10, 30 * 3600)).to.equal(34) -- a day at most
				expect(soakFor(40, 24 * 3600)).to.equal(Config.CatMaxLevel)
				expect(soakFor(Config.CatMaxLevel - 1, 24 * 3600)).to.equal(Config.CatMaxLevel)
				expect(LateStations.levelsEarned(45, NOW, NOW + 10 * 3600)).to.equal(5)
				expect(LateStations.levelsEarned(10, NOW, NOW - 3600)).to.equal(0) -- a clock that went back
				expect(LateStations.fullAt(NOW)).to.equal(NOW + 24 * 3600)
			end)

			it("tops out at CatMaxLevel with no XP left over", function()
				local profile = profileAt(6)
				local cat = add(profile, "c1", "tabby", Config.CatMaxLevel - 1)
				cat.xp = 30
				LateStations.put(profile, 1, "c1", NOW)
				LateStations.collect(profile, NOW + Config.SpaSeconds)
				expect(cat.level).to.equal(Config.CatMaxLevel)
				expect(cat.xp).to.equal(0)
			end)

			it("gives no level for taking a cat out early", function()
				local profile = profileAt(6)
				local cat = add(profile, "c1", "tabby", 10)
				LateStations.put(profile, 1, "c1", NOW)
				expect(LateStations.takeOut(profile, 1)).to.equal("c1")
				expect(cat.level).to.equal(10)
				expect(LateStations.takeOut(profile, 1)).to.equal(nil)
			end)

			it("earns no XP while soaking", function()
				local profile = profileAt(6)
				local cat = add(profile, "c1", "tabby", 10)
				LateStations.put(profile, 1, "c1", NOW)
				Economy.grantXp(profile, 10000)
				expect(cat.level).to.equal(10)
				expect(cat.xp).to.equal(0)
			end)

			it("sells slot 2 for 100 fish and slot 3 for 250, in order", function()
				local profile = profileAt(6)
				expect(LateStations.nextSlotPrice(profile)).to.equal(100)
				expect(LateStations.buyBlocker(profile, 6, 3, 1000)).to.equal(
					LateStations.Messages.notNext
				)
				expect(LateStations.buyBlocker(profile, 6, 2, 99)).to.equal(
					LateStations.Messages.fish
				)
				expect(LateStations.buyBlocker(profile, 5, 2, 1000)).to.equal(
					LateStations.Messages.spaShut
				)
				expect(LateStations.buyBlocker(profile, 6, 2, 100)).to.equal(nil)
				profile.spa.slots = 2
				expect(LateStations.nextSlotPrice(profile)).to.equal(250)
				expect(LateStations.buyBlocker(profile, 6, 3, 250)).to.equal(nil)
				profile.spa.slots = 3
				expect(LateStations.nextSlotPrice(profile)).to.equal(nil)
				expect(LateStations.buyBlocker(profile, 6, 3, 1000)).to.equal(
					LateStations.Messages.allOpen
				)
			end)

			it("keeps a spa cat away from the Collector", function()
				local profile = profileAt(6)
				add(profile, "c1", "tabby", 3)
				add(profile, "c2", "tabby", 1)
				add(profile, "c3", "tabby", 2)
				LateStations.put(profile, 1, "c2", NOW)
				local busy = LateStations.spaUids(profile)
				expect(Collector.askable(profile.cats.c2, busy)).to.equal(false)
				expect(Collector.askable(profile.cats.c3, busy)).to.equal(true)
				for _ = 1, 20 do
					local pick = Collector.pickCat(profile.cats, function(): number
						return 0.5
					end, 6, busy)
					expect(pick ~= nil and pick.uid ~= "c2").to.equal(true)
				end
			end)

			it("shows the picker line", function()
				local profile = profileAt(6)
				expect(
					LateStations.pickerLine(LateStations.SPA, LateStations.view(profile, 6, NOW))
				).to.equal("Oasis Spa: empty")
				add(profile, "c1", "tabby", 3)
				add(profile, "c2", "tuxedo", 3)
				profile.spa.slots = 2
				LateStations.put(profile, 1, "c1", NOW - 4000)
				LateStations.put(profile, 2, "c2", NOW)
				local view = LateStations.view(profile, 6, NOW)
				expect(view.spa.ready).to.equal(1)
				expect(view.spa.soaking[1].doneAt).to.equal(NOW - 4000 + 3600)
				expect(view.spa.soaking[1].levels).to.equal(1)
				expect(view.spa.soaking[2].levels).to.equal(0)
				expect(LateStations.pickerLine(LateStations.SPA, view)).to.equal(
					"Oasis Spa: 1 relaxing · +1 level ready !"
				)
				local later = LateStations.view(profile, 6, NOW + 7 * 3600)
				expect(LateStations.pickerLine(LateStations.SPA, later)).to.equal(
					"Oasis Spa: +15 levels ready !"
				)
			end)
		end)

		describe("Relic Museum", function()
			it(
				"gives every exhibit its own spot in the Museum model, 1 to 10 in its room (#2908)",
				function()
					local seen: { [string]: boolean } = {}
					for _, room in LateStations.rooms do
						expect(#room.cats <= 10).to.equal(true)
						for index, catId in room.cats do
							local spot = LateStations.exhibitSpot(catId)
							expect(spot).to.equal(
								string.format("ExhibitSpot_%s_%d", room.area, index)
							)
							expect(seen[spot :: string]).to.equal(nil)
							seen[spot :: string] = true
						end
					end
					expect(LateStations.exhibitSpot("no_such_cat")).to.equal(nil)
				end
			)

			it(
				"refuses the last cat of all, a locked copy, a spa copy, an open trade and a filled exhibit",
				function()
					local profile = profileAt(7)
					table.clear(profile.cats)
					add(profile, "a", "tuxedo", 4)
					expect(LateStations.donateBlocker(profile, 6, "a", false)).to.equal(
						LateStations.Messages.museumShut
					)
					-- #3123: the only copy of a cat may go, but never the player's last cat of all
					expect(LateStations.donateBlocker(profile, 7, "a", false)).to.equal(
						LateStations.Messages.lastCopy
					)
					add(profile, "other", "smoke", 1)
					expect(LateStations.donateBlocker(profile, 7, "a", false)).to.equal(nil)
					local b = add(profile, "b", "tuxedo", 9)
					b.locked = true
					expect(LateStations.donateBlocker(profile, 7, "b", false)).to.equal(
						LateStations.Messages.locked
					)
					expect(LateStations.donateBlocker(profile, 7, "a", true)).to.equal(
						LateStations.Messages.inTrade
					)
					LateStations.put(profile, 1, "a", NOW)
					expect(LateStations.donateBlocker(profile, 7, "a", false)).to.equal(
						LateStations.Messages.atSpa
					)
					LateStations.takeOut(profile, 1)
					expect(LateStations.donateBlocker(profile, 7, "a", false)).to.equal(nil)
					LateStations.donate(profile, "a")
					expect(profile.cats.a).to.equal(nil)
					expect(profile.museum.tuxedo).to.equal("base")
					b.locked = nil
					add(profile, "c", "tuxedo", 1)
					expect(LateStations.donateBlocker(profile, 7, "c", false)).to.equal(
						LateStations.Messages.filled
					)
					expect(LateStations.donateBlocker(profile, 7, "nobody", false)).to.equal(
						LateStations.Messages.notOwned
					)
				end
			)

			it(
				"lists the copy to give first first and counts the exhibits that can be filled",
				function()
					local profile = profileAt(7)
					add(profile, "strong", "ginger", 30)
					add(profile, "weak", "ginger", 2)
					add(profile, "mid", "ginger", 2).charm = 90
					add(profile, "shiny", "ginger", 1).variant = "gold" -- #3125: gold and rainbow last
					add(profile, "busy", "ginger", 1).spotId = "spot_1" -- #3125: working cats after idle ones
					local list = LateStations.donatable(profile, "ginger")
					expect(#list).to.equal(5)
					expect(list[1].uid).to.equal("weak")
					expect(list[2].uid).to.equal("mid")
					expect(list[3].uid).to.equal("strong")
					expect(list[4].uid).to.equal("busy")
					expect(list[5].uid).to.equal("shiny")
					-- #3123: the starter tabby's only copy can be given too
					expect(LateStations.canFill(profile)).to.equal(2)
				end
			)

			it(
				"plans an Auto fill: each exhibit's first pick, no gold, never the last cat (#3130)",
				function()
					local profile = profileAt(7)
					table.clear(profile.cats)
					local room = roomOf("alley")
					add(profile, "a1", room.cats[1], 9)
					add(profile, "a2", room.cats[1], 2)
					add(profile, "g", room.cats[2], 1).variant = "gold"
					add(profile, "c", room.cats[3], 1)
					local plan = LateStations.fillPlan(profile, "alley")
					expect(#plan).to.equal(2)
					expect(plan[1]).to.equal("a2")
					expect(plan[2]).to.equal("c")
					expect(#LateStations.fillPlan(profile, "nowhere")).to.equal(0)
					table.clear(profile.cats)
					add(profile, "solo", room.cats[1], 1)
					expect(#LateStations.fillPlan(profile, "alley")).to.equal(0)
				end
			)

			it(
				"adds 2% tips forever once for a finished room, and keeps it through a rejoin",
				function()
					local profile = profileAt(7)
					local before = IndexRewards.totals(profile).bonus
					local room = roomOf("alley")
					local finished: string? = nil
					for i, catId in room.cats do
						add(profile, "keep" .. i, catId, 1)
						add(profile, "give" .. i, catId, 1)
						local _, done = LateStations.donate(profile, "give" .. i)
						if i < #room.cats then
							expect(done).to.equal(nil)
						else
							finished = done
						end
					end
					expect(finished).to.equal("alley")
					expect(LateStations.roomsDone(profile.museum)[1]).to.equal("alley")
					expect(IndexRewards.totals(profile).bonus).to.be.near(before + 0.05, 1e-9)
					local again = ProfileSchema.migrate(profile, NOW + 60)
					expect(IndexRewards.totals(again).bonus).to.be.near(before + 0.05, 1e-9)
					expect(LateStations.museumBonus(again.museum)).to.be.near(0.05, 1e-9)
				end
			)

			it("keeps a gold copy's coat on the exhibit", function()
				local profile = profileAt(7)
				add(profile, "a", "smoke", 1)
				add(profile, "b", "smoke", 1).variant = "gold"
				LateStations.donate(profile, "b")
				expect(profile.museum.smoke).to.equal("gold")
				expect(
					LateStations.pickerLine(LateStations.MUSEUM, LateStations.view(profile, 7, NOW))
				).to.equal("Relic Museum: 1/80 · 1 can be filled !") -- #3123: the starter tabby's only copy
			end)
		end)
	end)
end
