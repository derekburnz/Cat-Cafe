--!strict
-- Effects/ArcadeGlow (#3062): the arcade cabinet's idle glow stays slow and small.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Presets = require(Client:WaitForChild("Effects"):WaitForChild("Presets")) :: any

	describe("Effects arcade glow", function()
		it("drifts slowly through a few colours near the cabinet", function()
			local p = Presets.arcadeGlow
			expect(p.step >= 1 / 3).to.equal(true)
			expect(#p.colours >= 2).to.equal(true)
			expect(p.within > 0).to.equal(true)
			expect(Presets.emitters[p.emitter]).to.be.ok()
			expect(p.screen).to.equal("Screen")
		end)
	end)
end
