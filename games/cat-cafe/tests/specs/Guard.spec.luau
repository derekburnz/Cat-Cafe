--!strict
-- Util/Guard.luau: the remote argument validators. Guard.id must pass every id the server itself hands out, or the
-- remotes that take one drop the call silently (laptop Studio run 2026-10-27: caught cats could not be placed,
-- sold or renamed because their uids carry a hyphen).
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Config = require(Shared.Config)
	local Guard = require(ServerScriptService.Server.Util.Guard)

	describe("Guard.id", function()
		it("passes a cat uid as CafeService makes them (12 characters of a lowercased GUID)", function()
			expect(Guard.id("fa3848f6-e97")).to.equal("fa3848f6-e97")
			expect(Guard.id("0c1d2e3f-4a5")).to.equal("0c1d2e3f-4a5")
		end)

		it("passes every uid CatStats.uidFromGuid makes from a GenerateGUID(false) string", function()
			for _, guid in {
				"FA3848F6-E97B-4C1D-9A2E-3F4A5B6C7D8E",
				"00000000-0000-0000-0000-000000000000",
				"ABCDEF12-3456-7890-ABCD-EF1234567890",
			} do
				local uid = CatStats.uidFromGuid(guid)
				expect(#uid).to.equal(12)
				expect(Guard.id(uid)).to.equal(uid)
			end
		end)

		it("passes the starter cat, catalog ids, spot ids and stray ids", function()
			for _, id in { "starter_tabby", "waiter_1", "plants", "home", "stray_4821_17" } do
				expect(Guard.id(id)).to.equal(id)
			end
		end)

		it("drops anything that is not a short lowercase id", function()
			local tooLong = string.rep("a", Config.MaxIdLength + 1)
			for _, bad in { "", "HOME", "Neon Sign", "../x", "a/b", "a.b", "a b", tooLong } do
				expect(Guard.id(bad)).to.equal(nil)
			end
			for _, bad in { 123, true, {} } do
				expect(Guard.id(bad)).to.equal(nil)
			end
			expect(Guard.id(nil)).to.equal(nil)
		end)

		it("takes an id exactly MaxIdLength long", function()
			local longest = string.rep("a", Config.MaxIdLength)
			expect(Guard.id(longest)).to.equal(longest)
		end)
	end)
end
