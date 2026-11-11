--!strict
-- Chat tags (#1624): puts a speaker's tag ("[VIP]") in front of their name in the chat window. The server sets the
-- tag as a Player attribute (shared/ChatTags); this only reads it, so it can't give anyone a tag.
--
-- Roblox terms: TextChatService is the built-in chat. Its OnIncomingMessage callback runs on each client for every
-- message and may return TextChatMessageProperties whose PrefixText replaces the name shown before the message, and
-- whose Text replaces the message shown (here the same text in the speaker's title colour).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ChatTags = require(ReplicatedStorage.Shared.ChatTags)

local ChatTagController = {}

function ChatTagController.start()
	TextChatService.OnIncomingMessage = function(
		message: TextChatMessage
	): TextChatMessageProperties?
		local source: TextSource? = message.TextSource -- nil for a system message
		if source == nil then
			return nil
		end
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker == nil then
			return nil
		end
		local tagId = speaker:GetAttribute(ChatTags.CHAT_TAG_ATTRIBUTE)
		local prefix = ChatTags.prefixFor(tagId)
		if prefix == nil then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = prefix .. message.PrefixText
		-- the title also colours the message itself (Derek2 11-11); Text arrives escaped, so nothing typed becomes markup
		local coloured = ChatTags.textFor(tagId, message.Text)
		if coloured ~= nil then
			properties.Text = coloured
		end
		return properties
	end
end

return ChatTagController
