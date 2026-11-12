--!strict
-- UI/Components/SecretTagLogic: the Secret stray's tag (#3470 section 5).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local SecretTagLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("SecretTagLogic")
	) :: any

	describe("SecretTagLogic", function()
		it("tags only a stray whose Rarity attribute is Secret", function()
			expect(SecretTagLogic.tagged("Secret")).to.equal(true)
			expect(SecretTagLogic.tagged("Mythical")).to.equal(false)
			expect(SecretTagLogic.tagged(nil)).to.equal(false)
			expect(SecretTagLogic.tagged(true)).to.equal(false)
		end)

		it("shows the name the server set and ??? for anything else", function()
			expect(SecretTagLogic.name("???")).to.equal("???")
			expect(SecretTagLogic.name("Nebula")).to.equal("Nebula")
			expect(SecretTagLogic.name(nil)).to.equal("???")
			expect(SecretTagLogic.name("")).to.equal("???")
			expect(SecretTagLogic.name(7)).to.equal("???")
		end)

		it("hides while the cat is held in a net and shows again once it bolts", function()
			expect(SecretTagLogic.shows(nil)).to.equal(true)
			expect(SecretTagLogic.shows(0)).to.equal(true)
			expect(SecretTagLogic.shows(12345)).to.equal(false)
		end)

		it("reads SECRET and shows within 150 studs", function()
			expect(SecretTagLogic.TEXT).to.equal("SECRET")
			expect(SecretTagLogic.UNKNOWN).to.equal("???")
			expect(SecretTagLogic.RANGE).to.equal(150)
		end)
	end)
end
