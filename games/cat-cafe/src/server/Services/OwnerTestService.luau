--!strict
-- Owner test mode on the server (#1770, Monetization-Agent's policy; shared/OwnerTest). For a player in
-- Config.OwnerTestUserIds, keyed by user id and decided here only:
-- - the player gets the OwnerTest attribute, so their client shows "Owner test mode" and sends OwnerGrant in place of
--   Roblox's purchase prompt (PassService counts every made pass as owned for them);
-- - OwnerGrant(productId) grants a made product through the normal grant path (ProductService.give, or the Cafe
--   Pass's CafePassService.buyPaid) with no receipt record and no Robux, the potions paid under an owner_test_ sku;
-- - every grant, and every OwnerGrant from anyone else, is logged in the server output.
-- - #2486 (live-events.md section 8): in Studio or a private server, an owner's chat command `/event <preset>
--   <minutes>` (or `/event stop`) runs a Cafe Event test in that server only (EventService.startTest), writing nothing
--   to the events store; from anyone else it is refused with a line in the output.
-- - #3212: in a live public server the same command (`/event 10` is the full party for 10 minutes) runs a real event
--   on every server through the events schedule (EventService.ownerStart), and `/shout <message>` shows a filtered
--   message to every player on every server (MessagingService topic OwnerTest.TOPIC). #3301: the message shows in the
--   OWNER bubble (OwnerShout), and the experience's own owner counts as an owner (OwnerTest.isOwnerPlayer).
-- Nothing a product holds can be traded (OwnerTest.tradeableIn, OwnerTest.spec), and grants never reach the Thank
-- You board, which lists idea credits only.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local Net = require(script.Parent.Net)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local ProductService = require(script.Parent.ProductService)
local Products = require(ReplicatedStorage.Shared.Products)
local QuietStartService = require(script.Parent.QuietStartService)

local OwnerTestService = {}

-- #3301: on the list, or the experience's own owner (OwnerTest.isOwnerPlayer); a user id with no player here goes
-- by the list alone
local function ownerId(userId: number): boolean
	if OwnerTest.isOwner(userId) then
		return true
	end
	local player = Players:GetPlayerByUserId(userId)
	return player ~= nil and OwnerTest.isOwnerPlayer(player)
end

local function mark(player: Player)
	if OwnerTest.isOwnerPlayer(player) then
		player:SetAttribute(OwnerTest.ATTRIBUTE, true)
		print(
			string.format(
				"[OwnerTest] %d (%s) joined in owner test mode",
				player.UserId,
				player.Name
			)
		)
	end
end

local function onOwnerGrant(player: Player, rawProductId: unknown)
	if not OwnerTest.isOwnerPlayer(player) then
		warn(
			string.format(
				"[OwnerTest] OwnerGrant from %d, who is not an owner: dropped",
				player.UserId
			)
		)
		return
	end
	local product = Products.forProductId(rawProductId)
	if product == nil then
		return
	end
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if product.seasonPass == true then
		if CafePassService.running() == 0 then
			Net.toast(player, "Owner test mode: no Cafe Pass season is running", "warn")
			return
		end
		local unlocked = CafePassService.buyPaid(player, profile)
		print(
			string.format(
				"[OwnerTest] %d granted %s (no receipt, no Robux): %s",
				player.UserId,
				product.id,
				if unlocked then "paid track unlocked" else "already unlocked"
			)
		)
		Net.toast(
			player,
			if unlocked
				then "Owner test mode: the Cafe Pass paid track is unlocked"
				else "Owner test mode: this season's paid track is already unlocked",
			"good"
		)
		CafePassService.send(player, profile)
		CafeService.sync(player)
		return
	end
	print(
		string.format("[OwnerTest] %d granted %s (no receipt, no Robux)", player.UserId, product.id)
	)
	ProductService.give(
		player,
		profile,
		product,
		OwnerTest.SKU_PREFIX .. product.id,
		"Owner test mode: "
	)
end

-- Studio, or a private server (a reserved server has no owner and counts as live, as PalService reads it).
local function testPlace(): boolean
	return RunService:IsStudio() or (game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0)
end

-- #3212: tells the other servers on OwnerTest.TOPIC (a shout to show, or "read the schedule now"). A failed
-- publish is dropped with a line in the log: a shout still showed here, and an event still starts everywhere at
-- each server's next read of the schedule.
local function tellServers(message: OwnerTest.Message)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(OwnerTest.TOPIC, message)
		end)
		if not ok then
			warn("[OwnerTest] publish to the other servers failed: " .. tostring(err))
		end
	end)
end

-- `/event <minutes>`, `/event <preset> <minutes>` or `/event stop` from `userId`. Returns the reply for the owner's
-- toast. In Studio or a private server it is section 8's test in that server only (EventService.startTest). #3212
-- (Derek2 2026-11-11: "I want to run it in a live game with a command from owner mode"): in a live public server
-- it is a real event on every server (EventService.ownerStart), for an owner only.
function OwnerTestService.eventCommand(userId: number, text: string): string?
	if not ownerId(userId) and not RunService:IsStudio() then
		warn(`[OwnerTest] /event from {userId}, who is not an owner: dropped`)
		return nil
	end
	local ask = OwnerTest.eventAsk(text)
	if testPlace() then
		local line = EventService.startTest(ask.preset, ask.minutes)
		print(`[OwnerTest] {userId} /event {ask.preset} {ask.minutes}: {line}`)
		return "Owner test mode: " .. line
	end
	local line: string, changed: boolean
	if ask.stop then
		line, changed = EventService.ownerStop()
	else
		line, changed = EventService.ownerStart(ask.preset, ask.minutes)
	end
	print(`[OwnerTest] {userId} /event {ask.preset} {ask.minutes} (live): {line}`)
	if changed then
		tellServers(OwnerTest.eventMessage(game.JobId))
	end
	return "Owner test mode: " .. line
end

-- #4195: `/admin <kind> [minutes] [now]` or `/admin stop` from `userId` (OwnerTest.adminAsk). As `/event`: in
-- Studio or a private server the admin event runs in that server only (EventService.startAdminTest); in a live
-- public server an owner's goes into the schedule for every server (EventService.ownerAdmin), beside a Cafe Party
-- if one runs. From anyone else it is dropped with a line in the output.
function OwnerTestService.adminCommand(userId: number, text: string): string?
	if not ownerId(userId) and not RunService:IsStudio() then
		warn(`[OwnerTest] /admin from {userId}, who is not an owner: dropped`)
		return nil
	end
	local ask = OwnerTest.adminAsk(text)
	if testPlace() then
		local line = EventService.startAdminTest(ask.kind, ask.minutes, ask.now)
		print(`[OwnerTest] {userId} /admin {ask.kind}: {line}`)
		return "Owner test mode: " .. line
	end
	local line: string, changed: boolean
	if ask.stop then
		line, changed = EventService.ownerAdminStop()
	else
		line, changed = EventService.ownerAdmin(ask.kind, ask.minutes, ask.now)
	end
	print(`[OwnerTest] {userId} /admin {ask.kind} (live): {line}`)
	if changed then
		tellServers(OwnerTest.eventMessage(game.JobId))
	end
	return "Owner test mode: " .. line
end

local lastShoutAt: number? = nil

-- #3212 (Derek2 2026-11-11: "add a command to /shout "msg" across all servers so I can tell people in all servers
-- things"): `/shout <message>` from an owner shows the message to every player on every server. The text goes
-- through Roblox's filter for a broadcast first (TextService:FilterStringAsync, then the string for everyone), one
-- shout every SHOUT_GAP_SECONDS a server. Returns the reply for the owner's toast.
function OwnerTestService.shoutCommand(userId: number, text: string): string?
	if not ownerId(userId) and not RunService:IsStudio() then
		warn(`[OwnerTest] /shout from {userId}, who is not an owner: dropped`)
		return nil
	end
	local body = OwnerTest.shoutText(text)
	if body == nil then
		return "Owner test mode: type /shout and then your message"
	end
	local now = os.clock()
	if not OwnerTest.shoutReady(lastShoutAt, now) then
		return string.format(
			"Owner test mode: one shout every %d seconds, try again in a moment",
			OwnerTest.SHOUT_GAP_SECONDS
		)
	end
	lastShoutAt = now
	local ok, filtered = pcall(function(): string
		local result =
			TextService:FilterStringAsync(body, userId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	local passed: string? = nil
	if ok and type(filtered) == "string" then
		passed = OwnerTest.shoutText("/shout " .. filtered)
	end
	if passed == nil then
		lastShoutAt = nil
		return "Owner test mode: Roblox's text filter did not pass that message, so nothing was sent"
	end
	local shown = passed :: string
	print(`[OwnerTest] {userId} /shout sent ({#shown} bytes)`)
	QuietStartService.fireAll(nil, "OwnerShout", shown) -- #4005: not over a new player's first minutes
	tellServers(OwnerTest.shoutMessage(shown, game.JobId))
	return if shown == body
		then "Owner test mode: shout sent to all servers"
		else "Owner test mode: shout sent to all servers (the filter changed some of it)"
end

local lastCommand: { userId: number, text: string, at: number }? = nil
local REPEAT_WINDOW = 1 -- seconds; Chatted and the legacy ChatService can both deliver one line

local function answer(player: Player?, userId: number, text: string)
	local now = os.clock()
	if OwnerTest.isRepeat(lastCommand, userId, text, now, REPEAT_WINDOW) then
		return
	end
	lastCommand = { userId = userId, text = text, at = now }
	local reply: string? = nil
	if OwnerTest.isShoutCommand(text) then
		reply = OwnerTestService.shoutCommand(userId, text)
	elseif OwnerTest.isAdminCommand(text) then
		reply = OwnerTestService.adminCommand(userId, text)
	else
		reply = OwnerTestService.eventCommand(userId, text)
	end
	if player ~= nil and reply ~= nil then
		Net.toast(player, reply :: string, "info") -- #3080: green toasts off ToastRules.KEEP no longer show
	end
end

-- #2754: with the legacy chat, Player.Chatted did not fire in the dev copy (Laptop-Tester 2026-11-09), so the line is
-- also caught by the legacy ChatService's command processor, which runs for every message before it is sent. It
-- swallows only an `/event` line; every other line returns false and goes out as normal. The owner and test place
-- checks stay in eventCommand. The ChatService module only exists once the legacy chat has loaded, so this waits for
-- it in its own thread and gives up quietly if it never comes.
local function legacyChatCommand()
	local runner = game:GetService("ServerScriptService"):WaitForChild("ChatServiceRunner", 30)
	local module = if runner ~= nil then runner:WaitForChild("ChatService", 30) else nil
	if module == nil or not module:IsA("ModuleScript") then
		warn("[OwnerTest] no legacy ChatService found; /event listens on Player.Chatted only")
		return
	end
	local ok, chatService = pcall(require, module)
	if not ok or type(chatService) ~= "table" then
		warn(
			"[OwnerTest] the legacy ChatService did not load; /event listens on Player.Chatted only"
		)
		return
	end
	local service = chatService :: any
	service:RegisterProcessCommandsFunction(
		"OwnerTestEvent",
		function(speakerName: string, message: string)
			if not OwnerTest.isCommand(message) then
				return false
			end
			local speaker = service:GetSpeaker(speakerName)
			local player: Player? = if speaker ~= nil then speaker:GetPlayer() else nil
			if player == nil then
				return false
			end
			answer(player, player.UserId, message)
			return true -- the command never shows in chat
		end
	)
end

-- With TextChatService chat, a TextChatCommand: the message never reaches the channel. With the legacy chat (the dev
-- copy's setting, Laptop-Tester 2026-11-08) TextChatCommands never fire, so the legacy ChatService and Player.Chatted
-- read it instead (whichever comes first answers; the other is a repeat).
local COMMANDS: { [string]: string } = {
	OwnerTestEventCommand = "/event",
	OwnerTestShoutCommand = "/shout",
	OwnerTestAdminCommand = "/admin", -- #4195
}

local function eventCommand()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		for name, alias in COMMANDS do
			local command = Instance.new("TextChatCommand")
			command.Name = name
			command.PrimaryAlias = alias
			command.AutocompleteVisible = false
			command.Triggered:Connect(function(source: TextSource, text: string)
				answer(Players:GetPlayerByUserId(source.UserId), source.UserId, text)
			end)
			command.Parent = TextChatService
		end
		return
	end
	task.spawn(legacyChatCommand)
	local function listen(player: Player)
		player.Chatted:Connect(function(message: string)
			if OwnerTest.isCommand(message) then
				answer(player, player.UserId, message)
			end
		end)
	end
	Players.PlayerAdded:Connect(listen)
	for _, player in Players:GetPlayers() do
		listen(player)
	end
end

local SUBSCRIBE_WAITS = { 5, 15 } -- seconds before the second and third tries
local SHOW_GAP_SECONDS = 5 -- a shout or a schedule read from another server, at most this often each
local lastShown: { [string]: number } = {}

-- #3212: another server's owner sent a shout, or changed the events schedule. Only this experience's own servers
-- (and its Open Cloud key) can publish here, and the sender checked the owner; the text is checked again for size.
local function onServerMessage(message: any)
	local data = if type(message) == "table" then message.Data else nil
	local kind, text = OwnerTest.parseMessage(data, game.JobId)
	if kind == nil then
		return
	end
	local now = os.clock()
	if now - (lastShown[kind] or -math.huge) < SHOW_GAP_SECONDS then
		return
	end
	lastShown[kind] = now
	if kind == "shout" and text ~= nil then
		QuietStartService.fireAll(nil, "OwnerShout", text) -- #4005
	elseif kind == "event" then
		EventService.refresh()
	end
end

local function listenToServers()
	task.spawn(function()
		local lastError = ""
		for attempt = 1, #SUBSCRIBE_WAITS + 1 do
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(OwnerTest.TOPIC, onServerMessage)
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
		warn("[OwnerTest] no shouts from other servers here: " .. lastError)
	end)
end

function OwnerTestService.start()
	Net.on("OwnerGrant", onOwnerGrant)
	eventCommand()
	listenToServers()
	-- mark can yield on a group-owned experience (OwnerTest.isOwnerPlayer's rank lookup)
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(mark, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(mark, player)
	end
end

return OwnerTestService
