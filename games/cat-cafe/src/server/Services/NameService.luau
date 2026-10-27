--!strict
-- Naming cats (F33, data-model section 4). RenameCat(uid, name): CatName.validate, then one TextService filter
-- with the owner's UserId; a filter error or a name filtered down to hashes is refused with a toast and the old
-- name stays. The save keeps the raw name. What anyone sees is the broadcast filter's text, cached here per cat and
-- filtered again each session because the filter changes over time; a cat whose display filter fails, or is not
-- filtered yet, shows its catalog name. CafeService puts the shown name on the cat room's views and on each cat
-- model's DisplayName. TextService throttles per server (reviewer N92), so the cats on show in the plot (working
-- cats and nappers) are filtered as soon as CafeService asks, and the rest of a player's named cats one at a time,
-- BACKGROUND_SECONDS apart, after the join settles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local CatName = require(ReplicatedStorage.Shared.CatName)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local NameService = {}

-- Fires when a player's shown names change; CafeService rebuilds the plot's cats and syncs.
NameService.changed = Signal.new() :: Signal.Signal<Player>

local BACKGROUND_DELAY = 10 -- seconds after a join before the names off show are filtered
local BACKGROUND_SECONDS = 5 -- between those filter calls
local BACKGROUND_LIMIT = 50 -- names off show filtered per session; the rest show the catalog name until renamed

type Shown = {
	raw: string, -- the saved name this text was filtered from
	text: string?, -- nil when the display filter failed: show the catalog name
}

local shown: { [Player]: { [string]: Shown } } = {}
local lastRenameAt: { [Player]: number } = {}
local queued: { [Player]: { Types.CatInstance } } = {} -- cats on show waiting for a filter, in the order asked
local draining: { [Player]: boolean } = {}

-- The broadcast-filtered text of `raw` as written by `player`, or nil when filtering failed.
local function broadcastText(player: Player, raw: string): string?
	local ok, result = pcall(function(): string
		local filtered = TextService:FilterStringAsync(raw, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	return nil
end

local function shownFor(player: Player): { [string]: Shown }
	local mine = shown[player]
	if mine == nil then
		mine = {}
		shown[player] = mine
	end
	return mine :: { [string]: Shown }
end

-- True once the player has left (or never loaded), so nothing is cached for them again.
local function gone(player: Player): boolean
	return player.Parent == nil or DataService.get(player) == nil
end

local function filtered(player: Player, instance: Types.CatInstance): boolean
	local mine = shown[player]
	local entry = if mine ~= nil then mine[instance.uid] else nil
	return entry ~= nil and entry.raw == instance.name
end

-- Filters one cat's saved name for display; false when nothing changed (unnamed, done, renamed or left meanwhile).
local function filterOne(player: Player, instance: Types.CatInstance): boolean
	local raw = instance.name
	if raw == nil or filtered(player, instance) or gone(player) then
		return false
	end
	local text = broadcastText(player, raw)
	if gone(player) or instance.name ~= raw or filtered(player, instance) then
		return false
	end
	shownFor(player)[instance.uid] = { raw = raw, text = text }
	return true
end

local function drain(player: Player)
	draining[player] = true
	local changed = false
	while true do
		local list = queued[player]
		local instance = if list ~= nil then table.remove(list, 1) else nil
		if instance == nil then
			break
		end
		if filterOne(player, instance) then
			changed = true
		end
	end
	draining[player] = nil
	queued[player] = nil
	if changed and not gone(player) then
		NameService.changed:Fire(player)
	end
end

-- The filtered name to show for this cat, or nil for its catalog name (unnamed, not filtered yet, or failed).
function NameService.displayName(player: Player, instance: Types.CatInstance): string?
	local mine = shown[player]
	local entry = if mine ~= nil then mine[instance.uid] else nil
	if instance.name == nil or entry == nil or entry.raw ~= instance.name then
		return nil
	end
	return entry.text
end

-- CafeService asks for every cat model it shows: a named cat not filtered this session is filtered soon, in order,
-- then one refresh puts the names up.
function NameService.request(player: Player, instance: Types.CatInstance)
	if instance.name == nil or filtered(player, instance) or gone(player) then
		return
	end
	local list = queued[player] or {}
	queued[player] = list
	if table.find(list, instance) == nil then
		table.insert(list, instance)
	end
	if not draining[player] then
		task.spawn(drain, player)
	end
end

-- After a join settles: the named cats nobody sees in the plot, for the owner's cat room, one at a time.
local function filterTheRest(player: Player, profile: Types.PlayerProfile)
	task.wait(BACKGROUND_DELAY)
	local done = 0
	for _, instance in profile.cats do
		if done >= BACKGROUND_LIMIT or DataService.get(player) ~= profile then
			return
		end
		if instance.name ~= nil and not filtered(player, instance) then
			done += 1
			if filterOne(player, instance) and DataService.get(player) == profile then
				NameService.changed:Fire(player)
			end
			task.wait(BACKGROUND_SECONDS)
		end
	end
end

local function rename(player: Player, rawUid: unknown, rawName: unknown)
	local uid = Guard.id(rawUid)
	local profile = DataService.get(player)
	if uid == nil or profile == nil then
		return
	end
	local instance = profile.cats[uid]
	if instance == nil then
		return
	end
	local name, reason = CatName.validate(rawName)
	if name == nil then
		Net.toast(player, reason or "That name can't be used", "warn")
		return
	end
	local now = os.clock()
	local last = lastRenameAt[player]
	if last ~= nil and now - last < Config.RenameCooldownSeconds then
		Net.toast(player, "Wait a moment before renaming again", "warn")
		return
	end
	lastRenameAt[player] = now
	local text = broadcastText(player, name)
	if text == nil then
		Net.toast(player, "Couldn't check that name. Try again in a moment.", "warn")
		return
	end
	if CatName.allHashes(text) then
		Net.toast(player, "That name isn't allowed. Try another one.", "warn")
		return
	end
	-- the cat can be sold, or the player gone, while the filter runs
	if DataService.get(player) ~= profile or profile.cats[uid] ~= instance then
		return
	end
	instance.name = name
	shownFor(player)[uid] = { raw = name, text = text }
	Net.toast(player, "Renamed to " .. text, "good")
	NameService.changed:Fire(player)
end

function NameService.start()
	Net.on("RenameCat", rename)
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		task.spawn(filterTheRest, player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player)
		shown[player] = nil
		lastRenameAt[player] = nil
		queued[player] = nil
	end)
end

-- Studio-only test hook: the RenameCat path with every check, as if `player` had sent it.
function NameService.debugRename(player: Player, uid: string, name: string)
	assert(RunService:IsStudio(), "debugRename is Studio only")
	rename(player, uid, name)
end

return NameService
