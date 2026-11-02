--!strict
-- shared/DecorBest.luau: Equip Best for decor (Derek 2026-10-28: "Equip Best for decor (highest rarity)").
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)
	local DecorBest = require(Shared.DecorBest)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function fresh(): any
		local p: any = ProfileSchema.template(1000)
		p.decorOwned = {}
		p.decorPlaced = {}
		return p
	end

	-- the crate pieces of `kind` at `rarity`, by id
	local function pieces(kind: string, rarity: string): { string }
		local ids: { string } = {}
		for _, def in Catalog.crateDecor do
			if def.kind == kind and def.rarity == rarity then
				table.insert(ids, def.id)
			end
		end
		table.sort(ids)
		return ids
	end

	local function count(set: { [string]: boolean }): number
		local n = 0
		for _ in set do
			n += 1
		end
		return n
	end

	describe("furniture and decorations", function()
		it(
			"puts out the rarest owned pieces up to the decor spots and puts the rest away",
			function()
				local p = fresh()
				local common = pieces("furniture", "Common")
				local legendary = pieces("decoration", "Legendary")
				local epic = pieces("furniture", "Epic")
				expect(#common >= 2 and #legendary >= 1 and #epic >= 1).to.equal(true)
				for _, id in { common[1], common[2], legendary[1], epic[1] } do
					p.decorOwned[id] = true
				end
				p.decorPlaced[common[1]] = true
				p.decorPlaced[common[2]] = true
				local plan = DecorBest.plan(p, 2)
				expect(plan.placed :: any).to.deepEqual({ [legendary[1]] = true, [epic[1]] = true })
				expect(plan.pieces).to.equal(2)
				local want = Config.CratePieceBonus.Legendary + Config.CratePieceBonus.Epic
				expect(plan.bonus).to.be.near(want, 1e-9)
				expect(DecorBest.isSame(p, plan)).to.equal(false)
			end
		)

		it(
			"keeps a piece already out on a tie, never takes more than the spots and never an unowned piece",
			function()
				local p = fresh()
				local rares = pieces("furniture", "Rare")
				expect(#rares >= 3).to.equal(true)
				p.decorOwned[rares[1]] = true
				p.decorOwned[rares[3]] = true
				p.decorPlaced[rares[3]] = true
				p.decorPlaced[rares[2]] = true -- placed but not owned: never comes back out
				local plan = DecorBest.plan(p, 1)
				expect(plan.placed :: any).to.deepEqual({ [rares[3]] = true })
				expect(count(DecorBest.plan(p, 0).placed)).to.equal(0)
				expect(count(DecorBest.plan(p, 5).placed)).to.equal(2)
			end
		)

		it("fills the tier's spots as Crates counts them", function()
			local p = fresh()
			for _, def in Catalog.crateDecor do
				if Crates.takesSpot(def) then
					p.decorOwned[def.id] = true
				end
			end
			local cap = Crates.spotCap(5, 0)
			local plan = DecorBest.plan(p, cap)
			p.decorPlaced = plan.placed
			expect(Crates.spotsUsed(p, {})).to.equal(cap)
			expect(DecorBest.isSame(p, DecorBest.plan(p, cap))).to.equal(true)
		end)
	end)

	describe("wallpaper, floor, paint, door and cat flap", function()
		it("uses the owned style with the most money, one of each kind", function()
			-- a style kind with a cheaper and a dearer piece
			local low: any, high: any = nil, nil
			for _, kind in { "floor", "wallpaper", "paint", "door", "catflap" } do
				for _, def in Catalog.crateDecor do
					if def.kind == kind then
						if low == nil or def.bonus < low.bonus then
							low = def
						end
						if high == nil or def.bonus > high.bonus then
							high = def
						end
					end
				end
				if low ~= nil and high ~= nil and high.bonus > low.bonus then
					break
				end
				low, high = nil, nil
			end
			expect(low).to.be.ok()
			local p = fresh()
			p.decorOwned[low.id] = true
			p.decorOwned[high.id] = true
			p.decorPlaced[low.id] = true
			local plan = DecorBest.plan(p, 0)
			expect(plan.placed :: any).to.deepEqual({ [high.id] = true })
			p.decorPlaced = plan.placed
			expect(Crates.styleInUse(p, high.kind)).to.equal(high.id)
		end)

		it(
			"keeps the style in use when nothing beats it, so the look only changes for more money",
			function()
				local p = fresh()
				local rareWalls = pieces("wallpaper", "Rare")
				expect(#rareWalls >= 2).to.equal(true)
				p.decorOwned[rareWalls[1]] = true
				p.decorOwned[rareWalls[2]] = true
				p.decorPlaced[rareWalls[2]] = true
				local plan = DecorBest.plan(p, 0)
				expect(plan.placed :: any).to.deepEqual({ [rareWalls[2]] = true })
				expect(DecorBest.isSame(p, plan)).to.equal(true)
			end
		)
	end)

	describe("the old coin pieces", function()
		it("puts out every owned one, since they take no spot", function()
			local p = fresh()
			local old: { string } = {}
			for _, def in Catalog.decor do
				if def.kind == nil then
					table.insert(old, def.id)
					p.decorOwned[def.id] = true
				end
			end
			expect(#old > 0).to.equal(true)
			local plan = DecorBest.plan(p, 0)
			expect(plan.pieces).to.equal(#old)
			for _, id in old do
				expect(plan.placed[id]).to.equal(true)
			end
		end)

		it("has nothing to put out without decor", function()
			local plan = DecorBest.plan(fresh(), 6)
			expect(plan.pieces).to.equal(0)
			expect(plan.bonus).to.equal(0)
		end)
	end)
end
