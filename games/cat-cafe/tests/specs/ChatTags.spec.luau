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

		it("offers the Thank You tag to a supporter, after VIP and before the season tags (#1168 row 4)", function()
			local items = ChatTags.withSupporter(MAPLE, true)
			expect(MAPLE.supporter).to.equal(nil) -- a copy
			expect(ChatTags.choices(true, items) :: any).to.deepEqual({ "vip", "supporter", "tag_maple" })
			expect(ChatTags.shown(nil, false, items)).to.equal("supporter")
			expect(ChatTags.choices(false, ChatTags.withSupporter(MAPLE, false)) :: any).to.deepEqual({
				"tag_maple",
			})
			expect(ChatTags.prefixFor("supporter")).to.equal('<font color="#FFC94D">[Thank You]</font> ')
			-- only the server's supporter mark gives it: a saved item named supporter means nothing once rebuilt
			expect(ChatTags.withSupporter({ supporter = true }, false).supporter).to.equal(nil)
		end)

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
end
