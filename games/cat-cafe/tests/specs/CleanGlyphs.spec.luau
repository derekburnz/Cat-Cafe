--!strict
-- UI/Components/CleanGlyphs.luau: windows draw the clean symbols the HUD uses (#1027).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CleanGlyphs = require(Components:WaitForChild("CleanGlyphs")) :: any
	local ShopIcons = require(Components:WaitForChild("ShopIcons")) :: any

	describe("CleanGlyphs", function()
		it("names an uploaded clean symbol for every entry", function()
			for _, name in CleanGlyphs.icons do
				expect(ShopIcons.clean(name)).to.be.ok()
			end
			for _, name in CleanGlyphs.foods do
				expect(ShopIcons.clean(name)).to.be.ok()
			end
		end)
		it("maps the Tip Jar and Daily Treat badges to the Rewards gift", function()
			expect(CleanGlyphs.icons.gifts).to.equal("Rewards")
			expect(CleanGlyphs.icons.daily).to.equal("Rewards")
		end)
		it("builds the sheet's glyph to cell map from Theme.icons keys", function()
			local cells = CleanGlyphs.sheet({ lock = "🔒", unlock = "🔓" })
			expect(cells["🔒"]).to.equal(CleanGlyphs.sheetCells.lock)
			expect(cells["🔓"]).to.equal(nil)
		end)
		it("builds a glyph map and skips keys the icon tables lack", function()
			local map = CleanGlyphs.map(
				{ crate = "📦", potion = "🧪", unlock = "🔓" },
				{ kibble = "🥣" }
			)
			expect(map["📦"]).to.equal("Crate")
			expect(map["🧪"]).to.equal("Potion")
			expect(map["🥣"]).to.equal("Bowl")
			expect(map["🔓"]).to.equal(nil)
			expect(map["🐱"]).to.equal(nil) -- cats is mapped, but this icon table has no cats key
		end)
		it(
			"draws the Settings gear, the Spin wheel and the Alley clean, not from the old sheet",
			function()
				local map = CleanGlyphs.map(
					{ settings = "⚙️", spin = "🎡", alley = "🐾" },
					{}
				)
				expect(map["⚙️"]).to.equal("Menu")
				expect(map["🎡"]).to.equal("Spin")
				expect(map["🐾"]).to.equal("Catflap")
			end
		)
		it("draws Equip Best, Invite and the lock clean (#1136)", function()
			local map = CleanGlyphs.map({ equipBest = "✨", invite = "💌", lock = "🔒" }, {})
			expect(map["✨"]).to.equal("EquipBest")
			expect(map["💌"]).to.equal("Invite")
			expect(map["🔒"]).to.equal("Lock")
		end)
		it(
			"has a clean symbol for every Theme.iconSheet cell, so no glyph reaches the old sheet",
			function()
				for key in CleanGlyphs.sheetCells do
					local name = CleanGlyphs.icons[key]
					expect(name).to.be.ok()
					expect(ShopIcons.clean(name)).to.be.ok()
				end
			end
		)
	end)
end
