--!strict
-- Catching.luau against data-model sections 8, 9 and 10.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local Config = require(Shared.Config)

	describe("ring", function()
		it("bonus per result (perfect 0.15, good 0.05, miss 0)", function()
			expect(Catching.ringBonus("perfect")).to.be.near(0.15)
			expect(Catching.ringBonus("good")).to.be.near(0.05)
			expect(Catching.ringBonus("miss")).to.equal(0)
		end)

		-- Section 10 (2026-10-26): the server derives the ring result from the seconds between GrabBegin and
		-- GrabEnd. Perfect is the last RingPerfectWindow of the hold, good the last RingGoodWindow, both extended
		-- past the hold by RingLatencyGraceSeconds; earlier is a miss; later is a miss; under GrabMinHoldSeconds
		-- the GrabEnd is dropped (nil) and the lock continues. Proposed signature, agreed with the engineer thread:
		--   Catching.ringResultFromHold(secondsSinceGrabBegin: number): Types.RingResult?
		local ringResultFromHold = (Catching :: any).ringResultFromHold

		it("ringResultFromHold exists (replaces the client reported ring value)", function()
			expect(ringResultFromHold).to.be.a("function")
		end)

		it("derives perfect, good, miss or dropped from the hold time", function()
			local hold = Config.GrabHoldSeconds
			local grace = (Config :: any).RingLatencyGraceSeconds
			expect(grace).to.be.a("number")
			local perfectFrom = hold - Config.RingPerfectWindow
			local goodFrom = hold - Config.RingGoodWindow
			local lateEdge = hold + grace
			-- dropped as spam
			expect(ringResultFromHold(-1)).to.equal(nil)
			expect(ringResultFromHold(0)).to.equal(nil)
			expect(ringResultFromHold(Config.GrabMinHoldSeconds - 0.001)).to.equal(nil)
			-- released too early: a miss, but the chance is still rolled
			expect(ringResultFromHold(Config.GrabMinHoldSeconds)).to.equal("miss")
			expect(ringResultFromHold(goodFrom - 0.001)).to.equal("miss")
			-- good band
			expect(ringResultFromHold(goodFrom)).to.equal("good")
			expect(ringResultFromHold(perfectFrom - 0.001)).to.equal("good")
			-- perfect band, including the latency grace after the hold completes
			expect(ringResultFromHold(perfectFrom)).to.equal("perfect")
			expect(ringResultFromHold(hold)).to.equal("perfect")
			expect(ringResultFromHold(lateEdge)).to.equal("perfect")
			-- released too late
			expect(ringResultFromHold(lateEdge + 0.001)).to.equal("miss")
			expect(ringResultFromHold(60)).to.equal("miss")
		end)

		it("the concrete numbers in the doc: 1.20 to 1.75 s perfect, 0.70 to 1.20 s good, under 0.15 s dropped", function()
			expect(ringResultFromHold(0.10)).to.equal(nil)
			expect(ringResultFromHold(0.69)).to.equal("miss")
			expect(ringResultFromHold(0.70)).to.equal("good")
			expect(ringResultFromHold(1.19)).to.equal("good")
			expect(ringResultFromHold(1.20)).to.equal("perfect")
			expect(ringResultFromHold(1.50)).to.equal("perfect")
			expect(ringResultFromHold(1.75)).to.equal("perfect")
			expect(ringResultFromHold(1.76)).to.equal("miss")
		end)

		it("the ring is a bonus, never a gate: a miss still rolls the full base chance", function()
			expect(Catching.chance("Common", 0, false, "miss")).to.be.near(0.90)
			expect(Catching.chance("Legendary", 0, false, "miss")).to.be.near(0.25)
		end)
	end)

	describe("chance (section 10): clamp(base + gloves x 0.10 + lure + ring, 0.05, 0.95)", function()
		it("bare handed uses the rarity base", function()
			expect(Catching.chance("Common", 0, false, "miss")).to.be.near(0.90)
			expect(Catching.chance("Rare", 0, false, "miss")).to.be.near(0.65)
			expect(Catching.chance("Epic", 0, false, "miss")).to.be.near(0.45)
			expect(Catching.chance("Legendary", 0, false, "miss")).to.be.near(0.25)
			expect(Catching.chance("Secret", 0, false, "miss")).to.be.near(0.20)
		end)

		it("adds 0.10 per gloves level", function()
			expect(Catching.chance("Legendary", 1, false, "miss")).to.be.near(0.35)
			expect(Catching.chance("Legendary", 3, false, "miss")).to.be.near(0.55)
		end)

		it("adds the lure bonus and the ring bonus", function()
			expect(Catching.chance("Legendary", 0, true, "miss")).to.be.near(0.45)
			expect(Catching.chance("Legendary", 0, false, "good")).to.be.near(0.30)
			expect(Catching.chance("Legendary", 0, false, "perfect")).to.be.near(0.40)
			expect(Catching.chance("Legendary", 3, true, "perfect")).to.be.near(0.90)
		end)

		it("never exceeds 0.95 (a cheat client with permanent perfect gains at most 15%)", function()
			expect(Catching.chance("Common", 0, false, "perfect")).to.equal(0.95)
			expect(Catching.chance("Common", 3, true, "perfect")).to.equal(0.95)
			expect(Catching.chance("Rare", 3, true, "perfect")).to.equal(0.95)
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local best = Catching.chance(rarity, 3, true, "perfect")
				local honest = Catching.chance(rarity, 3, true, "miss")
				expect(best - honest <= Config.RingBonusPerfect + 1e-9).to.equal(true)
			end
		end)

		it("never drops below 0.05", function()
			expect(Catching.chance("Secret", 0, false, "miss") >= Config.CatchChanceMin).to.equal(true)
			expect(Config.CatchChanceMin).to.equal(0.05)
			expect(Config.CatchChanceMax).to.equal(0.95)
		end)
	end)

	describe("succeeds", function()
		it("roll strictly below chance wins", function()
			expect(Catching.succeeds(0.5, 0.49)).to.equal(true)
			expect(Catching.succeeds(0.5, 0.5)).to.equal(false)
			expect(Catching.succeeds(0.95, 0.9499)).to.equal(true)
			expect(Catching.succeeds(0.95, 0.95)).to.equal(false)
			expect(Catching.succeeds(0.05, 0)).to.equal(true)
		end)

		it("a chance of 0 can never win, a chance of 1 always does for rolls in [0, 1)", function()
			expect(Catching.succeeds(0, 0)).to.equal(false)
			expect(Catching.succeeds(1, 0.999999)).to.equal(true)
		end)
	end)

	describe("flee on miss (section 10)", function()
		it("Commons stay, everything rarer flees", function()
			expect(Catching.fleesOnMiss("Common")).to.equal(false)
			expect(Catching.fleesOnMiss("Rare")).to.equal(true)
			expect(Catching.fleesOnMiss("Epic")).to.equal(true)
			expect(Catching.fleesOnMiss("Legendary")).to.equal(true)
		end)
	end)

	describe("pickRarity against odds tables (sections 8 and 9)", function()
		local alley = { Common = 75, Rare = 20, Epic = 4.5, Legendary = 0.5 }

		it("maps roll boundaries onto the cumulative odds", function()
			expect(Catching.pickRarity(alley, 0)).to.equal("Common")
			expect(Catching.pickRarity(alley, 0.7499)).to.equal("Common")
			expect(Catching.pickRarity(alley, 0.75)).to.equal("Rare")
			expect(Catching.pickRarity(alley, 0.9499)).to.equal("Rare")
			expect(Catching.pickRarity(alley, 0.95)).to.equal("Epic")
			expect(Catching.pickRarity(alley, 0.99499)).to.equal("Epic")
			expect(Catching.pickRarity(alley, 0.995)).to.equal("Legendary")
			expect(Catching.pickRarity(alley, 0.999999)).to.equal("Legendary")
		end)

		it("clamps out of range rolls instead of erroring", function()
			expect(Catching.pickRarity(alley, -1)).to.equal("Common")
			expect(Catching.pickRarity(alley, 1)).to.equal("Legendary")
			expect(Catching.pickRarity(alley, 7)).to.equal("Legendary")
		end)

		local function distribution(odds: any)
			local counts: { [string]: number } = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Secret = 0 }
			local n = 20000
			for i = 0, n - 1 do
				local rarity = Catching.pickRarity(odds, i / n)
				counts[rarity] += 1
			end
			return counts, n
		end

		local function oddsOf(def: any)
			assert(def ~= nil, "catalog entry missing")
			return def.odds
		end
		local sources: { { any } } = {
			{ "alley", oddsOf(Catalog.getArea("alley")) },
			{ "park", oddsOf(Catalog.getArea("park")) },
			{ "kibble", oddsOf(Catalog.getLure("kibble")) },
			{ "tuna", oddsOf(Catalog.getLure("tuna")) },
			{ "salmon", oddsOf(Catalog.getLure("salmon")) },
		}
		for _, source in ipairs(sources) do
			it(source[1] .. " produces the advertised percentages over an even sweep of rolls", function()
				local counts, n = distribution(source[2])
				for _, rarity in ipairs({ "Common", "Rare", "Epic", "Legendary" }) do
					expect(counts[rarity] / n * 100).to.be.near(source[2][rarity], 0.05)
				end
				expect(counts.Secret).to.equal(0)
			end)
		end
	end)

	describe("candidates and pickCat (section 3 areas)", function()
		local function idList(list: { any })
			local out = {}
			for _, def in ipairs(list) do
				table.insert(out, def.id)
			end
			return out
		end

		it("the alley never offers park-only cats", function()
			expect(idList(Catching.candidates("Rare", "alley"))).to.deepEqual({ "calico", "siamese" })
			expect(idList(Catching.candidates("Epic", "alley"))).to.deepEqual({ "sphynx" })
			expect(idList(Catching.candidates("Legendary", "alley"))).to.deepEqual({ "void" })
			expect(#Catching.candidates("Common", "alley")).to.equal(5)
		end)

		it("the park offers Tortie, Bengal and Ragdoll (F11 done-when)", function()
			expect(idList(Catching.candidates("Rare", "park"))).to.deepEqual({ "calico", "siamese", "tortie", "bengal" })
			expect(idList(Catching.candidates("Epic", "park"))).to.deepEqual({ "sphynx", "ragdoll" })
		end)

		it("pickCat is uniform over the candidates", function()
			local list = Catching.candidates("Rare", "park")
			expect(Catching.pickCat("Rare", "park", 0).id).to.equal(list[1].id)
			expect(Catching.pickCat("Rare", "park", 0.26).id).to.equal(list[2].id)
			expect(Catching.pickCat("Rare", "park", 0.51).id).to.equal(list[3].id)
			expect(Catching.pickCat("Rare", "park", 0.999).id).to.equal(list[4].id)
		end)

		it("pickCat falls down the rarity ladder when the area has nothing of that rarity", function()
			-- No Secret cats exist, so a Secret roll in the alley gives the Legendary.
			expect(Catching.pickCat("Secret", "alley", 0.5).id).to.equal("void")
			expect(Catching.pickCat("Secret", "park", 0.5).id).to.equal("void")
		end)

		it("pickCat never returns nil for any rarity, area and roll", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				for _, area in ipairs({ "alley", "park", "woods" }) do
					for _, roll in ipairs({ 0, 0.5, 0.999999, 1 }) do
						expect(Catching.pickCat(rarity, area, roll)).to.be.ok()
					end
				end
			end
		end)
	end)

	describe("rarityAtLeast and percentText", function()
		it("Epic and Legendary trigger announcements, Rare does not", function()
			expect(Catching.rarityAtLeast("Epic", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Legendary", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Rare", Config.AnnounceMinRarity)).to.equal(false)
			expect(Catching.rarityAtLeast("Common", "Bogus")).to.equal(false)
		end)

		it("percentText rounds to a whole percent", function()
			expect(Catching.percentText(0.45)).to.equal("45%")
			expect(Catching.percentText(0.949)).to.equal("95%")
			expect(Catching.percentText(0.004)).to.equal("0%")
			expect(Catching.percentText(0.005)).to.equal("1%")
			expect(Catching.percentText(1)).to.equal("100%")
		end)
	end)
end
