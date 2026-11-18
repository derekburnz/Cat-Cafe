--!strict
-- UI/Components/GoalNeed.luau: the goal card's biggest missing Rank Up need (#5331 goalNeedLine).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GoalNeed = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GoalNeed")
	) :: any

	local function row(kind: string, fraction: number, status: string, short: string?): any
		return {
			kind = kind,
			fraction = fraction,
			met = fraction >= 1,
			status = status,
			short = short or "Coins",
		}
	end
	local function progress(rows: { any }, tier: { [string]: any }?): any
		local ready = true
		for _, item in rows do
			ready = ready and item.met
		end
		return { ready = ready, nextTier = tier or { name = "Famous Cafe" }, requirements = rows }
	end

	describe("GoalNeed", function()
		it("names the coins when they are furthest from done", function()
			local p = progress({
				row("coins", 0.776, "$194K / $250K"),
				row("cats", 0.9, "9 / 10", "Cats"),
			})
			expect(GoalNeed.line(p)).to.equal("Coins $194K / $250K")
			expect(GoalNeed.chip(p)).to.equal("Famous Cafe: Coins $194K / $250K")
		end)

		it("calls distinct cats Kinds and any cats Cats", function()
			local rows = { row("coins", 1, "Done"), row("cats", 0.75, "9 / 12", "Cats") }
			expect(GoalNeed.line(progress(rows))).to.equal("Kinds 9 / 12")
			expect(GoalNeed.line(progress(rows, { name = "Cozy Cafe", anyCats = true }))).to.equal(
				"Cats 9 / 12"
			)
		end)

		it("asks for the rarity with its article or count", function()
			local one = progress(
				{ row("rarity", 0, "0 / 1") },
				{ name = "Grand Cafe", needsRarity = "Epic" }
			)
			expect(GoalNeed.line(one)).to.equal("Need an Epic")
			local two = progress(
				{ row("rarity", 0, "0 / 2") },
				{ name = "Grand Cafe", needsRarity = "Legendary" }
			)
			expect(GoalNeed.line(two)).to.equal("Need 2 Legendary+")
		end)

		it("breaks a tie coins first, then kinds, then rarity", function()
			local rows = {
				row("rarity", 0.5, "1 / 2"),
				row("cats", 0.5, "6 / 12", "Cats"),
				row("coins", 0.5, "$1K / $2K"),
			}
			expect(GoalNeed.biggest(rows).kind).to.equal("coins")
			expect(GoalNeed.biggest({ rows[1], rows[2] }).kind).to.equal("cats")
		end)

		it("reads Ready to Rank Up! once every need is met and nil at the top tier", function()
			local p = progress({ row("coins", 1, "Done"), row("cats", 1, "Done", "Cats") })
			expect(GoalNeed.line(p)).to.equal("Ready to Rank Up!")
			expect(GoalNeed.chip(p)).to.equal("Ready to Rank Up!")
			expect(GoalNeed.line({ ready = false, nextTier = nil, requirements = {} })).to.equal(
				nil
			)
		end)
	end)
end
