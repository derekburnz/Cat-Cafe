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

		it("names every shared/Jukebox song as the Jukebox names it", function()
			local Jukebox = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Jukebox")
			) :: any
			for _, track in Jukebox.TRACKS do
				expect(StyleLogic.name(track.id)).to.equal(track.name)
			end
		end)
	end)
end
