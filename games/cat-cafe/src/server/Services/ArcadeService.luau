--!strict
-- The Cat Arcade on the server (#3062; the rules are shared/Arcade). #4656 (Derek OK'd 2026-11-15): Circle Streak,
-- vaulted since #3296, is gone for good; Mouse Dash (MouseDashService) is the arcade's game. What stays here is the
-- arcade's own save (best, today's milestones, the Arcade Legend title), the milestone payouts, the leaderboard, the
-- cabinet's sign and the arcade_v1 funnel's first steps. The rest of this note is the removed game's, for history:
-- ArcadeStart checked the `arcade` switch, that the
-- player's arcade save is read, that no game is running, that they are in no catch, rescue or flight
-- (CatService.busyReason) and have no trade fish freeze (TradeService.fishSpendBlocker), then uses today's free run
-- (#3296) or spends ArcadeCostFish golden fish and sends the first block of circles (ArcadeBlock). Every press (ArcadePress) is stamped on arrival,
-- half the ping taken off, and judged by Circles.press with the arcade's windows, exactly as a catch's; a circle left
-- alone is a Miss at its deadline. Each judged circle goes back as ArcadeJudged with the points and any milestone it
-- paid (Payout.pay, once per UTC day each; shown in the window only, no toast, #3080). A block played through brings
-- the next at the step its points reached; the first Miss, 100 points, Close (ArcadeQuit), leaving or dying ends the
-- game with ArcadeOver. There is no arcade-specific bot check (Derek2 2026-11-10: "not worried about bots yet").
-- Each player's best, today's milestones and the Arcade Legend title live in their own DataStore, STORE (key: the
-- user id), not in the save, so the arcade needed no save version step and no restart (Derek2 2026-11-11). They are
-- read when the player joins (no game starts until the read answers) and written after each milestone and game, at
-- most once every WRITE_GAP seconds. The server's best is kept in memory and shown on the cabinet's prompt; an owner
-- account's games never set it (#3321).

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arcade = require(ReplicatedStorage.Shared.Arcade)
local ArcadeBoard = require(script.Parent.ArcadeBoard)
local ArcadeFunnel = require(ReplicatedStorage.Shared.ArcadeFunnel)
local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local LiveFlagService = require(script.Parent.LiveFlagService)
local MouseDash = require(ReplicatedStorage.Shared.MouseDash)
local Net = require(script.Parent.Net)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local ArcadeService = {}

local STORE = "CatCafe_Arcade" .. (if RunService:IsStudio() then "_dev" else "")
local READ_WAITS = { 2, 5, 15, 60 } -- seconds before each further try at a join's read
local WRITE_WAITS = { 2, 5, 15 } -- and at a write
local WRITE_GAP = 7 -- seconds between two writes of one key (a DataStore key takes one write per 6 s)
local saves: { [Player]: Arcade.Save } = {}
local pending: { [number]: Arcade.Save } = {} -- by user id: the newest save waiting for its write
local writing: { [number]: boolean } = {}
local leaving: { [number]: boolean } = {} -- a leaver's last save goes out with no WRITE_GAP wait (#3251 review)
local serverBest = { points = 0, circles = 0, name = nil :: string? } -- #4656: Circle Streak's, always 0 now (ArcadeState)
local SIGN_CHECK_SECONDS = 15

local function store(): DataStore?
	if RunService:IsStudio() and not DataService.saves() then
		return nil -- Studio with no API access: the arcade forgets at the end of the test
	end
	return DataStoreService:GetDataStore(STORE)
end

local function copy(save: Arcade.Save): Arcade.Save
	return {
		best = save.best,
		bestCircles = save.bestCircles,
		day = save.day,
		paid = table.clone(save.paid),
		legend = save.legend,
		runs = save.runs,
		freeDay = save.freeDay,
		epoch = save.epoch,
	}
end

-- Writes the player's newest save, at most once every WRITE_GAP seconds, trying again a few times. A lost write only
-- forgets a record or lets a milestone pay again on the player's next server the same day.
local function queueSave(userId: number, save: Arcade.Save)
	local where = store()
	if where == nil then
		return
	end
	pending[userId] = copy(save)
	if writing[userId] then
		return
	end
	writing[userId] = true
	task.spawn(function()
		local key = tostring(userId)
		while pending[userId] ~= nil do
			local value = pending[userId]
			pending[userId] = nil
			local ok = false
			for attempt = 1, #WRITE_WAITS + 1 do
				ok = pcall(function()
					-- #3251 review: joined with what is stored, so a late write from the player's last server can't take
					-- back a record or a paid milestone this one wrote, and the other way round
					(where :: DataStore):UpdateAsync(key, function(old: unknown)
						local now = os.time()
						return Arcade.merge(Arcade.sanitize(old, now), Arcade.sanitize(value, now))
					end)
				end)
				if ok then
					break
				end
				local wait = WRITE_WAITS[attempt]
				if wait == nil then
					break
				end
				task.wait(wait)
			end
			if not ok then
				warn("[ArcadeService] writing an arcade save failed") -- only this: DataStore errors can carry ids
			end
			local waited = 0
			while waited < WRITE_GAP and not leaving[userId] do
				waited += task.wait(0.5)
			end
		end
		writing[userId] = nil
		leaving[userId] = nil
	end)
end

-- #3338: the players here with an arcade best, at their bests now, for the leaderboard (ArcadeBoard.top)
local function present(): { Leaderboards.Present }
	local out: { Leaderboards.Present } = {}
	for player, save in saves do
		if save.best > 0 and player.Parent == Players then
			table.insert(out, {
				userId = player.UserId,
				name = player.DisplayName,
				value = Arcade.score(save.best, save.bestCircles),
			})
		end
	end
	return out
end

local function stateOf(player: Player): Arcade.State
	local save = saves[player]
	return {
		loaded = save ~= nil,
		best = if save ~= nil then save.best else 0,
		bestCircles = if save ~= nil then save.bestCircles else 0,
		today = if save ~= nil then table.clone(Arcade.today(save, os.time())) else {},
		legend = save ~= nil and save.legend,
		serverBest = serverBest.points,
		serverCircles = serverBest.circles,
		serverName = serverBest.name,
		free = save ~= nil and Arcade.freeToday(save, os.time()),
		top = ArcadeBoard.top(present(), player.UserId),
	}
end

local function sendState(player: Player)
	Net.fire(player, "ArcadeState", stateOf(player))
end

-- #3296: Mouse Dash's best in this server (MouseDashService reports each finished game), shown on the cabinet
-- while Mouse Dash is the arcade's game.
local mouseBest = { points = 0, seconds = 0, name = nil :: string? }
local shownBest: string? = nil

-- The cabinet's prompt carries Mouse Dash's server best: "Cat Arcade · Mouse Dash · Best 37 (Sam)" (#4656: Circle
-- Streak's own best is gone with it).
local function showServerBest()
	local text = Arcade.NAME
	if LiveFlagService.on(MouseDash.FLAG) then
		text ..= " · " .. MouseDash.NAME
		if mouseBest.points > 0 then
			text ..= " · Best " .. MouseDash.words(mouseBest.points, mouseBest.seconds)
			if mouseBest.name ~= nil then
				text ..= " (" .. mouseBest.name .. ")"
			end
		end
	end
	shownBest = text
	for _, model in CollectionService:GetTagged(Arcade.TAG) do
		local prompt = model:FindFirstChild(Arcade.PROMPT, true)
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			(prompt :: ProximityPrompt).ObjectText = text
		end
	end
end

-- #4722 review (Sync-Agent 2026-11-16): MouseDashState carries `loaded` (Mouse Dash's save and this one), so when
-- this save comes after Mouse Dash's, MouseDashService sends its state again through this hook; before, the client kept
-- loaded=false and the cabinet's "!" stayed down for the session.
ArcadeService.onSaveLoaded = nil :: ((player: Player) -> ())?

-- Reads `player`'s arcade save when they join, trying again a few times; nothing read keeps the arcade shut for them.
local function load(player: Player)
	task.spawn(function()
		local where = store()
		if where == nil then
			saves[player] = Arcade.fresh()
			sendState(player)
			local hook = ArcadeService.onSaveLoaded
			if hook ~= nil then
				hook(player)
			end
			return
		end
		local key = tostring(player.UserId)
		for attempt = 1, #READ_WAITS + 1 do
			local ok, raw = pcall(function()
				return (where :: DataStore):GetAsync(key)
			end)
			if player.Parent ~= Players then
				return
			end
			if ok then
				local save = Arcade.sanitize(raw, os.time())
				saves[player] = save
				ArcadeBoard.note(player, save.best, save.bestCircles) -- #3338
				sendState(player)
				local hook = ArcadeService.onSaveLoaded
				if hook ~= nil then
					hook(player) -- #4722 review: Mouse Dash's state names this save as loaded
				end
				return
			end
			local wait = READ_WAITS[attempt]
			if wait == nil then
				break
			end
			task.wait(wait)
		end
		warn(
			"[ArcadeService] reading an arcade save failed; that player's arcade stays shut this visit"
		)
	end)
end

-- Pays the milestones a move from `before` to `after` points crossed that today has not paid yet. `source` is the
-- payout reason's start ("arcade" for Circle Streak, "mousedash" for Mouse Dash, #3296).
local function claimAndPay(
	player: Player,
	before: number,
	after: number,
	source: string
): { number }
	local save = saves[player]
	local profile = DataService.get(player)
	if save == nil or profile == nil then
		return {}
	end
	local due = Arcade.claim(save, before, after, os.time())
	if #due == 0 then
		return due
	end
	for _, at in due do
		local milestone = Arcade.milestoneAt(at)
		if milestone ~= nil then
			Payout.pay(player, profile, milestone.prize, source .. "_" .. tostring(at))
		end
	end
	CafeService.sync(player)
	queueSave(player.UserId, save)
	return due
end

-- #3378: arcade_v1's steps before a game (seen, opened): "free" while the day's free game is still there.
local function funnelBefore(player: Player, step: number)
	if OwnerTest.isOwner(player.UserId) then
		return
	end
	local profile = DataService.get(player)
	local save = saves[player]
	if profile == nil then
		return
	end
	Telemetry.arcadeStep(player, profile, step, save ~= nil and Arcade.freeToday(save, os.time()))
end

-- MouseDashService asks so the two games never ran at once; #4656: with Circle Streak gone, never.
function ArcadeService.running(_player: Player): boolean
	return false
end

-- #3296: Mouse Dash shares the arcade's day (the milestones paid today) and the Arcade Legend title, both kept in
-- this service's save, so nothing pays twice whichever game or server gets there first. MouseDashService still sets
-- `otherGame` (whether its game is running for a player); #4656: nothing reads it since Circle Streak is gone.
ArcadeService.otherGame = nil :: ((player: Player) -> boolean)?

-- Whether the player's arcade save is read (no milestone can be paid before it is).
function ArcadeService.loaded(player: Player): boolean
	return saves[player] ~= nil
end

-- The milestones paid today, and whether the player holds Arcade Legend.
function ArcadeService.today(player: Player): ({ number }, boolean)
	local save = saves[player]
	if save == nil then
		return {}, false
	end
	return table.clone(Arcade.today(save, os.time())), save.legend
end

-- Pays the milestones a move from `before` to `after` points crossed that today has not paid yet, as a Circle
-- Streak game's were (`source` names the game in the payout's reason). Returns those paid.
function ArcadeService.claimMilestones(
	player: Player,
	before: number,
	after: number,
	source: string
): { number }
	return claimAndPay(player, before, after, source)
end

-- Arcade Legend for a 100 point game of either arcade game, kept for good.
-- #3296: a finished Mouse Dash game, for the cabinet's sign (MouseDashService). Kept when it beats this server's
-- best so far (more points, then fewer seconds).
function ArcadeService.noteMouseDash(player: Player, points: number, seconds: number)
	if MouseDash.beats(points, seconds, mouseBest.points, mouseBest.seconds) then
		mouseBest.points = points
		mouseBest.seconds = seconds
		mouseBest.name = player.DisplayName
		showServerBest()
	end
end

function ArcadeService.grantLegend(player: Player)
	local save = saves[player]
	if save ~= nil and not save.legend then
		save.legend = true
		queueSave(player.UserId, save)
		sendState(player)
	end
end

function ArcadeService.start()
	-- #4656: ArcadeStart, ArcadePress and ArcadeQuit stay declared (old clients) with nothing listening
	DataService.onLoaded:Connect(function(player: Player, _profile: Types.PlayerProfile)
		load(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		if writing[player.UserId] then
			leaving[player.UserId] = true
		end
		saves[player] = nil
	end)
	CollectionService:GetInstanceAddedSignal(Arcade.TAG):Connect(function()
		task.defer(showServerBest)
	end)
	showServerBest()
	-- #3296: the sign follows the game switches (they change with no restart), checked with the flags' own pace
	task.spawn(function()
		while true do
			task.wait(SIGN_CHECK_SECONDS)
			local was = shownBest
			showServerBest()
			if was ~= shownBest then
				print("[ArcadeService] the cabinet's sign now reads: " .. tostring(shownBest))
			end
		end
	end)
	-- #3378: arcade_v1 step 2, the window opened by its ring or prompt (the client's StationOpened count)
	Telemetry.onStationOpen(function(player: Player, window: string)
		if window == "Arcade" then
			funnelBefore(player, ArcadeFunnel.OPENED)
		end
	end)
	-- step 1: everyone within SEEN_STUDS of a cabinet. Telemetry logs it once a day, so a look is cheap.
	task.spawn(function()
		while true do
			task.wait(ArcadeFunnel.SEEN_EVERY)
			local spots: { Vector3 } = {}
			for _, model in CollectionService:GetTagged(Arcade.TAG) do
				-- a cabinet put away (#3443) is seen by nobody
				if model:IsA("PVInstance") and model:IsDescendantOf(workspace) then
					table.insert(spots, (model :: PVInstance):GetPivot().Position)
				end
			end
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = if character ~= nil
					then character:FindFirstChild("HumanoidRootPart")
					else nil
				if root ~= nil and root:IsA("BasePart") then
					for _, at in spots do
						if
							((root :: BasePart).Position - at).Magnitude <= ArcadeFunnel.SEEN_STUDS
						then
							funnelBefore(player, ArcadeFunnel.SEEN)
							break
						end
					end
				end
			end
		end
	end)
	ArcadeBoard.start(function()
		for player in saves do
			if player.Parent == Players then
				sendState(player)
			end
		end
	end)
end

return ArcadeService
