--!strict
-- Player profiles: load with session locking (ProfileStore), migrate, settle income, save on leave and on shutdown.
-- Also caches PolicyService info per player once on join.
-- In Studio without "Enable Studio Access to API Services", ProfileStore runs on its mock store: the game works, nothing persists.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile
-- ProfileStore wants T & JSONAcceptable; optional fields make PlayerProfile fail that test, so the store is typed any
-- and ProfileSchema.migrate() is the one place raw data becomes a typed Profile.
type Session = {
	profile: Profile,
	store: ProfileStore.Profile<any>,
	joinedAt: number,
	pendingOffline: number,
	pendingOfflineSeconds: number,
	policy: { [string]: any }?,
}

local DataService = {}

DataService.onLoaded = Signal.new() :: Signal.Signal<Player, Profile>
DataService.onReleasing = Signal.new() :: Signal.Signal<Player, Profile>

local sessions: { [Player]: Session } = {}
local finalizers: { (player: Player, profile: Profile) -> () } = {}
-- Studio playtests get their own store, so "Enable Studio Access to API Services" never touches live profiles
-- (DataStores are per experience, not per place).
local storeName = Config.ProfileStoreName .. (if RunService:IsStudio() then "_dev" else "")
local store: ProfileStore.ProfileStore<any> =
	ProfileStore.New(storeName, ProfileSchema.template(os.time()) :: any)

local function key(player: Player): string
	return Config.ProfileKeyPrefix .. player.UserId
end

local function finalize(player: Player, session: Session)
	local profile = session.profile
	local now = os.time()
	for _, fn in finalizers do
		local ok, err = pcall(function()
			fn(player, profile)
			return nil :: any
		end)
		if not ok then
			warn("[DataService] finalizer failed:", err)
		end
	end
	Economy.settle(profile, now)
	if session.pendingOffline > 0 then
		-- Offline earnings the player never claimed (popup dismissed, left early) are credited, not lost.
		Economy.credit(profile, session.pendingOffline)
		session.pendingOffline = 0
		session.pendingOfflineSeconds = 0
	end
	profile.rateAtLogout = Economy.incomePerSecond(profile)
	profile.lastSeen = now
	profile.stats.playtimeSeconds += math.max(0, now - session.joinedAt)
	session.store.Data = profile :: any
end

local function load(player: Player)
	local profileStore = store:StartSessionAsync(key(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profileStore == nil then
		player:Kick("Your data is still saving from another server. Please rejoin in a minute.")
		return
	end
	profileStore:AddUserId(player.UserId)

	local now = os.time()
	local profile = ProfileSchema.migrate(profileStore.Data, now)
	local offline, offlineSeconds = Economy.offlineGain(profile.rateAtLogout, profile.lastSeen, now)
	profile.lastTick = now -- never credit the offline gap at the online rate
	profile.stats.sessions += 1
	profileStore.Data = profile :: any

	local session: Session = {
		profile = profile,
		store = profileStore,
		joinedAt = now,
		pendingOffline = offline,
		pendingOfflineSeconds = offlineSeconds,
		policy = nil,
	}

	profileStore.OnSessionEnd:Connect(function()
		sessions[player] = nil
		if player.Parent == Players then
			player:Kick("Your data session ended. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profileStore:EndSession()
		return
	end
	sessions[player] = session

	task.spawn(function()
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and type(info) == "table" then
			session.policy = info
		else
			warn("[DataService] PolicyService lookup failed for", player.UserId, info)
		end
	end)

	DataService.onLoaded:Fire(player, profile)
end

local function release(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	-- Finalizers (for example saving a carried cat) run while DataService.get still answers for this player;
	-- the session is forgotten only after the profile is final.
	DataService.onReleasing:Fire(player, session.profile)
	local ok, err = pcall(function()
		finalize(player, session)
		return nil :: any
	end)
	if not ok then
		warn("[DataService] finalize failed:", err)
	end
	sessions[player] = nil
	session.store:EndSession()
end

function DataService.start()
	-- ProfileStore autosaves every 300 s by default; the design (section 17) wants 60 s.
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Config.AutosaveSeconds)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(release)

	game:BindToClose(function()
		if RunService:IsStudio() and ProfileStore.DataStoreState ~= "Access" then
			return
		end
		for player in sessions do
			release(player)
		end
	end)

	ProfileStore.OnError:Connect(function(message, storeName, profileKey)
		warn(
			string.format(
				"[DataService] ProfileStore error (%s / %s): %s",
				storeName,
				profileKey,
				message
			)
		)
	end)
end

function DataService.get(player: Player): Profile?
	local session = sessions[player]
	return if session ~= nil then session.profile else nil
end

-- Register work to run on the profile right before it is saved on leave or shutdown (e.g. save a carried cat).
function DataService.beforeRelease(fn: (player: Player, profile: Profile) -> ())
	table.insert(finalizers, fn)
end

function DataService.takePendingOffline(player: Player): (number, number)
	local session = sessions[player]
	if session == nil then
		return 0, 0
	end
	local amount, seconds = session.pendingOffline, session.pendingOfflineSeconds
	session.pendingOffline = 0
	session.pendingOfflineSeconds = 0
	return amount, seconds
end

function DataService.peekPendingOffline(player: Player): (number, number)
	local session = sessions[player]
	if session == nil then
		return 0, 0
	end
	return session.pendingOffline, session.pendingOfflineSeconds
end

function DataService.policy(player: Player): { [string]: any }?
	local session = sessions[player]
	return if session ~= nil then session.policy else nil
end

-- True when saves really reach the DataStore (false in Studio without API access).
function DataService.saves(): boolean
	return ProfileStore.DataStoreState == "Access"
end

function DataService.loadedPlayers(): { Player }
	local list: { Player } = {}
	for player in sessions do
		table.insert(list, player)
	end
	return list
end

return DataService
