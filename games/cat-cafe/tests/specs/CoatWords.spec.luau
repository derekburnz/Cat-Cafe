--!strict
-- shared/CoatWords (#3692): the word Rainbow in rainbow colours and the word Gold in gold, in announcement lines.
-- Written by the vfx-animator.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CoatWords = require(Shared.CoatWords)
	local GlobalCatch = require(Shared.GlobalCatch)
	local RareCatsTab = require(Shared.RareCatsTab)

	local function plain(rich: string): string
		return (string.gsub(rich, "<[^>]+>", ""))
	end

	describe("Coat words", function()
		it("finds the coat word after a or an, in either case", function()
			local text = "Sam caught a Rainbow Mythical Moonpaw!"
			local first, last, kind = CoatWords.find(text)
			expect(string.sub(text, first :: number, last :: number)).to.equal("Rainbow")
			expect(kind).to.equal("rainbow")
			local _, _, gold = CoatWords.find("A gold Mythical cat appeared in the Woods!")
			expect(gold).to.equal("gold")
			local _, _, out = CoatWords.find("A Rainbow Tabby is out in the Park!")
			expect(out).to.equal("rainbow")
		end)

		it("leaves names and other words alone", function()
			expect((CoatWords.find("Sam caught a Legendary Maine Coon!"))).to.equal(nil)
			expect((CoatWords.find("Goldie caught a Mythical Golden Paw!"))).to.equal(nil)
			expect((CoatWords.find("Gold caught a Mythical Moonpaw!"))).to.equal(nil)
			expect((CoatWords.find("You got 5 golden fish and a Goldfish Bowl"))).to.equal(nil)
			-- a name that holds the words: the cat's coat, later in the line, is the one coloured
			local text = "A Gold caught a Rainbow Mythical Moonpaw!"
			local first, last = CoatWords.find(text)
			expect(string.sub(text, first :: number, last :: number)).to.equal("Rainbow")
		end)

		it(
			"paints Rainbow one band colour a letter and Gold in gold, the letters unchanged",
			function()
				local rainbow = CoatWords.paint("Rainbow", "rainbow")
				expect(plain(rainbow)).to.equal("Rainbow")
				local count = select(2, string.gsub(rainbow, "<font ", ""))
				expect(count).to.equal(7)
				for _, color in CoatWords.RAINBOW do
					expect(string.find(rainbow, color, 1, true) ~= nil).to.equal(true)
				end
				expect(CoatWords.paint("Gold", "gold")).to.equal(
					'<b><font color="#FFC94D">Gold</font></b>'
				)
				expect(string.sub(rainbow, 1, 3)).to.equal("<b>")
				expect(string.sub(rainbow, -4)).to.equal("</b>")
			end
		)

		it("keeps the rest of the line as it was, escaped", function()
			local text = "<b>Sam</b> & 'Co' caught a Gold Mythical Moonpaw!"
			local rich, found = CoatWords.rich(text, CoatWords.escape)
			expect(found).to.equal(true)
			-- the name's own tag is escaped; the only bold is the coat word's
			expect(string.find(rich, "<b>Sam", 1, true)).to.equal(nil)
			expect(select(2, string.gsub(rich, "<b>", ""))).to.equal(1)
			expect(
				string.find(rich, "&lt;b&gt;Sam&lt;/b&gt; &amp; &apos;Co&apos; caught a ", 1, true)
			).to.equal(1)
			local none, missed = CoatWords.rich("Sam caught a Rare Tabby!", CoatWords.escape)
			expect(missed).to.equal(false)
			expect(none).to.equal("Sam caught a Rare Tabby!")
		end)

		it("is in the chat line and the Rare Cats tab line, inside the rarity's colour", function()
			local text = "Sam caught a Rainbow Mythical Moonpaw!"
			for _, line in
				{
					GlobalCatch.chatLine(text, "Mythical", true),
					RareCatsTab.line(text, "Mythical", false),
				}
			do
				expect(string.find(line, CoatWords.paint("Rainbow", "rainbow"), 1, true) ~= nil).to.equal(
					true
				)
				expect(
					string.find(
						line,
						'<font color="' .. GlobalCatch.color("Mythical") .. '">',
						1,
						true
					)
				).to.equal(1)
				expect(string.sub(line, -7)).to.equal("</font>")
			end
		end)
	end)
end
