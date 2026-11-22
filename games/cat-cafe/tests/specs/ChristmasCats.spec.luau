--!strict
-- #5665: the Christmas Event's 8 cats (snowglobe-village-spec section 4) and the event areas they share with Harvest.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any
	local Catching = require(Shared:WaitForChild("Catching")) :: any
	local DragonKeep = require(Shared:WaitForChild("DragonKeep")) :: any
	local Economy = require(Shared:WaitForChild("Economy")) :: any
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema")) :: any

	describe("Christmas cats", function()
		it("are the spec's 8, with Harvest's rarity shape", function()
			local ids = {}
			local shape: { [string]: number } = {}
			for _, def in Catalog.christmasCats do
				table.insert(ids, def.id)
				shape[def.rarity] = (shape[def.rarity] or 0) + 1
				expect(def.area).to.equal("snowglobe")
				expect(def.earnsLike).to.equal(Catalog.HARVEST_EARNS_LIKE[def.rarity])
			end
			expect(#ids).to.equal(8)
			for _, id in
				{
					"gingerbread",
					"snowball",
					"candy_cane",
					"tinsel",
					"jingle",
					"mistletoe",
					"sugar_plum",
					"star_topper",
				}
			do
				expect(table.find(ids, id)).to.be.ok()
			end
			expect(shape.Common).to.equal(2)
			expect(shape.Rare).to.equal(3)
			expect(shape.Epic).to.equal(1)
			expect(shape.Legendary).to.equal(1)
			expect(shape.Mythical).to.equal(1)
			expect(Catalog.catModelName("star_topper")).to.equal("CatCafe_Cat_StarTopper")
		end)

		it("are an event area's cats, as Harvest's are, and no one of the ten", function()
			expect(Catalog.isEventArea("snowglobe")).to.equal(true)
			expect(Catalog.isEventArea("harvest")).to.equal(true)
			expect(Catalog.isEventArea("alley")).to.equal(false)
			expect(Catalog.isEventArea(nil)).to.equal(false)
			expect(Catalog.getArea("snowglobe")).to.equal(nil)
		end)

		it("spawn nowhere but Snowglobe Village", function()
			for _, area in Catalog.areas do
				for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
					for _, def in Catching.candidates(rarity, area.id) do
						expect(def.area).never.to.equal("snowglobe")
					end
				end
			end
			expect(#Catching.candidates("Rare", "snowglobe")).to.equal(3)
		end)

		it("count toward no different kinds, and stay out of the Dragon Keep", function()
			local profile = ProfileSchema.migrate({}, os.time())
			local before = Economy.distinctCats(profile)
			profile.collection.jingle = { count = 1 }
			expect(Economy.distinctCats(profile)).to.equal(before)
			expect(DragonKeep.eventCat("jingle")).to.equal(true)
			expect(DragonKeep.eventCat("star_topper")).to.equal(true)
			expect(DragonKeep.eventCat("sugar_plum")).to.equal(true)
			expect(DragonKeep.eventCat("tabby")).to.equal(false)
		end)
	end)
end
