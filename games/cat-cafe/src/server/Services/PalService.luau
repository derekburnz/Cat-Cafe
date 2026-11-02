--!strict
-- Pals (F92, playing-together.md sections 1, 2 and 6; shared/Pals). Each player's pals on this server, worked out
-- each session and never saved: a link between two players is the first of
--   "invite"  one joined through the other's invite (Roblox's ReferredByPlayerId, else the invite's LaunchData
--             "pal:<userId>", Pals.inviterOf),
--   "follow"  one followed the other in (Player.FollowUserId),
--   "private" both are in a private server (invite only, so everyone there),
--   "friend"  Roblox friends (IsFriendsWith, asked once per pair at the later join, in a pcall),
-- and links go both ways. When a player's pal count changes, `changed(player, count)` fires (CafeService settles at
-- the old count, sets Economy.setPals and syncs) and the player gets PalsChanged(userIds) for the HUD chip.
-- pal_time (value the minutes with at least one pal; how the first pal was linked, tier) goes out on leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(script.Parent.Net)
local Pals = require(ReplicatedStorage.Shared.Pals)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Telemetry = require(script.Parent.Telemetry)

local PalService = {}

PalService.changed = Signal.new() :: Signal.Signal<Player, number>

type PalTime = { since: number?, seconds: number, first: Pals.Link? }

local links: { [Player]: { [Player]: Pals.Link } } = {}
local inviters: { [Player]: number } = {} -- who invited each player, from their join data
local sentCount: { [Player]: number } = {}
local palTime: { [Player]: PalTime } = {}

local function isPrivateServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

-- The inviter's user id from the player's join: Roblox's own referral first, then the invite's launch data.
local function inviterOf(player: Player): number?
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(data) ~= "table" then
		return nil
	end
	local referred = (data :: any).ReferredByPlayerId
	if type(referred) == "number" and referred > 0 then
		return referred
	end
	return Pals.inviterOf((data :: any).LaunchData)
end

-- The link between two players on this server, or nil for strangers. May yield (IsFriendsWith).
local function linkBetween(a: Player, b: Player): Pals.Link?
	if inviters[a] == b.UserId or inviters[b] == a.UserId then
		return "invite"
	end
	if a.FollowUserId == b.UserId or b.FollowUserId == a.UserId then
		return "follow"
	end
	if isPrivateServer() then
		return "private"
	end
	local ok, friends = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	if ok and friends == true then
		return "friend"
	end
	return nil
end

-- The player's pals' user ids, in no order.
function PalService.palIds(player: Player): { number }
	local ids: { number } = {}
	local mine = links[player]
	if mine ~= nil then
		for other in mine do
			table.insert(ids, other.UserId)
		end
	end
	return ids
end

function PalService.count(player: Player): number
	return #PalService.palIds(player)
end

-- Starts or stops the player's pal clock for pal_time and remembers how the first pal was linked.
local function clock(player: Player, count: number)
	local time = palTime[player]
	if time == nil then
		return
	end
	if count > 0 and time.since == nil then
		time.since = os.clock()
		local mine = links[player]
		if time.first == nil and mine ~= nil then
			for _, how in mine do
				time.first = how :: Pals.Link
				break
			end
		end
	elseif count == 0 and time.since ~= nil then
		time.seconds += os.clock() - (time.since :: number)
		time.since = nil
	end
end

local function recount(player: Player)
	if links[player] == nil then
		return
	end
	local ids = PalService.palIds(player)
	local count = #ids
	clock(player, count)
	if count ~= (sentCount[player] or 0) then
		sentCount[player] = count
		PalService.changed:Fire(player, count)
	end
	Net.fire(player, "PalsChanged", ids)
end

local function link(a: Player, b: Player, how: Pals.Link)
	local ofA, ofB = links[a], links[b]
	if ofA == nil or ofB == nil or ofA[b] ~= nil then
		return
	end
	ofA[b], ofB[a] = how, how
	recount(a)
	recount(b)
end

local function onPlayerAdded(player: Player)
	links[player] = {}
	palTime[player] = { seconds = 0 }
	local inviter = inviterOf(player)
	if inviter ~= nil then
		inviters[player] = inviter
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local how = linkBetween(player, other)
				-- either may have left while IsFriendsWith was out
				if how ~= nil and player.Parent ~= nil and other.Parent ~= nil then
					link(player, other, how :: Pals.Link)
				end
			end)
		end
	end
end

local function onPlayerRemoving(player: Player)
	local mine = links[player]
	links[player] = nil
	inviters[player] = nil
	sentCount[player] = nil
	if mine ~= nil then
		for other in mine do
			local theirs = links[other]
			if theirs ~= nil then
				theirs[player] = nil
				recount(other)
			end
		end
	end
	local time = palTime[player]
	palTime[player] = nil
	if time ~= nil then
		local seconds = time.seconds
			+ (if time.since ~= nil then os.clock() - (time.since :: number) else 0)
		if seconds > 0 then
			local profile = DataService.get(player)
			local tier = if profile ~= nil then Economy.tier(profile) else 0
			local fields: { string } = { time.first or "friend", tostring(tier) }
			Telemetry.custom(player, "pal_time", math.ceil(seconds / 60), fields)
		end
	end
end

function PalService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		if links[player] == nil then
			onPlayerAdded(player)
		end
	end
end

return PalService
