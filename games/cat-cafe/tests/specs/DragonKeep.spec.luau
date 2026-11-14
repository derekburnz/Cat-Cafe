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

		it("caps Rekindle hands at 3 waiting and keeps the Warmth for later", function()
			local save = DragonKeep.fresh()
			save.warmth = 5000 + 1500 * 5
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
end
