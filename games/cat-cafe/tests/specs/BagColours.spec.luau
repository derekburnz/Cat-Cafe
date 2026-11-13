--!strict
-- shared/BagColours.luau: the Backpack's two colour picks (#3699).
return function()
	local BagColours = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BagColours")
	) :: any

	describe("BagColours.LIST", function()
		it("has twelve colours with unique ids, the two defaults among them", function()
			expect(#BagColours.LIST).to.equal(12)
			local seen = {}
			for _, row in BagColours.LIST do
				expect(seen[row.id]).to.equal(nil)
				seen[row.id] = true
				expect(row.color.R >= 0 and row.color.R <= 1).to.equal(true)
			end
			expect(seen[BagColours.DEFAULT_MAIN]).to.equal(true)
			expect(seen[BagColours.DEFAULT_TRIM]).to.equal(true)
		end)

		it(
			"has the defaults as the bag's built colours, so no bag changes when this ships",
			function()
				expect(BagColours.row("plum").color).to.equal(BagColours.BUILT.main[1])
				expect(BagColours.row("rose").color).to.equal(BagColours.BUILT.trim[1])
			end
		)
	end)

	describe("BagColours.sanitize", function()
		it("keeps two known ids", function()
			local picks = BagColours.sanitize({ main = "navy", trim = "honey" })
			expect(picks.main).to.equal("navy")
			expect(picks.trim).to.equal("honey")
		end)

		it("keeps nothing for the two defaults", function()
			expect(BagColours.sanitize({ main = "plum", trim = "rose" })).to.equal(nil)
		end)

		it("refuses unknown ids, colour values and anything that is not a table", function()
			expect(BagColours.sanitize({ main = "neon", trim = "rose" })).to.equal(nil)
			expect(BagColours.sanitize({ main = "navy" })).to.equal(nil)
			expect(BagColours.sanitize({ main = Color3.new(1, 0, 0), trim = "rose" })).to.equal(nil)
			expect(BagColours.sanitize({ main = 3, trim = true })).to.equal(nil)
			expect(BagColours.sanitize("navy")).to.equal(nil)
			expect(BagColours.sanitize(nil)).to.equal(nil)
		end)

		it("reads nothing saved as the defaults", function()
			local picks = BagColours.picks(nil)
			expect(picks.main).to.equal("plum")
			expect(picks.trim).to.equal("rose")
			expect(BagColours.picks({ main = "sky", trim = "bogus" }).trim).to.equal("rose")
		end)
	end)

	describe("BagColours.slotOf", function()
		it("knows the bag's purples as main and its pinks as trim", function()
			for _, color in BagColours.BUILT.main do
				expect(BagColours.slotOf(color)).to.equal("main")
			end
			for _, color in BagColours.BUILT.trim do
				expect(BagColours.slotOf(color)).to.equal("trim")
			end
			-- the model file's rounded values
			expect(BagColours.slotOf(Color3.new(0.5804, 0.4745, 0.7451))).to.equal("main")
			expect(BagColours.slotOf(Color3.new(0.8784, 0.4784, 0.549))).to.equal("trim")
		end)

		it("leaves the cream, gold and mint parts alone", function()
			expect(BagColours.slotOf(Color3.new(0.9569, 0.9333, 0.9647))).to.equal(nil)
			expect(BagColours.slotOf(Color3.new(0.949, 0.7569, 0.3059))).to.equal(nil)
			expect(BagColours.slotOf(Color3.new(0.5608, 0.8275, 0.7569))).to.equal(nil)
		end)
	end)

	describe("BagColours.colorFor", function()
		local navy = BagColours.row("navy").color

		it("returns the built colour for the defaults and for parts of no slot", function()
			local defaults = { main = "plum", trim = "rose" }
			for _, color in BagColours.BUILT.main do
				expect(BagColours.colorFor(color, defaults)).to.equal(color)
			end
			local cream = Color3.new(0.9569, 0.9333, 0.9647)
			expect(BagColours.colorFor(cream, { main = "navy", trim = "honey" })).to.equal(cream)
		end)

		it("gives the slot's own colour the pick exactly", function()
			expect(BagColours.colorFor(BagColours.BUILT.main[1], { main = "navy", trim = "rose" })).to.equal(
				navy
			)
		end)

		it("keeps a lighter part lighter than the slot's own colour under every pick", function()
			for _, row in BagColours.LIST do
				local picks = { main = row.id, trim = row.id }
				local own = BagColours.value(BagColours.colorFor(BagColours.BUILT.main[1], picks))
				local light = BagColours.value(BagColours.colorFor(BagColours.BUILT.main[2], picks))
				expect(light >= own).to.equal(true)
				local trimOwn =
					BagColours.value(BagColours.colorFor(BagColours.BUILT.trim[1], picks))
				local trimLight =
					BagColours.value(BagColours.colorFor(BagColours.BUILT.trim[3], picks))
				expect(trimLight >= trimOwn).to.equal(true)
			end
		end)

		it("changes only the picked slot", function()
			local picks = { main = "navy", trim = "rose" }
			expect(BagColours.colorFor(BagColours.BUILT.trim[1], picks)).to.equal(
				BagColours.BUILT.trim[1]
			)
			expect(BagColours.colorFor(BagColours.BUILT.main[2], picks)).never.to.equal(
				BagColours.BUILT.main[2]
			)
		end)
	end)

	describe("BagColours.tint", function()
		-- stand-ins for the bag's parts: the cloud tests have no Instances
		local function bag(): any
			local parts = {}
			local model = {
				GetDescendants = function()
					return parts
				end,
			}
			for index, color in
				{
					BagColours.BUILT.main[1],
					BagColours.BUILT.main[2],
					BagColours.BUILT.trim[1],
					Color3.new(0.9569, 0.9333, 0.9647),
				}
			do
				local attributes = {}
				local part = {
					Color = color,
					IsA = function(_, class: string)
						return class == "BasePart"
					end,
					GetAttribute = function(_, name: string)
						return attributes[name]
					end,
					SetAttribute = function(_, name: string, value: any)
						attributes[name] = value
					end,
				}
				parts[index] = part
				model["P" .. index] = part
			end
			return model
		end

		it("colours the purple and pink parts and leaves the rest", function()
			local model = bag()
			expect(BagColours.tint(model, { main = "navy", trim = "honey" })).to.equal(3)
			expect((model :: any).P1.Color).to.equal(BagColours.row("navy").color)
			expect((model :: any).P3.Color).to.equal(BagColours.row("honey").color)
			expect((model :: any).P4.Color).to.equal(Color3.new(0.9569, 0.9333, 0.9647))
		end)

		it("can be picked again and put back to the built colours", function()
			local model = bag()
			BagColours.tint(model, { main = "navy", trim = "honey" })
			BagColours.tint(model, { main = "mint", trim = "honey" })
			expect((model :: any).P1.Color).to.equal(BagColours.row("mint").color)
			BagColours.tint(model, { main = "plum", trim = "rose" })
			expect((model :: any).P1.Color).to.equal(BagColours.BUILT.main[1])
			expect((model :: any).P2.Color).to.equal(BagColours.BUILT.main[2])
			expect((model :: any).P3.Color).to.equal(BagColours.BUILT.trim[1])
		end)
	end)
end
