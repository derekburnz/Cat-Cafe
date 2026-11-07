--!strict
-- Client side of the remotes: thin wrappers so controllers never touch RemoteEvent instances directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Net = {}

-- Remotes the server takes once a second (Net's RateLimiter.new(1, 1)) that a player can press twice by accident: a
-- double tap on Collect at a camp extra, or Travel twice. A repeat this soon would only be dropped there and logged
-- as "rate limit hit" (Derek2's dev console, 2026-11-07), so it is dropped here instead.
local SPACED: { [string]: number } = {
	CollectCampExtra = 1.05,
	Travel = 1.05,
}
local lastFired: { [string]: number } = {}

function Net.fire(name: string, ...: any)
	local gap = SPACED[name]
	if gap ~= nil then
		local now = os.clock()
		if now - (lastFired[name] or -math.huge) < gap then
			return
		end
		lastFired[name] = now
	end
	Remotes.event(name):FireServer(...)
end

function Net.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	return Remotes.event(name).OnClientEvent:Connect(handler)
end

return Net
