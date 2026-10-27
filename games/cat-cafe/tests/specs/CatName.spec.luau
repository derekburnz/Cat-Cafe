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

		it("keeps letters from any script and emoji", function()
			expect((CatName.validate("Ńeko 猫"))).to.equal("Ńeko 猫")
			expect((CatName.validate("Tiny 🐾"))).to.equal("Tiny 🐾")
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
