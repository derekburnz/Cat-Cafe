--!strict
-- JoinSource.luau (#1888): an ad's launch data becomes its tag, nothing at all is organic, anything else unknown.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local JoinSource = require(Shared.JoinSource)

	describe("JoinSource.parse", function()
		it("keeps an ad tag of our shape", function()
			expect(JoinSource.parse("ad_tiktok_nov")).to.equal("ad_tiktok_nov")
			expect(JoinSource.parse("ad_1")).to.equal("ad_1")
			expect(JoinSource.parse("ad_" .. string.rep("a", 20))).to.equal("ad_" .. string.rep("a", 20))
			expect(JoinSource.isAd("ad_1")).to.equal(true)
		end)

		it("reads no launch data as organic", function()
			expect(JoinSource.parse(nil)).to.equal("organic")
			expect(JoinSource.parse("")).to.equal("organic")
			expect(JoinSource.isAd("organic")).to.equal(false)
		end)

		it("never passes on launch data that is not an ad tag", function()
			for _, raw in { "ad_", "AD_x", "ad_X", "ad_a-b", "ad_ a", "hello", "ad_" .. string.rep("a", 21), "x ad_a" } do
				expect(JoinSource.parse(raw)).to.equal("unknown")
			end
			expect(JoinSource.parse(5)).to.equal("unknown")
			expect(JoinSource.parse({ "ad_a" })).to.equal("unknown")
			expect(JoinSource.parse("ad_a\n")).to.equal("unknown")
		end)
	end)
end
