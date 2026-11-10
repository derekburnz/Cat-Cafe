--!strict
-- The rare-catch chat line (#2203, shared/GlobalCatch): RareCatchChat(text, rarity, elsewhere) from the server becomes
-- a system line in the chat window, in the rarity's colour, "From another cafe: " first when it came from another
-- server (#3033: system lines land in the window's Here tab; its Global tab is Roblox's own player chat between
-- servers, which a game cannot write to; #3116: no globe on the line). The toast for this server's catches is UIController's Announce, as before.
--
-- Roblox terms: TextChatService is the built-in chat. Its RBXGeneral channel is the one every player sees, and
-- DisplaySystemMessage adds a line to it on this client only, with no speaker.
--
-- #3012 (Derek2 2026-11-10: the chat button's blue bubble lit but the chat window was empty, and "global chat for
-- mythic or better cats still does not work on live"): the place Rojo built had no TextChatService in it, so it ran
-- the legacy chat (ChatVersion LegacyChatService), which Roblox no longer draws a window for. default.project.json
-- sets ChatVersion to TextChatService since then (a script cannot change it at run time; run-tests.mjs checks the
-- project file), so the line takes the DisplaySystemMessage road. The legacy road (#2902:
-- StarterGui:SetCore("ChatMakeSystemMessage"), retried for LEGACY_TRIES seconds while that chat loads) stays for a
-- place file built without the setting, and says so once in the log.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local GlobalCatch = require(ReplicatedStorage.Shared.GlobalCatch)
local Net = require(script.Parent.Parent.Net)

local RareCatchChatController = {}

local LEGACY_TRIES = 10 -- one a second while the legacy chat loads
local CHANNEL_WAIT = 10 -- seconds a line waits for RBXGeneral just after join

local general: TextChannel? = nil

-- RBXGeneral: the channels appear a moment after join, so the first line waits up to CHANNEL_WAIT seconds.
local function channel(): TextChannel?
	if general ~= nil and general.Parent ~= nil then
		return general
	end
	local channels = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT)
	local found = if channels ~= nil then channels:WaitForChild("RBXGeneral", CHANNEL_WAIT) else nil
	if found ~= nil and found:IsA("TextChannel") then
		general = found :: TextChannel
	end
	return general
end

local function showNew(text: string, rarity: string, elsewhere: boolean)
	local current = channel()
	if current == nil then
		warn("[RareCatchChat] no RBXGeneral channel")
		return
	end
	local line = GlobalCatch.chatLine(text, rarity, elsewhere)
	local ok, err = pcall(function()
		current:DisplaySystemMessage(line)
	end)
	if not ok then
		warn("[RareCatchChat] " .. tostring(err))
	end
end

local function showLegacy(text: string, rarity: string, elsewhere: boolean)
	local message = {
		Text = GlobalCatch.plainLine(text, elsewhere),
		Color = Color3.fromHex(GlobalCatch.color(rarity)),
		Font = Enum.Font.GothamBold,
	}
	local lastError = ""
	for _ = 1, LEGACY_TRIES do
		local ok, err = pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", message)
		end)
		if ok then
			return
		end
		lastError = tostring(err)
		task.wait(1)
	end
	warn("[RareCatchChat] legacy chat: " .. lastError)
end

local function show(text: unknown, rarity: unknown, elsewhere: unknown)
	if type(text) ~= "string" or type(rarity) ~= "string" then
		return
	end
	local away = elsewhere == true
	task.spawn(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			showNew(text, rarity, away)
		else
			showLegacy(text, rarity, away)
		end
	end)
end

function RareCatchChatController.start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn(
			"[RareCatchChat] this place runs the legacy chat; rare catch lines may not show. Set ChatVersion in default.project.json (#3012)"
		)
	end
	Net.on("RareCatchChat", show)
end

return RareCatchChatController
