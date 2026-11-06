--!strict
-- Moods.luau against catch-rework.md 7a (#1884): the mood weights by rarity, the tutorial's Sleepy cat, the
-- Skittish front arc and cooldown, and the Curious walk and its trust bonus.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Moods = require(Shared.Moods)

	local function shares(rarity: string): { [string]: number }
		local counts: { [string]: number } = { Sleepy = 0, Curious = 0, Skittish = 0 }
		local n = 1000
		for i = 0, n - 1 do
			counts[Moods.roll(rarity :: any, (i + 0.5) / n)] += 1
		end
		return {
			Sleepy = counts.Sleepy / 10,
			Curious = counts.Curious / 10,
			Skittish = counts.Skittish / 10,
		}
	end

	describe("rolling a mood (7a table)", function()
		it("matches the table by rarity", function()
			local want: { [string]: { number } } = {
				Common = { 55, 45, 0 },
				Rare = { 55, 45, 0 },
				Epic = { 30, 35, 35 },
				Legendary = { 20, 30, 50 },
				Mythical = { 20, 30, 50 },
			}
			for rarity, row in want do
				local got = shares(rarity)
				expect(got.Sleepy).to.be.near(row[1], 0.2)
				expect(got.Curious).to.be.near(row[2], 0.2)
				expect(got.Skittish).to.be.near(row[3], 0.2)
				local weights = Catalog.rarities[rarity].moods
				expect(weights.Sleepy + weights.Curious + weights.Skittish).to.equal(100)
			end
		end)

		it("the tutorial stray is always Sleepy, and the ends of the roll stay in range", function()
			for _, u in { 0, 0.3, 0.6, 0.999999 } do
				expect(Moods.roll("Mythical", u, true)).to.equal("Sleepy")
			end
			expect(Moods.roll("Mythical", 0)).to.equal("Sleepy")
			expect(Moods.roll("Mythical", 0.999999)).to.equal("Skittish")
			expect(Moods.roll("Common", 0.999999)).to.equal("Curious")
		end)

		it("a player before tutorialStep 2 never startles a Skittish cat", function()
			expect(Moods.canStartle(0)).to.equal(false)
			expect(Moods.canStartle(1)).to.equal(false)
			expect(Moods.canStartle(2)).to.equal(true)
			expect(Moods.canStartle(30)).to.equal(true)
		end)
	end)

	describe("Skittish (7a, 7f check 4)", function()
		local at = Vector3.new(0, 0, 0)
		local look = Vector3.new(0, 0, -1)

		it(
			"startles within 10 studs inside its 90 degree front arc, not from behind or the side",
			function()
				expect(Moods.inFrontArc(at, look, Vector3.new(0, 0, -8))).to.equal(true) -- straight ahead
				expect(Moods.inFrontArc(at, look, Vector3.new(3, 2, -8))).to.equal(true) -- inside 45 degrees, height ignored
				expect(Moods.inFrontArc(at, look, Vector3.new(0, 0, -11))).to.equal(false) -- too far
				expect(Moods.inFrontArc(at, look, Vector3.new(0, 0, 5))).to.equal(false) -- behind
				expect(Moods.inFrontArc(at, look, Vector3.new(6, 0, 0))).to.equal(false) -- the side
				expect(Moods.inFrontArc(at, look, Vector3.new(6, 0, -5))).to.equal(false) -- just outside 45 degrees
			end
		)

		it(
			"hops SkittishHopStuds (6) straight away, at most once every SkittishCooldown (8 s)",
			function()
				local target = Moods.hopTarget(at, Vector3.new(0, 3, -4))
				expect(target.X).to.be.near(0, 1e-9)
				expect(target.Y).to.be.near(0, 1e-9)
				expect(target.Z).to.be.near(Config.SkittishHopStuds, 1e-9)
				expect(Moods.hopReady(nil, 100)).to.equal(true)
				expect(Moods.hopReady(100, 107.9)).to.equal(false)
				expect(Moods.hopReady(100, 108)).to.equal(true)
			end
		)
	end)

	describe("Curious (7a)", function()
		it(
			"notices a player within 12 studs and walks 4 studs toward them, stopping 2 short",
			function()
				local at = Vector3.new(0, 0, 0)
				expect(Moods.noticed(at, Vector3.new(0, 0, 12))).to.equal(true)
				expect(Moods.noticed(at, Vector3.new(0, 0, 12.5))).to.equal(false)
				local walk = Moods.curiousTarget(at, Vector3.new(0, 1, 10))
				expect(walk.Z).to.be.near(4, 1e-9)
				expect(walk.Y).to.be.near(0, 1e-9)
				expect(Moods.curiousTarget(at, Vector3.new(0, 0, 3)).Z).to.be.near(1, 1e-9)
				expect(Moods.curiousTarget(at, Vector3.new(0, 0, 1)).Z).to.be.near(0, 1e-9)
			end
		)

		it(
			"a swing within 2 s of the walk starting adds CuriousTrustBonus (1), later or never adds nothing",
			function()
				expect(Moods.trustBonus(nil, 10)).to.equal(0)
				expect(Moods.trustBonus(10, 10)).to.equal(Config.CuriousTrustBonus)
				expect(Moods.trustBonus(10, 12)).to.equal(1)
				expect(Moods.trustBonus(10, 12.01)).to.equal(0)
				expect(Moods.trustBonus(10, 9)).to.equal(0)
			end
		)
	end)
end
