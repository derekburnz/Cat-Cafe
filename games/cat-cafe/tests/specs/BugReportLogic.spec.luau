--!strict
-- UI/Components/BugReportLogic.luau: the Report a bug window's cap, counter, Send rule, kinds, client error lines and
-- toast answers (docs/playtests/bug-reports.md section 1), all following Shared.BugReport (review N151).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local BugReportLogic = require(Components:WaitForChild("BugReportLogic")) :: any
	local BugReport =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BugReport")) :: any

	describe("BugReportLogic Send", function()
		it("stays off under 3 bytes after trimming", function()
			expect(BugReportLogic.canSend("")).to.equal(false)
			expect(BugReportLogic.canSend("hi")).to.equal(false)
			expect(BugReportLogic.canSend("   hi  \n")).to.equal(false)
			expect(BugReportLogic.canSend("  hey ")).to.equal(true)
			expect(BugReportLogic.canSend("the cat fell through the floor")).to.equal(true)
		end)

		it("stays off when the server would drop control characters down to under 3 bytes (QA)", function()
			expect(BugReportLogic.canSend("a\rb")).to.equal(false)
			expect(BugReportLogic.canSend("a\0b")).to.equal(false)
			expect(BugReportLogic.canSend("a\tb")).to.equal(true) -- a tab becomes a space
		end)

		it("lights only for a text the server keeps, and sends what it keeps", function()
			local samples = { "", "ab", "a\rb", "  hello  ", "two\nlines", "a\0b\0c", "🐞", "abc\255", "x\r\ny" }
			for _, sample in samples do
				expect(BugReportLogic.canSend(sample)).to.equal(BugReport.text(sample) ~= nil)
				expect(BugReportLogic.text(sample)).to.equal(BugReport.text(sample))
			end
			expect(BugReportLogic.text("  two\nlines  ")).to.equal("two\nlines")
		end)

		it("counts bytes like the server, up to its 500", function()
			expect(BugReportLogic.MAX_BYTES).to.equal(BugReport.MaxBytes)
			expect(BugReportLogic.counter("")).to.equal("0 / 500")
			expect(BugReportLogic.counter("abc")).to.equal("3 / 500")
			expect(BugReportLogic.counter("🐞")).to.equal("4 / 500")
		end)

		it("will not send broken UTF-8", function()
			expect(BugReportLogic.canSend("abc\255")).to.equal(false)
		end)
	end)

	describe("BugReportLogic cut", function()
		it("keeps short text as it is", function()
			expect(BugReportLogic.cut("hello", 500)).to.equal("hello")
		end)

		it("cuts to the byte limit", function()
			expect(#BugReportLogic.cut(string.rep("a", 600), 500)).to.equal(500)
		end)

		it("never cuts a letter of several bytes in half", function()
			local text = string.rep("a", 498) .. "🐞" -- the bug's four bytes would end at 502
			local cut = BugReportLogic.cut(text, 500)
			expect(cut).to.equal(string.rep("a", 498))
			expect(utf8.len(cut)).to.equal(498)
		end)
	end)

	describe("BugReportLogic kinds", function()
		it("has Bug, Stuck and Idea in the server's order, Bug first", function()
			local ids: { string } = {}
			local labels: { string } = {}
			for _, kind in BugReportLogic.KINDS do
				table.insert(ids, kind.id)
				table.insert(labels, kind.label)
			end
			expect(table.concat(ids, ",")).to.equal(table.concat(BugReport.Kinds, ","))
			expect(table.concat(labels, ",")).to.equal("Bug,Stuck,Idea")
		end)

		it("turns anything else into bug, like the server", function()
			expect(BugReportLogic.kindOf("stuck")).to.equal("stuck")
			expect(BugReportLogic.kindOf("idea")).to.equal("idea")
			expect(BugReportLogic.kindOf("admin")).to.equal("bug")
			expect(BugReportLogic.kindOf(nil)).to.equal("bug")
		end)
	end)

	describe("BugReportLogic client errors", function()
		it("keeps the newest 3, oldest first", function()
			local lines: { string } = {}
			for index = 1, 5 do
				BugReportLogic.pushError(lines, "error " .. index)
			end
			expect(#lines).to.equal(3)
			expect(lines[1]).to.equal("error 3")
			expect(lines[3]).to.equal("error 5")
		end)

		it("keeps each line as the server would: cut to 200 bytes, newlines as spaces", function()
			local lines: { string } = {}
			BugReportLogic.pushError(lines, string.rep("x", 1000))
			BugReportLogic.pushError(lines, "Script error\nStack Begin")
			expect(#lines[1]).to.equal(200)
			expect(lines[2]).to.equal("Script error Stack Begin")
		end)

		it("skips a line the server would drop", function()
			local lines: { string } = {}
			BugReportLogic.pushError(lines, "   ")
			BugReportLogic.pushError(lines, "bad\255")
			expect(#lines).to.equal(0)
		end)
	end)

	describe("BugReportLogic answers", function()
		it("takes the server's Thanks as sent and its refusals as refused", function()
			expect(BugReportLogic.answer(BugReport.Messages.sent)).to.equal(true)
			expect(BugReportLogic.answer(BugReport.Messages.failed)).to.equal(false)
			expect(BugReportLogic.answer(BugReport.Messages.short)).to.equal(false)
			expect(BugReportLogic.answer(BugReport.Messages.limited)).to.equal(false)
		end)

		it("ignores every other toast, so a shove or a Tip Jar refusal cannot settle a report", function()
			expect(BugReportLogic.answer("Too far away to shove")).to.equal(nil)
			expect(BugReportLogic.answer("Your report was sent")).to.equal(nil)
			expect(BugReportLogic.answer("")).to.equal(nil)
		end)
	end)
end
