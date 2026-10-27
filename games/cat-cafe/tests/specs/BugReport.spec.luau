--!strict
-- shared/BugReport.luau: what the server keeps of a ReportBug call (docs/playtests/bug-reports.md section 2) and the
-- key a report is saved under. The abuse cases are QA's abuse row: nothing errors and every kept value is in bounds.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BugReport = require(Shared.BugReport)

	describe("BugReport.text", function()
		it("keeps a plain report, trimmed, with its newlines", function()
			expect(BugReport.text("  the cat fell through the floor\nnear the counter  ")).to.equal(
				"the cat fell through the floor\nnear the counter"
			)
		end)

		it("refuses anything that is not a string or is under 3 bytes once cleaned", function()
			local cases: { any } = { 5, true, {}, "", "  ", "ab", " \n\t ", "a\0b" }
			for _, raw in cases do
				expect(BugReport.text(raw)).never.to.be.ok()
			end
			expect(BugReport.text(nil)).never.to.be.ok()
			expect(BugReport.text("abc")).to.equal("abc")
		end)

		it("refuses invalid UTF-8", function()
			expect(BugReport.text("broken \255\254 text")).never.to.be.ok()
		end)

		it("takes out control characters but newlines, and turns a tab into a space", function()
			expect(BugReport.text("a\0b\1c\27d\127e")).to.equal("abcde")
			expect(BugReport.text("one\ttwo\r\nthree")).to.equal("one two\nthree")
		end)

		it(
			"cuts a long report to 500 bytes on a character boundary instead of refusing it",
			function()
				expect(BugReport.text(string.rep("a", 10000))).to.equal(string.rep("a", 500))
				local kept = BugReport.text(string.rep("é", 300)) :: string -- 2 bytes each
				expect(#kept).to.equal(500)
				kept = BugReport.text("a" .. string.rep("é", 300)) :: string
				expect(#kept).to.equal(499)
				expect(utf8.len(kept)).to.be.ok()
			end
		)

		it("looks at no more than 2,000 bytes of what it is sent", function()
			-- a bad byte past the bound is never read; the start of the report is kept
			expect(BugReport.text(string.rep("a", 3000) .. "\255")).to.equal(string.rep("a", 500))
			expect(BugReport.cut("ab\255\255", 3)).to.equal("ab\255")
		end)

		it("trims a long run of spaces quickly", function()
			local started = os.clock()
			expect(BugReport.text("abc" .. string.rep(" ", 20000) .. "d")).to.equal("abc")
			expect(os.clock() - started < 0.5).to.equal(true)
		end)
	end)

	describe("BugReport.kind", function()
		it("keeps bug, stuck and idea and makes anything else a bug", function()
			expect(BugReport.kind("bug")).to.equal("bug")
			expect(BugReport.kind("stuck")).to.equal("stuck")
			expect(BugReport.kind("idea")).to.equal("idea")
			local cases: { any } = { "admin", "Bug", 3, {} }
			for _, raw in cases do
				expect(BugReport.kind(raw)).to.equal("bug")
			end
			expect(BugReport.kind(nil)).to.equal("bug")
		end)
	end)

	describe("BugReport.clientErrors", function()
		it("keeps up to 3 lines, each cleaned and cut to 200 bytes", function()
			local lines =
				BugReport.clientErrors({ "first\nline", string.rep("x", 10000), "third", "fourth" })
			expect(#lines).to.equal(3)
			expect(lines[1]).to.equal("first line")
			expect(#lines[2]).to.equal(200)
			expect(lines[3]).to.equal("third")
		end)

		it("drops bad entries and anything that is not a table, never erroring", function()
			expect(#BugReport.clientErrors("an error")).to.equal(0)
			expect(#BugReport.clientErrors(nil)).to.equal(0)
			expect(#BugReport.clientErrors({ 5, "ok line", "\255bad" })).to.equal(1)
			local many: { string } = {}
			for i = 1, 50 do
				many[i] = "error " .. i
			end
			local kept = BugReport.clientErrors(many)
			expect(#kept).to.equal(3)
			expect(kept[3]).to.equal("error 3")
		end)
	end)

	describe("BugReport.key", function()
		it(
			"is r_<UTC day>_<time>_<userId>, so a day's reports list by prefix in time order",
			function()
				local at = 1793115053 -- 2026-10-27 UTC
				expect(BugReport.day(at)).to.equal("20261027")
				expect(BugReport.key(at, 40908216)).to.equal("r_20261027_1793115053_40908216")
				expect(BugReport.key(at, 1) < BugReport.key(at + 60, 1)).to.equal(true)
			end
		)

		it(
			"starts with s_ from Studio, so playtest reports list apart from the testers' ones",
			function()
				local at = 1793115053
				expect(BugReport.key(at, -1, true)).to.equal("s_20261027_1793115053_-1")
				expect(BugReport.prefix("20261027", true)).to.equal("s_20261027_")
				expect(BugReport.prefix("20261027")).to.equal("r_20261027_")
				expect(BugReport.key(at, 7):sub(1, #BugReport.prefix("20261027"))).to.equal(
					BugReport.prefix("20261027")
				)
			end
		)
	end)
end
