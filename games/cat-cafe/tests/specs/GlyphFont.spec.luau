--!strict
-- #2015: every fallback glyph the UI shows is one Roblox's emoji font can draw. Emoji from Unicode 12 on (🪴, 🪑,
-- 🦪, 🟫, 🪧 and the like) draw blank there, so a tile whose picture fails to load showed nothing. Theme's tables
-- need the game's fonts, so the uigate scene GlyphsDrawable checks those.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local StoreLogic = require(Components:WaitForChild("StoreLogic")) :: any
	local StyleLogic = require(Components:WaitForChild("StyleLogic")) :: any

	-- code point ranges of emoji added in Unicode 12 or later
	local NEW: { { number } } = {
		{ 0x1FA00, 0x1FAFF },
		{ 0x1F7E0, 0x1F7EB },
		{ 0x1F6D5, 0x1F6DF },
		{ 0x1F6FA, 0x1F6FF },
		{ 0x1F90C, 0x1F90F },
		{ 0x1F93F, 0x1F93F },
		{ 0x1F971, 0x1F979 },
		{ 0x1F97B, 0x1F97B },
		{ 0x1F9A3, 0x1F9AF },
		{ 0x1F9BA, 0x1F9BF },
		{ 0x1F9C3, 0x1F9CF },
	}

	local function drawable(glyph: string): boolean
		for _, code in utf8.codes(glyph) do
			for _, range in NEW do
				if code >= range[1] and code <= range[2] then
					return false
				end
			end
		end
		return true
	end

	local function check(name: string, glyphs: { [any]: any })
		for key, glyph in glyphs do
			if type(glyph) == "string" then
				if not drawable(glyph) then
					local text: string = glyph
					error(
						name
							.. "."
							.. tostring(key)
							.. " is "
							.. text
							.. ", which Roblox draws blank (#2015)"
					)
				end
			end
		end
	end

	describe("UI glyphs Roblox can draw (#2015)", function()
		it("finds a Unicode 12 emoji", function()
			expect(drawable("🪴")).to.equal(false)
			expect(drawable("🌿")).to.equal(true)
		end)

		it("uses none on a Store card", function()
			for _, card in StoreLogic.PASSES do
				check("StoreLogic.PASSES", { [card.key] = card.icon })
			end
		end)

		it("uses none beside a Style option", function()
			local rows = StyleLogic.rows({
				signStyles = { "bakery_stripes", "royal_crest" },
				looks = {
					themes = { "garden", "grand" },
					uniforms = { "striped" },
					accessories = { "hat" },
				},
				jukeboxTracks = { "jukebox_rainy_window" },
			})
			for _, row in rows do
				for _, option in row.options do
					if option.icon then
						check("StyleLogic", { [option.id] = option.icon })
					end
				end
			end
		end)
	end)
end
