--!strict
-- UI/Components/BugReportLogic.luau: the Report a bug window's cap, counter, Send rule, kinds and client error lines
-- (docs/playtests/bug-reports.md section 1).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local BugReportLogic = require(Components:WaitForChild("BugReportLogic")) :: any

	describe("BugReportLogic Send", function()
		it("stays off under 3 characters after trimming", function()
			expect(BugReportLogic.canSend("")).to.equal(false)
			expect(BugReportLogic.canSend("hi")).to.equal(false)
			expect(BugReportLogic.canSend("   hi  \n")).to.equal(false)
			expect(BugReportLogic.canSend("  hey ")).to.equal(true)
			expect(BugReportLogic.canSend("the cat fell through the floor")).to.equal(true)
		end)

		it("counts bytes like the server, so 500 is the most it will take", function()
			expect(BugReportLogic.canSend(string.rep("a", 500))).to.equal(true)
			expect(BugReportLogic.canSend(string.rep("a", 501))).to.equal(false)
			expect(BugReportLogic.counter("")).to.equal("0 / 500")
			expect(BugReportLogic.counter("abc")).to.equal("3 / 500")
			expect(BugReportLogic.counter("🐞")).to.equal("4 / 500")
		end)

		it("will not send broken UTF-8", function()
			expect(BugReportLogic.canSend("abc\255")).to.equal(false)
		end)

		it("trims the ends and keeps the middle", function()
			expect(BugReportLogic.trim("  two\nlines  ")).to.equal("two\nlines")
			expect(BugReportLogic.trim("   ")).to.equal("")
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

		it("drops everything from a broken byte on", function()
			expect(BugReportLogic.cut("ok\255more", 200)).to.equal("ok")
		end)
	end)

	describe("BugReportLogic kinds", function()
		it("has Bug, Stuck and Idea, Bug first", function()
			local ids: { string } = {}
			for _, kind in BugReportLogic.KINDS do
				table.insert(ids, kind.id)
			end
			expect(table.concat(ids, ",")).to.equal("bug,stuck,idea")
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

		it("cuts each line to 200 bytes", function()
			local lines: { string } = {}
			BugReportLogic.pushError(lines, string.rep("x", 1000))
			expect(#lines[1]).to.equal(200)
		end)
	end)
end
