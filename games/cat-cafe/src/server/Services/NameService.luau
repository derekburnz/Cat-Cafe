--!strict
-- Naming cats (F33, data-model section 4). RenameCat(uid, name): CatName.validate, then one TextService filter
-- with the owner's UserId; a filter error or a name filtered down to hashes is refused with a toast and the old
-- name stays. The save keeps the raw name. What anyone sees is the broadcast filter's text, cached here per cat and
-- filtered again on every join because the filter changes over time; a cat whose display filter fails shows its
-- catalog name. CafeService puts the shown name on the cat room's views and on each cat model's DisplayName.

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

local LOAD_LIMIT = 50 -- names filtered on a join, working cats first; the rest show the catalog name until renamed

type Shown = {
	raw: string, -- the saved name this text was filtered from
	text: string?, -- nil when the display filter failed: show the catalog name
}

local shown: { [Player]: { [string]: Shown } } = {}
local lastRenameAt: { [Player]: number } = {}

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

-- The filtered name to show for this cat, or nil for its catalog name (unnamed, not filtered yet, or failed).
function NameService.displayName(player: Player, instance: Types.CatInstance): string?
	local mine = shown[player]
	local entry = if mine ~= nil then mine[instance.uid] else nil
	if instance.name == nil or entry == nil or entry.raw ~= instance.name then
		return nil
	end
	return entry.text
end

-- On a join: filters every named cat again (working cats first, their names are on show), then one refresh.
local function load(player: Player, profile: Types.PlayerProfile)
	local named: { Types.CatInstance } = {}
	for _, instance in profile.cats do
		if instance.name ~= nil then
			table.insert(named, instance)
		end
	end
	if #named == 0 then
		return
	end
	table.sort(named, function(a, b)
		return a.spotId ~= nil and b.spotId == nil
	end)
	local mine = shownFor(player)
	for n = 1, math.min(#named, LOAD_LIMIT) do
		local instance = named[n]
		local raw = instance.name :: string
		local text = broadcastText(player, raw)
		if shown[player] ~= mine then
			return -- left while filtering
		end
		if instance.name == raw and mine[instance.uid] == nil then -- a rename during the load wins
			mine[instance.uid] = { raw = raw, text = text }
		end
	end
	NameService.changed:Fire(player)
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
		task.spawn(load, player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player)
		shown[player] = nil
		lastRenameAt[player] = nil
	end)
end

-- Studio-only test hook: the RenameCat path with every check, as if `player` had sent it.
function NameService.debugRename(player: Player, uid: string, name: string)
	assert(RunService:IsStudio(), "debugRename is Studio only")
	rename(player, uid, name)
end

return NameService
