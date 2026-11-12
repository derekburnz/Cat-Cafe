--!strict
-- Cat traits at the Mystic Pool (#3196, trait-station.md): the rarities and their odds, the six one-effect traits at
-- Common, Uncommon and Rare, the Legendary and Mythic combos, the roll, who pays (free starter rolls, then a token,
-- then golden fish), the caps on the cafe-wide effects, the pool's colour steps, the Mythic line, the station's token
-- timer and the saved trait's check. The station, the remotes and the save fields are TraitService's and later PRs'.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local Traits = require(Shared.Traits)

	-- a `random(n)` that answers from a list in turn
	local function answers(list: { number }): (number) -> number
		local i = 0
		return function(_n: number): number
			i += 1
			return list[i]
		end
	end

	local function t(id: string): Traits.Trait
		return { id = id }
	end

	describe("the rarities and traits (spec sections 2 and 3)", function()
		it("has five rarities at 35 / 30 / 20 / 10 / 5 with the pool's colours", function()
			local seen: { any } = {}
			local total = 0
			for i, rarity in Traits.RARITIES do
				expect(rarity.rank).to.equal(i)
				total += rarity.odds
				table.insert(seen, { rarity.name, rarity.odds, rarity.color })
			end
			expect(total).to.equal(100)
			expect(seen :: any).to.deepEqual({
				{ "Common", 35, "#9AA0A6" },
				{ "Uncommon", 30, "#4CAF50" },
				{ "Rare", 20, "#3F8FE0" },
				{ "Legendary", 10, "#F4C430" },
				{ "Mythic", 5, "#B04FE0" },
			})
		end)

		it(
			"holds 6 traits at each of Common, Uncommon and Rare, 4 Legendary and 3 Mythic",
			function()
				expect(#Traits.ofRarity("common")).to.equal(6)
				expect(#Traits.ofRarity("uncommon")).to.equal(6)
				expect(#Traits.ofRarity("rare")).to.equal(6)
				expect(#Traits.ofRarity("legendary")).to.equal(4)
				expect(#Traits.ofRarity("mythic")).to.equal(3)
				expect(#Traits.LIST).to.equal(25)
				for _, def in Traits.LIST do
					expect(Traits.get(def.id)).to.equal(def)
					local want = if def.rarity.rank <= 3 then 1 else def.rarity.rank - 2
					expect(#def.effects).to.equal(want)
				end
			end
		)

		it("keeps the spec's single-effect numbers, stronger at each rarity", function()
			local function check(base: string, kind: Traits.Kind, amounts: { number })
				for i, rarity in { "common", "uncommon", "rare" } do
					expect(Traits.amount(t(base .. "_" .. rarity), kind)).to.be.near(amounts[i])
				end
			end
			check("bigTipper", "income", { 0.05, 0.08, 0.12 })
			check("nightOwl", "nightIncome", { 0.10, 0.15, 0.22 })
			check("fastLearner", "xp", { 0.10, 0.15, 0.22 })
			check("luckyBowl", "bowlLuck", { 0.02, 0.03, 0.04 })
			check("quickPaws", "speed", { 0.3, 0.5, 0.7 })
			check("richFriend", "richRate", { 0.02, 0.03, 0.04 })
		end)

		it("keeps the spec's Legendary and Mythic combos", function()
			local function check(id: string, rarity: string, effects: { [string]: number })
				local def = Traits.get(id) :: Traits.Def
				expect(def.rarity.id).to.equal(rarity)
				local got: { [string]: number } = {}
				for _, effect in def.effects do
					got[effect.kind] = effect.amount
				end
				expect(got :: any).to.deepEqual(effects)
			end
			check("goldenWhiskers", "legendary", { income = 0.18, richRate = 0.06 })
			check("moonlitHunter", "legendary", { nightIncome = 0.30, bowlLuck = 0.06 })
			check("prodigy", "legendary", { xp = 0.30, income = 0.10 })
			check("lightningTail", "legendary", { speed = 1.0, xp = 0.20 })
			check("cosmicFortune", "mythic", { income = 0.40, bowlLuck = 0.12, richRate = 0.12 })
			check("eternalNight", "mythic", { nightIncome = 0.60, xp = 0.75, speed = 1.5 })
			check("starSage", "mythic", { xp = 1.0, income = 0.25, bowlLuck = 0.10 })
		end)

		it("names and words a trait for the card", function()
			expect(Traits.title(t("bigTipper_rare"))).to.equal("Big Tipper")
			expect(Traits.fullTitle(t("bigTipper_rare"))).to.equal("Rare Big Tipper")
			expect(Traits.fullTitle(t("cosmicFortune"))).to.equal("Mythic Cosmic Fortune")
			expect(Traits.effectLines(t("bigTipper_uncommon")) :: any).to.deepEqual({
				"+8% this cat's income",
			})
			expect(Traits.effectLines(t("lightningTail")) :: any).to.deepEqual({
				"+1 studs/s walk and carry speed",
				"+20% this cat's XP",
			})
			expect(Traits.effectLines(t("eternalNight")) :: any).to.deepEqual({
				"+60% this cat's night income",
				"+75% this cat's XP",
				"+1.5 studs/s walk and carry speed",
			})
			expect(#Traits.effectLines(t("nothing"))).to.equal(0)
		end)

		it("is behind the traits flag, off until switched on", function()
			expect(Traits.FLAG).to.equal("traits")
			expect(table.find(LiveFlags.KEYS, Traits.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[Traits.FLAG]).to.equal(true)
		end)
	end)

	describe("a saved trait (spec section 6)", function()
		it("keeps a known id and drops anything else", function()
			expect(Traits.sanitize({ id = "nightOwl_rare" }) :: any).to.deepEqual({
				id = "nightOwl_rare",
			})
			expect(Traits.sanitize({ id = "starSage", extra = 1 }) :: any).to.deepEqual({
				id = "starSage",
			})
			expect(Traits.sanitize(nil)).to.equal(nil)
			expect(Traits.sanitize("bigTipper_common")).to.equal(nil)
			expect(Traits.sanitize({ id = "flying" })).to.equal(nil)
			expect(Traits.sanitize({ id = "bigTipper" })).to.equal(nil) -- a single trait needs its rarity
			expect(Traits.sanitize({ id = 5 })).to.equal(nil)
		end)

		it("ranks a trait by rarity for the trade check, 0 for none", function()
			expect(Traits.rank(nil)).to.equal(0)
			expect(Traits.rank(t("flying"))).to.equal(0)
			expect(Traits.rank(t("quickPaws_common"))).to.equal(1)
			expect(Traits.rank(t("richFriend_rare"))).to.equal(3)
			expect(Traits.rank(t("prodigy"))).to.equal(4)
			expect(Traits.rank(t("starSage"))).to.equal(5)
		end)
	end)

	describe("the roll (spec sections 2 and 3)", function()
		it("picks the rarity first, then a trait of it evenly", function()
			expect(Traits.roll(answers({ 1, 1 })) :: any).to.deepEqual(t("bigTipper_common"))
			expect(Traits.roll(answers({ 35, 6 })) :: any).to.deepEqual(t("richFriend_common"))
			expect(Traits.roll(answers({ 36, 2 })) :: any).to.deepEqual(t("nightOwl_uncommon"))
			expect(Traits.roll(answers({ 65, 3 })) :: any).to.deepEqual(t("fastLearner_uncommon"))
			expect(Traits.roll(answers({ 66, 5 })) :: any).to.deepEqual(t("quickPaws_rare"))
			expect(Traits.roll(answers({ 85, 4 })) :: any).to.deepEqual(t("luckyBowl_rare"))
			expect(Traits.roll(answers({ 86, 1 })) :: any).to.deepEqual(t("goldenWhiskers"))
			expect(Traits.roll(answers({ 95, 4 })) :: any).to.deepEqual(t("lightningTail"))
			expect(Traits.roll(answers({ 96, 3 })) :: any).to.deepEqual(t("starSage"))
			-- out-of-range answers are clamped, never a missing trait
			expect(Traits.roll(answers({ 999, 99 })) :: any).to.deepEqual(t("starSage"))
			expect(Traits.roll(answers({ -5, 0 })) :: any).to.deepEqual(t("bigTipper_common"))
		end)

		it("lands near the printed odds over many rolls (QA check 9)", function()
			local rng = Random.new(3196)
			local ranks = { 0, 0, 0, 0, 0 }
			local ids: { [string]: number } = {}
			local N = 20000
			for _ = 1, N do
				local trait = Traits.roll(function(n: number): number
					return rng:NextInteger(1, n)
				end)
				ranks[Traits.rank(trait)] += 1
				ids[trait.id] = (ids[trait.id] or 0) + 1
			end
			expect(math.abs(ranks[1] / N - 0.35) < 0.02).to.equal(true)
			expect(math.abs(ranks[2] / N - 0.30) < 0.02).to.equal(true)
			expect(math.abs(ranks[3] / N - 0.20) < 0.015).to.equal(true)
			expect(math.abs(ranks[4] / N - 0.10) < 0.01).to.equal(true)
			expect(math.abs(ranks[5] / N - 0.05) < 0.008).to.equal(true)
			for _, def in Traits.ofRarity("common") do
				expect(math.abs((ids[def.id] or 0) / N - 0.35 / 6) < 0.01).to.equal(true)
			end
		end)

		it("prints the odds on the card", function()
			expect(Traits.oddsText()).to.equal(
				"Common 35%, Uncommon 30%, Rare 20%, Legendary 10%, Mythic 5%. Each trait inside a rarity is equally likely."
			)
		end)

		it(
			"steps the pool's colour up to the rolled rarity and never past it (QA check 10)",
			function()
				expect(Traits.poolSteps(t("bigTipper_common")) :: any).to.deepEqual({ "#9AA0A6" })
				expect(Traits.poolSteps(t("luckyBowl_rare")) :: any).to.deepEqual({
					"#9AA0A6",
					"#4CAF50",
					"#3F8FE0",
				})
				expect(#Traits.poolSteps(t("prodigy"))).to.equal(4)
				expect(#Traits.poolSteps(t("cosmicFortune"))).to.equal(5)
			end
		)

		it("words one server-wide line for a Mythic only (QA check 11)", function()
			expect(Traits.announceText("Mochi", t("starSage"))).to.equal(
				"Mochi's cat got a Mythic trait!"
			)
			expect(Traits.announceText("Mochi", t("prodigy"))).to.equal(nil)
			expect(Traits.announceText("Mochi", t("bigTipper_rare"))).to.equal(nil)
		end)
	end)

	describe("paying for a roll", function()
		it(
			"uses the 5 free starter rolls first, then a token, then 10 golden fish, else refuses",
			function()
				expect(Traits.FREE_ROLLS).to.equal(5)
				expect(Traits.COST_FISH).to.equal(10)
				expect(Traits.payment(0, 3, 100)).to.equal("free")
				expect(Traits.payment(4, 0, 0)).to.equal("free")
				expect(Traits.payment(5, 1, 100)).to.equal("token")
				expect(Traits.payment(5, 0, 10)).to.equal("fish")
				expect(Traits.payment(5, 0, 9)).to.equal(nil) -- QA check 5: 9 fish and no token is refused
				expect(Traits.payment(99, 0, 9)).to.equal(nil)
			end
		)

		it("words the Roll button for what it costs", function()
			expect(Traits.rollText(0, 0, false)).to.equal("Free roll (5 left)")
			expect(Traits.rollText(4, 2, true)).to.equal("Free roll (1 left)")
			expect(Traits.rollText(5, 2, false)).to.equal("Roll · 1 Trait Token")
			expect(Traits.rollText(5, 0, true)).to.equal("Re-roll · 10 golden fish")
			expect(Traits.freeLeft(7)).to.equal(0)
			expect(Traits.freeLeft(-3)).to.equal(5)
		end)
	end)

	describe("what a trait does (spec section 2d)", function()
		it("raises its own cat's income (night income only at night) and XP", function()
			expect(Traits.incomeMultiplier(nil, false)).to.equal(1)
			expect(Traits.incomeMultiplier(t("bigTipper_rare"), false)).to.be.near(1.12)
			expect(Traits.incomeMultiplier(t("nightOwl_uncommon"), false)).to.equal(1)
			expect(Traits.incomeMultiplier(t("nightOwl_uncommon"), true)).to.be.near(1.15)
			expect(Traits.incomeMultiplier(t("luckyBowl_rare"), true)).to.equal(1)
			-- a combo adds its income parts: Golden Whiskers +18%, Eternal Night +60% at night only
			expect(Traits.incomeMultiplier(t("goldenWhiskers"), false)).to.be.near(1.18)
			expect(Traits.incomeMultiplier(t("eternalNight"), false)).to.equal(1)
			expect(Traits.incomeMultiplier(t("eternalNight"), true)).to.be.near(1.6)
			expect(Traits.incomeMultiplier(t("cosmicFortune"), true)).to.be.near(1.4)
			expect(Traits.xpMultiplier(t("fastLearner_common"))).to.be.near(1.1)
			expect(Traits.xpMultiplier(t("starSage"))).to.be.near(2.0)
			expect(Traits.xpMultiplier(t("bigTipper_rare"))).to.equal(1)
			expect(Traits.xpMultiplier(nil)).to.equal(1)
		end)

		it(
			"counts only the best working cats of a cafe-wide effect, single and combo alike (QA checks 2 and 3)",
			function()
				-- bowl luck from 4 cats, mixed: the best 3 (12 + 10 + 6), at most 36%
				local four =
					{ t("luckyBowl_rare"), t("cosmicFortune"), t("moonlitHunter"), t("starSage") }
				expect(Traits.cafeBonus(four, "bowlLuck")).to.be.near(0.28)
				local mythic = {
					t("cosmicFortune"),
					t("cosmicFortune"),
					t("cosmicFortune"),
					t("cosmicFortune"),
				}
				expect(Traits.cafeBonus(mythic, "bowlLuck")).to.be.near(0.36)
				expect(Traits.cafeBonus(mythic, "bowlLuck") <= 0.36).to.equal(true)
				-- speed from Quick Paws, Lightning Tail and Eternal Night: the best one only
				local paws = { t("quickPaws_rare"), t("lightningTail"), t("eternalNight") }
				expect(Traits.cafeBonus(paws, "speed")).to.be.near(1.5)
				expect(Traits.cafeBonus({ t("quickPaws_common"), t("lightningTail") }, "speed")).to.be.near(
					1.0
				)
				-- rich rate: the best 2, at most 24%
				expect(Traits.cafeBonus(mythic, "richRate")).to.be.near(0.24)
				expect(
					Traits.cafeBonus(
						{ t("richFriend_rare"), t("goldenWhiskers"), t("richFriend_common") },
						"richRate"
					)
				).to.be.near(0.10)
				-- per-cat effects count nothing cafe wide
				expect(Traits.cafeBonus(mythic, "income")).to.equal(0)
				expect(Traits.cafeBonus(mythic, "xp")).to.equal(0)
				expect(Traits.cafeBonus({}, "speed")).to.equal(0)
			end
		)

		it("keeps every cafe-wide cap at the spec's maximum (section 5)", function()
			expect(Traits.KINDS.bowlLuck.best).to.equal(3)
			expect(Traits.KINDS.bowlLuck.cap).to.equal(0.36)
			expect(Traits.KINDS.speed.best).to.equal(1)
			expect(Traits.KINDS.speed.cap).to.equal(1.5)
			expect(Traits.KINDS.richRate.best).to.equal(2)
			expect(Traits.KINDS.richRate.cap).to.equal(0.24)
			-- no trait's own amount beats its kind's cap
			for _, def in Traits.LIST do
				for _, effect in def.effects do
					expect(effect.amount <= Traits.KINDS[effect.kind].cap).to.equal(true)
				end
			end
		end)
	end)

	describe("the station's free token (spec section 4, QA check 6)", function()
		local DAY = Traits.TOKEN_EVERY_SECONDS
		it("adds one every 12 hours and holds 2", function()
			expect(Traits.TOKEN_EVERY_SECONDS).to.equal(12 * 3600)
			expect(Traits.TOKEN_HOLD).to.equal(2)
			local held, at = Traits.fill(0, 1000, 1000 + DAY - 1)
			expect(held).to.equal(0)
			expect(at).to.equal(1000)
			held, at = Traits.fill(0, 1000, 1000 + DAY + 5)
			expect(held).to.equal(1)
			expect(at).to.equal(1000 + DAY) -- the next one counts from the whole period, not from now
			held, at = Traits.fill(1, 1000, 1000 + 5 * DAY)
			expect(held).to.equal(2)
			expect(at).to.equal(1000 + 5 * DAY) -- full: the timer waits from now
			held, at = Traits.fill(2, 1000, 2000)
			expect(held).to.equal(2)
			expect(at).to.equal(2000)
			held, at = Traits.fill(0, 5000, 1000) -- a clock behind the save adds nothing
			expect(held).to.equal(0)
			expect(at).to.equal(5000)
		end)
	end)
	describe("the save's side (spec sections 3, 4 and 6)", function()
		it(
			"pays free rolls, then a token, then fish, in one step with the check, and refunds",
			function()
				local save = Traits.fresh(100)
				for _ = 1, 5 do
					local how, fish = Traits.pay(save, 0)
					expect(how).to.equal("free")
					expect(fish).to.equal(0)
				end
				expect(save.freeUsed).to.equal(5)
				expect((Traits.pay(save, 9))).to.equal(nil) -- QA check 5
				expect(save.freeUsed).to.equal(5)
				Traits.give(save, 1)
				expect((Traits.pay(save, 0))).to.equal("token")
				expect(save.tokens).to.equal(0)
				local how, fish = Traits.pay(save, 10)
				expect(how).to.equal("fish")
				expect(fish).to.equal(10)
				Traits.refund(save, "token")
				expect(save.tokens).to.equal(1)
				Traits.refund(save, "free")
				expect(save.freeUsed).to.equal(4)
			end
		)

		it("banks tokens up to TOKEN_MAX and keeps the station's apart", function()
			local save = Traits.fresh(0)
			expect(Traits.give(save, 3)).to.equal(3)
			save.tokens = Traits.TOKEN_MAX - 1
			expect(Traits.give(save, 5)).to.equal(1)
			expect(Traits.give(save, -2)).to.equal(0)
			Traits.settle(save, true, 3 * Traits.TOKEN_EVERY_SECONDS)
			expect(save.held).to.equal(2)
			expect(save.tokens).to.equal(Traits.TOKEN_MAX)
			Traits.settle(save, false, 4 * Traits.TOKEN_EVERY_SECONDS)
			expect(save.held).to.equal(0)
			local view = Traits.view(save)
			expect(view.freeLeft).to.equal(5)
			expect(view.nextAt).to.equal(5 * Traits.TOKEN_EVERY_SECONDS)
		end)
	end)
end
