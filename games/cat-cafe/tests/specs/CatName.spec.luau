--!strict
-- shared/CatName.luau against data-model section 4 (F33, reviewer S30): what RenameCat accepts before it filters,
-- and when the filtered text counts as refused. The "edges (QA)" block is QA's: the ends of every allowed range,
-- every ASCII character, the reasons the abuse client keys on and the byte cap.
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

	describe("edges (QA)", function()
		local TOO_LONG = string.format("Names can be up to %d characters", Config.CatNameMaxLength)
		local BAD = "That name has characters we can't use"
		local EMPTY = "Type a name first"

		local function reasonFor(raw: any): string?
			local _, reason = CatName.validate(raw)
			return reason
		end

		it("allows both ends of every range and refuses the code point just outside", function()
			-- { first, last } of each allowed range in CatName, and the neighbours that must stay out
			local ranges = {
				{ 0x00C0, 0x00D6 },
				{ 0x00D8, 0x00F6 },
				{ 0x00F8, 0x024F },
				{ 0x3041, 0x3096 },
				{ 0x309B, 0x30FF },
				{ 0x4E00, 0x9FFF },
				{ 0xAC00, 0xD7A3 },
				{ 0x1F300, 0x1FAFF },
			}
			for _, range in ranges do
				for _, code in { range[1], range[2] } do
					local raw = "a" .. utf8.char(code)
					expect((CatName.validate(raw))).to.equal(raw)
				end
			end
			local outside = {
				0xBF, -- inverted question mark, before the Latin-1 letters
				0xD7, -- multiplication sign
				0xF7, -- division sign
				0x250, -- IPA, after Latin Extended-B
				0x3040, -- before Hiragana
				0x3097, -- after Hiragana
				0x3099, -- the combining sound marks
				0x309A,
				0x3100, -- Bopomofo, after Katakana
				0x4DFF, -- before the CJK ideographs
				0xA000, -- Yi, after them
				0xABFF, -- before the Hangul syllables
				0xD7A4, -- after them
				0x1F2FF, -- before the emoji
				0x1FB00, -- after them
			}
			for _, code in outside do
				expect(reasonFor("a" .. utf8.char(code))).to.equal(BAD)
			end
		end)

		it("takes ASCII letters, digits, space and ' - . ! ?, and no other ASCII", function()
			local letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
			local allowed = letters .. "0123456789 '-.!?"
			for code = 0, 0x7F do
				local char = string.char(code)
				local raw = "a" .. char .. "b"
				if string.find(allowed, char, 1, true) ~= nil then
					expect((CatName.validate(raw))).to.equal(raw)
				else
					expect(reasonFor(raw)).to.equal(BAD)
				end
			end
		end)

		it("refuses joined emoji, flags and keycaps", function()
			local cases = {
				"\u{1F468}\u{200D}\u{1F469}", -- a family joined by U+200D
				"\u{1F1EF}\u{1F1F5}", -- a flag from regional indicators
				"1\u{FE0F}\u{20E3}", -- a keycap
			}
			for _, raw in cases do
				expect(reasonFor(raw)).to.equal(BAD)
			end
		end)

		it("gives the abuse client's three reasons, length first and then characters", function()
			expect(reasonFor(nil)).to.equal(EMPTY)
			expect(reasonFor(" \t\n ")).to.equal(EMPTY)
			expect(reasonFor(string.rep("a", Config.CatNameMaxLength + 1))).to.equal(TOO_LONG)
			-- too long and a bad character: the length is checked first
			expect(reasonFor(string.rep("#", Config.CatNameMaxLength + 1))).to.equal(TOO_LONG)
			expect(reasonFor("Mo\255chi")).to.equal(BAD)
		end)

		it("counts a 4 byte emoji as one character", function()
			local max = Config.CatNameMaxLength
			expect((CatName.validate(string.rep("\u{1F43E}", max)))).to.be.ok()
			expect(reasonFor(string.rep("\u{1F43E}", max + 1))).to.equal(TOO_LONG)
		end)

		it("trims ASCII whitespace at the ends and caps the raw string at MAX_BYTES", function()
			expect((CatName.validate("\tMochi\n"))).to.equal("Mochi")
			local padding = string.rep(" ", CatName.MAX_BYTES - 5)
			expect((CatName.validate(padding .. "Mochi"))).to.equal("Mochi")
			expect(reasonFor(padding .. " Mochi")).to.equal(BAD)
			-- room for CatNameMaxLength 4 byte characters
			expect(CatName.MAX_BYTES >= 4 * Config.CatNameMaxLength).to.equal(true)
		end)
	end)
end
