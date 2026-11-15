--!strict
-- ChatTags.luau (#1624): the VIP chat tag's prefix, and nothing for an unknown or missing tag.
return function()
	local ChatTags = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").ChatTags)

	describe("prefixFor", function()
		it("gives the VIP tag in gold before the name", function()
			expect(ChatTags.prefixFor("vip")).to.equal('<font color="#F2C14E">[VIP]</font> ')
		end)

		it("gives nothing for no tag, an unknown id or a non-string", function()
			expect(ChatTags.prefixFor(nil)).to.equal(nil)
			expect(ChatTags.prefixFor("admin")).to.equal(nil)
			expect(ChatTags.prefixFor(5)).to.equal(nil)
		end)

		it("gives the Season 1 Maple tag (#1626)", function()
			expect(ChatTags.prefixFor("tag_maple")).to.equal(
				'<font color="#D9822B">[Maple]</font> '
			)
		end)
	end)

	describe("the tag pick (#1626)", function()
		local MAPLE = { tag_maple = true }

		it("offers VIP when owned, then the season tags the player has", function()
			expect(ChatTags.choices(true, MAPLE) :: any).to.deepEqual({ "vip", "tag_maple" })
			expect(ChatTags.choices(false, MAPLE) :: any).to.deepEqual({ "tag_maple" })
			expect(ChatTags.choices(true, {}) :: any).to.deepEqual({ "vip" })
			expect(ChatTags.choices(false, { leaf_beret = true }) :: any).to.deepEqual({})
		end)

		it("shows the pick, VIP then a season tag by default, and nothing for off", function()
			expect(ChatTags.shown(nil, true, MAPLE)).to.equal("vip")
			expect(ChatTags.shown(nil, false, MAPLE)).to.equal("tag_maple")
			expect(ChatTags.shown(nil, false, {})).to.equal(nil)
			expect(ChatTags.shown("tag_maple", true, MAPLE)).to.equal("tag_maple")
			expect(ChatTags.shown(ChatTags.OFF, true, MAPLE)).to.equal(nil)
		end)

		it(
			"offers the Thank You tag to a supporter, after VIP and before the season tags (#1168 row 4)",
			function()
				local items = ChatTags.withSupporter(MAPLE, true)
				expect(MAPLE.supporter).to.equal(nil) -- a copy
				expect(ChatTags.choices(true, items) :: any).to.deepEqual({
					"vip",
					"supporter",
					"tag_maple",
				})
				expect(ChatTags.shown(nil, false, items)).to.equal("supporter")
				expect(ChatTags.choices(false, ChatTags.withSupporter(MAPLE, false)) :: any).to.deepEqual({
					"tag_maple",
				})
				expect(ChatTags.prefixFor("supporter")).to.equal(
					'<font color="#FFC94D">[Thank You]</font> '
				)
				-- only the server's supporter mark gives it: a saved item named supporter means nothing once rebuilt
				expect(ChatTags.withSupporter({ supporter = true }, false).supporter).to.equal(nil)
			end
		)

		it("never shows a tag the player can't show any more", function()
			expect(ChatTags.shown("vip", false, MAPLE)).to.equal("tag_maple") -- VIP not owned
			expect(ChatTags.shown("tag_maple", false, {})).to.equal(nil)
		end)

		it("saves only known tag ids and off", function()
			expect(ChatTags.validPick("vip")).to.equal(true)
			expect(ChatTags.validPick("tag_maple")).to.equal(true)
			expect(ChatTags.validPick(ChatTags.OFF)).to.equal(true)
			expect(ChatTags.validPick("admin")).to.equal(false)
			expect(ChatTags.validPick(3)).to.equal(false)
			expect(ChatTags.validPick(nil)).to.equal(false)
		end)

		it("has a tag for every tag item on a Cafe Pass track", function()
			local Catalog =
				require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Catalog)
			for _, season in Catalog.passSeasons do
				for _, track in { season.free, season.paid } do
					for _, row in track do
						if row.item ~= nil and row.item.kind == "tag" then
							expect(ChatTags.TAGS[row.item.id]).to.be.ok()
							expect(table.find(ChatTags.ORDER, row.item.id)).to.be.ok()
						end
					end
				end
			end
		end)
	end)
	describe("the message colour (Derek2 11-11)", function()
		it("wraps the message in the tag's colour", function()
			expect(ChatTags.textFor("vip", "hi there")).to.equal(
				'<font color="#F2C14E">hi there</font>'
			)
		end)

		it("leaves the message alone for no tag or an unknown one", function()
			expect(ChatTags.textFor(nil, "hi")).to.equal(nil)
			expect(ChatTags.textFor("admin", "hi")).to.equal(nil)
		end)

		it(
			"shows [Owner] only for the owner's account, never as a choice or a pick (#3324)",
			function()
				expect(ChatTags.prefixFor(ChatTags.OWNER)).to.equal(
					'<font color="#FF7A6B">[Owner]</font> '
				)
				expect(ChatTags.isOwner(140223517)).to.equal(true)
				expect(ChatTags.isOwner(2573351)).to.equal(false)
				expect(table.find(ChatTags.ORDER, ChatTags.OWNER)).to.equal(nil)
				expect(ChatTags.validPick(ChatTags.OWNER)).to.equal(false)
				expect(table.find(ChatTags.choices(true, { owner = true }), ChatTags.OWNER)).to.equal(
					nil
				)
				expect(ChatTags.shown(ChatTags.OWNER, true, { owner = true })).to.equal("vip")
			end
		)

		it("maps places 1 to 3 to the rank titles, and nothing else (#3333)", function()
			expect(ChatTags.rankTag(1)).to.equal("rank_1")
			expect(ChatTags.rankTag(3)).to.equal("rank_3")
			expect(ChatTags.rankTag(4)).to.equal(nil)
			expect(ChatTags.rankTag(nil)).to.equal(nil)
			expect(ChatTags.validPick("rank_2")).to.equal(true)
			expect(ChatTags.shown("rank_2", false, {})).to.equal(nil) -- a lost place shows nothing
			expect(ChatTags.shown("rank_2", false, { rank_2 = true })).to.equal("rank_2")
		end)

		it("keeps every tag colour readable on the dark chat window (4.5:1 or more)", function()
			local function lum(c: Color3): number
				local function ch(v: number): number
					return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
				end
				return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
			end
			local back = lum(Color3.fromRGB(25, 27, 29))
			for id, tag in ChatTags.TAGS do
				local fore = lum(Color3.fromHex(tag.color))
				local ratio = (fore + 0.05) / (back + 0.05)
				if ratio < 4.5 then
					error(("%s is %.2f:1"):format(id, ratio))
				end
			end
		end)
	end)

	describe("achievement titles (#3694)", function()
		local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Catalog)

		it("gives each big achievement's title its own name, offered in ORDER", function()
			local n = 0
			for achievementId, tagId in ChatTags.ACHIEVEMENT_TITLES do
				n += 1
				local def = Catalog.getAchievement(achievementId) :: any
				expect(def).to.be.ok()
				expect(def.size).to.equal("XL")
				expect(ChatTags.TAGS[tagId].text).to.equal("[" .. def.name .. "]")
				expect(table.find(ChatTags.ORDER, tagId)).to.be.ok()
				expect(ChatTags.validPick(tagId)).to.equal(true)
			end
			expect(n).to.equal(5)
		end)

		it("adds only the titles of claimed achievements, from the save alone", function()
			local items = ChatTags.addAchievementTitles(
				{ tag_maple = true },
				{ a_catch10k = true, a_hours100 = false, a_catch100 = true }
			)
			expect(items.tag_maple).to.equal(true)
			expect(items.title_cat_legend).to.equal(true)
			expect(items.title_devoted).to.equal(nil)
			expect(ChatTags.choices(false, items)).to.deepEqual({ "tag_maple", "title_cat_legend" })
			expect(ChatTags.shown(nil, false, { title_gold_rush = true })).to.equal(
				"title_gold_rush"
			)
		end)
	end)
end
