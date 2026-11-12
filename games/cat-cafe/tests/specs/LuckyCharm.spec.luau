--!strict
-- #3298 (new-activities.md section 5): the Lucky Charm, a Golden Fish Market perk that adds overall Luck
-- (shared/LuckyCharm, shared/Luck's "charm" source), behind the `luckyCharm` switch.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Bait = require(Shared.Bait)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)
	local LiveFlags = require(Shared.LiveFlags)
	local Luck = require(Shared.Luck)
	local LuckyCharm = require(Shared.LuckyCharm)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local NOW = 100000

	local function fresh(): Types.PlayerProfile
		return ProfileSchema.template(NOW)
	end

	describe("LuckyCharm (#3298)", function()
		it("is a three level perk for 100, 250 and 500 golden fish", function()
			local row = Catalog.getFishShopRow(LuckyCharm.ID)
			assert(row and row.costs)
			expect(row.kind).to.equal("perk")
			expect(row.maxLevel).to.equal(LuckyCharm.MAX_LEVEL)
			expect(#row.costs).to.equal(3)
			expect(row.costs[1]).to.equal(100)
			expect(row.costs[2]).to.equal(250)
			expect(row.costs[3]).to.equal(500)
			local profile = fresh()
			profile.goldenFish = 99
			expect(Crates.buyCost(profile, row)).never.to.be.ok()
			profile.goldenFish = 100
			expect(Crates.buyCost(profile, row)).to.equal(100)
			profile.fishPerks[LuckyCharm.ID] = 3
			profile.goldenFish = 100000
			expect(Crates.buyCost(profile, row)).never.to.be.ok()
		end)

		it("adds a statue level's Luck a level, and nothing past level 3", function()
			expect(LuckyCharm.PER_LEVEL).to.equal(Config.LuckPerStatueLevel)
			expect(LuckyCharm.luckAt(0)).to.equal(0)
			expect(LuckyCharm.luckAt(1)).to.equal(0.1)
			expect(LuckyCharm.luckAt(2)).to.equal(0.2)
			expect(LuckyCharm.luckAt(3)).to.equal(0.3)
			expect(LuckyCharm.luckAt(9)).to.equal(0.3)
			expect(LuckyCharm.luckAt(-2)).to.equal(0)
		end)

		it("adds no Luck while the switch is off or unread", function()
			local profile = fresh()
			profile.fishPerks[LuckyCharm.ID] = 3
			expect(LuckyCharm.bonus(profile, false)).to.equal(0)
			expect(LuckyCharm.bonus(profile, nil)).to.equal(0)
			expect(LuckyCharm.bonus(nil, true)).to.equal(0)
			expect(#Luck.sources(profile, NOW, false)).to.equal(0)
			expect(#Luck.sources(profile, NOW, false, 0, false)).to.equal(0)
			expect(Luck.of(profile, NOW, false)).to.equal(1)
			expect(Luck.of(profile, NOW, false, 0, false)).to.equal(1)
		end)

		it("is a Luck source after the statue while the switch is on", function()
			local profile = fresh()
			expect(#Luck.sources(profile, NOW, false, 0, true)).to.equal(0)
			for level = 1, 3 do
				profile.fishPerks[LuckyCharm.ID] = level
				local sources = Luck.sources(profile, NOW, false, 0, true)
				expect(#sources).to.equal(1)
				expect(sources[1].id).to.equal("charm")
				expect(sources[1].value).to.equal(level / 10)
				expect(Luck.of(profile, NOW, false, 0, true)).to.equal(1 + level / 10)
			end
			profile.upgradeLevels[Luck.UPGRADE] = 2
			profile.buffs[Potions.LUCKY] = 600
			local sources = Luck.sources(profile, NOW, true, 0.5, true)
			expect(#sources).to.equal(5)
			expect(sources[1].id).to.equal("statue")
			expect(sources[2].id).to.equal("charm")
			expect(sources[3].id).to.equal("potion")
			expect(sources[4].id).to.equal("lucky_day")
			expect(sources[5].id).to.equal("event")
		end)

		it("never lifts Luck past LuckMax", function()
			local profile = fresh()
			profile.fishPerks[LuckyCharm.ID] = 3
			profile.upgradeLevels[Luck.UPGRADE] = 99
			profile.buffs[Potions.LUCKY] = 600
			expect(Luck.of(profile, NOW, true, 9, true)).to.equal(Config.LuckMax)
		end)

		it("moves the bait odds by exactly its Luck and keeps their total", function()
			local profile = fresh()
			profile.fishPerks[LuckyCharm.ID] = 3
			local base = Bait.oddsFor(Catalog.lures[1].odds, 1)
			local off = Luck.apply(base, Luck.of(profile, NOW, false, 0, false))
			local on = Luck.apply(base, Luck.of(profile, NOW, false, 0, true))
			expect(off.Epic).to.be.near(base.Epic, 1e-9)
			expect(on.Epic).to.be.near(base.Epic * 1.3, 1e-9)
			expect(on.Mythical).to.be.near(base.Mythical * 1.3, 1e-9)
			expect(on.Common + on.Rare + on.Epic + on.Legendary + on.Mythical).to.be.near(
				base.Common + base.Rare + base.Epic + base.Legendary + base.Mythical,
				1e-9
			)
		end)

		it("keeps a saved level through a load, capped at the top level", function()
			local raw: any = ProfileSchema.template(NOW)
			raw.fishPerks = { [LuckyCharm.ID] = 7 }
			local loaded = ProfileSchema.migrate(raw, NOW)
			expect(loaded.fishPerks[LuckyCharm.ID]).to.equal(3)
		end)

		it("waits behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, LuckyCharm.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[LuckyCharm.FLAG]).to.equal(true)
			expect(LiveFlags.shown(LuckyCharm.FLAG, nil)).to.equal(false)
			expect(LiveFlags.shown(LuckyCharm.FLAG, true)).to.equal(true)
		end)
	end)
end
