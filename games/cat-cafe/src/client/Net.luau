--!strict
-- Client side of the remotes: thin wrappers so controllers never touch RemoteEvent instances directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Net = {}

function Net.fire(name: string, ...: any)
	Remotes.event(name):FireServer(...)
end

function Net.on(name: string, handler: (...any) -> ()): RBXScriptConnection
	return Remotes.event(name).OnClientEvent:Connect(handler)
end

return Net
