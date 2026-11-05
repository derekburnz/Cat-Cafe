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
			safe = true,
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
				expect(
					Trade.askRefusal(
						facts({ safe = false }),
						facts(),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(Trade.Messages.notSafe)
				expect(
					Trade.askRefusal(
						facts(),
						facts({ safe = false }),
						3,
						true,
						false,
						0,
						"everyone",
						false
					)
				).to.equal(string.format(Trade.Messages.theirNotSafe, "Sam"))
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

		it("ends an open trade for the kill switch, a safe zone left or someone busy", function()
			expect(Trade.endReason(true, true, true, false, false)).to.equal(nil)
			expect(Trade.endReason(false, true, true, false, false)).to.equal(Trade.Ended.off)
			expect(Trade.endReason(true, false, true, false, false)).to.equal(Trade.Ended.notSafe)
			expect(Trade.endReason(true, true, true, false, true)).to.equal(Trade.Ended.busy)
		end)
	end)

	describe("arriving and applying (sections 1 and 4)", function()
		it(
			"keeps rarity, coat, charm, level and rescued; drops the name and slot; locks gold and the rarest",
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
				expect(arrived.locked).to.equal(true)
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
				if piece.rarity == rarity and Lawn.TIER_GIFTS[2] ~= piece.id and Lawn.TIER_GIFTS[3] ~= piece.id then
					return piece.id
				end
			end
			error("no " .. rarity .. " lawn piece")
		end

		local function profile(): any
			return ProfileSchema.template(1000)
		end

		it("trades crate decor and lawn pieces, never a lawn style, a tier gift or an unknown id", function()
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
		end)

		it("refuses a piece not owned, locked, the partner's already or past TradeMaxDecor", function()
			local me, them = profile(), profile()
			local common, legend = decorOf("Common"), decorOf("Legendary")
			expect(Trade.pieceRefusal(me, them, common, {})).to.equal(Trade.Messages.pieceNotOwned)
			me.decorOwned[common] = true
			me.decorOwned[legend] = true
			expect(Trade.pieceRefusal(me, them, common, {})).never.to.be.ok()
			-- Legendary and up arrive locked: unlocked on their card first
			expect(Trade.pieceLocked(me, legend)).to.equal(true)
			expect(Trade.pieceLocked(me, common)).to.equal(false)
			expect(Trade.pieceRefusal(me, them, legend, {})).to.equal(Trade.Messages.locked)
			me.decorUnlocked[legend] = true
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
			expect(Trade.pieceRefusal(me, them, gift, {})).to.equal(Trade.Messages.pieceNotTradable)
		end)

		it("values a piece by its rarity, as the Collector values a cat", function()
			expect(Trade.pieceValue(decorOf("Common"))).to.equal(Config.CollectorValue.Common)
			expect(Trade.pieceValue(decorOf("Epic"))).to.equal(Config.CollectorValue.Epic)
			expect(Trade.pieceValue("nope")).to.equal(0)
			-- a gift is getting nothing at all; a piece coming back is not a gift
			local _, gift = Trade.warnings(8, 0, 1)
			expect(gift).to.equal(false)
		end)

		it("moves placed pieces off their spots and lands new ones unplaced, locked when Legendary", function()
			local giver, taker = profile(), profile()
			local decor, legend, lawn = decorOf("Common"), decorOf("Legendary"), lawnOf("Rare")
			giver.decorOwned[decor] = true
			giver.decorPlaced[decor] = true
			giver.decorOwned[legend] = true
			giver.decorUnlocked[legend] = true
			giver.lawnOwned[lawn] = true
			local spot = (Catalog.getLawn(lawn) :: any).spot
			local spotId = assert(Lawn.firstFreeSpot(giver, spot))
			giver.lawn[spotId] = lawn
			local pieces = { decor, legend, lawn }
			expect(Trade.apply(giver, "t1", "Alex", {}, {}, {}, 2000, { gave = pieces, got = {} })).to.equal(true)
			expect(giver.decorOwned[decor]).never.to.be.ok()
			expect(giver.decorPlaced[decor]).never.to.be.ok()
			expect(giver.decorOwned[legend]).never.to.be.ok()
			expect(giver.decorUnlocked[legend]).never.to.be.ok()
			expect(giver.lawnOwned[lawn]).never.to.be.ok()
			expect(giver.lawn[spotId]).never.to.be.ok()
			expect(#(giver.tradeLog[1].gaveDecor :: any)).to.equal(3)
			expect(Trade.apply(taker, "t1", "Sam", {}, {}, {}, 2000, { gave = {}, got = pieces })).to.equal(true)
			expect(taker.decorOwned[decor]).to.equal(true)
			expect(taker.decorPlaced[decor]).never.to.be.ok() -- Equip Best puts it out
			expect(taker.lawnOwned[lawn]).to.equal(true)
			expect(Trade.pieceLocked(taker, legend)).to.equal(true) -- arrives locked
			expect((taker.tradeLog[1].gotDecor :: any)[3]).to.deepEqual({ id = lawn, kind = "lawn", rarity = "Rare" })
			-- once per trade id
			expect(Trade.apply(taker, "t1", "Sam", {}, {}, {}, 2000, { gave = pieces, got = {} })).to.equal(false)
			expect(taker.decorOwned[decor]).to.equal(true)
		end)

		it("keeps the log's decor and only owned, lockable unlocked pieces in the save", function()
			local log = Trade.sanitizeLog({
				{
					id = "t1",
					at = 5,
					partnerName = "Sam",
					gave = {},
					got = {},
					gaveDecor = { { id = "rug", kind = "decor", rarity = "Common" }, { id = 3 } },
					gotDecor = "nope",
				},
			})
			expect(log[1].gaveDecor :: any).to.deepEqual({ { id = "rug", kind = "decor", rarity = "Common" } })
			expect(log[1].gotDecor :: any).to.deepEqual({})
			local legend, common = decorOf("Legendary"), decorOf("Common")
			local raw: any = ProfileSchema.template(1000)
			raw.decorOwned = { [legend] = true, [common] = true }
			raw.decorUnlocked = { [legend] = true, [common] = true, [decorOf("Mythical")] = true, nope = true }
			local loaded = ProfileSchema.migrate(raw, 1000)
			expect(loaded.decorUnlocked :: any).to.deepEqual({ [legend] = true })
			expect(ProfileSchema.template(1000).decorUnlocked :: any).to.deepEqual({})
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
