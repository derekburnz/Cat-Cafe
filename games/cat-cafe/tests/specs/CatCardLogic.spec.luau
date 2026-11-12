--!strict
-- UI/Components/CatCardLogic.luau: the cat hover card's lines and the level up toast (F75, data-model 4b v0.12).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatCardLogic = require(Components:WaitForChild("CatCardLogic")) :: any
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

	describe("CatCardLogic.names", function()
		it("puts the catalog name under a named cat", function()
			local title, under = CatCardLogic.names("Biscuit", "Pirate Cat")
			expect(title).to.equal("Biscuit")
			expect(under).to.equal("Pirate Cat")
		end)

		it("shows the catalog name alone when the cat has no name of its own", function()
			for _, custom in { nil, "", "Pirate Cat" } :: { any } do
				local title, under = CatCardLogic.names(custom, "Pirate Cat")
				expect(title).to.equal("Pirate Cat")
				expect(under).never.to.be.ok()
			end
		end)
	end)

	describe("CatCardLogic.xp", function()
		it("reads the server's XP to the next level with commas", function()
			local text, share = CatCardLogic.xp(3, 340, 1440)
			expect(text).to.equal("340 / 1,440 XP")
			expect(math.abs(share - 340 / 1440) < 1e-9).to.equal(true)
		end)

		it("works the XP to the next level out from Config when it is not sent", function()
			local text, share = CatCardLogic.xp(2, 30.75, nil)
			local need = Config.CatXpBase * 2
			expect(text).to.equal(("30 / %d XP"):format(need))
			expect(math.abs(share - 30 / need) < 1e-9).to.equal(true)
		end)

		it("keeps the bar inside its ends", function()
			local _, over = CatCardLogic.xp(2, 99999, 240)
			local _, under = CatCardLogic.xp(2, -5, 240)
			expect(over).to.equal(1)
			expect(under).to.equal(0)
		end)

		it("says MAX with a full bar at the top level", function()
			local text, share = CatCardLogic.xp(Config.CatMaxLevel, 0, nil)
			expect(text).to.equal("MAX")
			expect(share).to.equal(1)
		end)

		it("shows two digit levels", function()
			expect(CatCardLogic.levelText(12)).to.equal("Level 12")
			expect(CatCardLogic.levelText(1)).to.equal("Level 1")
		end)
	end)

	describe("CatCardLogic.trait (#3196)", function()
		local Traits =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits")) :: any

		it("shows nothing for no trait, a broken one or an id it does not know", function()
			for _, value in { nil, {}, { id = 7 }, { id = "no_such_trait" }, "x" } :: { any } do
				local title, lines = CatCardLogic.trait(value)
				expect(title).never.to.be.ok()
				expect(#lines).to.equal(0)
			end
		end)

		it("gives every trait a title with its rarity's colour and one line per effect", function()
			for _, def in Traits.LIST do
				local title, lines = CatCardLogic.trait({ id = def.id })
				expect(title).to.be.ok()
				local hex = def.rarity.color:gsub("^#", "")
				expect(title:find('<font color="#' .. hex .. '">●</font> ', 1, true)).to.equal(1)
				expect(title:find(def.rarity.name .. " " .. def.name, 1, true)).to.be.ok()
				expect(#lines).to.equal(#def.effects)
				for _, line in lines do
					expect(line:sub(1, 1)).to.equal("+")
					-- fits the card: 232 px at 13 px text is about 38 letters
					expect(#line <= 38).to.equal(true)
				end
			end
		end)
	end)

	describe("CatCardLogic.role", function()
		it("names the role and marks the favourite one", function()
			local text, favourite = CatCardLogic.role("barista", "barista")
			expect(text).to.equal("Barista")
			expect(favourite).to.equal(true)
			local other, notFavourite = CatCardLogic.role("waiter", "barista")
			expect(other).to.equal("Waiter")
			expect(notFavourite).to.equal(false)
		end)

		it("adds Asleep for a working cat asleep on its spot (F79)", function()
			local text, favourite = CatCardLogic.role("barista", "barista", true)
			expect(text).to.equal("Barista · Asleep")
			expect(favourite).to.equal(true)
			expect((CatCardLogic.role(nil, "barista", true))).to.equal("Resting")
		end)

		it("says Resting for a cat with no role", function()
			local text, favourite = CatCardLogic.role(nil, "barista")
			expect(text).to.equal("Resting")
			expect(favourite).to.equal(false)
		end)
	end)

	describe("CatCardLogic.nearest", function()
		local function at(x: number): Vector3
			return Vector3.new(x, 0, 0)
		end

		it("picks the closest point within the radius", function()
			local points = { a = at(5), b = at(3), c = at(20) }
			local nearest = CatCardLogic.nearest(Vector3.zero, points, CatCardLogic.GAMEPAD_STUDS)
			expect(nearest).to.equal("b")
		end)

		it("finds nothing past the radius", function()
			expect(CatCardLogic.nearest(Vector3.zero, { far = at(9) }, 8)).never.to.be.ok()
		end)
	end)
end
