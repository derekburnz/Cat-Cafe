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

	describe("Wayfinding.lockedAlpha (Derek 2026-10-28)", function()
		it("shows a locked area's marker only right by its gate", function()
			expect(Wayfinding.lockedAlpha(0)).to.equal(1)
			expect(Wayfinding.lockedAlpha(Wayfinding.LOCKED_NEAR)).to.equal(1)
			expect(Wayfinding.lockedAlpha(Wayfinding.LOCKED_FAR)).to.equal(0)
			expect(Wayfinding.lockedAlpha(Wayfinding.FAR)).to.equal(0)
			expect(Wayfinding.lockedAlpha(500)).to.equal(0)
		end)

		it("fades out between LOCKED_NEAR and LOCKED_FAR, NaN hidden", function()
			local middle = (Wayfinding.LOCKED_NEAR + Wayfinding.LOCKED_FAR) / 2
			expect(Wayfinding.lockedAlpha(middle)).to.be.near(0.5, 1e-9)
			expect(Wayfinding.lockedAlpha(0 / 0)).to.equal(0)
		end)
	end)

	describe("Wayfinding.scale (Derek 2026-10-28)", function()
		it("draws near markers full size and far ones smaller", function()
			expect(Wayfinding.scale(0)).to.equal(1)
			expect(Wayfinding.scale(Wayfinding.SCALE_NEAR)).to.equal(1)
			expect(Wayfinding.scale(Wayfinding.SCALE_FAR)).to.be.near(Wayfinding.SCALE_MIN, 1e-9)
			expect(Wayfinding.scale(math.huge)).to.be.near(Wayfinding.SCALE_MIN, 1e-9)
		end)

		it("never grows as the player walks away", function()
			local last = math.huge
			for distance = 0, Wayfinding.SCALE_FAR + 50, 5 do
				local size = Wayfinding.scale(distance)
				expect(size <= last).to.equal(true)
				last = size
			end
			expect(Wayfinding.scale(0 / 0)).to.equal(1)
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

		it("never brightens a locked marker or grows any marker as the player walks away (#408)", function()
			local lastLocked, lastScale = 1, 1
			for distance = -10, Wayfinding.SCALE_FAR + 60, 0.5 do
				local locked = Wayfinding.lockedAlpha(distance)
				local scale = Wayfinding.scale(distance)
				expect(locked >= 0 and locked <= 1).to.equal(true)
				expect(locked <= lastLocked).to.equal(true)
				expect(scale >= Wayfinding.SCALE_MIN and scale <= 1).to.equal(true)
				expect(scale <= lastScale).to.equal(true)
				lastLocked, lastScale = locked, scale
			end
			-- a locked marker is full right at its gate, where an open one has faded out
			expect(Wayfinding.lockedAlpha(0)).to.equal(1)
			expect(Wayfinding.lockedAlpha(-math.huge)).to.equal(1)
			expect(Wayfinding.lockedAlpha(math.huge)).to.equal(0)
			expect(Wayfinding.scale(math.huge)).to.equal(Wayfinding.SCALE_MIN)
			expect(Wayfinding.scale(-math.huge)).to.equal(1)
		end)

		it("counts boxes within 1% of the biggest as the same size, and one 1.1% smaller as smaller", function()
			-- the side the player is on decides only between boxes that are the same size
			local close = { { area = 1000, x = -78 }, { area = 991, x = 78 } }
			expect(Wayfinding.pickBox(close, 1)).to.equal(2)
			expect(Wayfinding.pickBox(close, -1)).to.equal(1)
			local smaller = { { area = 1000, x = -78 }, { area = 989, x = 78 } }
			expect(Wayfinding.pickBox(smaller, 1)).to.equal(1)
			expect(Wayfinding.pickBox(smaller, -1)).to.equal(1)
		end)
	end)

	describe("Wayfinding.pickBox", function()
		it("takes the biggest box", function()
			local boxes = { { area = 100, x = 5 }, { area = 400, x = -40 }, { area = 50, x = 90 } }
			expect(Wayfinding.pickBox(boxes, 1)).to.equal(2)
		end)

		it("takes the one on the player's side when two are the same size", function()
			local alleys = { { area = 7530, x = 78 }, { area = 7530, x = -78 } }
			expect(Wayfinding.pickBox(alleys, 1)).to.equal(1)
			expect(Wayfinding.pickBox(alleys, -1)).to.equal(2)
		end)

		it("takes the west one with no cafe", function()
			local alleys = { { area = 7530, x = 78 }, { area = 7530, x = -78 } }
			expect(Wayfinding.pickBox(alleys, nil)).to.equal(2)
		end)

		it("finds nothing in no boxes", function()
			expect(Wayfinding.pickBox({}, 1)).never.to.be.ok()
		end)
	end)

	describe("Wayfinding.armArea", function()
		it("reads the Area attribute first", function()
			expect(Wayfinding.armArea("Woods", "Arm_Sewer")).to.equal("woods")
		end)

		it("falls back to the arm's name", function()
			expect(Wayfinding.armArea(nil, "Arm_Neighbourhood")).to.equal("neighbourhood")
			expect(Wayfinding.armArea(nil, "CatCafe_Square_Signpost_ArmPark")).to.equal("park")
		end)

		it("finds nothing on other parts", function()
			expect(Wayfinding.armArea(nil, "Post")).never.to.be.ok()
			expect(Wayfinding.armArea("", "Arm")).never.to.be.ok()
			expect(Wayfinding.armArea(3, "Cap")).never.to.be.ok()
		end)
	end)

	describe("Wayfinding.armLock", function()
		it("locks an arm above the player's tier", function()
			expect(Wayfinding.armLock(3, 1)).to.equal("🔒 Tier 3")
		end)

		it("leaves an opened area's arm plain", function()
			expect(Wayfinding.armLock(2, 2)).never.to.be.ok()
			expect(Wayfinding.armLock(1, 5)).never.to.be.ok()
		end)
	end)
end
