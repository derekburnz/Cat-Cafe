--!strict
-- #5707 picnicCount: the Picnic Basket sign counts the picnic cats while Picnic Time runs. Written by the
-- vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local PicnicLogic = require(Effects:WaitForChild("PicnicLogic")) :: any

	describe("Picnic cat count", function()
		it("names the cat now sitting, of three", function()
			expect(PicnicLogic.countSign({ false, false, false }, 3, false)).to.equal(
				"Picnic cats 1/3"
			)
			expect(PicnicLogic.countSign({ true, false, false }, 3, false)).to.equal(
				"Picnic cats 2/3"
			)
			expect(PicnicLogic.countSign({ true, true, false }, 3, false)).to.equal(
				"Picnic cats 3/3"
			)
		end)

		it("says the last one is a Rare when it is the first Park Rare", function()
			expect(PicnicLogic.countSign({ true, true, false }, 3, true)).to.equal(
				"Last one: a Rare!"
			)
			expect(PicnicLogic.countSign({ true, false, false }, 3, true)).to.equal(
				"Picnic cats 2/3"
			)
		end)

		it("hides once all three are caught", function()
			expect(PicnicLogic.countSign({ true, true, true }, 3, true)).to.equal(nil)
		end)
	end)
end
