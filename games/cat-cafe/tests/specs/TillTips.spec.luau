--!strict
-- UI/Components/TillTips.luau: the till's tip button reads the plot's tip piles and shows only on the plot (F61).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local TillTips = require(Components:WaitForChild("TillTips")) :: any
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")) :: any
	local World = Config.World

	describe("TillTips.amount", function()
		it("reads the waiting total only while at least one pile waits", function()
			expect(TillTips.amount(3, 120)).to.equal(120)
			expect(TillTips.amount(0, 120)).to.equal(0)
			expect(TillTips.amount(2, 0)).to.equal(0)
			expect(TillTips.amount(nil, nil)).to.equal(0)
			expect(TillTips.amount("3", 120)).to.equal(0)
			expect(TillTips.amount(1, 0 / 0)).to.equal(0)
			expect(TillTips.amount(1, math.huge)).to.equal(0)
		end)
	end)

	describe("TillTips.onPlot", function()
		-- points in plot space: -Z toward the street, +Z toward the yard and the back alley
		local halfW = World.PlotWidth / 2
		local halfD = World.PlotDepth / 2
		local function at(x: number, z: number): Vector3
			return Vector3.new(x, 0, z)
		end

		it("takes the cafe, the front garden and the yard, a stud wider than the walls", function()
			expect(TillTips.onPlot(at(0, 0))).to.equal(true)
			expect(TillTips.onPlot(at(halfW + 1, 0))).to.equal(true)
			expect(TillTips.onPlot(at(-halfW - 1, 0))).to.equal(true)
			expect(TillTips.onPlot(at(0, -halfD - 1 - World.FrontGardenDepth))).to.equal(true)
			expect(TillTips.onPlot(at(0, halfD + 1 + World.YardDepth))).to.equal(true)
		end)

		it("leaves out the sidewalk, the neighbour's plot and the back alley", function()
			expect(TillTips.onPlot(at(0, -halfD - 2 - World.FrontGardenDepth))).to.equal(false)
			expect(TillTips.onPlot(at(halfW + 2, 0))).to.equal(false)
			expect(TillTips.onPlot(at(0, halfD + 2 + World.YardDepth))).to.equal(false)
		end)

		it("puts the till on the counter top at the back of the cafe, on the plot", function()
			expect(TillTips.TILL.X).to.be.near(1.2, 1e-6)
			expect(TillTips.TILL.Y).to.be.near(3, 1e-6)
			expect(TillTips.TILL.Z).to.be.near(halfD - 3, 1e-6)
			expect(TillTips.onPlot(TillTips.TILL)).to.equal(true)
		end)
	end)

	describe("TillTips edges (QA, F61)", function()
		local Layout = require(game:GetService("ServerScriptService").Server.World.Layout) :: any
		local halfW = World.PlotWidth / 2
		local halfD = World.PlotDepth / 2

		-- the box the server's CollectTips takes (WorldBuilder.inSafeZone with no door radius), from its own numbers
		local function serverBox(x: number, z: number): boolean
			return math.abs(x) <= halfW + 1 and z >= Layout.plot.frontGarden.z1 and z <= halfD + 1 + World.YardDepth
		end

		it("shows Collect exactly where the server pays, a hair either side of every edge", function()
			local xs = { 0, halfW + 1 - 0.01, halfW + 1, halfW + 1.01, -(halfW + 1), -(halfW + 1.01) }
			local zs = {
				0,
				Layout.plot.frontGarden.z1,
				Layout.plot.frontGarden.z1 - 0.01,
				Layout.plot.frontGarden.z1 + 0.01,
				halfD + 1 + World.YardDepth,
				halfD + 1 + World.YardDepth + 0.01,
				halfD + 1 + World.YardDepth - 0.01,
			}
			for _, x in xs do
				for _, z in zs do
					local at = string.format("(%.2f, %.2f): ", x, z)
					expect(at .. tostring(TillTips.onPlot(Vector3.new(x, 0, z)))).to.equal(
						at .. tostring(serverBox(x, z))
					)
				end
			end
		end)

		it("floats the button over the counter the layout builds", function()
			expect(TillTips.TILL.X).to.be.near(Layout.plot.counter.x + 1.2, 1e-6)
			expect(TillTips.TILL.Z).to.be.near(Layout.plot.counter.z, 1e-6)
		end)

		it("reads 0 for a negative total or count and the whole total at six piles", function()
			expect(TillTips.amount(1, -5)).to.equal(0)
			expect(TillTips.amount(-1, 120)).to.equal(0)
			expect(TillTips.amount(Config.TipPilesMax, 5 * Config.TipPilesMax)).to.equal(5 * Config.TipPilesMax)
		end)
	end)
end
