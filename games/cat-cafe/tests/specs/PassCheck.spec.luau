--!strict
-- shared/PassCheck (#2130, #2131): a failed join lookup keeps trying while the player stays, and a bought pass counts
-- only once Roblox says the player owns it.
return function()
	local PassCheck = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PassCheck")
	)

	-- A lookup that gives `answers` in turn (nil is a failed call), and the waits it was asked to make.
	local function scripted(
		answers: { boolean | string }
	): (() -> boolean?, (number) -> (), { number }, () -> number)
		local asked = 0
		local waits: { number } = {}
		local function lookup(): boolean?
			asked += 1
			local answer = answers[asked]
			return if answer == true then true elseif answer == false then false else nil
		end
		local function wait(seconds: number)
			table.insert(waits, seconds)
		end
		return lookup, wait, waits, function(): number
			return asked
		end
	end

	describe("PassCheck", function()
		it(
			"retries a failed join lookup at 5, 15 and 45 s, then every 5 minutes for as long as it takes (#2130)",
			function()
				expect(PassCheck.retryAfter(1)).to.equal(5)
				expect(PassCheck.retryAfter(2)).to.equal(15)
				expect(PassCheck.retryAfter(3)).to.equal(45)
				for attempt = 4, 40 do
					expect(PassCheck.retryAfter(attempt)).to.equal(300)
				end
				expect(PassCheck.retryAfter(0)).to.equal(5)
			end
		)

		it(
			"grants nothing when the purchase flag says bought but Roblox says not owned (#2131)",
			function()
				local lookup, wait, waits, asked = scripted({ false, false, false })
				expect(PassCheck.confirm(lookup, wait)).to.equal(false)
				expect(asked()).to.equal(#PassCheck.CONFIRM_SECONDS)
				expect(#waits).to.equal(#PassCheck.CONFIRM_SECONDS - 1)
			end
		)

		it("grants nothing when every lookup fails", function()
			local lookup, wait = scripted({ "fail", "fail", "fail" })
			expect(PassCheck.confirm(lookup, wait)).to.equal(false)
		end)

		it("grants at once when Roblox already says owned, with no wait", function()
			local lookup, wait, waits, asked = scripted({ true })
			expect(PassCheck.confirm(lookup, wait)).to.equal(true)
			expect(asked()).to.equal(1)
			expect(#waits).to.equal(0)
		end)

		it("grants when the answer lags a moment after a real buy", function()
			local lookup, wait, waits, asked = scripted({ false, "fail", true })
			expect(PassCheck.confirm(lookup, wait)).to.equal(true)
			expect(asked()).to.equal(3)
			expect(waits[1]).to.equal(PassCheck.CONFIRM_SECONDS[2])
			expect(waits[2]).to.equal(PassCheck.CONFIRM_SECONDS[3])
		end)
	end)
end
