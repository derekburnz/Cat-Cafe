--!strict
-- shared/AdminWheel.luau (#4195): the Admin Wheel's eight prizes and odds, the pick, the save key one spin an
-- event is marked under, PlayerState.adminWheel and the cat a cat slice gives.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AdminWheel = require(Shared.AdminWheel)
	local CafeEvents = require(Shared.CafeEvents)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Traits = require(Shared.Traits)
	local UpdateGift = require(Shared.UpdateGift)

	local NOW = 1800000000

	local function event(id: string, test: boolean?, startsAt: number?): CafeEvents.AdminEvent
		return {
			id = id,
			title = "Admin Wheel",
			startsAt = startsAt or NOW,
			endsAt = (startsAt or NOW) + 300,
			test = test == true,
			effects = { bowlSpeed = 1, wheel = true },
		}
	end

	describe("the prizes", function()
		it("are the eight of the spec, with odds that sum to 100", function()
			local odds: { [string]: number } = {}
			local sum = 0
			for _, prize in AdminWheel.PRIZES do
				odds[prize.id] = prize.weight
				sum += prize.weight
				expect(#prize.name > 0).to.equal(true)
				expect(AdminWheel.get(prize.id)).to.equal(prize)
			end
			expect(sum).to.equal(100)
			expect(odds).to.deepEqual({
				rerolls20 = 22,
				fish200 = 22,
				crates5 = 15,
				potions = 15,
				money3x = 10,
				mythical = 8,
				mega = 6,
				secret = 2,
			})
			expect(AdminWheel.get("nope")).to.equal(nil)
		end)

		it("pay what they say, in things the game already pays", function()
			local function of(id: string): any
				return AdminWheel.get(id)
			end
			expect(of("rerolls20").tokens).to.equal(20)
			expect(of("fish200").prize).to.deepEqual({ fish = 200 })
			expect(of("crates5").prize).to.deepEqual({ crates = { highest_golden = 5 } })
			expect(of("potions").prize).to.deepEqual({
				potions = { big_tip_potion = 10, lucky_potion = 10, swift_potion = 10 },
			})
			expect(of("mega").tokens).to.equal(50)
			expect(of("mega").prize).to.deepEqual({ fish = 500 })
			expect(of("mythical").cat).to.equal("mythical")
			expect(of("secret").cat).to.equal("secret")
			-- the hour of 3x money is a potion the wheel starts
			local boost = Catalog.getPotion(of("money3x").boost) :: any
			expect(boost.id).to.equal(AdminWheel.BOOST)
			expect(boost.minutes).to.equal(60)
			expect(boost.tipsOver).to.equal(2)
			for _, prize in AdminWheel.PRIZES do
				local row: any = prize
				for potionId in (if row.prize ~= nil then row.prize.potions or {} else {}) do
					expect(Catalog.getPotion(potionId)).to.be.ok()
				end
				-- no coins, nothing bought and nothing that costs Robux
				expect(if row.prize ~= nil then row.prize.coins else nil).to.equal(nil)
			end
			-- the reroll prizes fit the Trait Token bank
			expect(Traits.TOKEN_MAX >= 50).to.equal(true)
		end)

		it("picks each slice over its share of the roll", function()
			local counts: { [string]: number } = {}
			local steps = 10000
			for i = 0, steps - 1 do
				local prize, slice = AdminWheel.pick((i + 0.5) / steps)
				expect(AdminWheel.PRIZES[slice]).to.equal(prize)
				counts[prize.id] = (counts[prize.id] or 0) + 1
			end
			for _, prize in AdminWheel.PRIZES do
				expect(counts[prize.id]).to.equal(prize.weight * steps / 100)
			end
			expect(AdminWheel.pick(0)).to.equal(AdminWheel.PRIZES[1])
			expect(AdminWheel.pick(0.999999)).to.equal(AdminWheel.PRIZES[#AdminWheel.PRIZES])
			-- a roll outside [0, 1) never errors
			expect(AdminWheel.pick(1)).to.equal(AdminWheel.PRIZES[#AdminWheel.PRIZES])
			expect(AdminWheel.pick(-1)).to.equal(AdminWheel.PRIZES[1])
		end)
	end)

	describe("one spin an account for each event", function()
		it("marks a spin under a key the save keeps and the Codes list hides", function()
			local ids = {
				"wheel-1115",
				"wheel-1116",
				CafeEvents.OWNER_ADMIN_PREFIX .. tostring(NOW),
				CafeEvents.OWNER_ADMIN_PREFIX .. tostring(NOW + 1),
				"a",
				string.rep("long-id-", 8),
			}
			local seen: { [string]: boolean } = {}
			for _, id in ids do
				local key = AdminWheel.key(event(id))
				expect(key).to.equal(AdminWheel.key(event(id))) -- the same on every server
				expect(seen[key]).to.equal(nil)
				seen[key] = true
				expect(#key <= Config.CodeMaxLength).to.equal(true)
				expect(string.match(key, "^%w+$") ~= nil).to.equal(true)
				expect(UpdateGift.isKey(key)).to.equal(true)
				-- it comes back from a save as it went in
				local raw: any = ProfileSchema.template(NOW)
				raw.codesRedeemed[key] = NOW
				local loaded = ProfileSchema.migrate(raw, NOW)
				expect(loaded.codesRedeemed[key]).to.equal(NOW)
			end
			-- no real code starts as these keys do
			for _, code in Catalog.codes do
				expect(UpdateGift.isKey(code.id)).to.equal(false)
			end
		end)

		it("counts a spin for its own event only", function()
			local redeemed: { [string]: number } = {}
			local first, second = event("wheel-1115"), event("wheel-1116")
			expect(AdminWheel.spun(redeemed, first)).to.equal(false)
			redeemed[AdminWheel.key(first)] = NOW
			expect(AdminWheel.spun(redeemed, first)).to.equal(true)
			expect(AdminWheel.spun(redeemed, second)).to.equal(false)
			-- a real event's key does not move with its times
			expect(AdminWheel.key(event("wheel-1115", false, NOW + 60))).to.equal(
				AdminWheel.key(first)
			)
			-- every run of the one-server test is its own wheel
			local testA = event("test-admin-wheel", true, NOW)
			local testB = event("test-admin-wheel", true, NOW + 600)
			expect(AdminWheel.key(testA) ~= AdminWheel.key(testB)).to.equal(true)
			expect(AdminWheel.key(testA)).to.equal(
				AdminWheel.key(event("test-admin-wheel", true, NOW))
			)
		end)

		it("shows the wheel that is up, and whether it was spun", function()
			local redeemed: { [string]: number } = {}
			local up = event("wheel-1115")
			expect(AdminWheel.view(redeemed, up, true)).to.deepEqual({
				eventId = "wheel-1115",
				spun = false,
				endsAt = NOW + 300,
			})
			redeemed[AdminWheel.key(up)] = NOW
			expect((AdminWheel.view(redeemed, up, true) :: any).spun).to.equal(true)
			-- none with the switch off, no admin event, or Bowl Frenzy alone
			expect(AdminWheel.view(redeemed, up, false)).to.equal(nil)
			expect(AdminWheel.view(redeemed, nil, true)).to.equal(nil)
			local bowl = event("frenzy-1115")
			bowl.effects = { bowlSpeed = 4, wheel = false }
			expect(AdminWheel.view(redeemed, bowl, true)).to.equal(nil)
		end)
	end)

	describe("the cat slices", function()
		local mythical = AdminWheel.get("mythical") :: AdminWheel.Prize
		local secret = AdminWheel.get("secret") :: AdminWheel.Prize

		it("give a Mythical of the newest area the player has opened", function()
			local topTier = 0
			for _, area in Catalog.areas do
				topTier = math.max(topTier, area.tier)
			end
			for tier = 1, topTier do
				local pool = AdminWheel.mythicals(tier)
				expect(#pool > 0).to.equal(true)
				local areaTier = (Catalog.getArea(pool[1].area :: string) :: any).tier
				expect(areaTier <= tier).to.equal(true)
				for _, def in pool do
					expect(def.rarity).to.equal("Mythical")
					expect(def.exclusive).never.to.equal(true)
					expect(def.area).to.equal(pool[1].area)
				end
				-- no newer opened area has a Mythical of its own
				for _, area in Catalog.areas do
					if area.tier <= tier and area.tier > areaTier then
						for _, def in Catalog.cats do
							expect(def.area == area.id and def.rarity == "Mythical").to.equal(false)
						end
					end
				end
				for _, roll in { 0, 0.5, 0.999999, 1 } do
					local def = AdminWheel.catFor(mythical, tier, true, roll) :: any
					expect(table.find(pool, def) ~= nil).to.equal(true)
				end
			end
			expect((AdminWheel.catFor(mythical, 1, true, 0) :: any).area).to.equal("alley")
		end)

		it("give a Secret cat only while Secret cats are switched on", function()
			expect(#Catalog.secretCats > 0).to.equal(true)
			local seen: { [string]: boolean } = {}
			for i = 0, 99 do
				local def = AdminWheel.catFor(secret, 3, true, i / 100) :: any
				expect(def.rarity).to.equal("Secret")
				seen[def.id] = true
			end
			for _, def in Catalog.secretCats do
				expect(seen[def.id]).to.equal(true)
			end
			-- switched off: the Mythical instead, never nothing
			local fallback = AdminWheel.catFor(secret, 3, false, 0.5) :: any
			expect(fallback.rarity).to.equal("Mythical")
			-- a slice with no cat gives none
			expect(AdminWheel.catFor(AdminWheel.PRIZES[1], 3, true, 0.5)).to.equal(nil)
		end)
	end)
end
