--!strict
-- The store's thank-you burst (#1823): small, short and only after a confirmed buy. Written by the vfx-animator for
-- QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects store burst", function()
		it("stays a short, modest thank-you for each kind", function()
			local s = Presets.storeBurst
			expect(s.seconds + s.stagger <= 1).to.equal(true)
			expect(s.ringSeconds <= 1).to.equal(true)
			for _, kind in { "pass", "pack", "bundle" } do
				local k = s.kinds[kind]
				expect(k ~= nil and k.colour ~= nil).to.equal(true)
				expect(k.sparkles >= 1 and k.sparkles <= 24).to.equal(true)
				expect(k.rings >= 1 and k.rings <= 2).to.equal(true)
			end
		end)

		it("draws over the store window and under the toasts", function()
			local order = Presets.storeBurst.displayOrder
			expect(order > 20 and order < 30).to.equal(true)
		end)
	end)
end
