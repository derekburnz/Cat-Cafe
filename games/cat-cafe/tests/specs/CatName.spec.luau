--!strict
-- shared/CatName.luau against data-model section 4 (F33, reviewer S30): what RenameCat accepts before it filters,
-- and when the filtered text counts as refused.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatName = require(Shared.CatName)
	local Config = require(Shared.Config)

	describe("validate", function()
		it("trims the name and keeps what is inside", function()
			expect((CatName.validate("  Mochi  "))).to.equal("Mochi")
			expect((CatName.validate("Sir Fluff"))).to.equal("Sir Fluff")
		end)

		it("needs a string with at least one character after trimming", function()
			local cases: { any } = { "", "   ", 5, true, {} }
			for _, raw in cases do
				local name, reason = CatName.validate(raw)
				expect(name).never.to.be.ok()
				expect(type(reason)).to.equal("string")
			end
		end)

		it("counts characters with utf8.len, up to CatNameMaxLength", function()
			local max = Config.CatNameMaxLength
			expect((CatName.validate(string.rep("a", max)))).to.be.ok()
			expect((CatName.validate(string.rep("a", max + 1)))).never.to.be.ok()
			-- 20 two-byte characters are 40 bytes and still fit
			expect((CatName.validate(string.rep("é", max)))).to.be.ok()
			expect((CatName.validate(string.rep("é", max + 1)))).never.to.be.ok()
		end)

		it("refuses invalid UTF-8 and anything over MAX_BYTES before counting", function()
			expect((CatName.validate("Mo\255chi"))).never.to.be.ok()
			expect((CatName.validate(string.rep(" ", CatName.MAX_BYTES) .. "a"))).never.to.be.ok()
		end)

		it("refuses control characters, newlines, < and >", function()
			for _, raw in { "Mo\nchi", "Mo\tchi", "Mo\0chi", "Mo\127chi", "<b>Mochi", "Mochi>", "Mo\u{85}chi" } do
				expect((CatName.validate(raw))).never.to.be.ok()
			end
		end)

		it("refuses zero-width and bidi format characters", function()
			for _, raw in { "Mo\u{200B}chi", "Mo\u{202E}chi", "Mo\u{2066}chi", "\u{FEFF}Mochi" } do
				expect((CatName.validate(raw))).never.to.be.ok()
			end
		end)

		it("allows only listed characters, so blanks, line breaks, tags and stacked marks fail (S47)", function()
			local cases = {
				"Mo\u{AD}chi", -- soft hyphen
				"Mo\u{34F}chi", -- combining grapheme joiner
				"Mo\u{61C}chi", -- Arabic letter mark
				"Mo\u{2028}chi", -- line separator
				"Mo\u{2029}chi", -- paragraph separator
				"\u{3164}", -- Hangul filler
				"Mo\u{2800}chi", -- braille blank
				"Mochi\u{E0041}", -- tag letter A
				"Moche\u{301}", -- combining acute
				"Mo\u{FE0F}chi", -- variation selector
				"Mo\u{FFF9}chi", -- annotation anchor
				"Mo\u{3099}chi", -- combining kana sound mark
				"Mo\u{A0}chi", -- no-break space (QA): only the ASCII space is a space
				"Mo\u{2003}chi", -- em space
				"\u{3000}", -- ideographic space
				"Mo\u{17B4}chi", -- Khmer inherent vowel, draws nothing
				"a" .. string.rep("\u{336}", 19), -- stacked combining strokes (QA's tower)
				"Mo@chi",
				"Mo#chi",
				"1 × 2",
			}
			for _, raw in cases do
				expect((CatName.validate(raw))).never.to.be.ok()
			end
		end)

		it("keeps ASCII letters, digits, spaces and ' - . ! ?", function()
			for _, raw in { "Mr. Whiskers!", "O'Malley", "Mochi-chan?", "Cat 9" } do
				expect((CatName.validate(raw))).to.equal(raw)
			end
		end)

		it("keeps accented Latin letters, kana, CJK, Hangul syllables and single emoji", function()
			for _, raw in { "Ńeko 猫", "Tiny 🐾", "Zoë", "ねこ", "ネコ", "고양이" } do
				expect((CatName.validate(raw))).to.equal(raw)
			end
		end)
	end)

	describe("allHashes", function()
		it("is true when the filter left only hashes and spaces, or nothing", function()
			expect(CatName.allHashes("#####")).to.equal(true)
			expect(CatName.allHashes("### ##")).to.equal(true)
			expect(CatName.allHashes("")).to.equal(true)
		end)

		it("is false when any of the name survives", function()
			expect(CatName.allHashes("Mochi")).to.equal(false)
			expect(CatName.allHashes("Mo###")).to.equal(false)
		end)
	end)
end
