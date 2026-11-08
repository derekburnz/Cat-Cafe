--!strict
-- UI/Components/PassLogic.luau: the Cafe Pass screen's rows, bar, end date and HUD tile (#1646, cafe-pass.md).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local PassLogic = require(Components:WaitForChild("PassLogic")) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CafePass = require(Shared:WaitForChild("CafePass")) :: any

	local function view(overrides: { [string]: any }?): any
		local out: { [string]: any } = {
			season = 1,
			startsAt = 0,
			endsAt = nil,
			level = 0,
			xp = 0,
			xpPerLevel = 800,
			levels = 30,
			paid = false,
			claimedFree = {},
			claimedPaid = {},
			claimable = 0,
			items = {},
			tag = nil,
		}
		for key, value in overrides or {} do
			out[key] = value
		end
		return out
	end

	local def = CafePass.seasonDef(1)

	describe("PassLogic.columns", function()
		it("has a column per level, with free and paid rewards on every level (#1883)", function()
			local columns = PassLogic.columns(view(), def)
			expect(#columns).to.equal(30)
			expect(columns[1].free).to.be.ok()
			expect(columns[2].free).to.be.ok()
			expect(columns[1].paid).to.be.ok()
			expect(columns[30].paid.reward.item.kind).to.equal("cat")
		end)

		it("marks reached free rewards ready, later ones ahead and claimed ones claimed", function()
			local columns =
				PassLogic.columns(view({ level = 4, xp = 3300, claimedFree = { 2 } }), def)
			expect(columns[2].free.state).to.equal("claimed")
			expect(columns[4].free.state).to.equal("ready")
			expect(columns[5].free.state).to.equal("ahead")
			expect(columns[4].reached).to.equal(true)
			expect(columns[5].reached).to.equal(false)
		end)

		it("locks every unclaimed paid reward until the paid track is bought", function()
			local columns = PassLogic.columns(view({ level = 7, xp = 5600 }), def)
			expect(columns[1].paid.state).to.equal("locked")
			expect(columns[20].paid.state).to.equal("locked")
			-- bought mid-season: every reached paid level is ready at once (QA case 1)
			local bought = PassLogic.columns(
				view({ level = 7, xp = 5600, paid = true, claimedPaid = { 1 } }),
				def
			)
			expect(bought[1].paid.state).to.equal("claimed")
			expect(bought[7].paid.state).to.equal("ready")
			expect(bought[8].paid.state).to.equal("ahead")
			expect(PassLogic.readyCount(bought)).to.equal(6 + 7) -- paid 2 to 7, free 1 to 7 (#1883)
		end)

		it("is empty while no season runs", function()
			expect(#PassLogic.columns(view({ season = 0 }), def)).to.equal(0)
			expect(#PassLogic.columns(nil, def)).to.equal(0)
			expect(PassLogic.shows(view({ season = 0 }))).to.equal(false)
			expect(PassLogic.shows(nil)).to.equal(false)
			expect(PassLogic.shows(view())).to.equal(true)
		end)
	end)

	describe("PassLogic.progress", function()
		it("shows the XP into the current level", function()
			local progress = PassLogic.progress(view({ level = 2, xp = 1800 }))
			expect(progress.level).to.equal(2)
			expect(progress.text).to.equal("200 / 800 XP")
			expect(progress.fraction).to.equal(0.25)
		end)

		it("reads Max level at the top", function()
			local progress = PassLogic.progress(view({ level = 30, xp = 24000 }))
			expect(progress.max).to.equal(true)
			expect(progress.text).to.equal("Max level")
			expect(progress.fraction).to.equal(1)
		end)
	end)

	describe("PassLogic.endText", function()
		it("gives the end as a plain UTC date, never a countdown", function()
			local endsAt = CafePass.dateToTime("2027-01-03")
			expect(PassLogic.endText(view({ endsAt = endsAt }))).to.equal("Season 1 ends 3 January")
			expect(PassLogic.dateText(CafePass.dateToTime("2026-12-31"))).to.equal("31 December")
			expect(PassLogic.dateText(CafePass.dateToTime("2028-02-29"))).to.equal("29 February")
		end)

		it("names only the season while no later season is set", function()
			expect(PassLogic.endText(view({ season = 2 }))).to.equal("Season 2")
			expect(PassLogic.subtitle(view(), "Season 1: Maple")).to.equal("Season 1: Maple")
		end)

		it("puts the end date after the season's name in the subtitle", function()
			local endsAt = CafePass.dateToTime("2027-01-03")
			expect(PassLogic.subtitle(view({ endsAt = endsAt }), "Season 1: Maple")).to.equal(
				"Season 1: Maple  ·  ends 3 January"
			)
			expect(PassLogic.subtitle(view({ endsAt = endsAt }), nil)).to.equal(
				"Season 1 ends 3 January"
			)
		end)
	end)

	describe("PassLogic.focus", function()
		it("scrolls to the first ready reward, else the next level", function()
			local ready =
				PassLogic.columns(view({ level = 4, xp = 3200, claimedFree = { 1, 2, 3 } }), def)
			expect(PassLogic.focus(ready, 4)).to.equal(4)
			local none = PassLogic.columns(view({ level = 1, xp = 900, claimedFree = { 1 } }), def)
			expect(PassLogic.focus(none, 1)).to.equal(2)
		end)
	end)

	describe("PassLogic.itemText", function()
		it("drops the kind the picture already shows", function()
			expect(
				PassLogic.itemText({ kind = "uniform", id = "u", name = "Uniform colour: Pumpkin" })
			).to.equal("Pumpkin uniform")
			expect(
				PassLogic.itemText({ kind = "tag", id = "t", name = "Season 1 chat tag [Maple]" })
			).to.equal("[Maple] chat tag")
			expect(
				PassLogic.itemText({ kind = "cat", id = "c", name = "Season cat: Maple Muffin" })
			).to.equal("Maple Muffin")
			expect(PassLogic.itemText({ kind = "decor", id = "d", name = "Hay Bale Seat" })).to.equal(
				"Hay Bale Seat"
			)
		end)

		it("lists the paid track's exact contents for the Store card", function()
			expect(PassLogic.paidContents(def)).to.equal(
				"Season cat Maple Muffin, [Maple] chat tag, 4 uniform colours, 6 accessories, 8 decor pieces, "
					.. "2 sign frames and 24 potions" -- #1883: +1 on nine potion levels; part C's levels 31 to 34
			)
			expect(PassLogic.paidContents(nil)).to.equal("")
		end)

		it("walks the chat tag button through the player's tags, then off (#1626)", function()
			local view: any = { season = 1, tags = { "vip", "tag_maple" }, tagShown = "vip" }
			local button = PassLogic.tagButton(view)
			expect(button.text).to.equal('Chat tag <font color="#F2C14E">[VIP]</font>')
			expect(button.nextPick).to.equal("tag_maple")
			view.tagShown = "tag_maple"
			expect(PassLogic.tagButton(view).text).to.equal(
				'Chat tag <font color="#D9822B">[Maple]</font>'
			)
			expect(PassLogic.tagButton(view).nextPick).to.equal("off")
			view.tagShown = nil
			expect(PassLogic.tagButton(view).text).to.equal("Chat tag: off")
			expect(PassLogic.tagButton(view).nextPick).to.equal("vip")
			-- no tags, an unknown one only, or no view: no button
			expect(PassLogic.tagButton({ season = 1, tags = {} } :: any)).to.equal(nil)
			expect(PassLogic.tagButton({ season = 1, tags = { "nope" } } :: any)).to.equal(nil)
			expect(PassLogic.tagButton({ season = 1 } :: any)).to.equal(nil)
			expect(PassLogic.tagButton(nil)).to.equal(nil)
		end)

		it("names every paid item of season 1 in a few words", function()
			for level = 1, 30 do
				local item = def.paid[level].item
				if item then
					expect(#PassLogic.itemText(item) <= 24).to.equal(true)
					expect(PassLogic.itemGlyph(item.kind) ~= "🎁").to.equal(true)
				end
			end
		end)
	end)

	describe("PassLogic.itemArt (#2087)", function()
		it(
			"gives every paid item of season 1 its own picture: a model, a uniform's colour or a tag's colour",
			function()
				for _, reward in def.paid do
					local item = reward.item
					if item then
						local art = PassLogic.itemArt(item)
						if item.kind == "uniform" or item.kind == "tag" then
							expect(art.tint ~= nil).to.equal(true)
						else
							-- the model's name (assets/cat-cafe/rbx holds each, checked when this was written)
							expect(type(art.asset)).to.equal("string")
							expect(string.sub(art.asset :: string, 1, 8)).to.equal("CatCafe_")
						end
						expect(art.glyph ~= "").to.equal(true)
					end
				end
			end
		)

		it(
			"takes the cat's, the accessory's and the sign's own models, and the uniform's own colour",
			function()
				expect(PassLogic.itemArt({ kind = "cat", id = "maple_muffin", name = "" }).asset).to.equal(
					"CatCafe_Cat_MapleMuffin"
				)
				expect(
					PassLogic.itemArt({ kind = "accessory", id = "acc_leaf_beret", name = "" }).asset
				).to.equal("CatCafe_Accessory_LeafBeret")
				expect(
					PassLogic.itemArt({ kind = "frame", id = "frame_golden_leaf", name = "" }).asset
				).to.equal("CatCafe_Plot_SignGoldenLeaf")
				local pumpkin =
					PassLogic.itemArt({ kind = "uniform", id = "uniform_pumpkin", name = "" }).tint
				expect(pumpkin == Color3.fromRGB(217, 102, 46)).to.equal(true)
				-- something unknown keeps its kind's symbol
				local unknown = PassLogic.itemArt({ kind = "decor", id = "nope", name = "" })
				expect(unknown.asset).to.equal(nil)
				expect(unknown.glyph).to.equal(PassLogic.itemGlyph("decor"))
			end
		)
	end)
end
