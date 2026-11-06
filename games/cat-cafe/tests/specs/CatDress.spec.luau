--!strict
-- CatDress.plan against features.md F71 and data-model section 5: a working cat leaves off the role pieces in the
-- slots its props take, and an Entertainer with a Head and a Back prop wears the party hat in place of its head prop.
-- The F78 cats with two props (Model-Agent #557): Jazz, Gardener and Plumber Head and Back, Gnome Head and Face.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatDress = require(Shared.CatDress)

	local function wears(role: string, propSlot: string?, propSlot2: string?): (string, string?)
		local pieces, offProp = CatDress.plan(role, propSlot, propSlot2)
		return table.concat(pieces, ","), offProp
	end

	describe("plan (F71)", function()
		it("a cat with no prop wears its role's whole outfit", function()
			expect((wears("barista"))).to.equal("Apron,BaristaCap")
			expect((wears("waiter"))).to.equal("BowTie,Vest")
			expect((wears("greeter"))).to.equal("Sash,Boater")
			expect((wears("entertainer"))).to.equal("PartyHat,Cape")
		end)

		it("one prop leaves off the piece in its slot, and a Face prop clashes with nothing", function()
			expect((wears("barista", "Head"))).to.equal("Apron")
			expect((wears("entertainer", "Back"))).to.equal("PartyHat")
			expect((wears("greeter", "Face"))).to.equal("Sash,Boater")
		end)

		it("a second prop leaves off the piece in its slot too", function()
			expect((wears("barista", "Head", "Back"))).to.equal("Apron")
			expect((wears("greeter", "Head", "Back"))).to.equal("Sash")
			expect((wears("waiter", "Head", "Back"))).to.equal("BowTie,Vest")
			expect((wears("entertainer", "Head", "Face"))).to.equal("Cape")
		end)

		it("an Entertainer with a Head and a Back prop swaps its head prop for the party hat", function()
			local pieces, offProp = wears("entertainer", "Head", "Back")
			expect(pieces).to.equal("PartyHat")
			expect(offProp).to.equal("Prop")
			pieces, offProp = wears("entertainer", "Back", "Head")
			expect(pieces).to.equal("PartyHat")
			expect(offProp).to.equal("Prop2")
		end)

		it("no other role or slot pair takes a prop off, and an unknown role wears nothing", function()
			for _, role in { "barista", "waiter", "greeter" } do
				local _, offProp = wears(role, "Head", "Back")
				expect(offProp).to.equal(nil)
			end
			local _, offProp = wears("entertainer", "Head")
			expect(offProp).to.equal(nil)
			expect((wears("juggler", "Head", "Back"))).to.equal("")
		end)
	end)

	-- Model-Agent #787: walking cuts of the waistcoat, sash and apron for F90's walking staff (Effects/CafeWalk).
	describe("walking cuts (F90)", function()
		local function body(name: string, pose: string?): any
			local self: any = { Name = name }
			function self.GetAttribute(_this: any, key: string): any
				return if key == "Pose" then pose else nil
			end
			return self
		end

		it("tells a walking body from a seated one by Pose or the _Sit name", function()
			expect(CatDress.isWalking(body("CafeWalker"))).to.equal(true)
			expect(CatDress.isWalking(body("CatCafe_Cat_Tabby"))).to.equal(true)
			expect(CatDress.isWalking(body("cat_7f3a", "sit"))).to.equal(false)
			expect(CatDress.isWalking(body("CatCafe_Cat_Tabby_Sit"))).to.equal(false)
			expect(CatDress.isWalking(body("CatCafe_Cat_Tabby_Gold_Sit"))).to.equal(false)
			-- the standing worker (S) has the seated body's chest, so it wears the seated cuts
			expect(CatDress.isWalking(body("cat_7f3a", "work"))).to.equal(false)
			expect(CatDress.isWalking(body("CatCafe_Cat_Tabby_Work"))).to.equal(false)
			expect(CatDress.isWalking(body("CatCafe_Cat_Tabby_Gold_Work"))).to.equal(false)
		end)

		it("tries the walking cut first on a walking body and the seated cut first on a seated one", function()
			expect(table.concat(CatDress.assetNames("Vest", true), ",")).to.equal(
				"CatCafe_Accessory_Vest_Walk,CatCafe_Accessory_Vest"
			)
			-- #1624: a seated cut (only the Tiny Lantern has one) else the plain piece
			expect(table.concat(CatDress.assetNames("Vest", false), ",")).to.equal(
				"CatCafe_Accessory_Vest_Sit,CatCafe_Accessory_Vest"
			)
		end)
	end)

	-- Model-Agent #826, Derek's pick of 2026-11-02: working cats stand on the worker body (S), posed by the manifest's
	-- cat_poses.work_<role>, each holding its role's thing.
	describe("the standing worker", function()
		local Catalog = require(Shared.Catalog)

		it("poses both front legs of every role, in the manifest's numbers", function()
			for role in Catalog.roleOutfits do
				local arms = CatDress.WORK_ARMS[role]
				expect(arms).to.be.ok()
				for _, leg in { "LegF1", "LegF2" } do
					expect(#arms[leg]).to.equal(3)
				end
			end
			expect(table.concat(CatDress.WORK_ARMS.barista.LegF2, ",")).to.equal("57.5,21.5,13.1")
			expect(table.concat(CatDress.WORK_ARMS.waiter.LegF1, ",")).to.equal("37.5,-27,-30.7")
			expect(table.concat(CatDress.WORK_ARMS.greeter.LegF1, ",")).to.equal("172.4,13,-59.1")
			expect(table.concat(CatDress.WORK_ARMS.entertainer.LegF1, ",")).to.equal("9.9,-1,-5.9")
			expect(table.concat(CatDress.WORK_ARMS.entertainer.LegF2, ",")).to.equal("18,84,30") -- #901, Derek's A
		end)

		it("keeps only the role's own held thing, and none for a greeter", function()
			expect(table.concat(CatDress.heldOff("barista"), ",")).to.equal("Held_Waiter,Held_Entertainer")
			expect(table.concat(CatDress.heldOff("waiter"), ",")).to.equal("Held_Barista,Held_Entertainer")
			expect(table.concat(CatDress.heldOff("entertainer"), ",")).to.equal("Held_Barista,Held_Waiter")
			expect(table.concat(CatDress.heldOff("greeter"), ",")).to.equal("Held_Barista,Held_Waiter,Held_Entertainer")
		end)

		it("names the worker after the walking model", function()
			expect(Catalog.workModelName("CatCafe_Cat_Tabby")).to.equal("CatCafe_Cat_Tabby_Work")
			expect(Catalog.workModelName("CatCafe_Cat_Tabby_Gold")).to.equal("CatCafe_Cat_Tabby_Gold_Work")
		end)
	end)

	describe("uniform styles (#1624)", function()
		it("puts the main colour on the biggest surface and the trim on the next, leaving the rest", function()
			-- the Boater: straw over most of it, a red band, a cream bow
			local slots = CatDress.uniformSlots({ e3b77a = 1.47, d9483b = 0.42, fff9f2 = 0.02 })
			expect(slots :: any).to.deepEqual({ e3b77a = "main", d9483b = "trim" })
		end)

		it("gives a one-colour piece only the main and an empty piece nothing", function()
			expect(CatDress.uniformSlots({ e8a0a0 = 0.24 }) :: any).to.deepEqual({ e8a0a0 = "main" })
			expect(CatDress.uniformSlots({}) :: any).to.deepEqual({})
		end)

		it("breaks a tie by the smaller key, the same every time", function()
			expect(CatDress.uniformSlots({ b = 1, a = 1, c = 0.5 }) :: any).to.deepEqual({ a = "main", b = "trim" })
		end)
	end)

	describe("the cafe's accessory (#1624 section 6)", function()
		it("puts a Head accessory on in place of the role hat", function()
			local wear, off, on = CatDress.plan("barista", nil, nil, "Head")
			expect(table.concat(wear, ",")).to.equal("Apron")
			expect(off).to.equal(nil)
			expect(on).to.equal(true)
		end)

		it("puts a Back accessory on in place of the cape, and a Face one beside the whole outfit", function()
			local wear, _, on = CatDress.plan("entertainer", nil, nil, "Back")
			expect(table.concat(wear, ",")).to.equal("PartyHat")
			expect(on).to.equal(true)
			local fwear, _, fon = CatDress.plan("waiter", nil, nil, "Face")
			expect(table.concat(fwear, ",")).to.equal("BowTie,Vest")
			expect(fon).to.equal(true)
		end)

		it("skips the accessory on a cat whose own prop fills its slot", function()
			local wear, _, on = CatDress.plan("greeter", "Head", nil, "Head")
			expect(table.concat(wear, ",")).to.equal("Sash")
			expect(on).to.equal(false)
			-- the Entertainer with a Head and a Back prop keeps its party hat exception and skips a Head accessory
			local ewear, eoff, eon = CatDress.plan("entertainer", "Head", "Back", "Head")
			expect(table.concat(ewear, ",")).to.equal("PartyHat")
			expect(eoff).to.equal("Prop")
			expect(eon).to.equal(false)
		end)

		it("wears the plain outfit with no accessory", function()
			local wear, _, on = CatDress.plan("barista", nil, nil, nil)
			expect(table.concat(wear, ",")).to.equal("Apron,BaristaCap")
			expect(on).to.equal(false)
		end)

		it("tries a seated cut first on a seated body", function()
			expect(table.concat(CatDress.assetNames("TinyLantern", false), ",")).to.equal(
				"CatCafe_Accessory_TinyLantern_Sit,CatCafe_Accessory_TinyLantern"
			)
		end)
	end)
end
