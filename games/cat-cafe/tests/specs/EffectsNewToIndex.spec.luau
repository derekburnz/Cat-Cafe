--!strict
-- The NEW tag over a stray's or stuck cat's rarity gem (#2258, Derek2 2026-11-07: "show new tag if it's a cat you
-- don't own yet for people index hunting"): Logic.newToIndex decides from this player's Index pages, and the pill sits
-- on the gem without covering most of it. The look on screen is a Studio row.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local seen = {
		collection = { tabby = 100, calico = 200 },
		gold = { tabby = 300 },
		rainbow = {},
	}

	describe("new to the Index", function()
		it("says nothing before the first sync or without a cat id", function()
			expect(Logic.newToIndex(nil, "tabby", "base")).to.equal(false)
			expect(Logic.newToIndex({}, "ghost", "base")).to.equal(false)
			expect(Logic.newToIndex(seen, nil, "base")).to.equal(false)
		end)
		it("marks a cat not caught yet, and not one already in the Index", function()
			expect(Logic.newToIndex(seen, "ghost", "base")).to.equal(true)
			expect(Logic.newToIndex(seen, "ghost", nil)).to.equal(true)
			expect(Logic.newToIndex(seen, "tabby", "base")).to.equal(false)
			expect(Logic.newToIndex(seen, "calico", nil)).to.equal(false)
		end)
		it("marks a gold or rainbow coat its page has not got yet", function()
			expect(Logic.newToIndex(seen, "tabby", "gold")).to.equal(false)
			expect(Logic.newToIndex(seen, "calico", "gold")).to.equal(true)
			expect(Logic.newToIndex(seen, "tabby", "rainbow")).to.equal(true)
			-- a page not synced yet says nothing for that coat
			expect(Logic.newToIndex({ collection = seen.collection }, "tabby", "gold")).to.equal(
				false
			)
		end)
		it("sits the pill on the gem's top corner, never over its middle", function()
			local r = Presets.rarityMark
			local t = r.newTag
			local foot = 0.5 - r.gem * math.sqrt(0.5) + t.overlap
			expect(foot < 0.5 - r.gem / 4).to.equal(true)
			expect(t.width <= 1).to.equal(true)
			expect(foot - t.height > -0.1).to.equal(true) -- pokes only a little over the billboard
		end)
	end)
end
