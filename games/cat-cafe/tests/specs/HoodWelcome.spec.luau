--!strict
-- shared/HoodWelcome: who gets the first Neighbourhood landing's stray, its rarity, once per account (#5652).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local HoodWelcome = require(Shared:WaitForChild("HoodWelcome")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any
	local Catching = require(Shared:WaitForChild("Catching")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema")) :: any

	local function profileAt(tier: number): any
		local profile = ProfileSchema.migrate({}, os.time())
		profile.tier = tier
		return profile
	end

	local function ownAll(collection: { [string]: any }, rarity: string?)
		for _, def in Catalog.cats do
			if def.area == HoodWelcome.AREA and (rarity == nil or def.rarity == rarity) then
				collection[def.id] = { count = 1 }
			end
		end
	end

	describe("HoodWelcome", function()
		it("is off by default and has a Neighbourhood to welcome to", function()
			expect(LiveFlags.defaults()[HoodWelcome.FLAG]).never.to.equal(true)
			expect(Catalog.getArea(HoodWelcome.AREA)).to.be.ok()
		end)

		it("is due from Tier 3 with the switch on, once per account", function()
			expect(HoodWelcome.due(profileAt(2), true)).to.equal(false)
			expect(HoodWelcome.due(profileAt(3), false)).to.equal(false)
			local profile = profileAt(3)
			expect(HoodWelcome.due(profile, true)).to.equal(true)
			expect(HoodWelcome.due(profileAt(4), true)).to.equal(true)
			profile.stats.hoodWelcome = 1
			expect(HoodWelcome.due(profile, true)).to.equal(false)
		end)

		it("keeps the once through a save round trip", function()
			local profile = profileAt(3)
			profile.stats.hoodWelcome = 1
			local again = ProfileSchema.migrate(profile, os.time())
			expect(again.stats.hoodWelcome).to.equal(1)
			expect(profileAt(3).stats.hoodWelcome).to.equal(0)
		end)

		it("rolls the area's odds over the rarities with a kind still missing", function()
			local odds = Catalog.getArea(HoodWelcome.AREA).odds
			local collection: { [string]: any } = {}
			expect(HoodWelcome.rarity(collection, odds, 0)).to.equal("Common")
			ownAll(collection, "Common")
			for _, roll in { 0, 0.3, 0.6, 0.99, 1 } do
				local rarity = HoodWelcome.rarity(collection, odds, roll)
				expect(rarity).to.be.ok()
				expect(rarity).never.to.equal("Common")
				-- and that rarity really has a kind the player lacks, which pickNewCat finds
				local def = Catching.pickNewCat(rarity, HoodWelcome.AREA, roll, collection)
				expect(collection[def.id]).to.equal(nil)
			end
		end)

		it("brings nothing once every Neighbourhood kind is owned", function()
			local collection: { [string]: any } = {}
			expect(HoodWelcome.lacks(collection)).to.equal(true)
			ownAll(collection, nil)
			expect(HoodWelcome.lacks(collection)).to.equal(false)
			local odds = Catalog.getArea(HoodWelcome.AREA).odds
			expect(HoodWelcome.rarity(collection, odds, 0.5)).to.equal(nil)
		end)
	end)
end
