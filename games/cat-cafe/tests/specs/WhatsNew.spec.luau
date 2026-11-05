--!strict
-- shared/WhatsNew.luau against idea-credits.md section 7 (#1216): every row's date, icon, text, id and creditId, the
-- order newest first, the board's newest five and the "Nov 4" date (QA checks 1 and 3).
return function()
	local WhatsNew = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WhatsNew")
	)

	local function realDate(date: string): boolean
		local y, m, d = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
		if y == nil then
			return false
		end
		local year, month, day = tonumber(y) :: number, tonumber(m) :: number, tonumber(d) :: number
		local at = os.time({ year = year, month = month, day = day, hour = 12 })
		local back = os.date("!*t", at) :: any
		return back.year == year and back.month == month and back.day == day
	end

	describe("the rows (section 7c)", function()
		it("each has a real date, a known icon, short calm text and a unique id", function()
			local icons: { [string]: boolean } = {}
			for _, icon in WhatsNew.ICONS do
				icons[icon] = true
			end
			local ids: { [string]: boolean } = {}
			expect(#WhatsNew.rows > 0).to.equal(true)
			for _, row in WhatsNew.rows do
				expect(realDate(row.date)).to.equal(true)
				expect(icons[row.icon]).to.equal(true)
				expect(utf8.len(row.text) :: number <= WhatsNew.TEXT_MAX).to.equal(true)
				expect(#row.text > 0).to.equal(true)
				expect(string.find(row.text, "[%.!]$")).to.equal(nil) -- no full stop, no "!!!"
				expect(string.find(row.text, "^New:")).to.equal(nil) -- the icon says the kind
				expect(string.find(row.text, "R%$")).to.equal(nil) -- no prices or Robux items
				expect(string.match(row.id, "^[%l%d_]+$") ~= nil).to.equal(true)
				expect(ids[row.id]).to.equal(nil)
				ids[row.id] = true
				if row.creditId ~= nil then
					expect(string.match(row.creditId :: string, "^c%d+$") ~= nil).to.equal(true)
				end
				expect(table.isfrozen(row)).to.equal(true)
			end
			expect(table.isfrozen(WhatsNew.rows)).to.equal(true)
		end)

		it("runs newest first and never back in time", function()
			for index = 2, #WhatsNew.rows do
				expect(WhatsNew.rows[index].date <= WhatsNew.rows[index - 1].date).to.equal(true)
			end
		end)
	end)

	describe("the panel (section 7a, QA check 1)", function()
		it("shows the newest five at most, never padding", function()
			local shown = WhatsNew.latest()
			expect(#shown).to.equal(math.min(WhatsNew.SHOWN, #WhatsNew.rows))
			expect(shown[1]).to.equal(WhatsNew.rows[1])
		end)

		it("writes the date as UTC month and day", function()
			expect(WhatsNew.shortDate("2026-11-04")).to.equal("Nov 4")
			expect(WhatsNew.shortDate("2026-01-31")).to.equal("Jan 31")
			expect(WhatsNew.shortDate("2026-13-01")).to.equal("")
			expect(WhatsNew.shortDate("Nov 4")).to.equal("")
		end)
	end)
end
