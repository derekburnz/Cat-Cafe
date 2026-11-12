--!strict
-- #3053: the chat's Rare Cats tab (shared/RareCatsTab), behind the `rareCatsTab` switch.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GlobalCatch = require(Shared.GlobalCatch)
	local LiveFlags = require(Shared.LiveFlags)
	local RareCatsTab = require(Shared.RareCatsTab)

	describe("RareCatsTab (#3053)", function()
		it(
			"sends every line to the tab and keeps other servers' lines out of Here (#3673)",
			function()
				expect(RareCatsTab.NAME).to.equal("🌍 Global")
				local toTab, toHere = RareCatsTab.route(true, true)
				expect(toTab).to.equal(true)
				expect(toHere).to.equal(false)
				toTab, toHere = RareCatsTab.route(true, false)
				expect(toTab).to.equal(true)
				expect(toHere).to.equal(true)
				-- no tab for this player: everything stays in the normal chat, as before
				for _, elsewhere in { true, false } do
					toTab, toHere = RareCatsTab.route(false, elsewhere)
					expect(toTab).to.equal(false)
					expect(toHere).to.equal(true)
				end
			end
		)

		it("takes Mythical and Secret lines and nothing below", function()
			expect(RareCatsTab.wants("Mythical")).to.equal(true)
			expect(RareCatsTab.wants("Secret")).to.equal(true)
			expect(RareCatsTab.wants("Legendary")).to.equal(false)
			expect(RareCatsTab.wants("Common")).to.equal(false)
			expect(RareCatsTab.wants("Nonsense")).to.equal(false)
		end)

		it(
			"takes a gold or rainbow Legendary cat's line, and no other Legendary line (Derek 2026-11-12)",
			function()
				expect(RareCatsTab.wants("Legendary", "Sam caught a gold Legendary Sunny!")).to.equal(
					true
				)
				expect(RareCatsTab.wants("Legendary", "Sam rescued a rainbow Legendary Sunny!")).to.equal(
					true
				)
				expect(RareCatsTab.wants("Legendary", "Sam caught a Legendary Sunny!")).to.equal(
					false
				)
				expect(RareCatsTab.wants("Legendary", "Sam found a Legendary Golden Fountain!")).to.equal(
					false
				)
				expect(RareCatsTab.wants("Epic", "Sam caught a gold Epic Moonpaw!")).to.equal(false)
				expect(RareCatsTab.wants("Mythical", "Sam caught a gold Mythical Moonpaw!")).to.equal(
					true
				)
			end
		)

		it(
			"marks a line from another server and one from this server, in the rarity's colour",
			function()
				local away =
					RareCatsTab.line("Sam caught a Mythical Midnight Sky!", "Mythical", true)
				local here =
					RareCatsTab.line("Sam caught a Mythical Midnight Sky!", "Mythical", false)
				expect(away).to.equal(
					'<font color="'
						.. GlobalCatch.color("Mythical")
						.. '">🌍 Sam caught a Mythical Midnight Sky!</font>'
				)
				expect(here).to.equal(
					'<font color="'
						.. GlobalCatch.color("Mythical")
						.. '">⭐ Sam caught a Mythical Midnight Sky!</font>'
				)
			end
		)

		it("escapes what rich text would read", function()
			local line = RareCatsTab.line('<b>x</b> & "y"', "Mythical", false)
			expect(string.find(line, "<b>", 1, true)).never.to.be.ok()
			expect(string.find(line, "&lt;b&gt;x&lt;/b&gt; &amp; &quot;y&quot;", 1, true)).to.be.ok()
		end)

		it("shows one line every GAP_SECONDS, oldest first", function()
			local queue = RareCatsTab.queue()
			expect(RareCatsTab.pop(queue, 100)).never.to.be.ok()
			RareCatsTab.push(queue, "a")
			RareCatsTab.push(queue, "b")
			RareCatsTab.push(queue, "c")
			expect(RareCatsTab.pop(queue, 100)).to.equal("a")
			expect(RareCatsTab.pop(queue, 100 + RareCatsTab.GAP_SECONDS - 0.1)).never.to.be.ok()
			expect(RareCatsTab.pop(queue, 100 + RareCatsTab.GAP_SECONDS)).to.equal("b")
			expect(RareCatsTab.pop(queue, 100 + 2 * RareCatsTab.GAP_SECONDS)).to.equal("c")
			expect(RareCatsTab.pop(queue, 1000)).never.to.be.ok()
		end)

		it(
			"keeps at most KEEP waiting and drops the oldest, so nothing shows minutes late",
			function()
				local queue = RareCatsTab.queue()
				for i = 1, RareCatsTab.KEEP + 5 do
					RareCatsTab.push(queue, tostring(i))
				end
				expect(#queue.waiting).to.equal(RareCatsTab.KEEP)
				expect(RareCatsTab.pop(queue, 0)).to.equal("6")
				-- the longest any line waits: KEEP lines at one every GAP_SECONDS
				expect(RareCatsTab.KEEP * RareCatsTab.GAP_SECONDS <= 90).to.equal(true)
			end
		)

		it("waits behind a switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, RareCatsTab.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[RareCatsTab.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[RareCatsTab.FLAG]).to.equal(false)
			expect(LiveFlags.shown(RareCatsTab.FLAG, nil)).to.equal(false)
			expect(LiveFlags.shown(RareCatsTab.FLAG, true)).to.equal(true)
		end)
	end)
end
