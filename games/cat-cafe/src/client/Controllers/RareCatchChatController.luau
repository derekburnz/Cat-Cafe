--!strict
-- The rare-catch chat line (#2203, shared/GlobalCatch): RareCatchChat(text, rarity, elsewhere) from the server becomes
-- a system line in the chat window, in the rarity's colour, "🌍 Global: " first when it came from another
-- server (#3033: system lines land in the window's Here tab; its Global tab is Roblox's own player chat between
-- servers, which a game cannot write to). The toast for this server's catches is UIController's Announce, as before.
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
--
-- #3053 (Derek2 2026-11-10: "the global chat should show mythical or better (including ones from your own server in
-- global)"): while the server keeps the feed channel (GlobalCatch.FEED_CHANNEL, behind a live switch), every line of
-- GlobalCatch.FEED_FROM or rarer is also written into it, this server's and the other servers' alike, so the chat
-- window's "Global Cats" tab is the feed Derek asked for. The window draws a tab for a custom channel only with
-- channel tabs on (TextChatService.ChannelTabsConfiguration.Enabled), so this turns them on while the channel is
-- here and puts them back as they were when it goes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local GlobalCatch = require(ReplicatedStorage.Shared.GlobalCatch)
local Net = require(script.Parent.Parent.Net)

local RareCatchChatController = {}

local LEGACY_TRIES = 10 -- one a second while the legacy chat loads
local CHANNEL_WAIT = 10 -- seconds a line waits for RBXGeneral just after join
local FEED_HELLO_WAIT = 2 -- seconds after the feed's tab is asked for before its first line

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

-- #3053: the feed channel, when the server has made it and seated this player
local function feedChannel(): TextChannel?
	local channels = TextChatService:FindFirstChild("TextChannels")
	local found = if channels ~= nil then channels:FindFirstChild(GlobalCatch.FEED_CHANNEL) else nil
	return if found ~= nil and found:IsA("TextChannel") then found else nil
end

local function showFeed(line: string)
	local feed = feedChannel()
	if feed == nil then
		return
	end
	local ok, err = pcall(function()
		feed:DisplaySystemMessage(line)
	end)
	if not ok then
		warn("[RareCatchChat] feed: " .. tostring(err))
	end
end

-- Channel tabs on while the feed channel is here, and back to what the place had once it is gone.
local tabsBefore: boolean? = nil
local function followTabs()
	local tabs = TextChatService:FindFirstChildOfClass("ChannelTabsConfiguration")
	if tabs == nil then
		return
	end
	if feedChannel() ~= nil then
		if tabsBefore == nil then
			tabsBefore = tabs.Enabled
			tabs.Enabled = true
			-- a first line, so the new tab is not empty (after the window has drawn the tab)
			task.delay(FEED_HELLO_WAIT, function()
				showFeed(GlobalCatch.feedLine(GlobalCatch.FEED_HELLO, GlobalCatch.FEED_FROM))
			end)
		end
	elseif tabsBefore ~= nil then
		tabs.Enabled = tabsBefore
		tabsBefore = nil
	end
end

local function watchFeed()
	local channels = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT)
	if channels == nil then
		return
	end
	channels.ChildAdded:Connect(followTabs)
	channels.ChildRemoved:Connect(function()
		task.defer(followTabs) -- (the child is still in the folder while ChildRemoved runs)
	end)
	followTabs()
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
	if GlobalCatch.inFeed(rarity) then
		showFeed(GlobalCatch.feedLine(text, rarity)) -- #3053
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
	else
		task.spawn(watchFeed) -- #3053
	end
	Net.on("RareCatchChat", show)
end

return RareCatchChatController
