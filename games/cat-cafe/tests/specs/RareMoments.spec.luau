--!strict
-- RareMoments.luau against luck-and-rare-moments.md section 2 (F89): which secures play the big pull and which the
-- first Epic's small card, which toast the server, and the crate toast's words.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local RareMoments = require(Shared.RareMoments)
	local Types = require(Shared.Types)

	local function firstOf(rarity: string): string
		for _, def in Catalog.cats do
			if def.rarity == rarity and def.area ~= "exclusive" then
				return def.id
			end
		end
		error("no " .. rarity .. " cat")
	end

	describe("the card", function()
		it("plays the big pull for every Legendary and Mythical, gold or not", function()
			for _, rarity in { "Legendary", "Mythical" } do
				for _, variant in { "base", "gold", nil :: string? } do
					for _, had in { false, true } do
						expect(RareMoments.card(rarity :: Types.Rarity, variant, had)).to.equal(
							"big"
						)
					end
				end
			end
		end)

		it("plays it for a gold Epic but never a gold Common or Rare", function()
			expect(RareMoments.card("Epic", "gold", true)).to.equal("big")
			expect(RareMoments.card("Epic", "gold", false)).to.equal("big")
			expect(RareMoments.card("Rare", "gold", false)).to.equal(nil)
			expect(RareMoments.card("Common", "gold", false)).to.equal(nil)
		end)

		it("plays it for every rainbow cat, Common included (F99)", function()
			for _, rarity in Catalog.rarityOrder do
				expect(RareMoments.card(rarity, "rainbow", true)).to.equal("big")
			end
		end)

		it("gives the first Epic ever the small card and later ones nothing", function()
			expect(RareMoments.card("Epic", "base", false)).to.equal("first_epic")
			expect(RareMoments.card("Epic", nil, false)).to.equal("first_epic")
			expect(RareMoments.card("Epic", "base", true)).to.equal(nil)
			expect(RareMoments.card("Rare", "base", false)).to.equal(nil)
			expect(RareMoments.card("Common", "base", false)).to.equal(nil)
		end)
	end)

	describe("the first Epic", function()
		it("counts any Epic or better already in the collection", function()
			expect(RareMoments.ownsEpicOrBetter({})).to.equal(false)
			expect(RareMoments.ownsEpicOrBetter({ [firstOf("Common")] = 3, [firstOf("Rare")] = 1 })).to.equal(
				false
			)
			for _, rarity in { "Epic", "Legendary", "Mythical" } do
				expect(RareMoments.ownsEpicOrBetter({ [firstOf(rarity)] = 1 })).to.equal(true)
			end
		end)

		it("skips unknown ids and empty counts", function()
			expect(RareMoments.ownsEpicOrBetter({ nope = 4, [firstOf("Epic")] = 0 })).to.equal(
				false
			)
		end)
	end)

	describe("the toasts", function()
		it("toast the server for Legendary and Mythical cats only", function()
			expect(RareMoments.toasts("Common")).to.equal(false)
			expect(RareMoments.toasts("Rare")).to.equal(false)
			expect(RareMoments.toasts("Epic")).to.equal(false)
			expect(RareMoments.toasts("Legendary")).to.equal(true)
			expect(RareMoments.toasts("Mythical")).to.equal(true)
		end)

		it("toast for Mythical crate pieces only, once a minute a player", function()
			expect(RareMoments.decorToasts("Mythical")).to.equal(true)
			for _, rarity in { "Common", "Rare", "Epic", "Legendary" } do
				expect(RareMoments.decorToasts(rarity)).to.equal(false)
			end
			expect(RareMoments.TOAST_SECONDS).to.equal(60)
		end)

		it("word the crate toast as the section does", function()
			expect(RareMoments.decorText("Sam", "Midnight Sky")).to.equal(
				"Sam found the Mythical Midnight Sky!"
			)
		end)

		it("say how a cat was secured for rare_secured", function()
			expect(RareMoments.how("net")).to.equal("catch")
			expect(RareMoments.how("bait")).to.equal("bait")
			expect(RareMoments.how("rescue")).to.equal("rescue")
		end)

		it("have a Mythical crate piece to toast", function()
			local found = false
			for _, crate in Catalog.crates do
				for _, decorId in crate.pieces do
					local decor = Catalog.getDecor(decorId)
					found = found or (decor ~= nil and decor.rarity == "Mythical")
				end
			end
			expect(found).to.equal(true)
		end)
	end)
end
