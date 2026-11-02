--!strict
-- The Rescue Rally on this client (F101, rescue-rally.md section 4). The server's RallyState is kept in
-- `RallyController.state` and handed to the UI's `UI.rally.update(state)` (the banner, the step icons, the Friday
-- chip, the cannon picker's line and the board's screen) once it has the hook. The pops come from Effects/Rally,
-- which listens to RallyPoint itself; the step prizes' toasts come from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)

local RallyController = {}

RallyController.state = nil :: Types.RallyState?

-- The UI's update hook, or nil until the UI has it.
local function updateHook(): ((Types.RallyState) -> ())?
	local rally = (UI :: any).rally
	local fn = if rally ~= nil then rally.update else nil
	return if type(fn) == "function" then fn else nil
end

function RallyController.start()
	Net.on("RallyState", function(state: Types.RallyState)
		RallyController.state = state
		local update = updateHook()
		if update ~= nil then
			update(state)
		end
	end)
end

return RallyController
