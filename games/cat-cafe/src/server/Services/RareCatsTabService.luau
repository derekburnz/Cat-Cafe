--!strict
-- #3053 (shared/RareCatsTab): the chat's "Rare Cats" channel. While the `rareCatsTab` live switch is on, this keeps a
-- TextChannel called RareCatsTab.NAME in the chat and every player in it as a reader who cannot send. While it is
-- off (the default) there is no channel, so the chat looks as it always has. The lines themselves are written on
-- each client (RareCatchChatController), from the same RareCatchChat event that feeds the normal chat, so no text a
-- player typed ever goes in.
--
-- Roblox terms: TextChatService is the built-in chat. A TextChannel is one stream of messages in it; the chat
-- window shows each channel of ours as a tab once the client turns channel tabs on. A TextSource is one player's
-- membership of a channel (AddUserAsync makes it); CanSend false makes that player a reader only.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local LiveFlagService = require(script.Parent.LiveFlagService)
local RareCatsTab = require(game:GetService("ReplicatedStorage").Shared.RareCatsTab)

local RareCatsTabService = {}

local CHECK_SECONDS = 5
local FOLDER_WAIT = 10

local channel: TextChannel? = nil
local reading: { [Player]: TextChannel } = {} -- the channel each player was added to
local warned = false

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn("[RareCatsTab] " .. message)
	end
end

-- The channel, made on first need beside Roblox's own (TextChatService.TextChannels).
local function ensure(): TextChannel?
	if channel ~= nil and channel.Parent ~= nil then
		return channel
	end
	local folder = TextChatService:WaitForChild("TextChannels", FOLDER_WAIT)
	if folder == nil then
		warnOnce("no TextChannels folder in TextChatService")
		return nil
	end
	local made = Instance.new("TextChannel")
	made.Name = RareCatsTab.NAME
	made.Parent = folder
	channel = made
	return made
end

-- Every player a reader of the channel: a TextSource that cannot send. AddUserAsync gives nothing for a player
-- with chat off, who then simply has no tab.
local function addReaders(into: TextChannel)
	for _, player in Players:GetPlayers() do
		if reading[player] == into then
			continue
		end
		reading[player] = into
		task.spawn(function()
			local ok, source = pcall(function()
				return into:AddUserAsync(player.UserId)
			end)
			if ok and typeof(source) == "Instance" and source:IsA("TextSource") then
				source.CanSend = false
			elseif not ok then
				reading[player] = nil -- tried again at the next check
				warnOnce("AddUserAsync failed: " .. tostring(source))
			end
		end)
	end
end

local function step()
	if LiveFlagService.on(RareCatsTab.FLAG) then
		local current = ensure()
		if current ~= nil then
			addReaders(current)
		end
	elseif channel ~= nil then
		channel:Destroy()
		channel = nil
		table.clear(reading)
	end
end

function RareCatsTabService.start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return -- the legacy chat has no channels of this kind (#3012)
	end
	Players.PlayerRemoving:Connect(function(player)
		reading[player] = nil
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function(): string?
				step()
				return nil
			end)
			if not ok then
				warnOnce(tostring(err))
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return RareCatsTabService
