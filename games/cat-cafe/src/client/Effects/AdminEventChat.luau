--!strict
-- An admin event's line in the chat window (#4195; Gameplay-Engineer 2026-11-14: "one system message per server at
-- the 2 min warning and at the start (same words as the cards)"). Each client writes it for itself as the card goes
-- up, so everyone in the server reads it once, with no remote: `AdminEventChat.say(line)` adds `line`
-- (AdminEventLogic.chatLine) to RBXGeneral as a system message, which has no speaker and shows on this client only.
-- A player with chat off, or a place on the legacy chat, simply gets no line; the cards and the timer still show.
--
-- Roblox terms: TextChatService is the built-in chat, RBXGeneral the channel every player sees, and
-- DisplaySystemMessage adds a line to it on this client.

local TextChatService = game:GetService("TextChatService")

local AdminEventChat = {}

local CHANNEL_WAIT = 10 -- seconds a line waits for RBXGeneral just after join

function AdminEventChat.say(line: string)
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT)
		local general = if channels ~= nil
			then channels:WaitForChild("RBXGeneral", CHANNEL_WAIT)
			else nil
		if general == nil or not general:IsA("TextChannel") then
			return
		end
		pcall(function()
			(general :: TextChannel):DisplaySystemMessage(line)
		end)
	end)
end

return AdminEventChat
