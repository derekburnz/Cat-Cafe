--!strict
-- shared/CafeName.luau: the owner's name on a cafe sign, capped at 12 characters (Derek 2026-10-27).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CafeName = require(Shared.CafeName)

	describe("CafeName", function()
		it("keeps a short name and adds 's Cafe", function()
			expect(CafeName.title("Derek")).to.equal("Derek's Cafe")
			expect(CafeName.shown("Gavin")).to.equal("Gavin")
		end)

		it("shows only the first 12 characters of a long name", function()
			expect(CafeName.shown("SuperLongDisplayName")).to.equal("SuperLongDis")
			expect(CafeName.title("SuperLongDisplayName")).to.equal("SuperLongDis's Cafe")
			expect(CafeName.shown("ExactlyTwelv")).to.equal("ExactlyTwelv")
		end)

		it("counts characters, not bytes, and never splits one", function()
			local name = string.rep("é", 15)
			local shown = CafeName.shown(name)
			expect(utf8.len(shown)).to.equal(12)
			expect(#shown).to.equal(24)
		end)

		it("drops a space left at the cut", function()
			expect(CafeName.shown("Captain Whiskers")).to.equal("Captain Whis")
			expect(CafeName.shown("Big Cat Lover Jo")).to.equal("Big Cat Love")
			expect(CafeName.shown("Mister Meowy Paws")).to.equal("Mister Meowy")
			expect(CafeName.shown("Abcdefghijk Lmn")).to.equal("Abcdefghijk")
		end)
	end)
end
