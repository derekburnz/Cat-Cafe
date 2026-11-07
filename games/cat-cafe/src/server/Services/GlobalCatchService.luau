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

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalCatch = require(ReplicatedStorage.Shared.GlobalCatch)
local Net = require(script.Parent.Net)

local GlobalCatchService = {}

local SUBSCRIBE_WAITS = { 5, 15 } -- seconds before the second and third tries

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
-- others when the publish gate lets it through.
function GlobalCatchService.share(text: string, rarity: string)
	Net.fireAll("RareCatchChat", text, rarity, false)
	if #text > GlobalCatch.MAX_TEXT or not GlobalCatch.take(publishGate, os.clock(), rarity) then
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

function GlobalCatchService.start()
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
