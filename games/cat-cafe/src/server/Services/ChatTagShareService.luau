--!strict
-- #4882 (Derek 2026-11-16: "make titles show in global chat"): shares each player's chat tag with the other servers,
-- so a line in the chat's Global tab from a player on another server shows their title too (shared/ChatTags).
-- Writes each player's shown tag (their ChatTag attribute, set by PassService) to the MemoryStore hash map
-- ChatTags.SHARE_MAP while they are here, and answers ChatTagAsk for a speaker a client can't see with ChatTagOf.
--
-- Roblox terms: MemoryStoreService is a fast store shared by every server of the game, for data that only has to
-- live a short while; each entry here expires on its own after ChatTags.SHARE_TTL_SECONDS unless refreshed, so a
-- server that stops without cleaning up leaves nothing behind for long.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatTags = require(ReplicatedStorage.Shared.ChatTags)
local Net = require(script.Parent.Net)

local ChatTagShareService = {}

local CACHE_SECONDS = 60 -- an answer read from the map is reused this long for every asker on this server
local CACHE_MAX = 500 -- entries kept before the cache starts over

type Cached = { tag: string?, at: number }

local cache: { [number]: Cached } = {}
local cached = 0
local waiting: { [number]: { Player } } = {} -- user id -> askers while its read runs
local written: { [Player]: string } = {} -- the tag last written for each player here ("" for none)
local warned = false

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn("[ChatTagShare] " .. message)
	end
end

local function map(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(ChatTags.SHARE_MAP)
end

-- Writes `player`'s shown tag to the map (or removes their entry when they show none), unless it is already there
-- and `force` is false.
local function write(player: Player, force: boolean)
	local tag = ChatTags.fromShared(player:GetAttribute(ChatTags.CHAT_TAG_ATTRIBUTE)) or ""
	if not force and written[player] == tag then
		return
	end
	if tag == "" and written[player] == nil then
		written[player] = "" -- never written, so nothing to remove
		return
	end
	written[player] = tag
	local key = tostring(player.UserId)
	task.spawn(function()
		local ok, err = pcall(function()
			if tag == "" then
				map():RemoveAsync(key)
			else
				map():SetAsync(key, tag, ChatTags.SHARE_TTL_SECONDS)
			end
		end)
		if not ok then
			written[player] = nil -- written again at the next change or refresh
			warnOnce("write failed: " .. tostring(err))
		end
	end)
end

local function answer(player: Player, userId: number, tag: string?)
	if player.Parent == Players then
		Net.fire(player, "ChatTagOf", userId, tag or "")
	end
end

local function remember(userId: number, tag: string?)
	if cached >= CACHE_MAX then
		table.clear(cache)
		cached = 0
	end
	if cache[userId] == nil then
		cached += 1
	end
	cache[userId] = { tag = tag, at = os.clock() }
end

-- ChatTagAsk(userId): the shown tag of that user, from this server when they are here, else from the map.
local function onAsk(player: Player, rawUserId: unknown)
	local userId = ChatTags.askable(rawUserId)
	if userId == nil then
		return
	end
	local here = Players:GetPlayerByUserId(userId)
	if here ~= nil then
		answer(player, userId, ChatTags.fromShared(here:GetAttribute(ChatTags.CHAT_TAG_ATTRIBUTE)))
		return
	end
	local hit = cache[userId]
	if hit ~= nil and os.clock() - hit.at < CACHE_SECONDS then
		answer(player, userId, hit.tag)
		return
	end
	local queue = waiting[userId]
	if queue ~= nil then
		if table.find(queue, player) == nil then
			table.insert(queue, player)
		end
		return
	end
	waiting[userId] = { player }
	task.spawn(function()
		local ok, value = pcall(function()
			return map():GetAsync(tostring(userId))
		end)
		local tag = if ok then ChatTags.fromShared(value) else nil
		if ok then
			remember(userId, tag)
		else
			warnOnce("read failed: " .. tostring(value))
		end
		local askers: { Player } = waiting[userId] or {}
		waiting[userId] = nil
		for _, asker in askers do
			answer(asker, userId, tag)
		end
	end)
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(ChatTags.CHAT_TAG_ATTRIBUTE):Connect(function()
		write(player, false)
	end)
	write(player, false)
end

function ChatTagShareService.start()
	Net.on("ChatTagAsk", onAsk)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- No remove on leave: a player hopping servers could have it land after their new server's write. The entry
	-- expires by itself (SHARE_TTL_SECONDS), and a player who left has no chat lines to tag.
	Players.PlayerRemoving:Connect(function(player: Player)
		written[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(ChatTags.SHARE_REFRESH_SECONDS)
			for _, player in Players:GetPlayers() do
				if written[player] ~= nil and written[player] ~= "" then
					write(player, true)
				end
			end
		end
	end)
end

return ChatTagShareService
