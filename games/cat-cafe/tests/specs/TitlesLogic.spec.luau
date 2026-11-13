--!strict
-- Components/TitlesLogic.luau: the Bag's Titles tab rows (Derek2 11-11).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ChatTags = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").ChatTags)
	local TitlesLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TitlesLogic")
	) :: any

	local function ids(rows: { any }): { string }
		local out = {}
		for _, row in rows do
			table.insert(out, row.id)
		end
		return out
	end

	it("lists Off, then the owned titles, then the rest", function()
		local rows = TitlesLogic.rows({ tags = { "tag_maple" }, tagShown = "tag_maple" } :: any)
		expect(ids(rows) :: any).to.deepEqual({
			ChatTags.OFF,
			"tag_maple",
			"vip",
			"supporter",
			"tag_grand_opener",
			"title_cat_legend", -- #3694
			"title_steady_hands",
			"title_devoted",
			"title_week_champion",
			"title_gold_rush",
			"rank_1", -- #3333
			"rank_2",
			"rank_3",
		})
		expect(rows[2].owned and rows[2].equipped).to.equal(true)
		expect(rows[1].equipped).to.equal(false)
		expect(rows[3].owned).to.equal(false)
	end)

	it("marks Off equipped when no title shows", function()
		local rows = TitlesLogic.rows({ tags = { "vip" }, tagShown = nil } :: any)
		expect(rows[1].equipped).to.equal(true)
		expect(rows[2].id).to.equal("vip")
		expect(rows[2].equipped).to.equal(false)
	end)

	it("shows every title locked before the pass state arrives", function()
		local rows = TitlesLogic.rows(nil)
		expect(#rows).to.equal(#ChatTags.ORDER + 1)
		for i = 2, #rows do
			expect(rows[i].owned).to.equal(false)
		end
	end)

	it("says where every title comes from", function()
		for _, id in ChatTags.ORDER do
			expect(#(TitlesLogic.HOW[id] or "") > 0).to.equal(true)
		end
	end)
end
