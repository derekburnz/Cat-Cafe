--!strict
-- #5068 LoadGate: with fxAfterLoad off a function runs at once; with it on it waits for done(). Written by the
-- vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local LoadGate = require(Client:WaitForChild("Effects"):WaitForChild("LoadGate")) :: any

	describe("Effects load gate", function()
		afterEach(function()
			LoadGate._reset(false)
		end)

		it("runs at once with the switch off", function()
			LoadGate._reset(false)
			local ran = 0
			LoadGate.whenLoaded(function()
				ran += 1
			end)
			expect(ran).to.equal(1)
			expect(LoadGate.holds()).to.equal(false)
		end)

		it("holds until done with the switch on, then runs at once", function()
			LoadGate._reset(true)
			local ran = 0
			LoadGate.whenLoaded(function()
				ran += 1
			end)
			LoadGate.whenLoaded(function()
				ran += 10
			end)
			expect(ran).to.equal(0)
			expect(LoadGate.isDone()).to.equal(false)
			LoadGate.done()
			expect(ran).to.equal(11)
			expect(LoadGate.isDone()).to.equal(true)
			LoadGate.whenLoaded(function()
				ran += 100
			end)
			expect(ran).to.equal(111)
			LoadGate.done()
			expect(ran).to.equal(111)
		end)

		it("never waits longer than the loading screen can stay up", function()
			expect(LoadGate.CAP > 0 and LoadGate.CAP <= 15).to.equal(true)
			expect(LoadGate.FLAG).to.equal("fxAfterLoad")
		end)
	end)
end
