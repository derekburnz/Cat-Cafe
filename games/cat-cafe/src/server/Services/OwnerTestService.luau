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
--   to the events store; anywhere else, or from anyone else, it is refused with a line in the output.
-- Nothing a product holds can be traded (OwnerTest.tradeableIn, OwnerTest.spec), and grants never reach the Thank
-- You board, which lists idea credits only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local CafePassService = require(script.Parent.CafePassService)
local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local Net = require(script.Parent.Net)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local ProductService = require(script.Parent.ProductService)
local Products = require(ReplicatedStorage.Shared.Products)

local OwnerTestService = {}

local function mark(player: Player)
	if OwnerTest.isOwner(player.UserId) then
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
	if not OwnerTest.isOwner(player.UserId) then
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

-- `/event <preset> <minutes>` or `/event stop` from `userId` (section 8). Returns the reply for the owner's toast.
function OwnerTestService.eventCommand(userId: number, text: string): string?
	if not OwnerTest.isOwner(userId) and not RunService:IsStudio() then
		warn(`[OwnerTest] /event from {userId}, who is not an owner: dropped`)
		return nil
	end
	if not testPlace() then
		warn(`[OwnerTest] /event from {userId} in a live server: dropped`)
		return "Owner test mode: /event runs only in Studio or a private server"
	end
	local words = string.split(string.lower(text), " ")
	local preset = words[2] or ""
	local minutes = tonumber(words[3] or "") or 10
	local line = EventService.startTest(preset, minutes)
	print(`[OwnerTest] {userId} /event {preset} {minutes}: {line}`)
	return "Owner test mode: " .. line
end

local function answer(player: Player?, userId: number, text: string)
	local reply = OwnerTestService.eventCommand(userId, text)
	if player ~= nil and reply ~= nil then
		Net.toast(player, reply, "good")
	end
end

-- With TextChatService chat, a TextChatCommand: the message never reaches the channel. With the legacy chat (the dev
-- copy's setting, Laptop-Tester 2026-11-08) TextChatCommands never fire, so Player.Chatted reads it instead.
local function eventCommand()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local command = Instance.new("TextChatCommand")
		command.Name = "OwnerTestEventCommand"
		command.PrimaryAlias = "/event"
		command.AutocompleteVisible = false
		command.Triggered:Connect(function(source: TextSource, text: string)
			answer(Players:GetPlayerByUserId(source.UserId), source.UserId, text)
		end)
		command.Parent = TextChatService
		return
	end
	local function listen(player: Player)
		player.Chatted:Connect(function(message: string)
			local lower = string.lower(message)
			if lower == "/event" or string.sub(lower, 1, 7) == "/event " then
				answer(player, player.UserId, message)
			end
		end)
	end
	Players.PlayerAdded:Connect(listen)
	for _, player in Players:GetPlayers() do
		listen(player)
	end
end

function OwnerTestService.start()
	Net.on("OwnerGrant", onOwnerGrant)
	eventCommand()
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
end

return OwnerTestService
