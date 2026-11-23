--!strict
-- #4783: load time and average FPS for every player (shared/PerfWatch).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PerfWatch = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfWatch"))

	describe("PerfWatch", function()
		it("marks 1, 3 and 10 minutes", function()
			expect(#PerfWatch.MARKS).to.equal(3)
			expect(PerfWatch.MARKS[1]).to.equal(1)
			expect(PerfWatch.MARKS[3]).to.equal(10)
		end)

		it("packs the mark, the quality and the fps into one number and back", function()
			local mark, quality, fps = PerfWatch.decode(PerfWatch.encode(2, 4, 48.6))
			expect(mark).to.equal(2)
			expect(quality).to.equal(4)
			expect(fps).to.equal(49)
			local _, q, capped = PerfWatch.decode(PerfWatch.encode(3, 99, 1e6))
			expect(q).to.equal(PerfWatch.MAX_QUALITY)
			expect(capped).to.equal(PerfWatch.MAX_FPS)
			local _, auto, none = PerfWatch.decode(PerfWatch.encode(1, 0, -5))
			expect(auto).to.equal(0)
			expect(none).to.equal(0)
		end)

		it("refuses what is not a report", function()
			for _, bad in
				{ "x", 0 / 0, -1, 60, 400060, 111000 + 500, 100000.5, 1e12, true } :: { any }
			do
				local mark = PerfWatch.decode(bad)
				expect(mark).to.equal(nil)
			end
		end)

		it("averages the counted frames, 0 when none", function()
			expect(PerfWatch.average(300, 6)).to.equal(50)
			expect(PerfWatch.average(0, 6)).to.equal(0)
			expect(PerfWatch.average(10, 0)).to.equal(0)
			expect(PerfWatch.average(1e6, 1)).to.equal(PerfWatch.MAX_FPS)
		end)

		it("buckets the client's load", function()
			expect(PerfWatch.loadBucket(1)).to.equal("lt3")
			expect(PerfWatch.loadBucket(0 / 0)).to.equal("lt3")
			expect(PerfWatch.loadBucket(8)).to.equal("6-10")
			expect(PerfWatch.loadBucket(12)).to.equal("10-20")
			expect(PerfWatch.loadBucket(90)).to.equal("40+")
		end)

		it("#5686: buckets an fps average for client_fps field 3", function()
			expect(PerfWatch.BUCKET_FLAG).to.equal("fpsBucket")
			expect(PerfWatch.fpsBucket(0 / 0)).to.equal("lt20")
			expect(PerfWatch.fpsBucket(12)).to.equal("lt20")
			expect(PerfWatch.fpsBucket(20)).to.equal("20-30")
			expect(PerfWatch.fpsBucket(29.9)).to.equal("20-30")
			expect(PerfWatch.fpsBucket(30)).to.equal("30-45")
			expect(PerfWatch.fpsBucket(45)).to.equal("45-60")
			expect(PerfWatch.fpsBucket(60)).to.equal("60+")
			expect(PerfWatch.fpsBucket(240)).to.equal("60+")
		end)
	end)
end
