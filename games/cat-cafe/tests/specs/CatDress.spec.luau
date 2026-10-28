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
end
