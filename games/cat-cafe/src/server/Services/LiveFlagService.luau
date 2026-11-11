--!strict
-- Reads the live switches (shared/LiveFlags, #2119) from the CatCafe_Flags DataStore every LiveFlags.CHECK_SECONDS
-- and answers `on(key)` for the services that check them. Studio playtests read the _dev store, and without "Enable
-- Studio Access to API Services" (DataService.saves() false) nothing is read and the switches keep LiveFlags.defaults()
-- (every feature on but tradeFish, #2745); Debug.flag sets a switch in this server only. A read that fails keeps what
-- this server had and is warned once until reads work again.
--
-- Roblox terms: a DataStore keeps values by key across servers; GetAsync with UseCache false skips the 4 second
-- read cache, so a change is seen at the next check.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)

local LiveFlagService = {}

local SUFFIX = if RunService:IsStudio() then "_dev" else ""

local current: LiveFlags.Flags = LiveFlags.defaults()
local overrides: { [string]: boolean } = {} -- Studio only (Debug.flag)
local failing = false

-- Whether feature `key` (one of LiveFlags.KEYS) is on in this server.
function LiveFlagService.on(key: string): boolean
	local override = overrides[key]
	if override ~= nil then
		return override
	end
	return current[key] ~= false
end

-- #3063: each switch as a ReplicatedStorage attribute (LiveFlags.ATTRIBUTE_PREFIX .. key), for the client's own
-- show and hide (the Market's Swift Paws row); the server always asks `on`.
local function publish()
	for _, key in LiveFlags.KEYS do
		ReplicatedStorage:SetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key, LiveFlagService.on(key))
	end
end

local function live(): boolean
	return not RunService:IsStudio() or DataService.saves()
end

local function read()
	if not live() then
		return
	end
	local ok, raw = pcall(function()
		local store = DataStoreService:GetDataStore(LiveFlags.STORE .. SUFFIX)
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false
		local values: { [string]: any } = {}
		for _, key in LiveFlags.KEYS do
			values[key] = store:GetAsync(key, options)
		end
		return values
	end)
	if not ok then
		if not failing then
			failing = true
			-- only the message's start: DataStore errors can carry ids, and logs are public
			warn(
				"[LiveFlagService] reading CatCafe_Flags failed, keeping the switches as they were"
			)
		end
		return
	end
	failing = false
	local new = LiveFlags.parse(raw)
	for _, key in LiveFlags.changed(current, new) do
		print(
			string.format("[LiveFlagService] %s is now %s", key, if new[key] then "on" else "off")
		)
	end
	current = new
	publish()
end

function LiveFlagService.start()
	publish()
	task.spawn(function()
		while true do
			read()
			task.wait(LiveFlags.CHECK_SECONDS)
		end
	end)
end

-- Studio only (Debug.flag): switch `key` in this server, over the store (nil goes back to it). Returns whether it is on.
function LiveFlagService.debugSet(key: string, on: boolean?): boolean
	assert(RunService:IsStudio(), "debugSet is Studio only")
	assert(table.find(LiveFlags.KEYS, key) ~= nil, "not a live switch: " .. key)
	if on == nil then
		overrides[key] = nil
	else
		overrides[key] = on
	end
	publish()
	return LiveFlagService.on(key)
end

return LiveFlagService
