--!strict
-- The rare-catch chat line (#2203, shared/GlobalCatch): RareCatchChat(text, rarity, elsewhere) from the server becomes
-- a system line in the chat window, in the rarity's colour, "From another cafe: " first when it came from another
-- server. The toast for this server's catches is UIController's Announce, as before.
--
-- Roblox terms: TextChatService is the built-in chat. Its RBXGeneral channel is the one every player sees, and
-- DisplaySystemMessage adds a line to it on this client only, with no speaker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local GlobalCatch = require(ReplicatedStorage.Shared.GlobalCatch)
local Net = require(script.Parent.Parent.Net)

local RareCatchChatController = {}

local general: TextChannel? = nil

-- RBXGeneral, found on first use: the channels appear a moment after join, and a line before then is skipped (its
-- toast still showed).
local function channel(): TextChannel?
	if general ~= nil and general.Parent ~= nil then
		return general
	end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local found = if channels ~= nil then channels:FindFirstChild("RBXGeneral") else nil
	if found ~= nil and found:IsA("TextChannel") then
		general = found :: TextChannel
	end
	return general
end

local function show(text: unknown, rarity: unknown, elsewhere: unknown)
	if type(text) ~= "string" or type(rarity) ~= "string" then
		return
	end
	local current = channel()
	if current == nil then
		return
	end
	local line = GlobalCatch.chatLine(text, rarity, elsewhere == true)
	local ok, err = pcall(function()
		current:DisplaySystemMessage(line)
	end)
	if not ok then
		warn("[RareCatchChat] " .. tostring(err))
	end
end

function RareCatchChatController.start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return -- the legacy chat has no system lines from here
	end
	Net.on("RareCatchChat", show)
end

return RareCatchChatController
