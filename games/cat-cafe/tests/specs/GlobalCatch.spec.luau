--!strict
-- GlobalCatch.luau (#2203): the rare-catch chat line, its MessagingService message and the two rate limits.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local GlobalCatch = require(Shared.GlobalCatch)
	local RestartNotice = require(Shared.RestartNotice)

	local TEXT = "Sam caught a Legendary Maine Coon!"

	describe("the message", function()
		it("reads back what another server sent", function()
			local text, rarity =
				GlobalCatch.parse(GlobalCatch.encode(TEXT, "Legendary", "job-a"), "job-b")
			expect(text).to.equal(TEXT)
			expect(rarity).to.equal("Legendary")
		end)

		it("skips this server's own message", function()
			local text = GlobalCatch.parse(GlobalCatch.encode(TEXT, "Legendary", "job-a"), "job-a")
			expect(text).never.to.be.ok()
		end)

		it("ignores anything that is not a rare-catch line", function()
			local bad: { any } = {
				nil,
				"text",
				5,
				{},
				{ t = TEXT, r = "Legendary" },
				{ t = TEXT, r = "Shiny", j = "job-a" },
				{ t = "", r = "Legendary", j = "job-a" },
				{ t = string.rep("a", GlobalCatch.MAX_TEXT + 1), r = "Legendary", j = "job-a" },
				{ t = 5, r = "Legendary", j = "job-a" },
				{ t = TEXT, r = "Legendary", j = 5 },
			}
			for i = 1, 10 do
				local text, rarity = GlobalCatch.parse(bad[i], "job-b")
				expect(text).never.to.be.ok()
				expect(rarity).never.to.be.ok()
			end
			local longest = string.rep("a", GlobalCatch.MAX_TEXT)
			expect(GlobalCatch.parse({ t = longest, r = "Mythical", j = "job-a" }, "job-b")).to.equal(
				longest
			)
		end)

		it("has its own topic, apart from the restart countdown's", function()
			expect(GlobalCatch.TOPIC).never.to.equal(RestartNotice.TOPIC)
		end)

		it("fits well inside MessagingService's 1 kB", function()
			-- its JSON is the three strings, their keys and about 20 characters of quotes, colons and braces
			local message = GlobalCatch.encode(
				string.rep("a", GlobalCatch.MAX_TEXT),
				"Legendary",
				string.rep("j", 40)
			)
			local size = 0
			for key, value in message :: any do
				size += #key + #value + 6
			end
			expect(size + 2 < 300).to.equal(true)
		end)
	end)

	describe("the gates", function()
		it("lets one line through every gap", function()
			local gate = GlobalCatch.gate(5)
			expect(GlobalCatch.take(gate, 100, "Legendary")).to.equal(true)
			expect(GlobalCatch.take(gate, 101, "Legendary")).to.equal(false)
			expect(GlobalCatch.take(gate, 104.99, "Common")).to.equal(false)
			expect(GlobalCatch.take(gate, 105, "Legendary")).to.equal(true)
		end)

		it("always lets a Mythical through, and counts it", function()
			local gate = GlobalCatch.gate(5)
			expect(GlobalCatch.take(gate, 100, "Legendary")).to.equal(true)
			expect(GlobalCatch.take(gate, 101, "Mythical")).to.equal(true)
			expect(GlobalCatch.take(gate, 102, "Mythical")).to.equal(true)
			expect(GlobalCatch.take(gate, 106, "Legendary")).to.equal(false)
			expect(GlobalCatch.take(gate, 107, "Legendary")).to.equal(true)
		end)

		it("publishes at most one a 5 s and shows one from elsewhere every 3 s", function()
			expect(GlobalCatch.PUBLISH_GAP_SECONDS).to.equal(5)
			expect(GlobalCatch.SHOW_GAP_SECONDS).to.equal(3)
		end)
	end)

	describe("the chat line", function()
		it("is the shout-out in the rarity's colour", function()
			expect(GlobalCatch.chatLine(TEXT, "Legendary", false)).to.equal(
				'<font color="#FFC94D">Sam caught a Legendary Maine Coon!</font>'
			)
		end)

		it("says when it came from another cafe", function()
			expect(GlobalCatch.chatLine("Dee tamed a Mythical Moonpaw!", "Mythical", true)).to.equal(
				'<font color="#FF5E7E">From another cafe: Dee tamed a Mythical Moonpaw!</font>'
			)
		end)

		it("escapes rich text in the name, so nobody can restyle the line", function()
			expect(GlobalCatch.chatLine("<b>A&B</b> \"x\" 'y'", "Rare", false)).to.equal(
				'<font color="#5FA8FF">&lt;b&gt;A&amp;B&lt;/b&gt; &quot;x&quot; &apos;y&apos;</font>'
			)
		end)

		it("has a colour for every rarity, and falls back to Common's", function()
			for rarity in Catalog.rarityRank do
				expect(GlobalCatch.COLORS[rarity]).to.be.ok()
			end
			expect(GlobalCatch.chatLine("x", "Bogus", false)).to.equal(
				'<font color="#8E97B2">x</font>'
			)
		end)
	end)
end
