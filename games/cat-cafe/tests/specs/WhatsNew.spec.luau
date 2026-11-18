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
				-- Derek2 11-07: a playtester's Roblox username (3 to 20 letters, digits or one underscore), never with a
				-- creditId
				local thanks = (row :: any).thanks
				if thanks ~= nil then
					expect(type(thanks)).to.equal("string")
					expect(string.match(thanks, "^[%w_]+$") ~= nil).to.equal(true)
					expect(#thanks >= 3 and #thanks <= 20).to.equal(true)
					expect(row.creditId).to.equal(nil)
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
			local shown = WhatsNew.latest(math.huge)
			expect(#shown).to.equal(math.min(WhatsNew.SHOWN, #WhatsNew.rows))
			expect(shown[1]).to.equal(WhatsNew.rows[1])
		end)

		it("leaves out a row until its startsAt, and fills from older rows", function()
			local timed: any = nil
			for _, row in WhatsNew.rows do
				if row.startsAt ~= nil then
					expect(type(row.startsAt)).to.equal("number")
					timed = timed or row
				end
			end
			if timed == nil then
				return
			end
			local before = WhatsNew.latest(timed.startsAt - 1)
			for _, row in before do
				expect(row.startsAt == nil or row.startsAt < timed.startsAt).to.equal(true)
				expect(row).never.to.equal(timed)
			end
			local live = 0
			for _, row in WhatsNew.rows do
				if WhatsNew.isLive(row, timed.startsAt - 1) then
					live += 1
				end
			end
			expect(#before).to.equal(math.min(WhatsNew.SHOWN, live))
			-- at its startsAt it is live, and on the board unless SHOWN newer live rows already fill it (an old
			-- update's row rolls off as newer rows come)
			expect(WhatsNew.isLive(timed, timed.startsAt)).to.equal(true)
			local ahead = 0
			for _, row in WhatsNew.rows do
				if row == timed then
					break
				end
				if WhatsNew.isLive(row, timed.startsAt) then
					ahead += 1
				end
			end
			local shownAt = false
			for _, row in WhatsNew.latest(timed.startsAt) do
				shownAt = shownAt or row == timed
			end
			expect(shownAt).to.equal(ahead < WhatsNew.SHOWN)
		end)

		it("writes the date as UTC month and day", function()
			expect(WhatsNew.shortDate("2026-11-04")).to.equal("Nov 4")
			expect(WhatsNew.shortDate("2026-01-31")).to.equal("Jan 31")
			expect(WhatsNew.shortDate("2026-13-01")).to.equal("")
			expect(WhatsNew.shortDate("Nov 4")).to.equal("")
		end)
	end)
end
