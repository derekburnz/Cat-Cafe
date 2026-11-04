--!strict
-- The drift guard (#1021): the Effects beats that must land with the server's read from Config, so a later Config
-- change fails here instead of silently breaking the animation (twice on 2026-11-03 the carry and the net swing
-- landed before the server's judgement). Written by the Animation-Engineer.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local pose, fx, plan = Presets.cannonPose, Presets.cannon, Presets.clouds.cannon

	describe("Effects beats match Config", function()
		it("ends the cannon flight at CannonLaunchSeconds", function()
			expect(pose.ends).to.be.near(Config.CannonLaunchSeconds, 1e-9)
			expect(fx.endAt).to.be.near(Config.CannonLaunchSeconds, 1e-9)
		end)

		it("goes into the clouds at CannonCloudsAt", function()
			expect(pose.gone).to.be.near(Config.CannonCloudsAt, 1e-9)
			expect(fx.puffAt).to.be.near(Config.CannonCloudsAt, 1e-9)
			expect(plan.coverFrom).to.be.near(Config.CannonCloudsAt, 1e-9)
		end)

		it("touches down at CannonTouchdownAt", function()
			expect(pose.touch).to.be.near(Config.CannonTouchdownAt, 1e-9)
			expect(fx.landAt).to.be.near(Config.CannonTouchdownAt, 1e-9)
		end)

		it("hides the server's move under full cloud, the flyer out of sight", function()
			local at = Config.CannonTeleportAtSeconds
			expect(Logic.cloudCover(at, plan)).to.equal(1)
			expect(at > pose.gone and at < pose.drop).to.equal(true)
			expect(Logic.cannonTrail(at, fx)).to.equal(false)
		end)

		it("lands the net swing at NetSmackDelay", function()
			expect(Presets.netSmack.land).to.be.near(Config.NetSmackDelay, 1e-9)
		end)
	end)
end
