--!strict
-- Util/FieldText.luau: Roblox drops an analytics custom field that holds , " ' or / (the live server log showed
-- "Event field CustomField02 is invalid"), so Telemetry cleans every field before it is sent.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local FieldText = require(ServerScriptService.Server.Util.FieldText)

	describe("FieldText.clean", function()
		it("leaves a plain value alone", function()
			expect(FieldText.clean("5-11")).to.equal("5-11")
			expect(FieldText.clean("30+")).to.equal("30+")
			expect(FieldText.clean("slot2 auto")).to.equal("slot2 auto")
			expect(FieldText.clean("")).to.equal("")
		end)

		it("takes out every character Roblox refuses", function()
			local out = FieldText.clean("a,b/c\"d'e")
			expect(string.find(out, "[,/\"']")).to.equal(nil)
			expect(out).to.equal("a b-cde")
		end)

		it("keeps one space where a comma and a space met, none at the ends", function()
			expect(FieldText.clean("tabby, calico")).to.equal("tabby calico")
			expect(FieldText.clean(",tabby,")).to.equal("tabby")
		end)

		it("cuts a long value to MAX", function()
			expect(#FieldText.clean(string.rep("x", 300))).to.equal(FieldText.MAX)
		end)
	end)
end
