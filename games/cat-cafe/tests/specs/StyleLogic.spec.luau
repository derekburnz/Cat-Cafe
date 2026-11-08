--!strict
-- UI/Components/StyleLogic.luau: the Decor window's Style tab rows (#1624, store-pass-looks.md).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local StyleLogic = require(Components:WaitForChild("StyleLogic")) :: any

	local function names(row: any): string
		local out: { string } = {}
		for _, option in row.options do
			table.insert(out, option.name .. (if option.picked then "*" else ""))
		end
		return table.concat(out, ",")
	end

	describe("StyleLogic.rows", function()
		it("shows nothing for a player with no style", function()
			expect(#StyleLogic.rows({ signStyles = {} })).to.equal(0)
			expect(StyleLogic.shows({ signStyles = {} })).to.equal(false)
			expect(StyleLogic.shows({})).to.equal(false)
			expect(StyleLogic.shows(nil)).to.equal(false)
		end)

		it("lists the plain sign and each owned sign style, the pick in gold", function()
			local rows = StyleLogic.rows({
				signStyles = { "bakery_stripes", "royal_crest" },
				signStyle = "royal_crest",
			})
			expect(#rows).to.equal(1)
			expect(rows[1].kind).to.equal("sign")
			expect(rows[1].title).to.equal("Cafe sign")
			expect(names(rows[1])).to.equal("Plain,Bakery Stripes,Royal Crest*")
			expect(rows[1].options[1].id).to.equal("")
			expect(StyleLogic.shows({ signStyles = { "bakery_stripes" } })).to.equal(true)
		end)

		it("shows the plain sign picked when the pick is not owned or unset", function()
			local unset = StyleLogic.rows({ signStyles = { "bakery_stripes" } })
			expect(names(unset[1])).to.equal("Plain*,Bakery Stripes")
			local gone =
				StyleLogic.rows({ signStyles = { "bakery_stripes" }, signStyle = "royal_crest" })
			expect(names(gone[1])).to.equal("Plain*,Bakery Stripes")
		end)

		it(
			"adds uniforms and themes once the server sends looks, leaving out the default",
			function()
				local rows = StyleLogic.rows({
					signStyles = {},
					looks = {
						uniform = "midnight",
						uniforms = { "default", "striped", "midnight", "mint", "uniform_pumpkin" },
						theme = "default",
						themes = { "default" },
					},
				})
				expect(#rows).to.equal(1) -- only the default theme: no theme row
				expect(rows[1].kind).to.equal("uniform")
				expect(names(rows[1])).to.equal("Classic,Striped,Midnight*,Mint,Pumpkin")
				local both = StyleLogic.rows({
					signStyles = { "bakery_stripes" },
					looks = {
						theme = "grand",
						themes = { "default", "garden", "grand" },
						uniforms = {},
					},
				})
				expect(#both).to.equal(2)
				expect(both[2].title).to.equal("Cafe theme")
				expect(names(both[2])).to.equal("Classic,Garden,Grand*")
			end
		)

		it("adds the cat accessory row next to the uniform, None first (#1708)", function()
			local rows = StyleLogic.rows({
				signStyles = {},
				looks = {
					uniform = "striped",
					uniforms = { "striped" },
					accessories = { "hat", "acc_tiny_lantern" },
					themes = { "garden" },
				},
			})
			expect(#rows).to.equal(3)
			expect(rows[2].kind).to.equal("accessory")
			expect(rows[2].title).to.equal("Cat accessory")
			expect(names(rows[2])).to.equal("None*,Tiny Hat,Tiny Lantern")
			expect(rows[3].kind).to.equal("theme")
			local picked =
				StyleLogic.rows({ looks = { accessory = "hat", accessories = { "hat" } } })
			expect(names(picked[1])).to.equal("None,Tiny Hat*")
			expect(StyleLogic.shows({ looks = { accessories = {} } })).to.equal(false)
		end)

		it("names an id it does not know from its words", function()
			expect(StyleLogic.name("sea_glass")).to.equal("Sea Glass")
			expect(StyleLogic.name("royal_crest")).to.equal("Royal Crest")
			expect(StyleLogic.name("x", { x = "Named" })).to.equal("Named")
		end)

		it("adds a Cafe music row with the songs the server sends, last, the mix first (#1875)", function()
			local tracks = { "jukebox_rainy_window", "jukebox_catnap_waltz" }
			local rows = StyleLogic.rows({ signStyles = { "bakery_stripes" }, jukeboxTracks = tracks })
			expect(#rows).to.equal(2)
			expect(rows[2].kind).to.equal("music")
			expect(rows[2].title).to.equal("Cafe music")
			expect(names(rows[2])).to.equal("Day and night mix*,Rainy Window,Catnap Waltz")
			local picked = StyleLogic.rows({ jukeboxTracks = tracks, jukebox = "jukebox_catnap_waltz" })
			expect(names(picked[1])).to.equal("Day and night mix,Rainy Window,Catnap Waltz*")
			expect(StyleLogic.shows({ jukeboxTracks = {} })).to.equal(false)
			expect(StyleLogic.shows({ jukeboxTracks = tracks })).to.equal(true)
		end)

		it("puts Shuffle right after the mix only while the client can play it (#2077)", function()
			local tracks = { "jukebox_rainy_window", "jukebox_catnap_waltz" }
			local plain = StyleLogic.rows({ jukeboxTracks = tracks, jukebox = "shuffle" })
			expect(names(plain[1])).to.equal("Day and night mix*,Rainy Window,Catnap Waltz")
			local rows = StyleLogic.rows({ jukeboxTracks = tracks, jukeboxShuffle = "shuffle" })
			expect(names(rows[1])).to.equal("Day and night mix*,Shuffle,Rainy Window,Catnap Waltz")
			expect(rows[1].options[2].icon).to.equal("🔀")
			local picked =
				StyleLogic.rows({ jukeboxTracks = tracks, jukeboxShuffle = "shuffle", jukebox = "shuffle" })
			expect(names(picked[1])).to.equal("Day and night mix,Shuffle*,Rainy Window,Catnap Waltz")
			expect(#tracks).to.equal(2) -- the server's list is left as it was
			expect(StyleLogic.shows({ jukeboxTracks = {}, jukeboxShuffle = "shuffle" })).to.equal(false)
		end)

		it("names every shared/Jukebox song as the Jukebox names it", function()
			local Jukebox = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Jukebox")
			) :: any
			for _, track in Jukebox.TRACKS do
				expect(StyleLogic.name(track.id)).to.equal(track.name)
			end
		end)
	end)

	describe("StyleLogic symbols and names (#2007)", function()
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local SignStyles = require(Shared:WaitForChild("SignStyles")) :: any
		local Looks = require(Shared:WaitForChild("Looks")) :: any
		local Jukebox = require(Shared:WaitForChild("Jukebox")) :: any
		-- emoji newer than Roblox's font, which it draws blank (#2015)
		local BLANK = { "🪴", "🪧", "🪄", "🫖" }

		it("puts a symbol beside every option, the plain sign included", function()
			local rows = StyleLogic.rows({
				signStyles = { "bakery_stripes", "royal_crest" },
				looks = { themes = { "garden" }, uniforms = { "striped" }, accessories = { "hat" } },
				jukeboxTracks = { "jukebox_rainy_window" },
			})
			expect(#rows).to.equal(5)
			for _, row in rows do
				for _, option in row.options do
					expect(type(option.icon)).to.equal("string")
					expect(#option.icon > 0).to.equal(true)
					for _, blank in BLANK do
						expect(option.icon).never.to.equal(blank)
					end
				end
			end
			expect(rows[1].options[1].icon).never.to.equal(rows[1].options[2].icon)
		end)

		it("gives every sign style its own symbol and its shared name", function()
			local seen: { [string]: boolean } = { [StyleLogic.icon("sign", "")] = true }
			for _, style in SignStyles.LIST do
				expect(StyleLogic.name(style.id)).to.equal(style.name)
				local icon = StyleLogic.icon("sign", style.id)
				expect(seen[icon]).to.equal(nil)
				seen[icon] = true
			end
		end)

		it("names every theme, uniform, accessory and song as shared/Looks and Jukebox do", function()
			for _, list in { Looks.THEMES, Looks.UNIFORMS, Looks.ACCESSORIES, Jukebox.TRACKS } do
				for _, item in list do
					expect(StyleLogic.name(item.id)).to.equal(item.name)
				end
			end
		end)

		it("titles a row with the option in use, Plain when the pick is cleared", function()
			local crest = StyleLogic.rows({ signStyles = { "royal_crest" }, signStyle = "royal_crest" })
			expect(StyleLogic.inUse(crest[1])).to.equal("Cafe sign: 👑 Royal Crest")
			local plain = StyleLogic.rows({ signStyles = { "royal_crest" }, signStyle = "" })
			expect(names(plain[1])).to.equal("Plain*,Royal Crest")
			expect(StyleLogic.inUse(plain[1])).to.equal("Cafe sign: ⬜ Plain")
		end)
	end)
end
