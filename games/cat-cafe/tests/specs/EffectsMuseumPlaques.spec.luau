--!strict
-- The Relic Museum's room names glow gold once the room is full (#3129; Effects/MuseumPlaques): the breath stays
-- between the two golds and slow, the calm version holds still, and every room has a plaque name to light.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LateStations = require(Shared.LateStations)

	describe("Effects museum plaques", function()
		it("breathes between the gold and the brighter gold, once every `every` seconds", function()
			local p = Presets.museumPlaques
			expect(Logic.plaqueGlow(0, p.every, false)).to.equal(0)
			expect(math.abs(Logic.plaqueGlow(p.every / 2, p.every, false) - 1) < 1e-6).to.equal(
				true
			)
			for step = 0, 200 do
				local level = Logic.plaqueGlow(step * 0.07, p.every, false)
				expect(level >= 0 and level <= 1).to.equal(true)
			end
			-- slow: well under three flashes a second
			expect(p.every >= 1.5).to.equal(true)
			expect(p.rate > 0 and p.rate <= 0.2).to.equal(true)
		end)

		it("holds the steady gold for Reduce Motion, Low performance and far away", function()
			local p = Presets.museumPlaques
			for step = 0, 50 do
				expect(Logic.plaqueGlow(step * 0.13, p.every, true)).to.equal(0)
			end
			expect(Logic.plaqueGlow(1, 0, false)).to.equal(0)
		end)

		it("lights in the room-complete gold, the bright end lighter still", function()
			local p = Presets.museumPlaques
			expect(p.gold).to.equal(Presets.palette.golden)
			expect(p.bright.R >= p.gold.R and p.bright.G > p.gold.G and p.bright.B > p.gold.B).to.equal(
				true
			)
		end)

		it(
			"has a plaque name for each of the ten rooms, and a room counts only when every exhibit is in",
			function()
				local p = Presets.museumPlaques
				expect(#LateStations.rooms).to.equal(10) -- #3997: the Snowy Mountain's room; #4070: the Water Park's; #4184: the Castle's
				local seen: { [string]: boolean } = {}
				for _, room in LateStations.rooms do
					local name = "CatCafe_Camp_Ruins_RelicMuseum" .. p.suffix .. room.area
					expect(seen[name]).to.equal(nil)
					seen[name] = true
				end
				local room = LateStations.rooms[1]
				local filled: { [string]: string } = {}
				for index, catId in room.cats do
					if index < #room.cats then
						filled[catId] = "normal"
					end
				end
				expect(table.find(LateStations.roomsDone(filled :: any), room.area)).to.equal(nil)
				filled[room.cats[#room.cats]] = "gold"
				expect(table.find(LateStations.roomsDone(filled :: any), room.area)).to.be.ok()
			end
		)
	end)
end
