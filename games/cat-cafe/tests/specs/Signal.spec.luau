--!strict
-- shared/Signal.luau: the engineer's typed signal. Handlers run via task.spawn.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Signal = require(Shared.Signal)

	describe("Signal", function()
		it("Connect receives every Fire with its arguments", function()
			local signal = Signal.new()
			local got = {}
			signal:Connect(function(a, b)
				table.insert(got, { a, b })
			end)
			signal:Fire(1, "x")
			signal:Fire(2, "y")
			expect(got).to.deepEqual({ { 1, "x" }, { 2, "y" } })
		end)

		it("Disconnect stops delivery and flips Connected", function()
			local signal = Signal.new()
			local count = 0
			local connection = signal:Connect(function()
				count += 1
			end)
			signal:Fire()
			expect(connection.Connected).to.equal(true)
			connection:Disconnect()
			expect(connection.Connected).to.equal(false)
			signal:Fire()
			expect(count).to.equal(1)
		end)

		it("Once fires a single time", function()
			local signal = Signal.new()
			local count = 0
			local connection = signal:Once(function()
				count += 1
			end)
			signal:Fire()
			signal:Fire()
			expect(count).to.equal(1)
			expect(connection.Connected).to.equal(false)
		end)

		it("DisconnectAll clears every handler", function()
			local signal = Signal.new()
			local count = 0
			local a = signal:Connect(function()
				count += 1
			end)
			local b = signal:Connect(function()
				count += 1
			end)
			signal:DisconnectAll()
			signal:Fire()
			expect(count).to.equal(0)
			expect(a.Connected).to.equal(false)
			expect(b.Connected).to.equal(false)
		end)

		it("one erroring handler does not stop the others", function()
			local signal = Signal.new()
			local reached = false
			signal:Connect(function()
				error("handler exploded")
			end)
			signal:Connect(function()
				reached = true
			end)
			expect(function()
				signal:Fire()
			end).never.to.throw()
			expect(reached).to.equal(true)
		end)

		it("disconnecting inside a handler during Fire is safe", function()
			local signal = Signal.new()
			local connection: Signal.Connection? = nil
			local fired = 0
			connection = signal:Connect(function()
				fired += 1
				if connection ~= nil then
					connection:Disconnect()
				end
			end)
			signal:Connect(function()
				fired += 1
			end)
			expect(function()
				signal:Fire()
			end).never.to.throw()
			expect(fired).to.equal(2)
		end)
	end)
end
