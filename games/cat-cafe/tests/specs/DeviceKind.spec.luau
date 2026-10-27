--!strict
-- DeviceKind.luau: the analytics device guess (growth analytics-plan, the joined step's device field). The "edges (QA)"
-- block is QA's: the phone and tablet edge both ways up, the ten-foot check first, no touch and no keyboard.
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

	describe("edges (QA)", function()
		it("splits phone and tablet at PHONE_SHORT_SIDE, either way up", function()
			local side = DeviceKind.PHONE_SHORT_SIDE
			local function touch(x: number, y: number): string
				return DeviceKind.classify(inputs(true, false, false, x, y))
			end
			expect(touch(1200, side - 1)).to.equal("phone")
			expect(touch(side - 1, 1200)).to.equal("phone")
			expect(touch(1200, side)).to.equal("tablet")
			expect(touch(side, 1200)).to.equal("tablet")
		end)

		it("checks the ten-foot interface before touch and keyboard", function()
			expect(DeviceKind.classify(inputs(true, false, true, 390, 844))).to.equal("console")
			expect(DeviceKind.classify(inputs(true, true, true, 1920, 1080))).to.equal("console")
		end)

		it("calls no touch and no keyboard a pc, as a gamepad on a computer is", function()
			expect(DeviceKind.classify(inputs(false, false, false, 1920, 1080))).to.equal("pc")
			expect(DeviceKind.classify(inputs(false, false, false, 390, 844))).to.equal("pc")
		end)
	end)
end
