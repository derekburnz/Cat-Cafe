--!strict
-- #4255 follow-up: a Secret hops once a visit, only at a running player, never mid-swing (SecretCalm).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.Config)
	local SecretCalm = require(ReplicatedStorage.Shared.SecretCalm)

	describe("SecretCalm (#4255 follow-up)", function()
		it("lets a Secret hop away from a player once, then it holds still", function()
			expect(SecretCalm.mayHop(nil)).to.equal(true)
			expect(SecretCalm.mayHop(0)).to.equal(true)
			expect(SecretCalm.mayHop(1)).to.equal(false)
			expect(SecretCalm.mayHop(5)).to.equal(false)
		end)

		it("startles only at a player running at it", function()
			local run = Config.NormalWalkSpeed
			expect(SecretCalm.running(Vector3.new(run, 0, 0))).to.equal(true)
			expect(SecretCalm.running(Vector3.new(0, 0, run * 1.5))).to.equal(true)
			expect(SecretCalm.running(Vector3.new(run * 0.4, 0, 0))).to.equal(false)
			expect(SecretCalm.running(Vector3.zero)).to.equal(false)
			-- a fall or a jump is not running at it
			expect(SecretCalm.running(Vector3.new(0, -50, 0))).to.equal(false)
		end)

		it("never startles while a swing is in the air", function()
			expect(SecretCalm.swinging(nil)).to.equal(false)
			expect(SecretCalm.swinging(0)).to.equal(true)
			expect(SecretCalm.swinging(Config.NetSmackDelay)).to.equal(true)
			expect(SecretCalm.swinging(SecretCalm.SWING_SECONDS + 0.01)).to.equal(false)
			expect(SecretCalm.SWING_SECONDS > Config.NetSmackDelay).to.equal(true)
		end)
	end)
end
