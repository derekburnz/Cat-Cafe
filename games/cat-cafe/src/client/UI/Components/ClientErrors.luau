--!strict
-- The newest client error lines since join, sent with a bug report as clientErrors (docs/playtests/bug-reports.md
-- section 1): at most 3, each cut to 200 bytes (BugReportLogic). UI.init starts it; it reads the errors already in
-- the log, then keeps up with new ones.
--
-- Roblox terms: LogService is the Output window as a service. On a player's device it sees only that device's
-- lines; MessageOut fires for each new one with its type, and red error lines have the type MessageError.

local LogService = game:GetService("LogService")

local BugReportLogic = require(script.Parent.BugReportLogic)

local ClientErrors = {}

local lines: { string } = {}
local connection: RBXScriptConnection? = nil

function ClientErrors.start()
	if connection then
		return
	end
	table.clear(lines)
	local ok, history = pcall(function()
		return LogService:GetLogHistory()
	end)
	if ok and type(history) == "table" then
		for _, entry in history do
			if entry.messageType == Enum.MessageType.MessageError then
				BugReportLogic.pushError(lines, entry.message)
			end
		end
	end
	connection = LogService.MessageOut:Connect(function(message: string, kind: Enum.MessageType)
		if kind == Enum.MessageType.MessageError then
			BugReportLogic.pushError(lines, message)
		end
	end)
end

-- A copy of the lines, oldest first.
function ClientErrors.recent(): { string }
	return table.clone(lines)
end

function ClientErrors.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return ClientErrors
