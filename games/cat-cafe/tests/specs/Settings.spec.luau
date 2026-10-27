--!strict
-- shared/Settings.luau: the saved settings, what SetSetting accepts and how a save is cleaned (data-model
-- section 14; Derek 2026-10-27: a settings menu with music, volume, screen shake and the like).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Settings = require(ReplicatedStorage.Shared.Settings)

	describe("defaults", function()
		it(
			"has every key: sound on at full volume, shake on, low performance off, other cats and markers shown",
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
end
