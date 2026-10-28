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
end
