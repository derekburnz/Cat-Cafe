--!strict
-- UI/Components/ThanksBoardLogic.luau: the Thank You board's credit line and paging (#1083).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("ThanksBoardLogic")) :: any

	describe("ThanksBoardLogic", function()
		it("words the credit line with the version and the display name", function()
			expect(Logic.creditLine({ idea = "x", version = 190, name = "MochiPie" })).to.equal(
				"v190 · Idea from MochiPie"
			)
			expect(Logic.creditLine({ idea = "x", version = 190, name = "a player" })).to.equal(
				"v190 · Idea from a player"
			)
			expect(Logic.creditLine({ idea = "x" })).to.equal("Idea from a player")
		end)
		it("puts a gold heart by a supporter's name, never on a hidden one (#1168)", function()
			expect(
				Logic.creditLine({ idea = "x", version = 2, name = "MochiPie", supporter = true })
			).to.equal("v2 · Idea from MochiPie 💛")
			expect(Logic.creditLine({ idea = "x", name = "MochiPie", supporter = false })).to.equal(
				"Idea from MochiPie"
			)
			expect(Logic.creditLine({ idea = "x", supporter = true })).to.equal(
				"Idea from a player"
			)
		end)
		it("pages six cards at a time and clamps the page", function()
			local rows = {}
			for index = 1, 14 do
				table.insert(rows, { idea = "idea " .. index, version = 1, name = "n" })
			end
			local first = Logic.page(rows, 1)
			expect(#first.rows).to.equal(6)
			expect(first.pages).to.equal(3)
			expect(first.rows[1].idea).to.equal("idea 1")
			local last = Logic.page(rows, 9)
			expect(last.page).to.equal(3)
			expect(#last.rows).to.equal(2)
			expect(Logic.page({}, 1).pages).to.equal(1)
		end)
		it("lines up What's new with its icon, short date and linked credit (#1216)", function()
			local updates = {
				{
					id = "a",
					date = "2026-11-05",
					icon = "faster",
					text = "Faster cannon",
					creditId = "c2",
				},
				{
					id = "b",
					date = "2026-11-04",
					icon = "fix",
					text = "Fixed a bug",
					creditId = "c9",
				},
				{ id = "c", date = "2026-11-03", icon = "look", text = "Cleaner buttons" },
			}
			local board = {
				{ idea = "x", version = 1, name = "MochiPie", creditId = "c2" },
				{ idea = "y", version = 1, name = "a player", creditId = "c9" },
			}
			local lines = Logic.whatsNew(updates, board)
			expect(lines[1].glyph).to.equal("⚡")
			expect(lines[1].date).to.equal("Nov 5")
			expect(lines[1].credit).to.equal("💡 Idea from MochiPie")
			expect(lines[2].credit).to.equal("💡 A player's idea")
			expect(lines[3].credit).to.equal(nil)
			expect(Logic.whatsNew(updates, nil)[1].credit).to.equal("💡 A player's idea")
			-- Derek2 11-07: a named playtester's report or suggestion
			local thanked = Logic.whatsNew({
				{
					id = "cash",
					date = "2026-11-07",
					icon = "fix",
					text = "Cash stays put",
					thanks = "bgdevila",
				},
				{ id = "plain", date = "2026-11-07", icon = "new", text = "Something new" },
			}, nil)
			expect(thanked[1].credit).to.equal("💡 Thanks to bgdevila")
			expect(thanked[2].credit).to.equal(nil)
		end)
		it(
			"names the next update from Config.UpdateEvents and moves on by itself (Derek 2026-11-14)",
			function()
				local list = {
					{
						id = "1",
						startsAt = 1794704400,
						title = "🔔 Next update tonight: RIFT RUN! Want a reminder when it lands?",
					},
					{
						id = "2",
						startsAt = 1794772800,
						title = "🔔 Next update Sunday: 3 NEW WORLDS! Want a reminder when it lands?",
					},
					{
						id = "3",
						startsAt = 1794780000,
						title = "🔔 Next update Sunday: the GOLDEN FISH STORE! Want a reminder when it lands?",
					},
					{
						id = "4",
						startsAt = 1795032000,
						title = "🔔 Next update Wednesday: better controls on every device! Want a reminder?",
					},
					{
						id = "5",
						startsAt = 1794799800,
						title = "🔔 Next update: 10 SECRET CATS! Want a reminder when it lands?",
					},
				}
				local before = Logic.nextUpdate(list, 1794704400 - 60)
				expect(before.text).to.equal("Next: RIFT RUN")
				expect(before.when).to.equal("Saturday 8 PM ET · tap Notify Me for a reminder")
				-- the first 10 minutes after an update goes out are its own
				expect(Logic.nextUpdate(list, 1794704400 + 60)).to.equal(nil)
				local after = Logic.nextUpdate(list, 1794704400 + 601)
				expect(after.text).to.equal("Next: 3 NEW WORLDS")
				expect(after.when).to.equal("Sunday 3 PM ET · tap Notify Me for a reminder")
				expect(Logic.nextUpdate(list, 1794772800 + 601).text).to.equal(
					"Next: GOLDEN FISH STORE"
				)
				local secret = Logic.nextUpdate(list, 1794780000 + 601)
				expect(secret.text).to.equal("Next: 10 SECRET CATS")
				expect(secret.when).to.equal("Sunday 10:30 PM ET · tap Notify Me for a reminder")
				expect(Logic.nextUpdate(list, 1794799800 + 601).text).to.equal(
					"Next: Better controls on every device"
				)
				expect(Logic.nextUpdate(list, 1795032000 + 601)).to.equal(nil)
				expect(Logic.nextUpdate(nil, 0)).to.equal(nil)
			end
		)
		it("prefers an entry's own name and falls back to a plain one", function()
			expect(Logic.updateName({ name = "Harvest Hollow", title = "x: y!" })).to.equal(
				"Harvest Hollow"
			)
			expect(Logic.updateName({ title = "no colon here" })).to.equal("A new update")
			expect(Logic.updateName({})).to.equal("A new update")
		end)
	end)
end
