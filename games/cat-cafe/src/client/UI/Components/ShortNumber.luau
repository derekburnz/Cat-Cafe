--!strict
-- #1814: the short numbers moved to Shared/ShortNumber, so the server's toasts can use them too. This keeps the
-- client's require(script.Parent.ShortNumber) paths working.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShortNumber"))
