--!strict
-- UI/Components/Wayfinding.luau: when location markers show, and which zones are safe.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Wayfinding = require(Components:WaitForChild("Wayfinding")) :: any
	local Catalog =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))

	describe("Wayfinding.alpha", function()
		it("hides a marker up close and shows it fully from FAR out", function()
			expect(Wayfinding.alpha(0)).to.equal(0)
			expect(Wayfinding.alpha(Wayfinding.NEAR)).to.equal(0)
			expect(Wayfinding.alpha(Wayfinding.FAR)).to.equal(1)
			expect(Wayfinding.alpha(500)).to.equal(1)
		end)

		it("fades in between NEAR and FAR", function()
			local middle = (Wayfinding.NEAR + Wayfinding.FAR) / 2
			expect(Wayfinding.alpha(middle)).to.be.near(0.5, 1e-9)
		end)

		it("treats NaN as hidden", function()
			expect(Wayfinding.alpha(0 / 0)).to.equal(0)
		end)
	end)

	describe("Wayfinding zones", function()
		it("counts the street and the cafes as safe", function()
			expect(Wayfinding.isSafe(nil)).to.equal(true)
			expect(Wayfinding.isSafe("Cafe")).to.equal(true)
			expect(Wayfinding.isSafe("Alley")).to.equal(false)
		end)

		it("names the area of a catching zone", function()
			expect(Wayfinding.areaOf("Alley")).to.equal("alley")
			expect(Wayfinding.areaOf("Neighbourhood")).to.equal("neighbourhood")
			expect(Wayfinding.areaOf("Cafe")).never.to.be.ok()
			expect(Wayfinding.areaOf(nil)).never.to.be.ok()
		end)
	end)

	describe("Wayfinding edges (QA)", function()
		-- WorldBuilder names each area's World.Zones boxes after its Catalog id with the first letter upper-cased
		-- ("alley" -> "Alley"), and every plot's box "Cafe". The chip and the markers read those names back.
		local function zoneName(areaId: string): string
			return areaId:sub(1, 1):upper() .. areaId:sub(2)
		end

		it("maps every Catalog area's zone box back to that area, never safe", function()
			expect(#Catalog.areas >= 5).to.equal(true)
			for _, area in Catalog.areas do
				local zone = zoneName(area.id)
				expect(zone).never.to.equal("Cafe")
				expect(Wayfinding.isSafe(zone)).to.equal(false)
				expect(Wayfinding.areaOf(zone)).to.equal(area.id)
			end
		end)

		it("never gets less visible as the player walks away, and stays between 0 and 1", function()
			local last = -1
			for distance = -10, Wayfinding.FAR + 40, 0.5 do
				local alpha = Wayfinding.alpha(distance)
				expect(alpha >= 0 and alpha <= 1).to.equal(true)
				expect(alpha >= last).to.equal(true)
				last = alpha
			end
			expect(Wayfinding.NEAR < Wayfinding.FAR).to.equal(true)
			expect(Wayfinding.alpha(-math.huge)).to.equal(0)
			expect(Wayfinding.alpha(math.huge)).to.equal(1)
		end)
	end)
end
