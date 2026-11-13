--!strict
-- #3743: the client memory marks (shared/MemoryWatch).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local MemoryWatch =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MemoryWatch"))

	describe("MemoryWatch", function()
		it("marks 5, 15, 30 and 60 minutes, with the groups at 5 and 30", function()
			expect(#MemoryWatch.MARKS).to.equal(4)
			expect(MemoryWatch.MARKS[1]).to.equal(5)
			expect(MemoryWatch.MARKS[3]).to.equal(30)
			expect(MemoryWatch.TAG_MARKS[1]).to.equal(true)
			expect(MemoryWatch.TAG_MARKS[2]).to.equal(nil)
			expect(MemoryWatch.TAG_MARKS[3]).to.equal(true)
		end)

		it("names only real memory groups", function()
			for _, name in MemoryWatch.TAGS do
				local ok = pcall(function()
					return (Enum :: any).DeveloperMemoryTag[name]
				end)
				expect(ok).to.equal(true)
			end
		end)

		it("packs an index and the megabytes into one number and back", function()
			local index, mb = MemoryWatch.decode(MemoryWatch.encode(3, 2871.6))
			expect(index).to.equal(3)
			expect(mb).to.equal(2871)
			local _, capped = MemoryWatch.decode(MemoryWatch.encode(1, 1e9))
			expect(capped).to.equal(MemoryWatch.MAX_MB)
		end)

		it("refuses what is not a report", function()
			for _, bad in { "x", 0 / 0, -1, 5, 100000.5, 1e12, true } :: { any } do
				local index = MemoryWatch.decode(bad)
				expect(index).to.equal(nil)
			end
		end)

		it("packs a mark and a group, and takes only the marks that send groups", function()
			local mark, tag = MemoryWatch.tagOf(MemoryWatch.tagIndex(3, 2))
			expect(mark).to.equal(3)
			expect(tag).to.equal(2)
			expect((MemoryWatch.tagOf(MemoryWatch.tagIndex(2, 2)))).to.equal(nil)
			expect((MemoryWatch.tagOf(MemoryWatch.tagIndex(1, #MemoryWatch.TAGS + 1)))).to.equal(
				nil
			)
			expect((MemoryWatch.tagOf(MemoryWatch.tagIndex(1, 0)))).to.equal(nil)
		end)

		it("buckets the growth since the session's first mark", function()
			expect(MemoryWatch.growthBucket(nil, 2000)).to.equal("first")
			expect(MemoryWatch.growthBucket(2000, 1900)).to.equal("lt200")
			expect(MemoryWatch.growthBucket(2000, 2300)).to.equal("200-500")
			expect(MemoryWatch.growthBucket(2000, 2700)).to.equal("500-1000")
			expect(MemoryWatch.growthBucket(2000, 3500)).to.equal("1000-2000")
			expect(MemoryWatch.growthBucket(2000, 6000)).to.equal("2000+")
		end)
	end)
end
