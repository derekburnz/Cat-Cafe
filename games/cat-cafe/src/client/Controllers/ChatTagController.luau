--!strict
-- Chat tags (#1624): puts a speaker's tag ("[VIP]") in front of their name in the chat window. The server sets the
-- tag as a Player attribute (shared/ChatTags); this only reads it, so it can't give anyone a tag.
--
-- Roblox terms: TextChatService is the built-in chat. Its OnIncomingMessage callback runs on each client for every
-- message and may return TextChatMessageProperties whose PrefixText replaces the name shown before the message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ChatTags = require(ReplicatedStorage.Shared.ChatTags)

local ChatTagController = {}

function ChatTagController.start()
	TextChatService.OnIncomingMessage = function(
		message: TextChatMessage
	): TextChatMessageProperties?
		local source = message.TextSource
		if source == nil then
			return nil
		end
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker == nil then
			return nil
		end
		local prefix = ChatTags.prefixFor(speaker:GetAttribute(ChatTags.CHAT_TAG_ATTRIBUTE))
		if prefix == nil then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = prefix .. message.PrefixText
		return properties
	end
end

return ChatTagController
