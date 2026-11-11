--!strict
-- Cat traits (#3196, trait-station.md): the six traits and their strengths, the roll and its odds, who pays (free
-- starter rolls, then a token, then golden fish), the caps on the cafe-wide traits, the station's token timer and
-- the saved trait's check. The station, the remotes and the save fields are TraitService's and later PRs'.
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

	describe("the six traits (spec section 2)", function()
		it("has six traits, each with I, II and III rising", function()
			expect(#Traits.LIST).to.equal(6)
			for _, def in Traits.LIST do
				expect(#def.values).to.equal(3)
				expect(def.values[1] < def.values[2] and def.values[2] < def.values[3]).to.equal(
					true
				)
				expect(Traits.get(def.id)).to.equal(def)
			end
		end)

		it("keeps the spec's numbers and caps", function()
			local function check(
				id: string,
				values: { number },
				cafe: boolean,
				best: number,
				cap: number
			)
				local def = Traits.get(id) :: Traits.Def
				expect(def.values :: any).to.deepEqual(values)
				expect(def.cafe).to.equal(cafe)
				if cafe then
					expect(def.best).to.equal(best)
					expect(def.cap).to.equal(cap)
				end
			end
			check("bigTipper", { 0.05, 0.10, 0.15 }, false, 1, 0)
			check("nightOwl", { 0.10, 0.20, 0.30 }, false, 1, 0)
			check("fastLearner", { 0.10, 0.20, 0.30 }, false, 1, 0)
			check("luckyBowl", { 0.02, 0.04, 0.06 }, true, 3, 0.18)
			check("quickPaws", { 0.3, 0.6, 1.0 }, true, 1, 1.0)
			check("richFriend", { 0.02, 0.04, 0.06 }, true, 2, 0.12)
		end)

		it("names and words a trait for the card", function()
			expect(Traits.title({ id = "bigTipper", strength = 2 })).to.equal("Big Tipper II")
			expect(Traits.effectText({ id = "bigTipper", strength = 2 })).to.equal(
				"+10% · this cat earns more money"
			)
			expect(Traits.effectText({ id = "quickPaws", strength = 2 })).to.equal(
				"+0.6 studs/s · you walk faster"
			)
			expect(Traits.effectText({ id = "luckyBowl", strength = 3 })).to.equal(
				"+6% · better bait bowl luck"
			)
		end)

		it("is behind the traits flag, off until switched on", function()
			expect(Traits.FLAG).to.equal("traits")
			expect(table.find(LiveFlags.KEYS, Traits.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[Traits.FLAG]).to.equal(true)
		end)
	end)

	describe("a saved trait", function()
		it("keeps a known id at strength 1 to 3 and drops anything else", function()
			expect(Traits.sanitize({ id = "nightOwl", strength = 3 }) :: any).to.deepEqual({
				id = "nightOwl",
				strength = 3,
			})
			expect(Traits.sanitize(nil)).to.equal(nil)
			expect(Traits.sanitize("bigTipper")).to.equal(nil)
			expect(Traits.sanitize({ id = "flying", strength = 1 })).to.equal(nil)
			expect(Traits.sanitize({ id = "bigTipper", strength = 0 })).to.equal(nil)
			expect(Traits.sanitize({ id = "bigTipper", strength = 4 })).to.equal(nil)
			expect(Traits.sanitize({ id = "bigTipper", strength = 1.5 })).to.equal(nil)
			expect(Traits.sanitize({ id = "bigTipper", strength = 0 / 0 })).to.equal(nil)
			expect(Traits.sanitize({ id = "bigTipper" })).to.equal(nil)
		end)
	end)

	describe("the roll (spec section 3)", function()
		it("picks the trait evenly, then the strength at I 70%, II 25%, III 5%", function()
			expect(Traits.STRENGTH_ODDS :: any).to.deepEqual({ 70, 25, 5 })
			expect(Traits.roll(answers({ 1, 1 })) :: any).to.deepEqual({
				id = "bigTipper",
				strength = 1,
			})
			expect(Traits.roll(answers({ 6, 70 })) :: any).to.deepEqual({
				id = "richFriend",
				strength = 1,
			})
			expect(Traits.roll(answers({ 2, 71 })) :: any).to.deepEqual({
				id = "nightOwl",
				strength = 2,
			})
			expect(Traits.roll(answers({ 3, 95 })) :: any).to.deepEqual({
				id = "fastLearner",
				strength = 2,
			})
			expect(Traits.roll(answers({ 5, 96 })) :: any).to.deepEqual({
				id = "quickPaws",
				strength = 3,
			})
			expect(Traits.roll(answers({ 4, 100 })) :: any).to.deepEqual({
				id = "luckyBowl",
				strength = 3,
			})
			-- out-of-range answers are clamped, never a missing trait
			expect(Traits.roll(answers({ 99, 999 })) :: any).to.deepEqual({
				id = "richFriend",
				strength = 3,
			})
		end)

		it("lands near the printed odds over many rolls", function()
			local rng = Random.new(3196)
			local strengths = { 0, 0, 0 }
			local ids: { [string]: number } = {}
			local N = 20000
			for _ = 1, N do
				local trait = Traits.roll(function(n: number): number
					return rng:NextInteger(1, n)
				end)
				strengths[trait.strength] += 1
				ids[trait.id] = (ids[trait.id] or 0) + 1
			end
			expect(math.abs(strengths[1] / N - 0.70) < 0.02).to.equal(true)
			expect(math.abs(strengths[2] / N - 0.25) < 0.02).to.equal(true)
			expect(math.abs(strengths[3] / N - 0.05) < 0.01).to.equal(true)
			for _, def in Traits.LIST do
				expect(math.abs((ids[def.id] or 0) / N - 1 / 6) < 0.02).to.equal(true)
			end
		end)

		it("prints the odds on the card", function()
			expect(Traits.oddsText()).to.equal(
				"Each of the 6 traits is equally likely. Strength: I 70%, II 25%, III 5%."
			)
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

	describe("what a trait does", function()
		it(
			"raises its own cat's income, Night Owl only at night, and Fast Learner its XP",
			function()
				expect(Traits.incomeMultiplier(nil, false)).to.equal(1)
				expect(Traits.incomeMultiplier({ id = "bigTipper", strength = 3 }, false)).to.be.near(
					1.15
				)
				expect(Traits.incomeMultiplier({ id = "nightOwl", strength = 2 }, false)).to.equal(
					1
				)
				expect(Traits.incomeMultiplier({ id = "nightOwl", strength = 2 }, true)).to.be.near(
					1.2
				)
				expect(Traits.incomeMultiplier({ id = "luckyBowl", strength = 3 }, true)).to.equal(
					1
				)
				expect(Traits.xpMultiplier({ id = "fastLearner", strength = 1 })).to.be.near(1.1)
				expect(Traits.xpMultiplier({ id = "bigTipper", strength = 3 })).to.equal(1)
				expect(Traits.xpMultiplier(nil)).to.equal(1)
			end
		)

		it(
			"counts only the best working cats of a cafe-wide trait, at most its cap (QA checks 2 and 3)",
			function()
				local function t(id: string, strength: number): Traits.Trait
					return { id = id, strength = strength }
				end
				-- Lucky Bowl from 4 cats: the best 3 (6 + 6 + 4), at most 18%
				local four = {
					t("luckyBowl", 2),
					t("luckyBowl", 3),
					t("luckyBowl", 1),
					nil :: any,
					t("luckyBowl", 3),
				}
				expect(Traits.cafeBonus(four, "luckyBowl")).to.be.near(0.16)
				local all =
					{ t("luckyBowl", 3), t("luckyBowl", 3), t("luckyBowl", 3), t("luckyBowl", 3) }
				expect(Traits.cafeBonus(all, "luckyBowl")).to.be.near(0.18)
				expect(Traits.cafeBonus(all, "luckyBowl") <= 0.18).to.equal(true)
				-- Quick Paws from 3 cats: the best one only
				local paws = { t("quickPaws", 1), t("quickPaws", 3), t("quickPaws", 2) }
				expect(Traits.cafeBonus(paws, "quickPaws")).to.be.near(1.0)
				-- Rich Friend: the best 2, at most 12%
				local rich = {
					t("richFriend", 3),
					t("richFriend", 3),
					t("richFriend", 3),
					t("bigTipper", 3),
				}
				expect(Traits.cafeBonus(rich, "richFriend")).to.be.near(0.12)
				-- other traits and a cat's own traits count nothing cafe wide
				expect(Traits.cafeBonus(rich, "luckyBowl")).to.equal(0)
				expect(Traits.cafeBonus(rich, "bigTipper")).to.equal(0)
				expect(Traits.cafeBonus({}, "quickPaws")).to.equal(0)
			end
		)
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
end
