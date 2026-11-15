--!strict
-- #3995: a player who joins through a friend gets the free cafe nearest the friend's, and pal_join's fields.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PalJoin = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PalJoin")) :: any
	local LiveFlags =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any

	describe("PalJoin", function()
		it("ships behind an off switch", function()
			expect(LiveFlags.OFF_BY_DEFAULT[PalJoin.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, PalJoin.FLAG) ~= nil).to.equal(true)
		end)

		it("picks the free door nearest the friend's", function()
			local free = {
				{ index = 1, x = -40, z = -60 },
				{ index = 4, x = 40, z = 60 },
				{ index = 6, x = 40, z = 112 },
			}
			expect(PalJoin.nearest(free, -40, 60)).to.equal(4) -- across the street from the friend
			expect(PalJoin.nearest(free, 40, 160)).to.equal(6)
			expect(PalJoin.nearest({}, 0, 0)).to.equal(nil)
		end)

		it("breaks a tie by the lower plot", function()
			local free = { { index = 5, x = 10, z = 0 }, { index = 2, x = -10, z = 0 } }
			expect(PalJoin.nearest(free, 0, 0)).to.equal(2)
		end)

		it(
			"counts the plots beside and opposite as next door, and not the ones past them",
			function()
				expect(PalJoin.nextDoor(40, 60, 40, 112)).to.equal(true) -- beside, 52 studs
				expect(PalJoin.nextDoor(40, 60, -40, 60)).to.equal(true) -- across the street
				expect(PalJoin.nextDoor(40, 60, 40, 164)).to.equal(false) -- two along, 104 studs
			end
		)

		it("logs how they came, new or returning and next door", function()
			local f = PalJoin.fields("invite", true, true)
			expect(f[1]).to.equal("invite")
			expect(f[2]).to.equal("new")
			expect(f[3]).to.equal("yes")
			f = PalJoin.fields("follow", false, false)
			expect(f[1]).to.equal("follow")
			expect(f[2]).to.equal("returning")
			expect(f[3]).to.equal("no")
		end)
	end)
end
