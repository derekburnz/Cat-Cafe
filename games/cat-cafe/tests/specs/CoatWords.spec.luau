--!strict
-- #3692: the coat word of a rare cat line in its own colours (shared/CoatWords).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local CoatWords = require(Shared.CoatWords)
	local GlobalCatch = require(Shared.GlobalCatch)
	local RareCatsTab = require(Shared.RareCatsTab)

	local GOLD = '<b><font color="#FFC94D">gold</font></b>'
	local RAINBOW = "<b>"
		.. '<font color="#FF5A5F">r</font>'
		.. '<font color="#FF9F43">a</font>'
		.. '<font color="#FFD93D">i</font>'
		.. '<font color="#4CD38A">n</font>'
		.. '<font color="#4AA8FF">b</font>'
		.. '<font color="#B46CFF">o</font>'
		.. '<font color="#FF5A5F">w</font>'
		.. "</b>"

	describe("CoatWords (#3692)", function()
		it("finds the coat right before a rarity word", function()
			local text = "Sam caught a gold Legendary Maine Coon!"
			local first, last, coat = CoatWords.find(text)
			expect(coat).to.equal("gold")
			expect(string.sub(text, first :: number, last :: number)).to.equal("gold")
			text = "A rainbow Mythical cat appeared in the Woods!"
			first, last, coat = CoatWords.find(text)
			expect(coat).to.equal("rainbow")
			expect(string.sub(text, first :: number, last :: number)).to.equal("rainbow")
			text = "Sam caught a gold SECRET cat: Nebula!"
			first, last, coat = CoatWords.find(text)
			expect(coat).to.equal("gold")
			expect(string.sub(text, first :: number, last :: number)).to.equal("gold")
		end)

		it("finds the Rainbow of a rainbow stray's spawn line", function()
			local lines = {
				"A Rainbow Tabby is out in the Woods!",
				"🌈 A Rainbow Tabby is out in the Woods!",
			}
			for _, text in lines do
				local first, last, coat = CoatWords.find(text)
				expect(coat).to.equal("rainbow")
				expect(string.sub(text, first :: number, last :: number)).to.equal("Rainbow")
			end
		end)

		it("leaves a plain line, a player's name and a cat's name alone", function()
			expect((CoatWords.find("Sam caught a Mythical Moonpaw!"))).to.equal(nil)
			-- the words in a name are not the coat: no rarity word comes right after them
			expect((CoatWords.find("gold caught a Mythical Moonpaw!"))).to.equal(nil)
			expect((CoatWords.find("Sam caught a Legendary Rainbow Trout!"))).to.equal(nil)
			expect((CoatWords.find("Sam pulled a Mythical Gold Leaf from a crate!"))).to.equal(nil)
			-- a name that reads like a coat line loses to the real coat, which comes after it
			local text = "a gold Epic caught a rainbow Legendary Tabby!"
			local first, last, coat = CoatWords.find(text)
			expect(coat).to.equal("rainbow")
			expect(string.sub(text, 1, (first :: number) - 1)).to.equal("a gold Epic caught a ")
			expect(last).to.equal((first :: number) + #"rainbow" - 1)
		end)

		it("finds the coat in every line Catching words", function()
			for rarity in Catalog.rarityRank do
				for _, coat in { "gold", "rainbow" } do
					local def = { name = "Tabby", rarity = rarity } :: any
					local line = Catching.shoutOut("Sam", "caught", def, coat, nil)
					if line ~= nil then
						local first, last, found = CoatWords.find(line)
						expect(found).to.equal(coat)
						expect(string.sub(line, first :: number, last :: number)).to.equal(coat)
					end
				end
			end
		end)

		it("paints gold in one colour and rainbow a colour a letter", function()
			expect(CoatWords.paint("gold", "gold")).to.equal(GOLD)
			expect(CoatWords.paint("rainbow", "rainbow")).to.equal(RAINBOW)
		end)

		it("escapes everything around the word", function()
			local line = CoatWords.rich("<Sam> caught a gold Epic Tabby!", GlobalCatch.escape)
			expect(line).to.equal("&lt;Sam&gt; caught a " .. GOLD .. " Epic Tabby!")
			line = CoatWords.rich("<b>x</b>", GlobalCatch.escape)
			expect(line).to.equal("&lt;b&gt;x&lt;/b&gt;")
		end)

		it("colours the word in the chat line and in the tab's line", function()
			local chat =
				GlobalCatch.chatLine("Sam caught a rainbow Legendary Tabby!", "Legendary", true)
			local open = '<font color="#FFC94D">🌍 Global: Sam caught a '
			expect(chat).to.equal(open .. RAINBOW .. " Legendary Tabby!</font>")
			local tab = RareCatsTab.line("Sam caught a gold Mythical Moonpaw!", "Mythical", false)
			open = '<font color="#FF5E7E">⭐ Sam caught a '
			expect(tab).to.equal(open .. GOLD .. " Mythical Moonpaw!</font>")
		end)
	end)
end
