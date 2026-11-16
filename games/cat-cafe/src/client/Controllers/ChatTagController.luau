--!strict
-- Chat tags (#1624): puts a speaker's tag ("[VIP]") in front of their name in the chat window. The server sets the
-- tag as a Player attribute (shared/ChatTags); this only reads it, so it can't give anyone a tag.
--
-- Roblox terms: TextChatService is the built-in chat. Its OnIncomingMessage callback runs on each client for every
-- message and may return TextChatMessageProperties whose PrefixText replaces the name shown before the message, and
-- whose Text replaces the message shown (here the same text in the speaker's title colour).
--
-- #4882: a line in the Global tab can come from a player on another server, who is not in Players here. Their tag
-- comes from the server instead (ChatTagAsk, answered with ChatTagOf from ChatTagShareService), asked once per
-- speaker and again after ChatTags.ASK_AGAIN_SECONDS. The callback cannot wait, so the tag shows from their next line.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ChatTags = require(ReplicatedStorage.Shared.ChatTags)
local Net = require(script.Parent.Parent.Net)

local ChatTagController = {}

local ASKS_MOST = 8 -- asks in ASK_WINDOW_SECONDS, under the server's 10 every 10 s
local ASK_WINDOW_SECONDS = 10

type Known = { tag: string?, at: number }

local KNOWN_MOST = 1000 -- speakers kept before the list starts over
local knownCount = 0
local known: { [number]: Known } = {} -- speakers on other servers: their tag and when it was answered
local askedAt: { [number]: number } = {} -- when each was last asked
local recent: { number } = {} -- when the asks in the window went

-- Asks the server for `userId`'s tag unless it was asked lately or the window's asks are used up.
local function ask(userId: number, now: number)
	if now - (askedAt[userId] or -math.huge) < ChatTags.ASK_AGAIN_SECONDS then
		return
	end
	while #recent > 0 and now - recent[1] >= ASK_WINDOW_SECONDS do
		table.remove(recent, 1)
	end
	if #recent >= ASKS_MOST then
		return -- asked at their next line
	end
	table.insert(recent, now)
	askedAt[userId] = now
	Net.fire("ChatTagAsk", userId)
end

-- The tag id of a speaker who is not on this server, as far as known now (asking when it is unknown or old).
local function elsewhereTag(userId: number): string?
	if ChatTags.askable(userId) == nil then
		return nil
	end
	local now = os.clock()
	local entry = known[userId]
	if entry == nil or now - entry.at >= ChatTags.ASK_AGAIN_SECONDS then
		ask(userId, now)
	end
	return if entry ~= nil then entry.tag else nil
end

function ChatTagController.start()
	Net.on("ChatTagOf", function(userId: unknown, tagId: unknown)
		local id = ChatTags.askable(userId)
		if id ~= nil then
			if known[id] == nil then
				knownCount += 1
				if knownCount > KNOWN_MOST then
					table.clear(known)
					knownCount = 1
				end
			end
			known[id] = { tag = ChatTags.fromShared(tagId), at = os.clock() }
		end
	end)
	TextChatService.OnIncomingMessage = function(
		message: TextChatMessage
	): TextChatMessageProperties?
		local source: TextSource? = message.TextSource -- nil for a system message
		if source == nil then
			return nil
		end
		local speaker = Players:GetPlayerByUserId(source.UserId)
		local tagId = if speaker ~= nil
			then speaker:GetAttribute(ChatTags.CHAT_TAG_ATTRIBUTE)
			else elsewhereTag(source.UserId) -- #4882: a Global tab line from another server
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
