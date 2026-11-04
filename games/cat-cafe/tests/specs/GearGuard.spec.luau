--!strict
-- GearGuard.luau (#1062, "no gear from items allowed in game"): a Tool or HopperBin is removed unless the game marked
-- it with CatCafeTool = true; accessories, clothing and other avatar parts are never touched.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GearGuard = require(Shared.GearGuard)

	-- A stand-in instance: its class chain and attributes are all GearGuard reads.
	local function fake(classes: { string }, attributes: { [string]: any }?): Instance
		local attrs = attributes or {}
		local item = {}
		function item.IsA(_, className: string): boolean
			return table.find(classes, className) ~= nil
		end
		function item.GetAttribute(_, name: string): any
			return attrs[name]
		end
		return item :: any
	end

	describe("isForeign", function()
		it("removes a gear Tool and an old HopperBin", function()
			expect(GearGuard.isForeign(fake({ "Tool", "BackpackItem", "Instance" }))).to.equal(true)
			expect(GearGuard.isForeign(fake({ "HopperBin", "BackpackItem", "Instance" }))).to.equal(
				true
			)
		end)

		it("keeps a Tool the game marked", function()
			local ours = fake({ "Tool", "BackpackItem", "Instance" }, { [GearGuard.MARK] = true })
			expect(GearGuard.isForeign(ours)).to.equal(false)
			local notTrue = fake({ "Tool", "BackpackItem", "Instance" }, { [GearGuard.MARK] = "yes" })
			expect(GearGuard.isForeign(notTrue)).to.equal(true)
		end)

		it("never touches accessories, clothing or body parts", function()
			for _, classes in
				{
					{ "Accessory", "Accoutrement", "Instance" },
					{ "Shirt", "Clothing", "Instance" },
					{ "Pants", "Clothing", "Instance" },
					{ "ShirtGraphic", "Instance" },
					{ "MeshPart", "BasePart", "Instance" },
					{ "Humanoid", "Instance" },
				}
			do
				expect(GearGuard.isForeign(fake(classes))).to.equal(false)
			end
		end)
	end)
end
