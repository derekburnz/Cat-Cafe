--!strict
-- SellExtras.luau (#1573, "Sell extra Commons, keeping one of each"): the best Common of each kind stays, and so do
-- working, locked, gold, rainbow and on-offer cats, and the last cat; the rest are sold at the Common sellValue.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Catalog = require(Shared.Catalog)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SellExtras = require(Shared.SellExtras)

	local VALUE = Catalog.rarities.Common.sellValue

	-- The first two Common, non-exclusive kinds, and a Rare one.
	local commons: { string } = {}
	local rare: string? = nil
	for _, def in Catalog.cats do
		if def.exclusive ~= true then
			if def.rarity == "Common" and #commons < 2 then
				table.insert(commons, def.id)
			elseif def.rarity == "Rare" and rare == nil then
				rare = def.id
			end
		end
	end
	local A, B = commons[1], commons[2]

	local function profile(): any
		local p = ProfileSchema.template(0)
		p.cats = {}
		return p
	end

	local function add(p: any, uid: string, catId: string, charm: number?, extra: { [string]: any }?)
		local instance: any = CatStats.newInstance(uid, catId, 0, charm)
		for key, value in extra or {} do
			instance[key] = value
		end
		p.cats[uid] = instance
		return instance
	end

	it("keeps the best of each Common kind and sells the rest", function()
		local p = profile()
		add(p, "a1", A, 20)
		add(p, "a2", A, 90) -- the best A stays
		add(p, "a3", A, 50)
		add(p, "b1", B, 40) -- the only B stays
		add(p, "r1", rare :: string, 10)
		add(p, "r2", rare :: string, 20) -- Rares are never extras
		local plan = SellExtras.plan(p, 1)
		expect(plan.uids).to.deepEqual({ "a1", "a3" })
		expect(plan.coins).to.equal(2 * VALUE)
	end)

	it("keeps a working cat as its kind's one, and never sells a working cat", function()
		local p = profile()
		add(p, "a1", A, 20, { spotId = "greeter_1" })
		add(p, "a2", A, 90)
		add(p, "a3", A, 50, { spotId = "barista_1" })
		expect(SellExtras.plan(p, 1).uids).to.deepEqual({ "a2" })
	end)

	it("never sells locked, gold, rainbow or on-offer cats", function()
		local p = profile()
		add(p, "a1", A, 90)
		add(p, "a2", A, 10, { locked = true })
		add(p, "a3", A, 10, { variant = "gold" })
		add(p, "a4", A, 10, { variant = "rainbow" })
		add(p, "a5", A, 10)
		add(p, "a6", A, 10)
		local plan = SellExtras.plan(p, 1, function(uid: string): boolean
			return uid == "a6"
		end)
		expect(plan.uids).to.deepEqual({ "a5" })
	end)

	it("has nothing to sell with one of each, and never empties the cafe", function()
		local p = profile()
		add(p, "a1", A, 50)
		add(p, "b1", B, 50)
		expect(#SellExtras.plan(p, 1).uids).to.equal(0)
		expect(SellExtras.plan(p, 1).coins).to.equal(0)
		expect(#SellExtras.plan(profile(), 1).uids).to.equal(0)
	end)
end
