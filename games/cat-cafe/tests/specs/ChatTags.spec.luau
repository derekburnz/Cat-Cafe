--!strict
-- ChatTags.luau (#1624): the VIP chat tag's prefix, and nothing for an unknown or missing tag.
return function()
	local ChatTags = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").ChatTags)

	describe("prefixFor", function()
		it("gives the VIP tag in gold before the name", function()
			expect(ChatTags.prefixFor("vip")).to.equal('<font color="#F2C14E">[VIP]</font> ')
		end)

		it("gives nothing for no tag, an unknown id or a non-string", function()
			expect(ChatTags.prefixFor(nil)).to.equal(nil)
			expect(ChatTags.prefixFor("admin")).to.equal(nil)
			expect(ChatTags.prefixFor(5)).to.equal(nil)
		end)
	end)
end
