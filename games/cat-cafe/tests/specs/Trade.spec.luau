--!strict
-- shared/Trade.luau (F102, docs/design/cat-cafe/trading.md): what may go on offer, who may ask whom, the values and
-- warnings, how a traded cat arrives, the one-time apply and the save's trade fields (version 27); decor and lawn
-- pieces since #1574 (section 1b).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Trade = require(Shared.Trade)
	-- #1629: TradesPerDay counts the global game day; two sunrises on the shared clock
	local DAY3 = Config.ClockEpoch + require(Shared.Clock).sunriseOf(3)
	local DAY4 = Config.ClockEpoch + require(Shared.Clock).sunriseOf(4)

	-- the first catalog cat of `rarity` that spawns (not exclusive)
	local function catOf(rarity: string): string
		for _, def in Catalog.cats do
			if def.rarity == rarity and def.exclusive ~= true then
				return def.id
			end
		end
		error("no " .. rarity .. " cat")
	end

	local function cat(uid: string, rarity: string, variant: string?): any
		local instance: any = CatStats.newInstance(uid, catOf(rarity), 100, 70)
		instance.variant = variant or "base"
		return instance
	end

	local function facts(overrides: { [string]: any }?): any
		local f: any = {
			tier = 3,
			busy = false,
			inTrade = false,
			sinceLastTrade = math.huge,
			today = 0,
			name = "Sam",
		}
		for key, value in overrides or {} do
			f[key] = value
		end
		return f
	end

	describe("what can go on offer (section 1)", function()
		it("takes an unlocked cat of the player's own, up to TradeMaxCats", function()
			local a = cat("a", "Common")
			expect(Trade.offerRefusal(a, {})).to.equal(nil)
			expect(Trade.offerRefusal(a, { "a" })).to.equal(nil) -- already on offer: nothing to do
			local full: { string } = {}
			for n = 1, Config.TradeMaxCats do
				table.insert(full, "x" .. n)
			end
			expect(Trade.offerRefusal(a, full)).to.equal(
				string.format(Trade.Messages.full, Config.TradeMaxCats)
			)
		end)

		it("refuses a cat that is not theirs, a locked cat and an exclusive cat", function()
			expect(Trade.offerRefusal(nil, {})).to.equal(Trade.Messages.notOwned)
			local locked = cat("l", "Rare")
			locked.locked = true
			expect(Trade.offerRefusal(locked, {})).to.equal(Trade.Messages.locked)
			expect(Trade.tradable(locked)).to.equal(false)
			local bellhop: any = CatStats.newInstance("b", "bellhop_cat", 100)
			expect((Catalog.getCat("bellhop_cat") :: any).exclusive).to.equal(true)
			expect(Trade.offerRefusal(bellhop, {})).to.equal(Trade.Messages.exclusive)
			expect(Trade.tradable(bellhop)).to.equal(false)
			expect(Trade.tradable(cat("c", "Epic"))).to.equal(true)
			expect(Trade.tradable(nil)).to.equal(false)
		end)
	end)

	describe("values and warnings (section 3)", function()
		it("values a cat as the Collector does, gold x3 and rainbow x10", function()
			expect(Trade.value(cat("a", "Common"))).to.equal(1)
			expect(Trade.value(cat("b", "Mythical"))).to.equal(50)
			expect(Trade.value(cat("c", "Rare", "gold"))).to.equal(9)
			expect(Trade.value(cat("d", "Epic", "rainbow"))).to.equal(80)
			expect(Trade.sideValue({ cat("e", "Legendary"), cat("f", "Common") })).to.equal(21)
		end)

		it("warns a side giving three times what it gets, and a gift", function()
			-- a Mythical for one Common (QA check 6)
			local lopsided, gift = Trade.warnings(50, 1, 1)
			expect(lopsided).to.equal(true)
			expect(gift).to.equal(false)
			lopsided, gift = Trade.warnings(1, 50, 1)
			expect(lopsided).to.equal(false)
			lopsided, gift = Trade.warnings(8, 3, 1)
			expect(lopsided).to.equal(false)
			lopsided, gift = Trade.warnings(9, 3, 1)
			expect(lopsided).to.equal(true)
			lopsided, gift = Trade.warnings(3, 0, 0)
			expect(gift).to.equal(true)
			expect(lopsided).to.equal(false)
		end)
	end)

	describe("asking (section 2)", function()
		it("lets two Tier 3 players in safe zones ask", function()
			expect(Trade.askRefusal(facts(), facts(), 3, true, false, 0, "everyone", false)).to.equal(
				nil
			)
		end)

		it(
			"refuses below the minimum tier, with the kill switch off and out of the safe zones",
			function()
				expect(
					Trade.askRefusal(
						facts({ tier = 2 }),
						facts(),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(string.format(Trade.Messages.tier, 3))
				expect(
					Trade.askRefusal(
						facts(),
						facts({ tier = 2 }),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(string.format(Trade.Messages.theirTier, "Sam", 3))
				-- Debug tradeMinTier 0 lowers the bar in one server (QA check 1)
				expect(
					Trade.askRefusal(
						facts({ tier = 2 }),
						facts({ tier = 2 }),
						0,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(nil)
				expect(Trade.askRefusal(facts(), facts(), 3, false, false, 0, "everyone", false)).to.equal(
					Trade.Messages.off
				)
				-- #2568: trading from anywhere: no town or camp rule any more
				expect((Trade.Messages :: any).notSafe).to.equal(nil)
				expect((Trade.Ended :: any).notSafe).to.equal(nil)
			end
		)

		it("follows the asked player's Trade requests setting (QA check 9)", function()
			expect(Trade.askRefusal(facts(), facts(), 3, true, false, 0, "off", true)).to.equal(
				string.format(Trade.Messages.requestsOff, "Sam")
			)
			expect(Trade.askRefusal(facts(), facts(), 3, true, false, 0, "friends", false)).to.equal(
				string.format(Trade.Messages.friendsOnly, "Sam")
			)
			expect(Trade.askRefusal(facts(), facts(), 3, true, false, 0, "friends", true)).to.equal(
				nil
			)
		end)

		it(
			"holds one trade and one request at a time, the re-ask wait, the cooldown and the day's cap",
			function()
				expect(
					Trade.askRefusal(
						facts({ inTrade = true }),
						facts(),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(Trade.Messages.inTrade)
				expect(
					Trade.askRefusal(
						facts(),
						facts({ inTrade = true }),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(string.format(Trade.Messages.theirInTrade, "Sam"))
				expect(Trade.askRefusal(facts(), facts(), 3, true, true, 0, "everyone", false)).to.equal(
					Trade.Messages.asking
				)
				expect(Trade.askRefusal(facts(), facts(), 3, true, false, 30, "everyone", false)).to.equal(
					string.format(Trade.Messages.reask, "Sam")
				)
				expect(
					Trade.askRefusal(
						facts({ sinceLastTrade = 4 }),
						facts(),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(Trade.Messages.cooldown)
				expect(
					Trade.askRefusal(
						facts({ today = Config.TradesPerDay }),
						facts(),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(Trade.Messages.daily)
				expect(
					Trade.askRefusal(
						facts(),
						facts({ today = Config.TradesPerDay }),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(string.format(Trade.Messages.theirDaily, "Sam"))
				expect(
					Trade.askRefusal(
						facts({ busy = true }),
						facts(),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(Trade.Messages.busy)
			end
		)

		it(
			"lets an ask through whatever a player is doing, and never counts carrying (#3211)",
			function()
				local idle = { flying = false, catching = false, rescuing = false }
				local catching = { flying = false, catching = true, rescuing = false }
				local rescuing = { flying = false, catching = false, rescuing = true }
				local flying = { flying = true, catching = false, rescuing = false }
				expect(Trade.busy(idle, false)).to.equal(false) -- a carried cat is not on the list at all
				for _, doing in { catching, rescuing, flying } do
					expect(Trade.busy(doing, true)).to.equal(false) -- the ask still goes out and arrives
					expect(Trade.busy(doing, false)).to.equal(true) -- a trade waits for it to end
				end
			end
		)

		it(
			"ends an open trade for the kill switch or someone busy, wherever they stand (#2568)",
			function()
				expect(Trade.endReason(true, false, false)).to.equal(nil)
				expect(Trade.endReason(false, false, false)).to.equal(Trade.Ended.off)
				expect(Trade.endReason(true, true, false)).to.equal(Trade.Ended.busy)
				expect(Trade.endReason(true, false, true)).to.equal(Trade.Ended.busy)
			end
		)
	end)

	describe("arriving and applying (sections 1 and 4)", function()
		it(
			"keeps rarity, coat, charm, level and rescued; drops the name and slot; never locks it",
			function()
				local sent = cat("u1", "Rare", "gold")
				sent.level = 12
				sent.xp = 3.5
				sent.name = "Biscuit"
				sent.spotId = "barista_1"
				sent.rescued = true
				sent.locked = nil
				local arrived = Trade.arrival(sent, 500)
				expect(arrived.uid).to.equal("u1")
				expect(arrived.variant).to.equal("gold")
				expect(arrived.charm).to.equal(70)
				expect(arrived.level).to.equal(12)
				expect(arrived.xp).to.equal(3.5)
				expect(arrived.rescued).to.equal(true)
				expect(arrived.name).to.equal(nil)
				expect(arrived.spotId).to.equal(nil)
				expect(arrived.method).to.equal("trade")
				expect(arrived.caughtAt).to.equal(500)
				expect(arrived.locked).to.equal(nil) -- #2906: a gold cat arrives unlocked too
				expect(Trade.arrival(cat("u2", "Common"), 500).locked).to.equal(nil)
			end
		)

		it("moves the cats, fills the Index pages, logs and counts the trade once", function()
			local p = ProfileSchema.template(1000)
			local mine = cat("mine", "Common")
			p.cats.mine = mine
			local theirs = cat("theirs", "Epic", "rainbow")
			local gave = Trade.summaries({ mine })
			expect(Trade.apply(p, "t1", "Sam", { "mine" }, gave, { theirs }, 2000)).to.equal(true)
			expect(p.cats.mine).to.equal(nil)
			expect(p.cats.theirs).to.be.ok()
			expect(p.collection[theirs.catId]).to.equal(2000)
			expect(p.rainbowCollection[theirs.catId]).to.equal(2000)
			expect(p.tradeIds[1]).to.equal("t1")
			expect(p.tradeLog[1].partnerName).to.equal("Sam")
			expect(p.tradeLog[1].gave[1].catId).to.equal(mine.catId)
			expect(p.tradeLog[1].got[1].variant).to.equal("rainbow")
			expect(p.stats.trades).to.equal(1)
			expect(Trade.today(p, 2000)).to.equal(1)
			-- a second apply of the same trade (a pointer left after a shutdown) changes nothing (QA check 7)
			p.cats.theirs = nil
			expect(Trade.apply(p, "t1", "Sam", { "mine" }, gave, { theirs }, 2001)).to.equal(false)
			expect(p.cats.theirs).to.equal(nil)
			expect(p.stats.trades).to.equal(1)
		end)

		it(
			"keeps the last TradeLogMax log entries and TradeIdsMax ids, and counts today by game day",
			function()
				local p = ProfileSchema.template(1000)
				for n = 1, Config.TradeIdsMax + 5 do
					Trade.apply(p, "t" .. n, "Sam", {}, {}, {}, DAY3 + n)
				end
				expect(#p.tradeLog).to.equal(Config.TradeLogMax)
				expect(p.tradeLog[1].id).to.equal("t" .. (Config.TradeIdsMax + 5))
				expect(#p.tradeIds).to.equal(Config.TradeIdsMax)
				expect(p.tradeIds[1]).to.equal("t6")
				expect(Trade.today(p, DAY3 + 1)).to.equal(Config.TradeIdsMax + 5)
				expect(Trade.today(p, DAY4)).to.equal(0) -- #1629: the next game day
			end
		)
	end)

	describe("the save (version 27)", function()
		it("keeps valid trade fields and drops the rest", function()
			local raw: any = ProfileSchema.template(1000)
			raw.tradeLog = {
				{
					id = "t1",
					at = 900,
					partnerName = "Sam",
					gave = { { catId = "tabby", rarity = "Common", level = 3 } },
					got = {
						{ catId = "tabby", rarity = "Common", variant = "gold", level = 1 },
						"junk",
					},
				},
				{ id = 5, at = 900, partnerName = "Sam" },
				"junk",
			}
			raw.tradeIds = { "t1", 7, "t2" }
			raw.stats.tradesToday = { day = 12, count = 3 }
			raw.cats.traded =
				{ catId = "tabby", variant = "base", method = "trade", level = 1, charm = 50 }
			local p = ProfileSchema.migrate(raw, 1000)
			expect(#p.tradeLog).to.equal(1)
			expect(#p.tradeLog[1].got).to.equal(1)
			expect(p.tradeLog[1].got[1].variant).to.equal("gold")
			expect(p.tradeIds :: any).to.deepEqual({ "t1", "t2" })
			expect(p.stats.tradesToday :: any).to.deepEqual({ day = 12, count = 3 })
			expect(p.cats.traded.method).to.equal("trade")
		end)

		it(
			"cleans a stored trade's cat as a save's cat: no spot, stats in range, unknown kinds refused",
			function()
				local clean: any = ProfileSchema.cleanCat({
					uid = "u1",
					catId = catOf("Common"),
					variant = "gold",
					level = 99999,
					charm = 99999,
					xp = 5,
					spotId = "barista_1",
					locked = true,
					name = 5,
					method = "trade",
				}, 100)
				expect(clean).to.be.ok()
				expect(clean.uid).to.equal("u1")
				expect(clean.spotId).never.to.be.ok()
				expect(clean.level).to.equal(Config.CatMaxLevel)
				expect(clean.charm).to.equal(CatStats.MAX_CHARM)
				expect(clean.variant).to.equal("gold")
				expect(clean.locked).to.equal(true)
				expect(clean.name).never.to.be.ok()
				expect(clean.method).to.equal("trade")
				expect(ProfileSchema.cleanCat({ uid = "u2", catId = "no_such_cat" }, 100)).never.to.be.ok()
				expect(ProfileSchema.cleanCat({ catId = catOf("Common") }, 100)).never.to.be.ok()
				expect(ProfileSchema.cleanCat("tabby", 100)).never.to.be.ok()
			end
		)

		it("gives a version 26 save no trades", function()
			local raw: any = ProfileSchema.template(1000)
			raw.version = 26
			raw.tradeLog = nil
			raw.tradeIds = nil
			raw.stats.trades = nil
			raw.stats.tradesToday = nil
			local p = ProfileSchema.migrate(raw, 1000)
			expect(#p.tradeLog).to.equal(0)
			expect(#p.tradeIds).to.equal(0)
			expect(p.stats.trades).to.equal(0)
			expect(p.stats.tradesToday :: any).to.deepEqual({ day = 0, count = 0 })
		end)
	end)

	describe("decor joins (section 1b, #1574)", function()
		local Lawn = require(Shared.Lawn)

		-- the first crate decor piece of `rarity`
		local function decorOf(rarity: string): string
			for _, def in Catalog.decorById do
				if def.source == "crate" and def.rarity == rarity then
					return def.id
				end
			end
			error("no " .. rarity .. " decor")
		end

		-- the first lawn piece of `rarity` that isn't a tier gift
		local function lawnOf(rarity: string): string
			for _, piece in Catalog.lawn do
				if
					piece.rarity == rarity
					and Lawn.TIER_GIFTS[2] ~= piece.id
					and Lawn.TIER_GIFTS[3] ~= piece.id
				then
					return piece.id
				end
			end
			error("no " .. rarity .. " lawn piece")
		end

		local function profile(): any
			return ProfileSchema.template(1000)
		end

		it(
			"trades crate decor and lawn pieces, never a lawn style, a tier gift or an unknown id",
			function()
				local common = Trade.piece(decorOf("Common")) :: any
				expect(common.kind).to.equal("decor")
				expect(common.rarity).to.equal("Common")
				expect(common.bonus > 0).to.equal(true)
				local lawn = Trade.piece(lawnOf("Rare")) :: any
				expect(lawn.kind).to.equal("lawn")
				expect(lawn.bonus).to.equal(Lawn.rarityBonus("Rare"))
				for _, gift in Lawn.TIER_GIFTS do
					expect(Trade.piece(gift)).never.to.be.ok()
				end
				expect(Trade.piece(Lawn.DEFAULT_PATH)).never.to.be.ok() -- a style
				expect(Trade.piece("nope")).never.to.be.ok()
				-- a piece id names one thing: no crate decor id is also a lawn piece id
				for id in Catalog.decorById do
					expect(Catalog.getLawn(id)).never.to.be.ok()
				end
				expect(Config.TradeMaxDecor).to.equal(9)
			end
		)

		it(
			"refuses a piece not owned, locked, the partner's already or past TradeMaxDecor",
			function()
				local me, them = profile(), profile()
				local common, legend = decorOf("Common"), decorOf("Legendary")
				expect(Trade.pieceRefusal(me, them, common, {})).to.equal(
					Trade.Messages.pieceNotOwned
				)
				me.decorOwned[common] = true
				me.decorOwned[legend] = true
				expect(Trade.pieceRefusal(me, them, common, {})).never.to.be.ok()
				-- #3276: Legendary and up arrive unlocked; one locked on its card can't go on offer
				expect(Trade.pieceLocked(me, legend)).to.equal(false)
				expect(Trade.pieceRefusal(me, them, legend, {})).never.to.be.ok()
				Trade.setPieceLocked(me, legend, true)
				expect(Trade.pieceLocked(me, legend)).to.equal(true)
				expect(me.decorUnlocked[legend]).never.to.be.ok() -- the older servers' mirror
				expect(Trade.pieceRefusal(me, them, legend, {})).to.equal(Trade.Messages.locked)
				-- only a lockable rarity has a lock
				Trade.setPieceLocked(me, common, true)
				expect(Trade.pieceLocked(me, common)).to.equal(false)
				Trade.setPieceLocked(me, legend, false)
				expect(me.decorUnlocked[legend]).to.equal(true)
				expect(Trade.pieceRefusal(me, them, legend, {})).never.to.be.ok()
				them.decorOwned[common] = true
				expect(Trade.pieceRefusal(me, them, common, {})).to.equal(Trade.Messages.theyHaveIt)
				expect(Trade.pieceRefusal(me, them, common, { common })).never.to.be.ok() -- on offer already
				local full: { string } = table.create(Config.TradeMaxDecor, "x")
				expect(Trade.pieceRefusal(me, them, legend, full)).to.equal(
					string.format(Trade.Messages.fullDecor, Config.TradeMaxDecor)
				)
				local gift = Lawn.TIER_GIFTS[2]
				me.lawnOwned[gift] = true
				expect(Trade.pieceRefusal(me, them, gift, {})).to.equal(
					Trade.Messages.pieceNotTradable
				)
			end
		)

		it("values a piece by its rarity, as the Collector values a cat", function()
			expect(Trade.pieceValue(decorOf("Common"))).to.equal(Config.CollectorValue.Common)
			expect(Trade.pieceValue(decorOf("Epic"))).to.equal(Config.CollectorValue.Epic)
			expect(Trade.pieceValue("nope")).to.equal(0)
			-- a gift is getting nothing at all; a piece coming back is not a gift
			local _, gift = Trade.warnings(8, 0, 1)
			expect(gift).to.equal(false)
		end)

		it(
			"moves placed pieces off their spots and lands new ones unplaced and unlocked (#3276)",
			function()
				local giver, taker = profile(), profile()
				local decor, legend, lawn = decorOf("Common"), decorOf("Legendary"), lawnOf("Rare")
				giver.decorOwned[decor] = true
				giver.decorPlaced[decor] = true
				giver.decorOwned[legend] = true
				Trade.setPieceLocked(giver, legend, false)
				giver.lawnOwned[lawn] = true
				local spot = (Catalog.getLawn(lawn) :: any).spot
				local spotId = assert(Lawn.firstFreeSpot(giver, spot))
				giver.lawn[spotId] = lawn
				local pieces = { decor, legend, lawn }
				expect(
					Trade.apply(giver, "t1", "Alex", {}, {}, {}, 2000, { gave = pieces, got = {} })
				).to.equal(true)
				expect(giver.decorOwned[decor]).never.to.be.ok()
				expect(giver.decorPlaced[decor]).never.to.be.ok()
				expect(giver.decorOwned[legend]).never.to.be.ok()
				expect(giver.decorUnlocked[legend]).never.to.be.ok()
				expect(giver.decorLocked[legend]).never.to.be.ok()
				expect(giver.lawnOwned[lawn]).never.to.be.ok()
				expect(giver.lawn[spotId]).never.to.be.ok()
				expect(#(giver.tradeLog[1].gaveDecor :: any)).to.equal(3)
				expect(
					Trade.apply(taker, "t1", "Sam", {}, {}, {}, 2000, { gave = {}, got = pieces })
				).to.equal(true)
				expect(taker.decorOwned[decor]).to.equal(true)
				expect(taker.decorPlaced[decor]).never.to.be.ok() -- Equip Best puts it out
				expect(taker.lawnOwned[lawn]).to.equal(true)
				expect(Trade.pieceLocked(taker, legend)).to.equal(false) -- #3276: arrives unlocked
				expect(taker.decorUnlocked[legend]).to.equal(true)
				expect((taker.tradeLog[1].gotDecor :: any)[3]).to.deepEqual({
					id = lawn,
					kind = "lawn",
					rarity = "Rare",
				})
				-- once per trade id
				expect(
					Trade.apply(taker, "t1", "Sam", {}, {}, {}, 2000, { gave = pieces, got = {} })
				).to.equal(false)
				expect(taker.decorOwned[decor]).to.equal(true)
			end
		)

		it(
			"keeps the log's decor, only owned lockable pieces as locked, and every other one unlocked (#3276)",
			function()
				local log = Trade.sanitizeLog({
					{
						id = "t1",
						at = 5,
						partnerName = "Sam",
						gave = {},
						got = {},
						gaveDecor = {
							{ id = "rug", kind = "decor", rarity = "Common" },
							{ id = 3 },
						},
						gotDecor = "nope",
					},
				})
				expect(log[1].gaveDecor :: any).to.deepEqual({
					{ id = "rug", kind = "decor", rarity = "Common" },
				})
				expect(log[1].gotDecor :: any).to.deepEqual({})
				local legend, common = decorOf("Legendary"), decorOf("Common")
				local raw: any = ProfileSchema.template(1000)
				raw.decorOwned = { [legend] = true, [common] = true }
				-- a save from before #3276 (only `decorUnlocked`): every owned Legendary and up piece loads unlocked
				local legend2 = decorOf("Mythical")
				raw.decorOwned[legend2] = true
				raw.decorUnlocked = { [legend] = true, [common] = true, nope = true }
				local loaded = ProfileSchema.migrate(raw, 1000)
				expect(loaded.decorLocked :: any).to.deepEqual({})
				expect(loaded.decorUnlocked :: any).to.deepEqual({
					[legend] = true,
					[legend2] = true,
				})
				-- a lock is kept for an owned lockable piece only, and the mirror leaves it out
				local again: any = ProfileSchema.template(1000)
				again.decorOwned = { [legend] = true, [common] = true, [legend2] = true }
				again.decorLocked =
					{ [legend] = true, [common] = true, [decorOf("Epic")] = true, nope = true }
				local relocked = ProfileSchema.migrate(again, 1000)
				expect(relocked.decorLocked :: any).to.deepEqual({ [legend] = true })
				expect(relocked.decorUnlocked :: any).to.deepEqual({ [legend2] = true })
				expect(ProfileSchema.template(1000).decorUnlocked :: any).to.deepEqual({})
				expect(ProfileSchema.template(1000).decorLocked :: any).to.deepEqual({})
			end
		)
	end)

	describe("crates join (section 1c, #2745)", function()
		local function profile(): any
			return ProfileSchema.template(1000)
		end

		it("trades plain crates only, never a golden crate or an unknown id", function()
			expect(Trade.crateTradable("classic_crate")).to.equal(true)
			expect(Trade.crateTradable("park_crate")).to.equal(true)
			expect(Trade.crateTradable("classic_golden_crate")).to.equal(false)
			expect(Trade.crateTradable("park_golden_crate")).to.equal(false)
			expect(Trade.crateTradable("nope")).to.equal(false)
			for _, crate in Catalog.crates do
				expect(Trade.crateTradable(crate.id)).to.equal(not crate.golden)
			end
			expect(Config.TradeMaxCrateKinds).to.equal(6)
			expect(Config.TradeMaxCrates).to.equal(20)
		end)

		it("refuses a crate not banked, a bad count, a closed zone or past the caps", function()
			local me = profile()
			local desert = Catalog.getArea("desert") :: any
			me.crates = { classic_crate = 3, desert_crate = 2, classic_golden_crate = 1 }
			expect(Trade.crateRefusal(me, 1, "classic_crate", 3, {})).never.to.be.ok()
			expect(Trade.crateRefusal(me, 1, "classic_crate", 4, {})).to.equal(
				Trade.Messages.crateNotEnough
			)
			expect(Trade.crateRefusal(me, 1, "classic_crate", 1, { classic_crate = 3 })).to.equal(
				Trade.Messages.crateNotEnough
			)
			for _, bad in { 0, -1, 0.5, 0 / 0, math.huge } do
				expect(Trade.crateRefusal(me, 1, "classic_crate", bad, {})).to.equal(
					Trade.Messages.crateCount
				)
			end
			expect(Trade.crateRefusal(me, 9, "classic_golden_crate", 1, {})).to.equal(
				Trade.Messages.crateNotTradable
			)
			expect(Trade.crateRefusal(me, 9, "park_crate", 1, {})).to.equal(
				Trade.Messages.crateNotEnough
			)
			-- the partner's zone: the Desert crate waits for the Desert's tier
			expect(Trade.crateRefusal(me, desert.tier - 1, "desert_crate", 1, {})).to.equal(
				string.format(Trade.Messages.theyCantOpen, desert.name)
			)
			expect(Trade.crateRefusal(me, desert.tier, "desert_crate", 1, {})).never.to.be.ok()
			expect(Trade.crateAreaBlocker(1, "classic_crate")).never.to.be.ok() -- open from Tier 1
			-- the caps: kinds and crates in all
			me.crates.park_crate = 30
			local six = { a = 1, b = 1, c = 1, d = 1, e = 1, f = 1 }
			expect(Trade.crateRefusal(me, 9, "park_crate", 1, six)).to.equal(
				string.format(Trade.Messages.fullCrateKinds, 6)
			)
			expect(Trade.crateRefusal(me, 9, "park_crate", 21, {})).to.equal(
				string.format(Trade.Messages.fullCrates, 20)
			)
			expect(Trade.crateRefusal(me, 9, "park_crate", 2, { park_crate = 18 })).never.to.be.ok()
			expect(Trade.crateRefusal(me, 9, "park_crate", 3, { park_crate = 18 })).to.equal(
				string.format(Trade.Messages.fullCrates, 20)
			)
		end)

		it(
			"values a crate at its expected piece, between its rarest and commonest piece",
			function()
				for _, crate in Catalog.crates do
					local value = Trade.crateValue(crate.id)
					if crate.golden then
						expect(value).to.equal(0)
					else
						local low, high = math.huge, 0
						for _, decorId in crate.pieces do
							local v = Trade.pieceValue(decorId)
							low, high = math.min(low, v), math.max(high, v)
						end
						expect(value >= low - 0.05 and value <= high + 0.05).to.equal(true)
						expect(value * 10).to.equal(math.round(value * 10)) -- one decimal
					end
				end
				expect(Trade.crateValue("nope")).to.equal(0)
			end
		)

		it("cleans crates from a record: tradeable ids, whole counts, the caps", function()
			expect(Trade.sanitizeCrates(nil)).to.deepEqual({})
			expect(Trade.sanitizeCrates({
				classic_crate = 2.7,
				park_crate = 0,
				desert_crate = -1,
				classic_golden_crate = 1,
				nope = 1,
				[1] = 3,
			})).to.deepEqual({ classic_crate = 2 })
			local many: { [string]: number } = {}
			for _, crate in Catalog.crates do
				if not crate.golden then
					many[crate.id] = 20
				end
			end
			local kept = Trade.sanitizeCrates(many)
			local kinds, total = Trade.crateTotals(kept)
			expect(kinds).to.equal(1) -- the first kind (sorted) takes all 20
			expect(total).to.equal(20)
		end)

		it(
			"moves crates once: the giver's bank goes down, the taker's up, and the log keeps both",
			function()
				local giver, taker = profile(), profile()
				giver.crates = { classic_crate = 3, park_crate = 1 }
				taker.crates = { classic_crate = 1 }
				local crates = { classic_crate = 2, park_crate = 1 }
				expect(
					Trade.apply(
						giver,
						"t1",
						"Alex",
						{},
						{},
						{},
						2000,
						nil,
						{ gave = crates, got = {} }
					)
				).to.equal(true)
				expect(giver.crates).to.deepEqual({ classic_crate = 1 })
				expect(
					Trade.apply(
						taker,
						"t1",
						"Sam",
						{},
						{},
						{},
						2000,
						nil,
						{ gave = {}, got = crates }
					)
				).to.equal(true)
				expect(taker.crates).to.deepEqual({ classic_crate = 3, park_crate = 1 })
				-- applied once only
				expect(
					Trade.apply(
						taker,
						"t1",
						"Sam",
						{},
						{},
						{},
						2000,
						nil,
						{ gave = {}, got = crates }
					)
				).to.equal(false)
				expect(taker.crates.classic_crate).to.equal(3)
				local entry = taker.tradeLog[1]
				expect(entry.gotCrates).to.deepEqual({
					{ id = "classic_crate", count = 2 },
					{ id = "park_crate", count = 1 },
				})
				expect(entry.gaveCrates).to.deepEqual({})
				-- the log survives the save's sanitizer; an old entry without crates reads as none
				local clean = Trade.sanitizeLog({
					entry,
					{ id = "old", at = 1, partnerName = "Ola", gave = {}, got = {} },
				})
				expect(clean[1].gotCrates).to.deepEqual(entry.gotCrates)
				expect(clean[2].gotCrates).to.deepEqual({})
			end
		)
	end)

	describe("golden fish join (section 1d, #2745)", function()
		local function profile(fish: number): any
			local p: any = ProfileSchema.template(DAY3)
			p.goldenFish = fish
			return p
		end

		it("has the caps and value the spec sets", function()
			expect(Config.TradeMaxFish).to.equal(200)
			expect(Config.TradeFishPerDay).to.equal(250) -- Derek2 2026-11-10 (400 before)
			expect(Trade.fishValue(40)).to.be.near(3, 1e-9) -- 40 fish count as one Rare
		end)

		it(
			"refuses negative, fractional, NaN, infinite, over-cap and over-wallet amounts",
			function()
				local me, them = profile(150), profile(0)
				for _, bad in { -10, -1, 0.5, 0 / 0, math.huge, -math.huge, "10", true } do
					expect(Trade.fishRefusal(me, them, bad, DAY3)).to.equal(
						Trade.Messages.fishAmount
					)
				end
				expect(Trade.fishRefusal(me, them, 0, DAY3)).never.to.be.ok() -- taking them all off
				expect(Trade.fishRefusal(me, them, 150, DAY3)).never.to.be.ok()
				expect(Trade.fishRefusal(me, them, 151, DAY3)).to.equal(
					Trade.Messages.fishNotEnough
				) -- balance + 1
				me.goldenFish = 999
				expect(Trade.fishRefusal(me, them, 200, DAY3)).never.to.be.ok()
				expect(Trade.fishRefusal(me, them, 201, DAY3)).to.equal(
					string.format(Trade.Messages.fullFish, 200)
				)
			end
		)

		it(
			"keeps each receiver to TradeFishPerDay a game day, afresh at the next sunrise",
			function()
				local me, them = profile(999), profile(0)
				expect(Trade.fishRoom(them, DAY3)).to.equal(250)
				them.stats.tradesToday = { day = Trade.day(DAY3), count = 2, fishIn = 100 }
				expect(Trade.fishRoom(them, DAY3)).to.equal(150)
				expect(Trade.fishRefusal(me, them, 150, DAY3)).never.to.be.ok()
				expect(Trade.fishRefusal(me, them, 151, DAY3)).to.equal(
					string.format(Trade.Messages.fishRoom, 150)
				)
				expect(Trade.fishRoom(them, DAY4)).to.equal(250) -- the next game day
				them.stats.tradesToday.fishIn = 999 -- over the cap: no room, never below 0
				expect(Trade.fishRoom(them, DAY3)).to.equal(0)
			end
		)

		it("moves fish once, wallet only: never lifetimeGoldenFish or fishEarned", function()
			local giver, taker = profile(300), profile(20)
			taker.lifetimeGoldenFish = 20
			local fish = { gave = 120, got = 0 }
			expect(Trade.apply(giver, "t1", "Alex", {}, {}, {}, DAY3, nil, nil, fish)).to.equal(
				true
			)
			expect(giver.goldenFish).to.equal(180)
			local got = { gave = 0, got = 120 }
			expect(Trade.apply(taker, "t1", "Sam", {}, {}, {}, DAY3, nil, nil, got)).to.equal(true)
			expect(taker.goldenFish).to.equal(140)
			expect(taker.lifetimeGoldenFish).to.equal(20) -- received fish are not earned
			expect(taker.stats.fishEarned).to.equal(0)
			expect(Trade.fishInToday(taker, DAY3)).to.equal(120)
			expect(Trade.fishInToday(giver, DAY3)).to.equal(0)
			expect(Trade.today(taker, DAY3)).to.equal(1)
			-- applied once only
			expect(Trade.apply(taker, "t1", "Sam", {}, {}, {}, DAY3, nil, nil, got)).to.equal(false)
			expect(taker.goldenFish).to.equal(140)
			expect(Trade.fishInToday(taker, DAY3)).to.equal(120)
			-- the log, through the save's sanitizer
			expect(taker.tradeLog[1].gotFish).to.equal(120)
			expect(taker.tradeLog[1].gaveFish).never.to.be.ok()
			expect(giver.tradeLog[1].gaveFish).to.equal(120)
			local clean = Trade.sanitizeLog({
				taker.tradeLog[1],
				{
					id = "bad",
					at = 1,
					partnerName = "Ola",
					gave = {},
					got = {},
					gotFish = -5,
					gaveFish = 0 / 0,
				},
			})
			expect(clean[1].gotFish).to.equal(120)
			expect(clean[2].gotFish).never.to.be.ok()
			expect(clean[2].gaveFish).never.to.be.ok()
		end)

		it("never takes a wallet below 0, and cleans a record's amount", function()
			local giver = profile(50)
			Trade.apply(giver, "t2", "Alex", {}, {}, {}, DAY3, nil, nil, { gave = 80, got = 0 })
			expect(giver.goldenFish).to.equal(0)
			expect(Trade.sanitizeFish(nil)).to.equal(0)
			expect(Trade.sanitizeFish(-3)).to.equal(0)
			expect(Trade.sanitizeFish(2.5)).to.equal(0)
			expect(Trade.sanitizeFish(0 / 0)).to.equal(0)
			expect(Trade.sanitizeFish(math.huge)).to.equal(0)
			expect(Trade.sanitizeFish(5000)).to.equal(200)
			expect(Trade.sanitizeFish(37)).to.equal(37)
		end)

		it("keeps today's fishIn through the save, and leaves an old save's count alone", function()
			expect(Trade.sanitizeToday({ day = 3, count = 2, fishIn = 150 })).to.deepEqual({
				day = 3,
				count = 2,
				fishIn = 150,
			})
			expect(Trade.sanitizeToday({ day = 3, count = 2 })).to.deepEqual({ day = 3, count = 2 })
			for _, bad in { -1, 0, 1.5, 0 / 0, "9" } do
				expect(Trade.sanitizeToday({ day = 3, count = 2, fishIn = bad }).fishIn).never.to.be.ok()
			end
			-- a trade with no fish leaves fishIn out
			local p = profile(0)
			Trade.countToday(p, DAY3)
			expect(p.stats.tradesToday.fishIn).never.to.be.ok()
			Trade.countToday(p, DAY3, 30)
			Trade.countToday(p, DAY3, 40)
			expect(p.stats.tradesToday.fishIn).to.equal(70)
			Trade.countToday(p, DAY4, 5) -- a new game day starts afresh
			expect(p.stats.tradesToday.fishIn).to.equal(5)
			expect(p.stats.tradesToday.count).to.equal(1)
		end)
	end)

	describe("TradesPerDay by the game day (#1629)", function()
		it("counts trades per in-game day and starts afresh at the next sunrise", function()
			local Clock = require(Shared.Clock)
			local start = Config.ClockEpoch + Clock.sunriseOf(40)
			local p: any = ProfileSchema.template(start)
			Trade.countToday(p, start + 10)
			Trade.countToday(p, start + 20)
			expect(Trade.today(p, start + 30)).to.equal(2)
			expect(Trade.day(start + 30)).to.equal(40)
			-- the next sunrise, well inside the same UTC day
			local next = Config.ClockEpoch + Clock.sunriseOf(41)
			expect(Trade.today(p, next)).to.equal(0)
			-- an old save's UTC day number never matches a game day
			p.stats.tradesToday = { day = start // 86400, count = 50 }
			expect(Trade.today(p, start + 30)).to.equal(0)
		end)
	end)
end
