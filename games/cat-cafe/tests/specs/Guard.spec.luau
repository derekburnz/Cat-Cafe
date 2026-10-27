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

	-- QA (laptop run 2026-10-27): every id the game makes or a save holds, so no remote drops one silently again.
	describe("QA edges", function()
		local Catalog = require(Shared.Catalog)
		local ProfileSchema = require(Shared.ProfileSchema)
		local HEX = "0123456789ABCDEF"

		-- The shape HttpService:GenerateGUID(false) returns: 8-4-4-4-12 upper case hex digits.
		local function fakeGuid(rng: Random): string
			local groups = {}
			for _, size in { 8, 4, 4, 4, 12 } do
				local digits = {}
				for i = 1, size do
					local at = rng:NextInteger(1, 16)
					digits[i] = string.sub(HEX, at, at)
				end
				table.insert(groups, table.concat(digits))
			end
			return table.concat(groups, "-")
		end

		local function passes(id: string, what: string)
			if Guard.id(id) ~= id then
				error(string.format("Guard.id drops %s %q", what, id), 2)
			end
		end

		it("passes every catalog id: cats, spots, upgrades, decor, foods and areas", function()
			local lists: { any } =
				{ Catalog.cats, Catalog.spots, Catalog.upgrades, Catalog.decor, Catalog.lures }
			for _, list in lists do
				for _, def in list do
					passes(def.id, "catalog id")
				end
			end
			for _, area in Catalog.areas do
				passes(area.id, "area")
				for i = 1, area.rescueSpots do
					passes("rescue_" .. area.id .. "_" .. i, "rescue spot") -- WorldBuilder's naming
				end
			end
		end)

		it("passes 500 seeded uids from uidFromGuid, each 12 characters and distinct", function()
			local rng = Random.new(27)
			local seen: { [string]: boolean } = {}
			for _ = 1, 500 do
				local uid = CatStats.uidFromGuid(fakeGuid(rng))
				expect(#uid).to.equal(12)
				passes(uid, "generated uid")
				expect(seen[uid]).never.to.be.ok()
				seen[uid] = true
			end
		end)

		it("passes every cat uid in a loaded save made before the fix, and loses no cat", function()
			local rng = Random.new(16)
			local raw = ProfileSchema.template(1000) :: any
			for _ = 1, 40 do
				local uid = string.lower(string.sub(fakeGuid(rng), 1, 12))
				raw.cats[uid] = { catId = "ginger", caughtAt = 900, level = 1, xp = 0, charm = 50 }
			end
			local loaded = 0
			for uid, instance in ProfileSchema.migrate(raw, 1000).cats do
				passes(uid, "saved uid")
				expect(instance.uid).to.equal(uid)
				loaded += 1
			end
			expect(loaded).to.equal(41) -- the 40 plus the starter Tabby
		end)

		it("drops upper case uids, control and non-ASCII characters", function()
			for _, bad in { "FA3848F6-E97", " tabby", "tabby\n", "a\0b", "tab\tby", "tabb\u{E9}" } do
				expect(Guard.id(bad)).to.equal(nil)
			end
		end)
	end)
end
