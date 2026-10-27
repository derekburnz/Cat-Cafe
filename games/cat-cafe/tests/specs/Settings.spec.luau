--!strict
-- shared/Settings.luau: the saved settings, what SetSetting accepts and how a save is cleaned (data-model
-- section 14; Derek 2026-10-27: a settings menu with music, volume, screen shake and the like).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Settings = require(ReplicatedStorage.Shared.Settings)

	describe("defaults", function()
		it(
			"has every key: sound on at full volume, shake on, low performance off, other cats, markers and the Tutorial tile shown",
			function()
				expect(Settings.defaults() :: any).to.deepEqual({
					music = true,
					sfx = true,
					musicVolume = 1,
					sfxVolume = 1,
					screenShake = true,
					lowPerformance = false,
					showOtherCats = true,
					markers = true,
					tutorialButton = true,
				})
				for key in pairs(Settings.defaults() :: any) do
					expect(Settings.kinds[key]).to.be.ok()
				end
			end
		)
	end)

	describe("clean (what SetSetting accepts)", function()
		it("a switch takes only a boolean", function()
			expect(Settings.clean("music", false)).to.equal(false)
			expect(Settings.clean("screenShake", true)).to.equal(true)
			expect(Settings.clean("lowPerformance", 1)).never.to.be.ok()
			expect(Settings.clean("markers", "true")).never.to.be.ok()
			expect(Settings.clean("showOtherCats", nil)).never.to.be.ok()
			expect(Settings.clean("tutorialButton", false)).to.equal(false)
			expect(Settings.clean("tutorialButton", "off")).never.to.be.ok()
		end)

		it("a volume takes a number, clamped to 0 to 1 and kept to two decimals", function()
			expect(Settings.clean("musicVolume", 0.5)).to.equal(0.5)
			expect(Settings.clean("sfxVolume", 0)).to.equal(0)
			expect(Settings.clean("sfxVolume", 0.333333)).to.equal(0.33)
			expect(Settings.clean("musicVolume", 1.0000001)).to.equal(1)
			expect(Settings.clean("musicVolume", 7)).to.equal(1)
			expect(Settings.clean("musicVolume", -2)).to.equal(0)
			expect(Settings.clean("musicVolume", 0 / 0)).never.to.be.ok()
			expect(Settings.clean("musicVolume", math.huge)).never.to.be.ok()
			expect(Settings.clean("musicVolume", -math.huge)).never.to.be.ok()
			expect(Settings.clean("musicVolume", true)).never.to.be.ok()
			expect(Settings.clean("musicVolume", "0.5")).never.to.be.ok()
		end)

		it("refuses keys the profile does not save", function()
			expect(Settings.clean("coins", true)).never.to.be.ok()
			expect(Settings.clean("volume", 0.5)).never.to.be.ok()
			expect(Settings.clean(5, true)).never.to.be.ok()
			expect(Settings.clean(nil, true)).never.to.be.ok()
		end)
	end)

	describe("sanitize (loading a save)", function()
		it("fills missing keys, keeps valid values and drops the rest", function()
			local cleaned = Settings.sanitize({
				music = false,
				sfxVolume = 0.25,
				musicVolume = "loud",
				screenShake = "no",
				lowPerformance = true,
				extra = true,
			})
			expect(cleaned :: any).to.deepEqual({
				music = false,
				sfx = true,
				musicVolume = 1,
				sfxVolume = 0.25,
				screenShake = true,
				lowPerformance = true,
				showOtherCats = true,
				markers = true,
				tutorialButton = true,
			})
		end)

		it("gives the defaults for a save with no settings", function()
			expect(Settings.sanitize(nil) :: any).to.deepEqual(Settings.defaults())
			expect(Settings.sanitize("on") :: any).to.deepEqual(Settings.defaults())
		end)

		it("copies, so the sync never shares the profile's table", function()
			local settings = Settings.defaults()
			local copy = Settings.copy(settings)
			expect(copy :: any).to.deepEqual(settings)
			expect(copy).never.to.equal(settings)
		end)
	end)

	describe("Settings edges (QA)", function()
		-- Every new profile takes Settings.defaults() (ProfileSchema.template). A shared table would let one
		-- player's SetSetting change the settings of every player who joins that server after them.
		it("gives every caller a fresh defaults table", function()
			local first = Settings.defaults() :: any
			first.music = false
			first.musicVolume = 0
			expect(Settings.defaults() :: any).never.to.equal(first)
			expect(Settings.defaults().music).to.equal(true)
			expect(Settings.defaults().musicVolume).to.equal(1)
			local loaded = Settings.sanitize(nil) :: any
			loaded.sfx = false
			expect(Settings.defaults().sfx).to.equal(true)
		end)

		it("has a default for every kind, each one a value clean keeps", function()
			local defaults = Settings.defaults() :: any
			for key in Settings.kinds do
				expect(key .. " = " .. tostring(defaults[key])).never.to.equal(key .. " = nil")
				expect(Settings.clean(key, defaults[key])).to.equal(defaults[key])
			end
		end)

		it("saves a volume as clean's own answer: 0 to 1, two decimals, never down", function()
			local last = -1
			for step = -500, 1500 do
				local value = Settings.clean("sfxVolume", step / 1000) :: number
				expect(value >= 0 and value <= 1).to.equal(true)
				expect(value >= last).to.equal(true)
				expect(Settings.clean("sfxVolume", value)).to.equal(value)
				expect(math.abs(value * 100 - math.round(value * 100)) < 1e-9).to.equal(true)
				last = value
			end
		end)

		it("cleans a cleaned save to itself and leaves the loaded table alone", function()
			local raw = {
				music = 0,
				sfx = false,
				musicVolume = 0.456,
				sfxVolume = 2,
				lowPerformance = "yes",
				markers = false,
			}
			local once = Settings.sanitize(raw) :: any
			expect(once).never.to.equal(raw)
			expect(Settings.sanitize(once) :: any).to.deepEqual(once)
			expect(once.music).to.equal(true)
			expect(once.musicVolume).to.equal(0.46)
			expect(once.sfxVolume).to.equal(1)
			expect(once.markers).to.equal(false)
			expect(raw.music).to.equal(0)
			expect(raw.sfxVolume).to.equal(2)
			expect(raw.lowPerformance).to.equal("yes")
		end)
	end)
end
