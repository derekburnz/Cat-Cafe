--!strict
-- DragonKeep.luau (#4062): the 54 cards, Warmth per cat, giving cats safely, the stages and Rekindle hands, the deal
-- (never an owned card, pity, a full binder), picks, the binder and slots, sets and the save.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local DragonKeep = require(Shared.DragonKeep)
	local ProfileSchema = require(Shared.ProfileSchema)

	local T = 1794787200

	local function catOf(rarity: string): string
		for _, def in Catalog.cats do
			if def.rarity == rarity and def.area ~= "exclusive" then
				return def.id
			end
		end
		error("no " .. rarity .. " cat")
	end

	local function profileWith(cats: { { uid: string, rarity: string, variant: string? } })
		local profile = ProfileSchema.template(T)
		profile.cats = {}
		for _, entry in cats do
			profile.cats[entry.uid] = {
				uid = entry.uid,
				catId = catOf(entry.rarity),
				level = 1,
				xp = 0,
				charm = 1,
				variant = entry.variant,
			} :: any
		end
		return profile
	end

	-- a roll that walks through fixed values
	local function rolls(values: { number }): () -> number
		local i = 0
		return function(): number
			i += 1
			return values[(i - 1) % #values + 1]
		end
	end

	describe("the cards", function()
		it("holds 54 cards: Flame 10, Claw 10, Wing 9, Hoard 10, Heart 10, Crown 5", function()
			expect(#DragonKeep.CARDS).to.equal(54)
			local families: { [string]: number } = {}
			local rarities: { [string]: number } = {}
			for _, card in DragonKeep.CARDS do
				families[card.family] = (families[card.family] or 0) + 1
				rarities[card.rarity] = (rarities[card.rarity] or 0) + 1
				expect(DragonKeep.card(card.id)).to.equal(card)
			end
			expect(families.flame).to.equal(10)
			expect(families.wing).to.equal(9)
			expect(families.crown).to.equal(5)
			expect(rarities.Common).to.equal(10)
			expect(rarities.Rare).to.equal(15)
			expect(rarities.Epic).to.equal(14)
			expect(rarities.Legendary).to.equal(10)
			expect(rarities.Mythic).to.equal(5)
		end)

		it("shows odds that add to 100 at every stage", function()
			for _, stage in { 1, 3, 5 } do
				local total = 0
				for _, n in DragonKeep.odds(stage, "stage") do
					total += n
				end
				expect(total).to.equal(100)
			end
		end)
	end)

	describe("giving cats", function()
		it("gives Warmth by rarity and coat", function()
			local profile = profileWith({
				{ uid = "a", rarity = "Epic", variant = "gold" },
				{ uid = "b", rarity = "Common" },
			})
			expect(DragonKeep.warmthOf(profile.cats.a)).to.equal(8)
			expect(DragonKeep.warmthOf(profile.cats.b)).to.equal(1)
		end)

		it("never takes a locked cat, the last cat, or a special one without the yes", function()
			local profile = profileWith({
				{ uid = "a", rarity = "Common" },
				{ uid = "b", rarity = "Common", variant = "gold" },
				{ uid = "c", rarity = "Common" },
			})
			profile.cats.c.locked = true
			expect(DragonKeep.giveBlocker(profile, 9, { "a" }, false, false)).to.equal(
				DragonKeep.Messages.shut
			)
			expect(DragonKeep.giveBlocker(profile, 10, { "c" }, false, false)).to.equal(
				DragonKeep.Messages.locked
			)
			expect(DragonKeep.giveBlocker(profile, 10, { "b" }, false, false)).to.equal(
				DragonKeep.Messages.confirm
			)
			expect(DragonKeep.giveBlocker(profile, 10, { "b" }, false, true)).to.equal(nil)
			expect(DragonKeep.giveBlocker(profile, 10, { "a" }, true, false)).to.equal(
				DragonKeep.Messages.inTrade
			)
			profile.cats.c = nil
			expect(DragonKeep.giveBlocker(profile, 10, { "a", "b" }, false, true)).to.equal(
				DragonKeep.Messages.lastCat
			)
			expect(DragonKeep.giveBlocker(profile, 10, { "zz" }, false, true)).to.equal(
				DragonKeep.Messages.notOwned
			)
			profile.cats.c = profile.cats.a
			profile.traits.pending = { uid = "a", id = "x" }
			expect(DragonKeep.giveBlocker(profile, 10, { "a" }, false, true)).to.equal(
				DragonKeep.Messages.pending
			)
		end)

		it("refuses an event cat only with keepNoEvent on (#5428)", function()
			local profile = profileWith({
				{ uid = "a", rarity = "Common" },
				{ uid = "b", rarity = "Common" },
				{ uid = "c", rarity = "Common" },
			})
			profile.cats.a.catId = "hay_bale"
			profile.cats.b.catId = "hay_bale"
			expect(DragonKeep.eventCat("hay_bale")).to.equal(true)
			expect(DragonKeep.eventCat("tabby")).to.equal(false)
			expect(DragonKeep.giveBlocker(profile, 10, { "a" }, false, true)).to.equal(nil)
			expect(DragonKeep.giveBlocker(profile, 10, { "a" }, false, true, true)).to.equal(
				DragonKeep.Messages.eventCat
			)
			expect(DragonKeep.giveBlocker(profile, 10, { "c" }, false, true, true)).to.equal(nil)
			expect(#DragonKeep.quickPlan(profile, "repeats", true)).to.equal(0)
			expect(#DragonKeep.quickPlan(profile, "repeats")).to.equal(1)
		end)

		it("plans repeats without gold, working or the last copy", function()
			local profile = profileWith({
				{ uid = "a", rarity = "Common" },
				{ uid = "b", rarity = "Common" },
				{ uid = "c", rarity = "Common", variant = "gold" },
				{ uid = "d", rarity = "Common" },
			})
			profile.cats.d.spotId = "barista_1"
			local plan = DragonKeep.quickPlan(profile, "repeats")
			expect(#plan).to.equal(2) -- a and b; c is gold, d works; 4 copies leave at least one
			for _, uid in plan do
				expect(uid == "a" or uid == "b").to.equal(true)
			end
		end)
	end)

	describe("stages and hands", function()
		it("moves cats out of the save, raises stages and queues a hand each", function()
			local list = {}
			for i = 1, 60 do
				table.insert(list, { uid = "c" .. i, rarity = "Epic" })
			end
			local profile = profileWith(list)
			local uids = {}
			for i = 1, 13 do
				table.insert(uids, "c" .. i)
			end
			local warmth, raised = DragonKeep.give(profile, uids) -- 52 Warmth
			expect(warmth).to.equal(52)
			expect(raised).to.equal(1)
			expect(profile.cats.c1).to.equal(nil)
			expect(profile.dragon.stage).to.equal(1)
			expect(#profile.dragon.slots).to.equal(1)
			expect(#profile.dragon.queue).to.equal(1)
			expect(profile.dragon.kept).to.equal(13)
			expect(#profile.dragon.napping).to.equal(12)
		end)

		it(
			"deals 3 different unowned cards, fills the new slot on a pick and deals the next",
			function()
				local save = DragonKeep.fresh()
				save.warmth = 300
				save.stage = 0
				save.binder.warmTips = true
				DragonKeep.give({ cats = {}, dragon = save } :: any, {})
				expect(save.stage).to.equal(2)
				DragonKeep.dealNext(save, rolls({ 0.01, 0.0 }))
				expect(#save.hand).to.equal(3)
				local seen = {}
				for _, id in save.hand do
					expect(seen[id]).to.equal(nil)
					expect(id ~= "warmTips").to.equal(true)
					seen[id] = true
				end
				local id, slot = DragonKeep.pick(save, 2, nil)
				expect(slot).to.equal(1)
				expect(save.slots[1]).to.equal(id)
				expect(save.binder[id]).to.equal(true)
				DragonKeep.dealNext(save, rolls({ 0.5 }))
				expect(#save.hand).to.equal(3)
				expect(#save.queue).to.equal(1)
			end
		)

		it("gives the pity Epic from stage 4", function()
			local save = DragonKeep.fresh()
			save.stage = 4
			local hand = DragonKeep.deal(save, "stage", rolls({ 0.0 }))
			local card = DragonKeep.card(hand[3]) :: DragonKeep.Card
			expect(card.rarity == "Epic" or card.rarity == "Legendary" or card.rarity == "Mythic").to.equal(
				true
			)
		end)

		it("asks 1,400 Warmth for stage 4 and 2,400 for stage 5 (#4615, #4962)", function()
			expect(DragonKeep.STAGES[3].warmth).to.equal(1000)
			expect(DragonKeep.STAGES[4].warmth).to.equal(1400)
			expect(DragonKeep.STAGES[5].warmth).to.equal(2400)
			expect(DragonKeep.REKINDLE).to.equal(1500)
		end)

		it("gives a loaded save the stage its Warmth already reaches (#4615)", function()
			local save = DragonKeep.sanitize({ warmth = 1500, stage = 3, slots = { "", "", "" } })
			expect(save.stage).to.equal(4)
			expect(#save.slots).to.equal(4)
			expect(save.queue[1]).to.equal("stage")
			-- and nothing twice: a second pass over the same save adds no hand
			local again = DragonKeep.sanitize(save)
			expect(again.stage).to.equal(4)
			expect(#again.queue).to.equal(1)
			-- a save below the next stage is left alone
			local low = DragonKeep.sanitize({ warmth = 1399, stage = 3 })
			expect(low.stage).to.equal(3)
			expect(#low.queue).to.equal(0)
		end)

		it("caps Rekindle hands at 3 waiting and keeps the Warmth for later", function()
			local save = DragonKeep.fresh()
			save.warmth = 2400 + 1500 * 5
			DragonKeep.give({ cats = {}, dragon = save } :: any, {})
			expect(save.stage).to.equal(5)
			local rekindles = 0
			for _, kind in save.queue do
				if kind == "rekindle" then
					rekindles += 1
				end
			end
			expect(rekindles).to.equal(3)
			expect(save.rekindled).to.equal(3)
		end)

		it(
			"pays 50 fish for a Rekindle with every card owned, and Keep my cards only on a Rekindle",
			function()
				local save = DragonKeep.fresh()
				save.stage = 5
				for _, card in DragonKeep.CARDS do
					save.binder[card.id] = true
				end
				save.queue = { "rekindle" }
				expect(DragonKeep.dealNext(save, rolls({ 0.3 }))).to.equal(50)
				expect(#save.queue).to.equal(0)
				save.queue = { "stage" }
				save.hand = { "warmTips" }
				expect(DragonKeep.keepCards(save)).to.equal(false)
				save.queue = { "rekindle" }
				expect(DragonKeep.keepCards(save)).to.equal(true)
			end
		)
	end)

	describe("the binder and slots", function()
		it("swaps binder cards freely and counts sets from slotted cards only", function()
			local save = DragonKeep.fresh()
			save.stage = 5
			save.slots = { "warmTips", "emberTips", "", "", "" }
			for _, id in { "warmTips", "emberTips", "nightGlow", "sharpEye" } do
				save.binder[id] = true
			end
			expect(#DragonKeep.sets(save)).to.equal(0)
			expect(DragonKeep.slotBlocker(save, "nightGlow", 3)).to.equal(nil)
			DragonKeep.slot(save, "nightGlow", 3)
			expect(DragonKeep.sets(save)[1]).to.equal("flame")
			-- a slotted card moved to another slot swaps places
			DragonKeep.slot(save, "warmTips", 3)
			expect(save.slots[1]).to.equal("nightGlow")
			expect(save.slots[3]).to.equal("warmTips")
			expect(DragonKeep.slotBlocker(save, "dragonGaze", 1)).to.equal(
				"That card is not in your binder"
			)
			expect(DragonKeep.slotBlocker(save, "sharpEye", 6)).to.equal(
				"That slot is not open yet"
			)
		end)
	end)

	describe("the save", function()
		it("drops unknown cards and slots past the stage, and survives a migrate", function()
			local out = DragonKeep.sanitize({
				warmth = 400,
				stage = 2,
				slots = { "warmTips", "notACard", "emberTips" },
				binder = { warmTips = true, notACard = true },
				hand = { "emberTips" },
				queue = { "rekindle", "boom" },
				colour = "ruby",
			})
			expect(out.stage).to.equal(2)
			expect(out.slots[1]).to.equal("warmTips")
			expect(out.slots[2]).to.equal("")
			expect(out.slots[3]).to.equal(nil)
			expect(out.binder.notACard).to.equal(nil)
			expect(#out.queue).to.equal(1)
			expect(out.colour).to.equal("ruby")
			local profile =
				ProfileSchema.migrate({ version = 49, dragon = { warmth = 60, stage = 1 } }, T)
			expect(profile.dragon.warmth).to.equal(60)
			expect(#profile.dragon.slots).to.equal(1)
		end)
	end)

	describe("card effects (#4447 part 1)", function()
		local Economy = require(Shared.Economy)

		local function withSlots(ids: { string }): any
			local save = DragonKeep.fresh() :: any
			save.stage = 5
			save.slots = ids
			for _, id in ids do
				save.binder[id] = true
			end
			return save
		end

		it("adds the money and tip cards and the Flame set, slotted only", function()
			local save = withSlots({ "warmTips", "emberTips", "dragonCoin" })
			local fx = DragonKeep.effects(save)
			-- three Flame cards slotted light the Flame set (#4569: +0.25)
			expect(math.abs(fx.money - 0.35) < 1e-9).to.equal(true)
			expect(math.abs(fx.tips - 0.12) < 1e-9).to.equal(true)
			local binderOnly = withSlots({})
			binderOnly.binder.crownOfEmbers = true
			local none = DragonKeep.effects(binderOnly)
			expect(none.money).to.equal(0)
			expect(none.tips).to.equal(0)
		end)

		it(
			"holds card money and tips together to MONEY_CAP, the set bonus on top (#4569)",
			function()
				local save = withSlots({
					"crownOfEmbers",
					"treasureTax",
					"dragonCoin",
					"warmTips",
					"emberTips",
				})
				local fx = DragonKeep.effects(save)
				-- cards: 0.45 money, then tips held to the 0.05 left; the four Flame cards light the 3/3 set (+0.25)
				local set = DragonKeep.SET_LEVELS.flame[3].money :: number
				expect(math.abs(fx.money - (0.45 + set)) < 1e-9).to.equal(true)
				expect(math.abs(fx.tips - 0.05) < 1e-9).to.equal(true)
			end
		)

		it("gives Ticket Dragon's quarter more tickets and Fish Scale's repeat fish", function()
			local none = DragonKeep.effects(withSlots({}))
			expect(DragonKeep.extraTickets(none, 8)).to.equal(0)
			expect(DragonKeep.catchFish(none, "Epic", false)).to.equal(0)
			local fx = DragonKeep.effects(withSlots({ "ticketDragon", "fishScale" }))
			expect(DragonKeep.extraTickets(fx, 8)).to.equal(2)
			expect(DragonKeep.extraTickets(fx, 3)).to.equal(0) -- rounded down
			expect(DragonKeep.catchFish(fx, "Epic", false)).to.equal(1)
			expect(DragonKeep.catchFish(fx, "Mythical", false)).to.equal(1)
			expect(DragonKeep.catchFish(fx, "Epic", true)).to.equal(0) -- a new entry has its own fish
			expect(DragonKeep.catchFish(fx, "Rare", false)).to.equal(0)
		end)

		it(
			"adds Lucky Scale to Luck and Gold Fever inside the gold cap, only with the switch on",
			function()
				local Luck = require(Shared.Luck)
				local IndexRewards = require(Shared.IndexRewards)
				local Config = require(Shared.Config)
				local profile = ProfileSchema.migrate({ version = 49 }, T) :: any
				profile.dragon = withSlots({ "luckyScale", "goldFever" })
				DragonKeep.setOn(false)
				local luckOff = Luck.of(profile, T, false)
				local goldOff = IndexRewards.luckiest({ profile }, 1, function()
					return 10
				end)
				DragonKeep.setOn(true)
				local luckOn = Luck.of(profile, T, false)
				local goldOn = IndexRewards.luckiest({ profile }, 1, function()
					return 10
				end)
				DragonKeep.setOn(nil)
				expect(math.abs(luckOn - luckOff - 0.05) < 1e-9).to.equal(true)
				expect(math.abs(goldOn - goldOff - 0.10) < 1e-9).to.equal(true)
				expect(goldOn <= Config.GoldLuckMax).to.equal(true)
			end
		)

		it(
			"adds the Claw set's bowl luck, no net reach, only with the switch on (#4569)",
			function()
				local NetSwing = require(Shared.NetSwing)
				local profile = ProfileSchema.migrate({ version = 49 }, T) :: any
				-- three Claw cards light the Claw set: +0.25 bowl luck, with Sharp Eye's 0.03
				profile.dragon = withSlots({ "sharpEye", "quickPaws", "steadyClaw" })
				profile.tier = 2 -- #4815: past the walk-through's bigger net
				DragonKeep.setOn(false)
				local off = DragonKeep.of(profile)
				DragonKeep.setOn(true)
				local extra = NetSwing.extraForProfile(profile)
				local fx = DragonKeep.of(profile)
				DragonKeep.setOn(nil)
				expect(off.luck).to.equal(0)
				expect(extra).to.equal(NetSwing.extraFor(profile.mystery))
				expect(math.abs(fx.luck - 0.28) < 1e-9).to.equal(true)
				expect(fx.luckMult).to.equal(1)
			end
		)

		it(
			"#4569: no card adds walk speed; the wing cards and the Wing set pay money and tips",
			function()
				DragonKeep.setOn(true)
				local fx = DragonKeep.of(
					{ dragon = withSlots({ "lightStep", "wingbeat", "glide" }) } :: any
				)
				DragonKeep.setOn(false)
				local off = DragonKeep.of({ dragon = withSlots({ "lightStep" }) } :: any)
				DragonKeep.setOn(nil)
				expect(fx.walk).to.equal(0)
				expect(fx.money).to.equal(0)
				expect(math.abs(fx.tips - (DragonKeep.TIPS.lightStep + 0.25)) < 1e-9).to.equal(true) -- with the Wing set
				expect(math.abs(fx.rich - DragonKeep.RICH_CARDS.wingbeat) < 1e-9).to.equal(true)
				expect(off.tips).to.equal(0)
			end
		)

		it("#4569: Soft Landing pays money, not a skipped cannon wait", function()
			DragonKeep.setOn(true)
			local fx = DragonKeep.of({ dragon = withSlots({ "softLanding" }) } :: any)
			DragonKeep.setOn(nil)
			expect(fx.softLanding).to.equal(false)
			expect(math.abs(fx.money - DragonKeep.MONEY.softLanding) < 1e-9).to.equal(true)
		end)

		it(
			"#4569: lights each set at 3 and at 5 cards of one family, and tags them for the looks",
			function()
				local three =
					withSlots({ "warmTips", "emberTips", "dragonCoin", "sharpEye", "quickPaws" })
				local levels = DragonKeep.setLevels(three)
				expect(levels.flame).to.equal(3)
				expect(levels.claw).to.equal(nil)
				expect(DragonKeep.setsTag(three)).to.equal("flame3")
				local full = withSlots({
					"crownOfEmbers",
					"skyfire",
					"royalDecree",
					"dragonHeart",
					"mythicRoar",
				})
				expect(DragonKeep.setLevels(full).crown).to.equal(5)
				expect(DragonKeep.setsTag(full)).to.equal("crown5")
				expect(DragonKeep.setsTag(withSlots({ "warmTips" }))).to.equal(nil)
				for _, family in DragonKeep.FAMILY_ORDER do
					expect(type(DragonKeep.SETS[family])).to.equal("string")
					expect(type(DragonKeep.SETS_FULL[family])).to.equal("string")
					expect(DragonKeep.SET_LEVELS[family][3] ~= nil).to.equal(true)
					expect(DragonKeep.SET_LEVELS[family][5] ~= nil).to.equal(true)
				end
			end
		)

		it("#4569: the full sets: 2x luck, 50 fish a rich tip, 3 fish a tip pile", function()
			local claw = DragonKeep.effects(
				withSlots({ "sharpEye", "quickPaws", "steadyClaw", "emberNet", "baitWhisperer" })
			)
			expect(claw.luckMult).to.equal(2)
			local wing = DragonKeep.effects(
				withSlots({ "lightStep", "softLanding", "glide", "fireTrail", "quickCannon" })
			)
			expect(wing.richFish).to.equal(50)
			local hoard = DragonKeep.effects(
				withSlots({ "shinyPocket", "coinSniffer", "treasureNose", "hoarder", "fishScale" })
			)
			expect(DragonKeep.pileFish(hoard, 0.99)).to.equal(3)
			local hoard3 = DragonKeep.effects(withSlots({ "shinyPocket", "hoarder", "fishScale" }))
			expect(DragonKeep.pileFish(hoard3, 0.99)).to.equal(1)
			local none = DragonKeep.effects(withSlots({ "coinSniffer" }))
			expect(DragonKeep.pileFish(none, 0.99)).to.equal(0)
		end)

		it("crate, trait and spin luck from Lucky Crate, Trait Spark and Lucky Spin", function()
			local fx = DragonKeep.effects(withSlots({ "luckyCrate", "traitSpark", "quickCannon" }))
			expect(math.abs(fx.crateLuck - 0.15) < 1e-9).to.equal(true)
			expect(math.abs(fx.traitLuck - 0.15) < 1e-9).to.equal(true)
			expect(math.abs(fx.spinLuck - 0.10) < 1e-9).to.equal(true)
			expect(fx.luck).to.equal(0) -- no bowl luck from them any more
			expect(fx.xp).to.equal(0) -- Trait Spark gave cat XP before
			local none = DragonKeep.effects(withSlots({ "lightStep" }))
			expect(none.crateLuck + none.traitLuck + none.spinLuck).to.equal(0)
			expect(DragonKeep.LUCK_KIND_CAP).to.equal(0.30)
		end)

		it("#4569: the Claw full set doubles the whole Luck, still at most LuckMax", function()
			local Luck = require(Shared.Luck)
			local Config = require(Shared.Config)
			local profile = ProfileSchema.migrate({ version = 49 }, T) :: any
			profile.dragon =
				withSlots({ "sharpEye", "quickPaws", "steadyClaw", "emberNet", "baitWhisperer" })
			DragonKeep.setOn(true)
			local luck = Luck.of(profile, T, false, nil, false)
			DragonKeep.setOn(false)
			local plain = Luck.of(profile, T, false, nil, false)
			DragonKeep.setOn(nil)
			-- (plain + Sharp Eye 0.03 + the set's 0.25) x2, at most LuckMax
			expect(math.abs(luck - math.min((plain + 0.28) * 2, Config.LuckMax)) < 0.011).to.equal(
				true
			)
		end)

		it("#4569: every card pays a bonus (Derek: all cards have some value)", function()
			local tables = {
				DragonKeep.MONEY,
				DragonKeep.TIPS,
				DragonKeep.BOWL_LUCK,
				DragonKeep.GOLD,
				DragonKeep.RICH_CARDS,
				DragonKeep.PILE,
				DragonKeep.XP,
				DragonKeep.REACH,
				DragonKeep.CRATE_LUCK,
				DragonKeep.TRAIT_LUCK,
				DragonKeep.SPIN_LUCK,
			}
			-- the cards whose bonus is a rule of its own in DragonKeep.effects
			local own = {
				kindred = true,
				ticketDragon = true,
				fishScale = true,
				emberNet = true,
				quickPaws = true,
				steadyClaw = true,
				doubleCatch = true,
				doubleJump = true,
				glide = true,
				cosyNap = true,
				nightGlow = true,
				patPat = true,
				hoarder = true,
				baitWhisperer = true,
				coinSniffer = true,
				goldenBreath = true,
			}
			local bare: { string } = {}
			for _, card in DragonKeep.CARDS do
				local found = own[card.id] == true
				for _, map in tables do
					if (map :: any)[card.id] ~= nil then
						found = true
					end
				end
				if not found then
					table.insert(bare, card.id)
				end
			end
			expect(table.concat(bare, ", ")).to.equal("")
		end)

		it(
			"#4569: holds card bowl luck, gold luck, rich visitors and tip piles to CAP each",
			function()
				DragonKeep.setOn(true)
				local fx = DragonKeep.of({
					dragon = withSlots({
						"skyfire",
						"dragonGaze",
						"luckyScale",
						"luckyCrate",
						"quickCannon",
					}),
				} :: any)
				local rich = DragonKeep.of({
					dragon = withSlots({
						"mythicRoar",
						"smokeSignal",
						"wingbeat",
						"treasureNose",
						"toastyTables",
					}),
				} :: any)
				DragonKeep.setOn(nil)
				expect(fx.luck <= DragonKeep.CAP + 1e-9).to.equal(true)
				expect(math.abs(fx.luck - 0.23) < 1e-9).to.equal(true) -- Lucky Crate and Lucky Spin are crate and spin luck now
				expect(rich.rich <= DragonKeep.CAP + 1e-9).to.equal(true)
			end
		)

		it("names Double Jump and Glide for the client while slotted", function()
			DragonKeep.setOn(true)
			local fx = DragonKeep.of({ dragon = withSlots({ "doubleJump", "glide" }) } :: any)
			local none = DragonKeep.of({ dragon = withSlots({ "lightStep" }) } :: any)
			DragonKeep.setOn(nil)
			expect(fx.doubleJump).to.equal(true)
			expect(fx.glide).to.equal(true)
			expect(none.doubleJump).to.equal(false)
			expect(none.glide).to.equal(false)
		end)

		it(
			"adds Fast Learner and the Heart set to every cat's XP, Cosy Nap to a resting cat's",
			function()
				DragonKeep.setOn(true)
				local fx = DragonKeep.of(
					{ dragon = withSlots({ "fastLearner", "cosyNap", "patPat" }) } :: any
				)
				DragonKeep.setOn(nil)
				expect(math.abs(fx.xp - 0.60) < 1e-9).to.equal(true) -- 0.10 + the lit Heart set's 0.50 (#4569)
				expect(fx.restXp).to.equal(DragonKeep.REST_XP)
			end
		)

		it("adds Night Glow's 12% of the cafe rate to the night rate", function()
			local Economy = require(Shared.Economy)
			local profile = profileWith({ { uid = "a", rarity = "Common" } }) :: any
			profile.cats.a.spotId = "barista_1"
			DragonKeep.setOn(true)
			local before = Economy.nightTraitRate(profile)
			profile.dragon = withSlots({ "nightGlow" })
			local after = Economy.nightTraitRate(profile)
			local rate = Economy.incomePerSecond(profile)
			DragonKeep.setOn(nil)
			expect(rate > 0).to.equal(true)
			expect(math.abs(after - before - rate * DragonKeep.NIGHT) < 1e-9).to.equal(true)
		end)

		it("brings rich visitors 15% more often with Smoke Signal", function()
			local Economy = require(Shared.Economy)
			local profile = profileWith({}) :: any
			DragonKeep.setOn(true)
			local before = Economy.richRate(profile)
			profile.dragon = withSlots({ "smokeSignal" })
			local after = Economy.richRate(profile)
			DragonKeep.setOn(nil)
			expect(math.abs(after - before - DragonKeep.RICH) < 1e-9).to.equal(true)
		end)

		it(
			"pays Furnace's 20% more a tip pile and Coin Sniffer's fish inside its chance",
			function()
				local fx = DragonKeep.effects(withSlots({ "furnace", "coinSniffer" }))
				expect(fx.pile).to.equal(DragonKeep.PILE.furnace)
				expect(DragonKeep.pileFish(fx, 0.01)).to.equal(1)
				expect(DragonKeep.pileFish(fx, 0.5)).to.equal(0)
				expect(DragonKeep.pileFish(DragonKeep.effects(withSlots({ "furnace" })), 0)).to.equal(
					0
				)
			end
		)

		it(
			"adds Sky Mail to the tip pile share, Hoarder's refund and Bait Whisperer's shorter wait",
			function()
				local Economy = require(Shared.Economy)
				local fx = DragonKeep.effects(withSlots({ "furnace", "skyMail", "hoarder" }))
				expect(math.abs(fx.pile - 0.30) < 1e-9).to.equal(true)
				expect(fx.refund).to.equal(DragonKeep.REFUND)
				local profile = profileWith({}) :: any
				DragonKeep.setOn(true)
				local before = Economy.baitWaitSeconds(profile)
				profile.dragon = withSlots({ "baitWhisperer" })
				local after = Economy.baitWaitSeconds(profile)
				DragonKeep.setOn(nil)
				expect(after < before).to.equal(true)
				expect(
					math.abs(after - math.floor(before * (1 - DragonKeep.BAIT_SPEED) + 1e-6)) <= 1
				).to.equal(true)
			end
		)

		it("turns Golden Breath on only while it is slotted", function()
			expect(DragonKeep.effects(withSlots({ "goldenBreath" })).breath).to.equal(true)
			expect(DragonKeep.effects(withSlots({ "furnace" })).breath).to.equal(false)
		end)

		it("adds Kindred's 0.1% money a kept cat, up to 10%", function()
			local save = withSlots({ "kindred" })
			save.kept = 40
			expect(math.abs(DragonKeep.effects(save).money - 0.04) < 1e-9).to.equal(true)
			save.kept = 500
			expect(math.abs(DragonKeep.effects(save).money - DragonKeep.KINDRED_MAX) < 1e-9).to.equal(
				true
			)
		end)

		it("grows a resting cat's XP by Fast Learner and Cosy Nap in Economy.grantXp", function()
			local Economy = require(Shared.Economy)
			local CatStats = require(Shared.CatStats)
			local plain = profileWith({ { uid = "a", rarity = "Common" } }) :: any
			local carded = profileWith({ { uid = "a", rarity = "Common" } }) :: any
			carded.dragon = withSlots({ "fastLearner", "cosyNap" })
			DragonKeep.setOn(true)
			Economy.grantXp(plain, 10)
			Economy.grantXp(carded, 10)
			DragonKeep.setOn(nil)
			local base = CatStats.xp(plain.cats.a)
			expect(base > 0).to.equal(true)
			expect(math.abs(CatStats.xp(carded.cats.a) - base * 1.2) < 1e-6).to.equal(true)
		end)

		it("shortens the swing wait with Ember Net, only with the switch on", function()
			local NetSwing = require(Shared.NetSwing)
			local Config = require(Shared.Config)
			local profile = ProfileSchema.migrate({ version = 49 }, T) :: any
			profile.dragon = withSlots({ "emberNet" })
			DragonKeep.setOn(false)
			expect(NetSwing.cooldownFor(profile)).to.equal(Config.NetSwingCooldown)
			DragonKeep.setOn(true)
			local cooldown = NetSwing.cooldownFor(profile)
			DragonKeep.setOn(nil)
			expect(math.abs(cooldown - Config.NetSwingCooldown * 0.92) < 1e-9).to.equal(true)
			local base = { carrying = false, busy = false, inFlight = false, inCamp = false }
			local early = table.clone(base) :: any
			-- just inside the Config wait, but past the shorter one
			early.sinceSwing = Config.NetSwingCooldown - NetSwing.COOLDOWN_SLACK - 0.01
			expect(NetSwing.refusal(early)).to.equal("cooldown") -- the Config wait without the card
			early.cooldown = cooldown
			expect(NetSwing.refusal(early)).to.equal(nil)
		end)

		it("slows the rings with Quick Paws and forgives one Miss with Steady Claw", function()
			local Circles = require(Shared.Circles)
			local fx = DragonKeep.effects(withSlots({ "quickPaws", "steadyClaw" }))
			expect(fx.slowRings).to.equal(DragonKeep.SLOW_RINGS)
			expect(fx.forgive).to.equal(true)
			local function roll(): number
				return 0.5
			end
			local plain = Circles.schedule("Rare", 1, T, roll, nil)
			local slow = Circles.schedule("Rare", 1, T, roll, nil, fx.slowRings)
			expect(math.abs(slow[1].shrinkSeconds - plain[1].shrinkSeconds * 1.05) < 1e-9).to.equal(
				true
			)
			local windows = Circles.windows(1)
			local trust = Circles.trustFor("Rare")
			local attempt = Circles.newAttempt(plain, windows, trust, true)
			local start = attempt.trust :: number
			-- the first ring left to run out is a Miss that costs nothing, the second costs as ever
			Circles.expire(attempt, Circles.deadline(plain[1], windows) + 0.01)
			expect(attempt.grades[1]).to.equal("miss")
			expect(attempt.trust).to.equal(start)
			Circles.expire(attempt, Circles.deadline(plain[2], windows) + 0.01)
			expect(attempt.grades[2]).to.equal("miss")
			expect(attempt.trust).to.equal(start + Circles.trustDelta("miss"))
			local noCard = Circles.newAttempt(plain, windows, trust)
			Circles.expire(noCard, Circles.deadline(plain[1], windows) + 0.01)
			expect(noCard.trust).to.equal(start + Circles.trustDelta("miss"))
		end)

		it("brings a friend with Double Catch, Common and Rare only", function()
			local none = DragonKeep.effects(withSlots({}))
			expect(DragonKeep.bringsFriend(none, "Common", 0)).to.equal(false)
			local fx = DragonKeep.effects(withSlots({ "doubleCatch" }))
			expect(DragonKeep.bringsFriend(fx, "Common", 0.039)).to.equal(true)
			expect(DragonKeep.bringsFriend(fx, "Rare", 0.01)).to.equal(true)
			expect(DragonKeep.bringsFriend(fx, "Common", 0.04)).to.equal(false)
			expect(DragonKeep.bringsFriend(fx, "Epic", 0)).to.equal(false)
		end)

		it("names only real cards in its tables", function()
			for id in DragonKeep.MONEY do
				expect(DragonKeep.card(id)).to.be.ok()
			end
			for id in DragonKeep.TIPS do
				expect(DragonKeep.card(id)).to.be.ok()
			end
			for id in DragonKeep.REACH do
				expect(DragonKeep.card(id)).to.be.ok()
			end
		end)

		it("reach cafeMultiplier and tipMultiplier only with the switch on", function()
			local profile = ProfileSchema.migrate({ version = 49 }, T) :: any
			profile.dragon = withSlots({ "crownOfEmbers", "warmTips" })
			Economy.setDragonKeep(false)
			local off = Economy.cafeMultiplier(profile)
			local offTips = Economy.tipMultiplier(profile, T)
			Economy.setDragonKeep(true)
			local on = Economy.cafeMultiplier(profile)
			local onTips = Economy.tipMultiplier(profile, T)
			Economy.setDragonKeep(nil)
			expect(math.abs(on - off - 0.20) < 1e-9).to.equal(true)
			expect(math.abs(onTips - offTips - 0.04) < 1e-9).to.equal(true)
		end)
	end)
end
