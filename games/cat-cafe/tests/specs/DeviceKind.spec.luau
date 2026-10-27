--!strict
-- DeviceKind.luau: the analytics device guess (growth analytics-plan, the joined step's device field).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local DeviceKind = require(Shared.DeviceKind)

	local function inputs(
		touch: boolean,
		keyboard: boolean,
		tenFoot: boolean,
		x: number,
		y: number
	): DeviceKind.Inputs
		return {
			touch = touch,
			keyboard = keyboard,
			tenFoot = tenFoot,
			viewport = Vector2.new(x, y),
		}
	end

	it("calls a ten-foot interface a console", function()
		expect(DeviceKind.classify(inputs(false, false, true, 1920, 1080))).to.equal("console")
	end)

	it("splits touch-only devices into phones and tablets by the short side", function()
		expect(DeviceKind.classify(inputs(true, false, false, 844, 390))).to.equal("phone")
		expect(DeviceKind.classify(inputs(true, false, false, 1024, 768))).to.equal("tablet")
	end)

	it("calls anything with a keyboard a pc, touch screen or not", function()
		expect(DeviceKind.classify(inputs(false, true, false, 1920, 1080))).to.equal("pc")
		expect(DeviceKind.classify(inputs(true, true, false, 1366, 768))).to.equal("pc")
	end)
end
