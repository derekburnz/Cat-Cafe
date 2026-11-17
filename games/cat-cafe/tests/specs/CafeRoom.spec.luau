--!strict
-- #4543: the cafe's room grows every two tiers behind cafeGrows (shared/CafeRoom), on Model-Agent's wall rules.

return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local CafeRoom = require(Shared:WaitForChild("CafeRoom"))

	describe("CafeRoom", function()
		it("is a live switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, CafeRoom.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[CafeRoom.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[CafeRoom.FLAG]).to.equal(false)
		end)

		it("keeps every room 44 x 34 with the switch off", function()
			for tier = 0, 10 do
				local width, depth = CafeRoom.size(tier, false)
				expect(width).to.equal(44)
				expect(depth).to.equal(34)
			end
		end)

		it("grows every two tiers up to the 60 x 46 cap with it on", function()
			local want = {
				[0] = { 44, 34 },
				[1] = { 44, 34 },
				[2] = { 44, 34 },
				[3] = { 48, 37 },
				[4] = { 48, 37 },
				[5] = { 52, 40 },
				[6] = { 52, 40 },
				[7] = { 56, 43 },
				[8] = { 56, 43 },
				[9] = { 60, 46 },
				[10] = { 60, 46 },
			}
			for tier, size in want do
				local width, depth = CafeRoom.size(tier, true)
				expect(width).to.equal(size[1])
				expect(depth).to.equal(size[2])
			end
		end)

		it("names the sized art and keeps the base names for the first room", function()
			expect(CafeRoom.suffix(44, 34)).to.equal("")
			expect(CafeRoom.suffix(48, 37)).to.equal("_48x37")
			expect(CafeRoom.suffix(60, 46)).to.equal("_60x46")
		end)

		it("keeps the front wall put and moves the back wall back", function()
			expect(CafeRoom.centre(34)).to.equal(0)
			expect(CafeRoom.centre(46)).to.equal(6)
			expect(CafeRoom.backShift(46)).to.equal(12)
		end)

		it("leaves every point alone in the first room", function()
			local p: any = { x = 21, y = 0, z = 15, rotY = 90 }
			expect(CafeRoom.point(p, 44, 34)).to.equal(p)
		end)

		it("moves a back wall piece back and keeps its x", function()
			local counter = CafeRoom.point({ x = 0, y = 0, z = 14 }, 60, 46)
			expect(counter.x).to.equal(0)
			expect(counter.z).to.equal(26)
			local yard = CafeRoom.point({ x = -2.6, y = 0, z = 19.6 }, 52, 40)
			expect(yard.x).to.equal(-2.6)
			expect(yard.z).to.be.near(25.6)
		end)

		it("moves a side wall piece out and keeps its share of the depth", function()
			local side = CafeRoom.point({ x = -20.5, y = 1, z = 0, rotY = 90 }, 60, 46)
			expect(side.x).to.equal(-28.5)
			expect(side.z).to.equal(6) -- the middle of the wall stays the middle
			expect(side.y).to.equal(1)
			expect(side.rotY).to.equal(90)
		end)

		it("takes both moves for a back corner piece", function()
			local corner = CafeRoom.point({ x = 20.5, y = 0, z = 15 }, 48, 37)
			expect(corner.x).to.equal(22.5)
			expect(corner.z).to.equal(18)
		end)

		it("moves a piece under a front window out and leaves the door's pieces", function()
			local window = CafeRoom.point({ x = 14, y = 0, z = -15 }, 56, 43)
			expect(window.x).to.equal(20)
			expect(window.z).to.equal(-15)
			local door = CafeRoom.point({ x = 3, y = 0, z = -15 }, 56, 43)
			expect(door.x).to.equal(3)
			expect(door.z).to.equal(-15)
		end)

		it("never moves the street side of the front wall", function()
			local garden = CafeRoom.point({ x = 21, y = 0, z = -19 }, 60, 46)
			expect(garden.x).to.equal(21)
			expect(garden.z).to.equal(-19)
		end)

		it("keeps the middle of the room where it was", function()
			local middle = CafeRoom.point({ x = 4, y = 0, z = 2 }, 60, 46)
			expect(middle.x).to.equal(4)
			expect(middle.z).to.equal(2)
		end)

		it("knows the room's floor from the front wall back", function()
			expect(CafeRoom.inside(Vector3.new(0, 0, 28), 60, 46)).to.equal(true)
			expect(CafeRoom.inside(Vector3.new(0, 0, 28), 44, 34)).to.equal(false)
			expect(CafeRoom.inside(Vector3.new(29.5, 0, 0), 60, 46)).to.equal(true)
			expect(CafeRoom.inside(Vector3.new(0, 0, -18), 60, 46)).to.equal(false)
			expect(CafeRoom.inside(Vector3.new(0, 0, -18), 60, 46, 1)).to.equal(true)
		end)
	end)
end
