--!strict
-- The rare-catch chat line across servers (#2203, shared/GlobalCatch). RareMomentService.shoutOut hands it every
-- catch shout-out that went out as this server's toast: RareCatchChat(text, rarity, false) puts it in this server's
-- chat, and, at most once every GlobalCatch.PUBLISH_GAP_SECONDS (a Mythical always), it is published on
-- MessagingService topic GlobalCatch.TOPIC. A message from another server, checked by GlobalCatch.parse and at most
-- one every GlobalCatch.SHOW_GAP_SECONDS (a Mythical always), goes to every player here as RareCatchChat(text, rarity,
-- true): a chat line only, no toast.
--
-- Roblox terms: MessagingService is Roblox's message bus between the running servers of one experience. A publish
-- reaches every subscribed server within about a second. It fails in a Studio place that was never published, so the
-- subscribe is tried three times and then left with one warning in the log, and a failed publish is dropped: the
-- line still shows in this server's chat.
--
-- #3053: while the live switch GlobalCatch.FEED_FLAG is on, this server keeps a chat channel named
-- GlobalCatch.FEED_CHANNEL with every player in it as a reader (their TextSource cannot send). The chat window gives
-- a custom channel its own tab, and each client writes the Mythical lines it is sent into it
-- (RareCatchChatController). The switch is read every FEED_CHECK_SECONDS; off again destroys the channel, which
-- takes the tab off every client.
-- Roblox terms: a TextChannel is one chat channel; a player sees it once the server calls AddUserAsync for them,
-- which makes a TextSource (that player's seat in the channel) whose CanSend says whether they may type there.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local GlobalCatch = require(ReplicatedStorage.Shared.GlobalCatch)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)

local GlobalCatchService = {}

local SUBSCRIBE_WAITS = { 5, 15 } -- seconds before the second and third tries
local FEED_CHECK_SECONDS = 15 -- how often the feed channel follows its live switch
local CHANNELS_WAIT = 30 -- seconds the first check waits for the chat's TextChannels folder

local publishGate = GlobalCatch.gate(GlobalCatch.PUBLISH_GAP_SECONDS)
local showGate = GlobalCatch.gate(GlobalCatch.SHOW_GAP_SECONDS)

local function onMessage(message: any)
	local data = if type(message) == "table" then message.Data else nil
	local text, rarity = GlobalCatch.parse(data, game.JobId)
	if text == nil or rarity == nil then
		return
	end
	if GlobalCatch.take(showGate, os.clock(), rarity) then
		Net.fireAll("RareCatchChat", text, rarity, true)
	end
end

-- A catch shout-out `text` of a `rarity` cat that this server just toasted: in this server's chat, and to the
-- others when the publish gate lets it through. `here` (#2567: a pity or shower cat) keeps it in this server.
function GlobalCatchService.share(text: string, rarity: string, here: boolean?)
	Net.fireAll("RareCatchChat", text, rarity, false)
	if
		here == true
		or #text > GlobalCatch.MAX_TEXT
		or not GlobalCatch.take(publishGate, os.clock(), rarity)
	then
		return
	end
	local message = GlobalCatch.encode(text, rarity, game.JobId)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(GlobalCatch.TOPIC, message)
		end)
		if not ok then
			warn("[GlobalCatch] publish failed: " .. tostring(err))
		end
	end)
end

-- #3053: the feed channel while its switch is on
local feed: TextChannel? = nil
local feedWarned = false

-- `player` joins the feed as a reader. AddUserAsync refuses a player Roblox does not let chat; they just get no tab.
local function seat(player: Player)
	local channel = feed
	if channel == nil then
		return
	end
	local ok, source = pcall(function()
		return channel:AddUserAsync(player.UserId)
	end)
	if ok and typeof(source) == "Instance" and source:IsA("TextSource") then
		source.CanSend = false
	end
end

local function followFeed()
	local want = LiveFlagService.on(GlobalCatch.FEED_FLAG)
	if want == (feed ~= nil) then
		return
	end
	if not want then
		local channel = feed :: TextChannel
		feed = nil
		channel:Destroy()
		return
	end
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return -- the legacy chat has no channels (RareCatchChatController says so once)
	end
	local channels = TextChatService:WaitForChild("TextChannels", CHANNELS_WAIT)
	if channels == nil then
		if not feedWarned then
			feedWarned = true
			warn(
				"[GlobalCatch] no TextChannels folder, so no " .. GlobalCatch.FEED_CHANNEL .. " tab"
			)
		end
		return
	end
	local channel = Instance.new("TextChannel")
	channel.Name = GlobalCatch.FEED_CHANNEL
	channel.Parent = channels
	feed = channel
	for _, player in Players:GetPlayers() do
		task.spawn(seat, player)
	end
end

function GlobalCatchService.start()
	Players.PlayerAdded:Connect(seat)
	task.spawn(function()
		while true do
			followFeed()
			task.wait(FEED_CHECK_SECONDS)
		end
	end)
	task.spawn(function()
		local lastError = ""
		for attempt = 1, #SUBSCRIBE_WAITS + 1 do
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(GlobalCatch.TOPIC, onMessage)
			end)
			if ok then
				return
			end
			lastError = tostring(err)
			local wait = SUBSCRIBE_WAITS[attempt]
			if wait ~= nil then
				task.wait(wait)
			end
		end
		warn("[GlobalCatch] no rare catches from other servers here: " .. lastError)
	end)
end

-- Studio-only test hook (Debug): a message as if another server sent it, through the same parse and gate. Returns
-- the chat text shown, or nil when it was ignored or held back.
function GlobalCatchService.debugReceive(data: unknown): string?
	local text, rarity = GlobalCatch.parse(data, game.JobId)
	if text == nil or rarity == nil or not GlobalCatch.take(showGate, os.clock(), rarity) then
		return nil
	end
	Net.fireAll("RareCatchChat", text, rarity, true)
	return GlobalCatch.chatLine(text, rarity, true)
end

return GlobalCatchService
