--!strict
-- #4070 the Water Park and #4071 the Medieval Castle: each area's air, its strays' puff, its cannon tint and a catch
-- that grows with the cat's rarity (Derek 2026-11-13: "make the rarer ones more special"). Written by the
-- vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Water Park and Castle", function()
		for _, area in { "waterpark", "castle" } do
			it(
				"gives the " .. area .. " its air, a stray puff and a cannon tint, in budget",
				function()
					local spec = Presets.areaFx.areas[area]
					expect(spec).to.be.ok()
					local air = Presets.emitters[spec.air]
					expect(air).to.be.ok()
					expect(air.rate <= 14).to.equal(true) -- no thicker than the snow
					expect(air.size[1] <= 0.25).to.equal(true) -- motes, never a fog
					expect(Presets.emitters[spec.puffPreset]).to.be.ok()
					expect(Presets.cannon.tints[area]).to.be.ok()
				end
			)

			it("makes a catch in the " .. area .. " bigger as the cat gets rarer", function()
				local spec = Presets.catchFlavour.areas[area]
				expect(Presets.emitters[spec.preset]).to.be.ok()
				local function size(rarity: string): number
					local plan = Logic.catchFlavour(area, "some_cat", rarity)
					return plan.puff + plan.flakes + plan.ringScale * 10 + plan.gusts * 10
				end
				expect(size("Common")).to.equal(size("Rare"))
				expect(size("Epic") > size("Rare")).to.equal(true)
				expect(size("Legendary") > size("Epic")).to.equal(true)
				expect(size("Mythical") > size("Legendary")).to.equal(true)
				expect(size("Secret")).to.equal(size("Mythical"))
				-- a short column, quick but never a flicker
				expect(spec.gusts <= 4 and spec.gustEvery >= 0.12).to.equal(true)
			end)
		end

		it("reads each new area's box from the Config by its own name", function()
			local boxes = {
				{
					id = "waterpark",
					centre = { x = 0, z = 0 },
					size = { width = 100, depth = 100 },
				},
				{
					id = "castle",
					centre = { x = 500, z = 0 },
					size = { width = 100, depth = 100 },
				},
			}
			expect(Logic.areaAt(10, 10, boxes, 0)).to.equal("waterpark")
			expect(Logic.areaAt(520, -20, boxes, 0)).to.equal("castle")
			expect(Logic.areaAt(250, 0, boxes, 0)).to.equal(nil)
		end)
	end)
end
