--!strict
-- UI/Components/SettingsList.luau: the Settings screen's rows and what each switch and volume shows.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local SettingsList = require(Components:WaitForChild("SettingsList")) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema"))
	local Settings = require(Shared:WaitForChild("Settings")) :: any

	describe("SettingsList", function()
		it("lists the sound and screen rows with unique keys, a kind each", function()
			local seen = {}
			for _, row in SettingsList.ROWS do
				expect(seen[row.key]).to.equal(nil)
				seen[row.key] = true
				expect(#row.name > 0).to.equal(true)
				expect(row.kind == "switch" or row.kind == "volume").to.equal(true)
			end
			expect(#SettingsList.SECTIONS).to.equal(2)
			expect(SettingsList.kind("musicVolume")).to.equal("volume")
			expect(SettingsList.kind("markers")).to.equal("switch")
			expect(SettingsList.isKey("music")).to.equal(true)
			expect(SettingsList.isKey("volume")).to.equal(false)
			expect(SettingsList.isKey(nil)).to.equal(false)
		end)

		it("reads the saved value and nil when the server sends none", function()
			expect(SettingsList.saved(nil, "music")).to.equal(nil)
			expect(SettingsList.saved({ music = false }, "music")).to.equal(false)
			expect(SettingsList.saved({ music = true }, "music")).to.equal(true)
			expect(SettingsList.saved({ music = true }, "markers")).to.equal(nil)
			expect(SettingsList.saved({ musicVolume = 0.4 }, "musicVolume")).to.equal(0.4)
			expect(SettingsList.saved({ musicVolume = 3 }, "musicVolume")).to.equal(1)
			expect(SettingsList.saved({ musicVolume = true }, "musicVolume")).to.equal(nil)
		end)

		it("starts from shared/Settings defaults: on, full volume, Low performance off", function()
			expect(SettingsList.shown(nil, {}, "music", 0)).to.equal(true)
			expect(SettingsList.shown({ sfx = true }, {}, "markers", 0)).to.equal(true)
			expect(SettingsList.shown(nil, {}, "lowPerformance", 0)).to.equal(false)
			expect(SettingsList.shown(nil, {}, "sfxVolume", 0)).to.equal(1)
		end)

		it("shows a fresh tap until the server agrees or the hold runs out", function()
			local taps = { music = { value = false, at = 100 } }
			expect(SettingsList.shown({ music = true }, taps, "music", 101)).to.equal(false)
			expect(SettingsList.shown({ music = false }, taps, "music", 101)).to.equal(false)
			local late = 100 + SettingsList.HOLD_SECONDS
			expect(SettingsList.shown({ music = true }, taps, "music", late)).to.equal(true)
		end)

		it("holds a released volume until the server's two decimals match it", function()
			local taps = { musicVolume = { value = 0.35, at = 100 } }
			expect(SettingsList.shown({ musicVolume = 1 }, taps, "musicVolume", 101)).to.equal(0.35)
			local saved = Settings.clean("musicVolume", 0.35)
			expect(SettingsList.shown({ musicVolume = saved }, taps, "musicVolume", 101)).to.equal(saved)
			local late = 100 + SettingsList.HOLD_SECONDS
			expect(SettingsList.shown({ musicVolume = 1 }, taps, "musicVolume", late)).to.equal(1)
		end)

		it("keeps a tap for the session on a key the server does not send", function()
			local taps = { markers = { value = false, at = 0 } }
			expect(SettingsList.shown({ music = true }, taps, "markers", 1000)).to.equal(false)
			expect(SettingsList.shown(nil, taps, "markers", 1000)).to.equal(false)
		end)

		it("follows the saved value with no tap", function()
			expect(SettingsList.shown({ sfx = false }, {}, "sfx", 0)).to.equal(false)
		end)

		it("moves volumes in 5% steps and writes them as percents", function()
			expect(SettingsList.step(0.33)).to.equal(0.35)
			expect(SettingsList.step(-1)).to.equal(0)
			expect(SettingsList.step(1.4)).to.equal(1)
			expect(SettingsList.percent(0.35)).to.equal("35%")
			expect(SettingsList.percent(1)).to.equal("100%")
			for tenths = 0, 20 do
				local volume = SettingsList.step(tenths * 0.05)
				expect(Settings.clean("sfxVolume", volume)).to.equal(volume)
			end
		end)
	end)

	describe("SettingsList edges (QA)", function()
		-- The server saves what the profile template holds (SetSetting takes the same keys, shared/Settings since
		-- engineer PR #215, which also saves Place icons). Every saved key has a row that starts at its default.
		it("has a row per saved setting, each starting at the saved default", function()
			local saved = ProfileSchema.template(0).settings :: any
			for key, value in saved do
				expect(SettingsList.isKey(key)).to.equal(true)
				expect(SettingsList.shown(nil, {}, key, 0)).to.equal(value)
			end
			for _, row in SettingsList.ROWS do
				expect(saved[row.key] ~= nil).to.equal(true)
			end
		end)
	end)
end
