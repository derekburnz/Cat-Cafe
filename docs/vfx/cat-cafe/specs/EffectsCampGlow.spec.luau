--!strict
-- The camp stations' ready glows (#1133, #1154, #1232): one soft light per station, inside the night glow budget,
-- that reads what the station holds. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects camp glows", function()
		it("stays a soft light inside the night glow budget", function()
			local g = Presets.campGlow
			expect(g.brightness > 0 and g.brightness <= 1).to.equal(true)
			expect(g.range > 0 and g.range <= 10).to.equal(true)
			for _, extraId in { "picnic", "yardSale", "pond" } do
				local e = g.extras[extraId]
				expect(e ~= nil).to.equal(true)
				-- under the roof, above the ground
				expect(e.under > 0 and e.under < 1).to.equal(true)
				expect(e.colour ~= nil).to.equal(true)
			end
		end)

		it("glows only while something waits", function()
			for _, id in { "picnic", "yardSale", "pond" } do
				local function held(open: boolean, n: number): number
					return Logic.campHeld({ [id] = { open = open, held = n } }, id)
				end
				expect(held(true, 1) > 0).to.equal(true)
				expect(held(true, 0)).to.equal(0)
				expect(held(false, 0)).to.equal(0)
			end
			expect(Logic.campHeld(nil, "pond")).to.equal(0)
		end)
	end)
end
