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

	-- QA (docs/playtests/bug-reports.md): the module checked against a reference that walks code points instead of
	-- using patterns, over seeded random reports that mix what a TextBox can hold with what only an exploiter sends.
	describe("BugReport edges (QA)", function()
		local pieces = {
			"a",
			"Z",
			"7",
			".",
			" ",
			"  ",
			"\n",
			" \n",
			"\t",
			"\r",
			"\v",
			"\0",
			"\1",
			"\27",
			"\127",
			"é", -- 2 bytes
			"€", -- 3 bytes
			"😀", -- 4 bytes
			"\194\160", -- no-break space, not trimmed
			"\194\133", -- U+0085, not a control character to %c
			"\226\128\174", -- right-to-left override
		}
		local broken = { "\255", "\192\175", "\237\160\128", "\226\128" } -- bad byte, overlong, surrogate, cut short

		-- A small LCG, so every run sees the same reports.
		local seed = 20261027
		local function roll(n: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n + 1
		end

		local function report(): string
			local count = ({ roll(9) - 1, 150 + roll(250), 900 + roll(900) })[roll(3)]
			local parts: { string } = {}
			for index = 1, count do
				parts[index] = pieces[roll(#pieces)]
			end
			if roll(6) == 1 then
				table.insert(parts, roll(#parts + 1), broken[roll(#broken)])
			end
			return table.concat(parts)
		end

		local function isSpace(point: number): boolean
			return point == 32 or point == 10
		end

		-- What the server keeps, worked out one code point at a time: the first `bound` bytes (backing off a split
		-- character), nil if those are not UTF-8, control characters out (a tab, and a newline unless kept, become
		-- spaces), spaces and newlines off both ends, cut to `limit` bytes between characters, the end trimmed again.
		local function reference(
			raw: string,
			bound: number,
			limit: number,
			keepNewlines: boolean
		): string?
			if #raw > bound then
				local stop = bound + 1
				while stop > 1 and math.floor((string.byte(raw, stop) :: number) / 64) == 2 do
					stop -= 1
				end
				raw = string.sub(raw, 1, stop - 1)
			end
			local ok, points = pcall(function(): { number }
				local list: { number } = {}
				for _, point in utf8.codes(raw) do
					table.insert(list, point)
				end
				return list
			end)
			if not ok then
				return nil
			end
			local kept: { number } = {}
			for _, point in points do
				if point == 10 then
					table.insert(kept, if keepNewlines then 10 else 32)
				elseif point == 9 then
					table.insert(kept, 32)
				elseif point >= 32 and point ~= 127 then
					table.insert(kept, point)
				end
			end
			local first, last = 1, #kept
			while first <= last and isSpace(kept[first]) do
				first += 1
			end
			while last >= first and isSpace(kept[last]) do
				last -= 1
			end
			local out: { string } = {}
			local bytes = 0
			for index = first, last do
				local char = utf8.char(kept[index])
				if bytes + #char > limit then
					break
				end
				bytes += #char
				table.insert(out, char)
			end
			while #out > 0 and (out[#out] == " " or out[#out] == "\n") do
				table.remove(out)
			end
			return table.concat(out)
		end

		-- The first 40 bytes as printable ASCII, for a failure message.
		local function shown(text: string): string
			return (
				string.gsub(string.sub(text, 1, 40), "[^%w%p ]", function(c: string): string
					return "\\" .. string.byte(c)
				end)
			)
		end

		local function wellFormed(text: string, limit: number): boolean
			return utf8.len(text) ~= nil
				and #text <= limit
				and string.find(text, "[%z\1-\9\11-\31\127]") == nil
				and string.find(text, "^%s") == nil
				and string.find(text, "%s$") == nil
		end

		it("keeps what a code point reference keeps, for 2,000 seeded random reports", function()
			local differ: { string } = {}
			for _ = 1, 2000 do
				local raw = report()
				local want = reference(raw, BugReport.MaxBytes * 4, BugReport.MaxBytes, true)
				if want ~= nil and #want < BugReport.MinBytes then
					want = nil
				end
				local got = BugReport.text(raw)
				local line = reference(raw, BugReport.ErrorBytes * 4, BugReport.ErrorBytes, false)
				if line == "" then
					line = nil
				end
				if (got ~= want or BugReport.errorLine(raw) ~= line) and #differ < 5 then
					table.insert(differ, shown(raw))
				end
			end
			expect(table.concat(differ, " | ")).to.equal("")
		end)

		it("keeps only clean UTF-8 of 3 to 500 bytes, unchanged when cleaned again", function()
			local bad: { string } = {}
			for _ = 1, 2000 do
				local raw = report()
				local text = BugReport.text(raw)
				if text ~= nil then
					if
						not wellFormed(text, BugReport.MaxBytes)
						or #text < BugReport.MinBytes
						or BugReport.text(text) ~= text
					then
						table.insert(bad, shown(text))
					end
				end
				local line = BugReport.errorLine(raw)
				if line ~= nil then
					if
						not wellFormed(line, BugReport.ErrorBytes)
						or string.find(line, "\n", 1, true) ~= nil
					then
						table.insert(bad, shown(line))
					end
				end
				for _, kept in BugReport.clientErrors({ raw, raw, raw, raw }) do
					if not wellFormed(kept, BugReport.ErrorBytes) then
						table.insert(bad, shown(kept))
					end
				end
			end
			expect(table.concat(bad, " | ", 1, math.min(#bad, 5))).to.equal("")
		end)

		it("trims again after the 500 byte cut, and keeps a space in the middle", function()
			expect(BugReport.text(string.rep("a", 499) .. " b")).to.equal(string.rep("a", 499))
			expect(BugReport.text(string.rep("a", 499) .. "\n\nb")).to.equal(string.rep("a", 499))
			expect(BugReport.text("ab c")).to.equal("ab c")
			expect(BugReport.errorLine(string.rep("e", 199) .. " f")).to.equal(string.rep("e", 199))
		end)

		it("answers a 200,000 byte flood of control characters in well under a second", function()
			local started = os.clock()
			expect(BugReport.text(string.rep("\1", 200000) .. "abc")).never.to.be.ok()
			expect(#BugReport.clientErrors({ string.rep("\1", 200000) })).to.equal(0)
			expect(os.clock() - started < 0.5).to.equal(true)
		end)

		it("answers with the contract's toasts", function()
			expect(BugReport.Messages.sent).to.equal("Thanks! Your report was sent.")
			expect(BugReport.Messages.failed).to.equal("Couldn't send that, try again in a minute")
			expect(BugReport.Messages.short).to.equal("Write a few words about what happened")
			expect(BugReport.Messages.limited).to.equal("You just sent one, try again in a moment")
		end)

		it("sorts a day's keys by time for any user, in the 50 character key limit", function()
			local dayStart = 1793059200 -- 2026-10-27 00:00:00 UTC
			local users = { -2, -1, 1, 7, 40908216, 9007199254740991 }
			for _, studio in { false, true } do
				local previous = ""
				for step = 0, 24 do
					local at = dayStart + math.min(step * 3600, 86399)
					local prefix = BugReport.prefix("20261027", studio)
					for _, userId in users do
						local key = BugReport.key(at, userId, studio)
						expect(string.sub(key, 1, #prefix)).to.equal(prefix)
						expect(#key <= 50).to.equal(true)
						if previous ~= "" and step > 0 then
							expect(key > previous).to.equal(true)
						end
					end
					previous = BugReport.key(at, users[#users], studio)
				end
				expect(BugReport.day(dayStart + 86400)).to.equal("20261028")
			end
			expect(string.sub(BugReport.key(dayStart, 1, true), 1, 2)).never.to.equal(
				string.sub(BugReport.key(dayStart, 1), 1, 2)
			)
		end)
	end)
end
