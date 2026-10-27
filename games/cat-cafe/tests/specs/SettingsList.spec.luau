--!strict
-- UI/Components/SettingsList.luau: the Settings screen's rows and what each switch shows.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local SettingsList = require(Components:WaitForChild("SettingsList")) :: any

	describe("SettingsList", function()
		it("lists music, sound and place icons with unique keys", function()
			local seen = {}
			for _, row in SettingsList.ROWS do
				expect(seen[row.key]).to.equal(nil)
				seen[row.key] = true
				expect(#row.name > 0).to.equal(true)
			end
			expect(seen.music).to.equal(true)
			expect(seen.sfx).to.equal(true)
			expect(seen.markers).to.equal(true)
			expect(SettingsList.isKey("music")).to.equal(true)
			expect(SettingsList.isKey("volume")).to.equal(false)
			expect(SettingsList.isKey(nil)).to.equal(false)
		end)

		it("reads the saved value and nil when the server sends none", function()
			expect(SettingsList.saved(nil, "music")).to.equal(nil)
			expect(SettingsList.saved({ music = false }, "music")).to.equal(false)
			expect(SettingsList.saved({ music = true }, "music")).to.equal(true)
			expect(SettingsList.saved({ music = true }, "markers")).to.equal(nil)
		end)

		it("is on by default", function()
			expect(SettingsList.shown(nil, {}, "music", 0)).to.equal(true)
			expect(SettingsList.shown({ sfx = true }, {}, "markers", 0)).to.equal(true)
		end)

		it("shows a fresh tap until the server agrees or the hold runs out", function()
			local taps = { music = { value = false, at = 100 } }
			expect(SettingsList.shown({ music = true }, taps, "music", 101)).to.equal(false)
			expect(SettingsList.shown({ music = false }, taps, "music", 101)).to.equal(false)
			local late = 100 + SettingsList.HOLD_SECONDS
			expect(SettingsList.shown({ music = true }, taps, "music", late)).to.equal(true)
		end)

		it("keeps a tap for the session on a key the server does not save", function()
			local taps = { markers = { value = false, at = 0 } }
			expect(SettingsList.shown({ music = true }, taps, "markers", 1000)).to.equal(false)
			expect(SettingsList.shown(nil, taps, "markers", 1000)).to.equal(false)
		end)

		it("follows the saved value with no tap", function()
			expect(SettingsList.shown({ sfx = false }, {}, "sfx", 0)).to.equal(false)
		end)
	end)
end
