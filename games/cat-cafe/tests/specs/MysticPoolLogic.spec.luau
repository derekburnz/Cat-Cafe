--!strict
-- UI/Components/MysticPoolLogic.luau (#3196, trait-station.md): the Mystic Pool card's words and button states.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local MysticPoolLogic = require(Components:WaitForChild("MysticPoolLogic")) :: any
	local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits")) :: any

	local first = Traits.LIST[1]
	local last = Traits.LIST[#Traits.LIST]

	describe("MysticPoolLogic.canSkip (#3943)", function()
		it("lets a tap skip below Mythic and never for Mythic or Secret", function()
			expect(MysticPoolLogic.canSkip("mythic")).to.equal(false)
			expect(MysticPoolLogic.canSkip("secret")).to.equal(false)
			for _, rarity in Traits.RARITIES do
				if rarity.id ~= "mythic" and rarity.id ~= "secret" then
					expect(MysticPoolLogic.canSkip(rarity.id)).to.equal(true)
				end
			end
		end)
	end)

	describe("MysticPoolLogic.card", function()
		it("shows a plain card for no trait or one it does not know", function()
			for _, value in { nil, {}, { id = 3 }, { id = "no_such_trait" } } :: { any } do
				local card = MysticPoolLogic.card(value)
				expect(card.has).to.equal(false)
				expect(card.name).to.equal("No trait yet")
				expect(card.rarity).to.equal("")
				expect(#card.lines).to.equal(0)
			end
		end)

		it("shows every trait's name, rarity, colour and effects", function()
			for _, def in Traits.LIST do
				local card = MysticPoolLogic.card({ id = def.id })
				expect(card.has).to.equal(true)
				expect(card.name).to.equal(def.name)
				expect(card.rarity).to.equal(def.rarity.name)
				expect(card.color).to.equal(def.rarity.color)
				expect(#card.lines).to.equal(#def.effects)
			end
		end)
	end)

	describe("MysticPoolLogic.roll", function()
		it("is shut without the station's numbers", function()
			local roll = MysticPoolLogic.roll(nil, false, 999)
			expect(roll.enabled).to.equal(false)
			expect(roll.why).to.be.ok()
		end)

		it("uses a free roll first and says how many are left", function()
			local roll = MysticPoolLogic.roll({ tokens = 2, freeLeft = 5, held = 0 }, false, 0)
			expect(roll.text).to.equal("Free roll (5 left)")
			expect(roll.enabled).to.equal(true)
			roll = MysticPoolLogic.roll({ tokens = 0, freeLeft = 1, held = 0 }, true, 0)
			expect(roll.text).to.equal("Free roll (1 left)")
			expect(roll.enabled).to.equal(true)
		end)

		it("then a token, then golden fish, and says Re-roll for a cat with a trait", function()
			local roll = MysticPoolLogic.roll({ tokens = 1, freeLeft = 0, held = 0 }, false, 0)
			expect(roll.text).to.equal("Roll · 1 Trait Token")
			expect(roll.enabled).to.equal(true)
			roll =
				MysticPoolLogic.roll({ tokens = 0, freeLeft = 0, held = 0 }, true, Traits.COST_FISH)
			expect(roll.text).to.equal(string.format("Re-roll · %d golden fish", Traits.COST_FISH))
			expect(roll.enabled).to.equal(true)
		end)

		it("rests with one golden fish too few and no token (QA check 5)", function()
			local roll = MysticPoolLogic.roll(
				{ tokens = 0, freeLeft = 0, held = 0 },
				false,
				Traits.COST_FISH - 1
			)
			expect(roll.enabled).to.equal(false)
			expect(roll.why).to.be.ok()
		end)

		it("rests while a re-roll waits for its choice", function()
			local roll = MysticPoolLogic.roll(
				{ tokens = 3, freeLeft = 2, held = 0, pending = { uid = "c1", id = first.id } },
				true,
				100
			)
			expect(roll.enabled).to.equal(false)
			expect(roll.why).to.equal("Pick Keep old or Take new first")
		end)

		it("reads odd numbers from the network as none", function()
			local roll = MysticPoolLogic.roll({ tokens = "9", freeLeft = -4 } :: any, false, 0 / 0)
			expect(roll.enabled).to.equal(false)
		end)
	end)

	describe("MysticPoolLogic.pending", function()
		it("is nil with nothing waiting or a broken record", function()
			expect(MysticPoolLogic.pending(nil, {})).never.to.be.ok()
			expect(MysticPoolLogic.pending({ tokens = 0 }, {})).never.to.be.ok()
			expect(MysticPoolLogic.pending({ pending = { uid = "c1" } }, {})).never.to.be.ok()
		end)

		it("puts the cat's old trait beside the new one", function()
			local cats = { c1 = { uid = "c1", trait = { id = first.id } } }
			local waiting =
				MysticPoolLogic.pending({ pending = { uid = "c1", id = last.id } }, cats)
			expect(waiting.uid).to.equal("c1")
			expect(waiting.old.name).to.equal(first.name)
			expect(waiting.new.name).to.equal(last.name)
		end)

		it("still shows the choice when the cat is gone, so it can be cleared", function()
			local waiting = MysticPoolLogic.pending(
				{ pending = { uid = "gone", id = last.id } },
				{}
			)
			expect(waiting.old.has).to.equal(false)
			expect(waiting.new.has).to.equal(true)
		end)
	end)

	describe("MysticPoolLogic.haveLine and tokens", function()
		it("lists free rolls only while any are left", function()
			expect(MysticPoolLogic.haveLine({ tokens = 2, freeLeft = 5 }, 34)).to.equal(
				"5 free rolls · 2 Trait Tokens · 34 golden fish"
			)
			expect(MysticPoolLogic.haveLine({ tokens = 1, freeLeft = 1 }, 0)).to.equal(
				"1 free roll · 1 Trait Token · 0 golden fish"
			)
			expect(MysticPoolLogic.haveLine({ tokens = 0, freeLeft = 0 }, 7)).to.equal(
				"0 Trait Tokens · 7 golden fish"
			)
		end)

		it("offers Collect while the station holds a token", function()
			local line, ready = MysticPoolLogic.tokens({ held = 2 }, 1000)
			expect(line).to.equal("2 Trait Tokens ready")
			expect(ready).to.equal(true)
			line, ready = MysticPoolLogic.tokens({ held = 1 }, 1000)
			expect(line).to.equal("1 Trait Token ready")
			expect(ready).to.equal(true)
		end)

		it("counts down to the next free token (QA check 6)", function()
			local line, ready =
				MysticPoolLogic.tokens({ held = 0, nextAt = 1000 + 3 * 3600 + 12 * 60 }, 1000)
			expect(line).to.equal("Next free token in 3h 12m")
			expect(ready).to.equal(false)
			expect((MysticPoolLogic.tokens({ held = 0, nextAt = 1000 + 61 }, 1000))).to.equal(
				"Next free token in 2m"
			)
			expect((MysticPoolLogic.tokens({ held = 0, nextAt = 1000 + 45 }, 1000))).to.equal(
				"Next free token in 45s"
			)
			expect((MysticPoolLogic.tokens({ held = 0, nextAt = 900 }, 1000))).to.equal(
				"Next free token soon"
			)
			expect((MysticPoolLogic.tokens(nil, 1000))).to.equal("")
		end)
	end)

	describe("MysticPoolLogic.odds", function()
		it("lists every rarity with its percent, adding up to 100", function()
			local rows = MysticPoolLogic.odds()
			expect(#rows).to.equal(#Traits.RARITIES)
			local total = 0
			for index, row in rows do
				expect(row.name).to.equal(Traits.RARITIES[index].name)
				expect(row.color).to.equal(Traits.RARITIES[index].color)
				total += row.percent
			end
			expect(total).to.equal(100)
			expect(MysticPoolLogic.ODDS_LINE:find("equally likely", 1, true)).to.be.ok()
		end)

		it("never uses near-miss words on its buttons", function()
			for _, text in
				{ MysticPoolLogic.KEEP_OLD, MysticPoolLogic.TAKE_NEW, MysticPoolLogic.NO_TRAIT }
			do
				local low = text:lower()
				expect(low:find("almost", 1, true)).never.to.be.ok()
				expect(low:find("close", 1, true)).never.to.be.ok()
			end
		end)
	end)

	describe("MysticPoolLogic picker and roll helpers", function()
		local cats = {
			a = { uid = "a", catId = "x", level = 3, rating = 1 },
			b = { uid = "b", catId = "x", level = 9, rating = 1 },
			c = { uid = "c", catId = "x", level = 2, rating = 1, spotId = "s1" },
			d = { uid = "d", catId = "x", level = 9, rating = 4 },
			junk = 7,
		} :: any

		it("lists working cats first, then level, rate and uid", function()
			local list = MysticPoolLogic.cats(cats)
			local order = {}
			for _, cat in list do
				table.insert(order, cat.uid)
			end
			expect(table.concat(order, ",")).to.equal("c,d,b,a")
			expect(#MysticPoolLogic.cats(nil)).to.equal(0)
		end)

		it("changes the list's key when a cat gets a trait", function()
			local before = MysticPoolLogic.key(MysticPoolLogic.cats(cats))
			expect(MysticPoolLogic.key(MysticPoolLogic.cats(cats))).to.equal(before)
			cats.a.trait = { id = first.id }
			expect(MysticPoolLogic.key(MysticPoolLogic.cats(cats))).never.to.equal(before)
			cats.a.trait = nil
		end)

		it(
			"changes the stamp on a payment, a trait, a waiting re-roll or a collected token",
			function()
				local view = { tokens = 1, freeLeft = 0, held = 1 } :: any
				local base = MysticPoolLogic.stamp(view, 20, nil)
				expect(MysticPoolLogic.stamp(view, 20, nil)).to.equal(base)
				expect(MysticPoolLogic.stamp(view, 10, nil)).never.to.equal(base)
				expect(MysticPoolLogic.stamp(view, 20, { id = first.id })).never.to.equal(base)
				expect(MysticPoolLogic.stamp({ tokens = 2, freeLeft = 0, held = 0 }, 20, nil)).never.to.equal(
					base
				)
				expect(MysticPoolLogic.stamp({
					tokens = 1,
					freeLeft = 0,
					held = 1,
					pending = { uid = "a", id = last.id },
				}, 20, nil)).never.to.equal(base)
				expect(MysticPoolLogic.stamp(nil, 20, nil)).to.equal("shut")
			end
		)

		it("finds what a roll gave: a first trait, or the waiting re-roll for that cat", function()
			local view = { tokens = 0, freeLeft = 0, held = 0 } :: any
			expect(MysticPoolLogic.rolled(view, "a", false, nil)).never.to.be.ok()
			expect(MysticPoolLogic.rolled(view, "a", false, { id = first.id })).to.equal(first.id)
			-- a cat that had a trait only shows a result through the waiting re-roll
			expect(MysticPoolLogic.rolled(view, "a", true, { id = first.id })).never.to.be.ok()
			view.pending = { uid = "a", id = last.id }
			expect(MysticPoolLogic.rolled(view, "a", true, { id = first.id })).to.equal(last.id)
			expect(MysticPoolLogic.rolled(view, "b", true, { id = first.id })).never.to.be.ok()
			view.pending = { uid = "a", id = "no_such_trait" }
			expect(MysticPoolLogic.rolled(view, "a", true, nil)).never.to.be.ok()
		end)

		it("names a trait's rarity for the pool's colour", function()
			expect(MysticPoolLogic.rarityId(first.id)).to.equal(first.rarity.id)
			expect(MysticPoolLogic.rarityId(last.id)).to.equal(last.rarity.id)
			expect(MysticPoolLogic.rarityId("no_such_trait")).to.equal(Traits.RARITIES[1].id)
		end)
	end)

	describe("MysticPoolLogic.pickerLine (the Cannon menu's strip, #3196)", function()
		it("shows on no area's card now the pool stands in the Town Square (#3715)", function()
			local view = { tokens = 1, freeLeft = 0, held = 0 }
			expect(MysticPoolLogic.pickerLine(nil, MysticPoolLogic.AREA)).to.equal(nil)
			expect(MysticPoolLogic.pickerLine(view, "town")).to.equal(nil)
			expect(MysticPoolLogic.pickerLine(view, "woods")).to.equal(nil)
			expect(MysticPoolLogic.pickerLine(view, "park")).to.equal(nil)
			expect(MysticPoolLogic.pickerLine(view, MysticPoolLogic.AREA) :: any).to.deepEqual({
				extraId = "mysticPool",
				icon = MysticPoolLogic.ICON,
				name = "Mystic Pool",
				state = "Give a cat a trait",
				ready = false,
			})
		end)

		it("says what waits: free tokens at the station first, then starter rolls", function()
			local tokens: any = MysticPoolLogic.pickerLine(
				{ tokens = 0, freeLeft = 5, held = 2 },
				MysticPoolLogic.AREA
			)
			expect(tokens.state).to.equal("2 free tokens")
			expect(tokens.ready).to.equal(true)
			local one: any = MysticPoolLogic.pickerLine(
				{ tokens = 0, freeLeft = 5, held = 1 },
				MysticPoolLogic.AREA
			)
			expect(one.state).to.equal("1 free token")
			local rolls: any = MysticPoolLogic.pickerLine(
				{ tokens = 0, freeLeft = 5, held = 0 },
				MysticPoolLogic.AREA
			)
			expect(rolls.state).to.equal("5 free rolls")
			expect(rolls.ready).to.equal(false)
			local last: any = MysticPoolLogic.pickerLine(
				{ tokens = 0, freeLeft = 1, held = 0 },
				MysticPoolLogic.AREA
			)
			expect(last.state).to.equal("1 free roll")
			local bare: any = MysticPoolLogic.pickerLine({}, MysticPoolLogic.AREA)
			expect(bare.state).to.equal("Give a cat a trait")
		end)
	end)
	-- #3864: the Trait Token bundles, offered once the free rolls are used (a paid random item: odds on the offer)
	describe("MysticPoolLogic.bundles", function()
		local ids = { trait_tokens_20 = 11, trait_tokens_50 = 22 }
		local used = { tokens = 0, freeLeft = 0, held = 0, bundles = true }
		it("offers both bundles, priced, once the free rolls are used", function()
			local list: any = MysticPoolLogic.bundles(used, ids, false)
			expect(#list).to.equal(2)
			expect(list[1].id).to.equal(11)
			expect(list[1].label).to.equal("20 Tokens · R$99")
			expect(list[2].label).to.equal("50 Tokens · R$199")
			-- #3948: the picture cards' words
			expect(list[1].tokens).to.equal(20)
			expect(list[1].price).to.equal("R$99")
			expect(list[2].rolls).to.equal("50 rolls")
		end)
		it(
			"offers nothing while free rolls are left, a choice waits, or it was seen this session",
			function()
				expect(
					MysticPoolLogic.bundles(
						{ tokens = 0, freeLeft = 1, held = 0, bundles = true },
						ids,
						false
					)
				).to.equal(nil)
				expect(MysticPoolLogic.bundles({
					tokens = 0,
					freeLeft = 0,
					held = 0,
					bundles = true,
					pending = { uid = "a", id = "b" },
				}, ids, false)).to.equal(nil)
				expect(MysticPoolLogic.bundles(used, ids, true)).to.equal(nil)
			end
		)
		it(
			"offers nothing unless the server says so (switch off, or paid random items restricted)",
			function()
				expect(MysticPoolLogic.bundles({ tokens = 0, freeLeft = 0, held = 0 }, ids, false)).to.equal(
					nil
				)
				expect(
					MysticPoolLogic.bundles(
						{ tokens = 0, freeLeft = 0, held = 0, bundles = false },
						ids,
						false
					)
				).to.equal(nil)
				expect(MysticPoolLogic.bundles(nil, ids, false)).to.equal(nil)
			end
		)
		it("offers only products that are made", function()
			expect(
				MysticPoolLogic.bundles(used, { trait_tokens_20 = 0, trait_tokens_50 = 0 }, false)
			).to.equal(nil)
			local one: any =
				MysticPoolLogic.bundles(used, { trait_tokens_20 = 0, trait_tokens_50 = 22 }, false)
			expect(#one).to.equal(1)
			expect(one[1].product).to.equal("trait_tokens_50")
		end)
		it("hangs the red ! over the pool while a roll waits (#3936)", function()
			expect(MysticPoolLogic.bangShows(nil)).to.equal(false)
			expect(MysticPoolLogic.bangShows({ tokens = 0, freeLeft = 0, held = 0 })).to.equal(
				false
			)
			expect(MysticPoolLogic.bangShows({ tokens = 10, freeLeft = 0, held = 0 })).to.equal(
				true
			)
			expect(MysticPoolLogic.bangShows({ tokens = 0, freeLeft = 2, held = 0 })).to.equal(true)
			expect(MysticPoolLogic.bangShows({ tokens = 0, freeLeft = 0, held = 1 })).to.equal(true)
			expect(MysticPoolLogic.bangShows({ tokens = 3, pending = { uid = "a", id = "b" } })).to.equal(
				false
			)
			expect(MysticPoolLogic.bangShows({ tokens = -4, freeLeft = 0 / 0 } :: any)).to.equal(
				false
			)
		end)
		it("shows every roll's odds, summing to 100 (monetization-policy 2.1)", function()
			local sum = 0
			for _, row in MysticPoolLogic.odds() do
				sum += row.percent
			end
			expect(sum).to.equal(100)
			expect(#MysticPoolLogic.ODDS_LINES >= 1).to.equal(true)
		end)
	end)
end
