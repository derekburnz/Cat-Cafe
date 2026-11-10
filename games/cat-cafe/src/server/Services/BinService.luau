--!strict
-- The Rummage Bin on the server (#3050; the rules are shared/RummageBin). Its bar runs on the rescue remotes under
-- the spot id RummageBin.SPOT: RescueService hands that id's RescueBegin, RescuePress and RescueCancel here
-- (RescueService.addBar), so no new remote and the same rate limits. Begin checks the `alleyBin` switch, that the
-- player stands at the bin, is in no catch, rescue or flight, that their bin is full (save.bin.nextAt) and that their
-- last miss is BinMissRetrySeconds old, then sends the bar as RescueChallenge. Each press is judged as a rescue's
-- (Rescue.pressBar, the press's own time kept within half the ping). A win rolls the prize here, pays it
-- (Payout.pay), starts the wait and ends the bar with RescueResult's last argument, the win ({ id, first }), which
-- the bar shows as its closing words: no toast (#3080). A miss, Give up, walking away, dying or leaving costs nothing.
-- The player's BinNextAt attribute carries the save's nextAt, so each client words its own prompt ("Rummage" or
-- "Empty for now 🐾", never a countdown) and shows the bin's full or empty look. Logs bin_play (the prize row, the
-- win's number) and, on an account's first win, step_time "first_bin". Nothing here is sold.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Config = require(ReplicatedStorage.Shared.Config)
local Cooldown = require(ReplicatedStorage.Shared.Cooldown)
local DataService = require(script.Parent.DataService)
local Layout = require(script.Parent.Parent.World.Layout)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Rescue = require(ReplicatedStorage.Shared.Rescue)
local RescueService = require(script.Parent.RescueService)
local RummageBin = require(ReplicatedStorage.Shared.RummageBin)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local BinService = {}

local RANGE_SLACK = 4 -- studs past the prompt's reach, for a character the server sees a moment late
local LEAVE_RANGE_STUDS = 16 -- further than this from the bin ends the bar, as a rescue's
local FLAG_SECONDS = 5

type Run = { attempt: Rescue.Attempt }

local runs: { [Player]: Run } = {}
local retryAt: { [Player]: number } = {} -- server time each player may try again after a miss
local rng = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function binModel(): Model?
	for _, instance in CollectionService:GetTagged(RummageBin.TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			return instance :: Model
		end
	end
	return nil
end

-- Where the bin's prompt is: the placed model's PromptAnchor, else its Layout spot.
local function anchor(): Vector3?
	local model = binModel()
	if model ~= nil then
		local found = model:FindFirstChild("PromptAnchor", true)
		if found ~= nil and found:IsA("Attachment") then
			return (found :: Attachment).WorldPosition
		end
		return model:GetPivot().Position
	end
	local x, y, z = Layout.rummageBinAt()
	if x ~= nil and y ~= nil and z ~= nil then
		return Vector3.new(x, y + 1.5, z)
	end
	return nil
end

local function distance(player: Player): number?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local at = anchor()
	if root == nil or not root:IsA("BasePart") or at == nil then
		return nil
	end
	return ((root :: BasePart).Position - at).Magnitude
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0
end

local function publish(player: Player, profile: Types.PlayerProfile)
	player:SetAttribute(RummageBin.NEXT_AT_ATTRIBUTE, profile.bin.nextAt)
end

local function send(player: Player, attempt: Rescue.Attempt, win: Types.RummageWin?)
	local done = attempt.stage == "done"
	Net.fire(
		player,
		"RescueResult",
		RummageBin.SPOT,
		attempt.hits,
		attempt.paws,
		done,
		done and attempt.success,
		Rescue.barState(attempt),
		win
	)
end

-- Ends the player's bar. A win pays one prize and starts the wait; anything else costs nothing and starts the short
-- retry wait. `reason` is a toast for an end the bar does not show (walking away).
local function finish(player: Player, run: Run, reason: string?)
	if runs[player] ~= run then
		return -- already finished
	end
	runs[player] = nil
	local attempt = run.attempt
	if attempt.stage ~= "done" then
		Rescue.abandon(attempt)
	end
	local profile = DataService.get(player)
	local present = player.Parent == Players and profile ~= nil
	local now = os.time()
	-- the wait cannot have started since Begin, but a win is never paid on a bin that is not full
	local won = attempt.success
		and profile ~= nil
		and present
		and RummageBin.ready(profile.bin, now)
	attempt.success = won
	local win: Types.RummageWin? = nil
	if won and profile ~= nil then
		local first = profile.bin.uses == 0
		local row = RummageBin.win(profile.bin, now, rng:NextNumber())
		Payout.pay(player, profile, RummageBin.prize(row), "rummage_bin")
		Telemetry.custom(
			player,
			"bin_play",
			1,
			{ row.id, tostring(math.min(profile.bin.uses, 10)) }
		)
		if first then
			Telemetry.stepTime(player, profile, "first_bin")
		end
		win = { id = row.id, first = first }
		publish(player, profile)
		CafeService.sync(player)
	elseif present then
		retryAt[player] = serverNow() + Config.BinMissRetrySeconds
	end
	if present then
		send(player, attempt, win)
		if reason ~= nil then
			Net.toast(player, reason, "warn")
		end
	end
end

-- Watches a bar until it ends: its deadline, the player leaving, dying or walking away from the bin.
local function watch(player: Player, run: Run)
	task.spawn(function()
		while runs[player] == run do
			task.wait(0.2)
			if runs[player] ~= run then
				return
			end
			if Rescue.expire(run.attempt, serverNow()) then
				finish(player, run, nil) -- out of time: the bar shows it on its own clock
				return
			end
			if player.Parent ~= Players or not alive(player) then
				finish(player, run, nil)
				return
			end
			local away = distance(player)
			if away == nil or away > LEAVE_RANGE_STUDS then
				finish(player, run, "You walked away from the bin")
				return
			end
		end
	end)
end

local function begin(player: Player)
	local profile = DataService.get(player)
	if profile == nil or runs[player] ~= nil then
		return
	end
	if
		not LiveFlagService.on(RummageBin.FLAG)
		or not alive(player)
		or CatService.inFlight(player)
	then
		return
	end
	if CatService.inCatch(player) then
		Net.toast(player, "Finish this catch first", "warn")
		return
	end
	local away = distance(player)
	if away == nil or away > RummageBin.RANGE_STUDS + RANGE_SLACK then
		Net.toast(player, "Walk up to the Rummage Bin first", "warn")
		return
	end
	if not RummageBin.ready(profile.bin, os.time()) then
		publish(player, profile) -- the prompt already reads "Empty for now"
		return
	end
	local now = serverNow()
	local retry = retryAt[player]
	if retry ~= nil and now < retry then
		Net.toast(player, Cooldown.text(retry - now), "warn")
		return
	end
	local challenge = RummageBin.challenge(RummageBin.early(profile.bin), now, function()
		return rng:NextNumber()
	end)
	local run: Run = { attempt = RummageBin.attempt(challenge) }
	runs[player] = run
	Net.fire(player, "RescueChallenge", RummageBin.SPOT, challenge)
	watch(player, run)
end

local function press(player: Player, rawPressedAt: unknown)
	local run = runs[player]
	if run == nil then
		return
	end
	local attempt = run.attempt
	local arrival = serverNow()
	local pressTime = Rescue.pressedAt(arrival, player:GetNetworkPing(), rawPressedAt)
	local result = Rescue.pressBar(attempt, pressTime, false)
	if result == "ignored" then
		-- too early, or arriving after the deadline: end it now rather than at the next watch tick
		if attempt.stage == "done" or Rescue.expire(attempt, arrival) then
			finish(player, run, nil)
		end
		return
	end
	if attempt.stage == "done" then
		finish(player, run, nil)
	else
		send(player, attempt, nil)
	end
end

local function cancel(player: Player)
	local run = runs[player]
	if run ~= nil then
		finish(player, run, nil)
	end
end

-- True while the player's bin bar runs: no catch, rescue or fast travel starts then (RescueService's check).
function BinService.busy(player: Player): boolean
	return runs[player] ~= nil
end

function BinService.start()
	RescueService.addBar(RummageBin.SPOT, {
		begin = begin,
		press = press,
		cancel = cancel,
		busy = BinService.busy,
	})
	DataService.onLoaded:Connect(function(player: Player, profile: Types.PlayerProfile)
		publish(player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run ~= nil then
			finish(player, run, nil)
		end
		retryAt[player] = nil
	end)
	-- the `alleyBin` switch: off hides the prompt for everyone within FLAG_SECONDS of the flag's read
	task.spawn(function()
		while true do
			local model = binModel()
			local prompt = if model ~= nil
				then model:FindFirstChild(RummageBin.PROMPT, true)
				else nil
			if prompt ~= nil and prompt:IsA("ProximityPrompt") then
				local found = prompt :: ProximityPrompt
				local on = LiveFlagService.on(RummageBin.FLAG)
				if found.Enabled ~= on then
					found.Enabled = on
				end
			end
			task.wait(FLAG_SECONDS)
		end
	end)
end

-- Studio-only test hooks (Debug.bin). "ready" fills the player's bin now; "reset" also forgets its wins, so the two
-- fixed first prizes come again. Returns the save.
function BinService.debugSet(player: Player, how: string): Types.RummageBinSave?
	assert(RunService:IsStudio(), "debugSet is Studio only")
	local profile = DataService.get(player)
	if profile == nil then
		return nil
	end
	profile.bin.nextAt = 0
	if how == "reset" then
		profile.bin.uses = 0
	end
	retryAt[player] = nil
	publish(player, profile)
	return profile.bin
end

-- Studio-only test hook: a press on `player`'s running bin bar that `kind` "hit" or "miss" says, judged as a real
-- press (as RescueService.debugPress). Returns "hit hits=1/2 paws=3", or why it did nothing.
function BinService.debugPress(player: Player, kind: string): string
	assert(RunService:IsStudio(), "debugPress is Studio only")
	local run = runs[player]
	if run == nil then
		return "no bin bar running"
	end
	local attempt = run.attempt
	local centre = Rescue.currentZone(attempt)
	if centre == nil then
		return "no zone left"
	end
	local now = serverNow()
	local x = if kind == "hit" then centre elseif centre > 0.5 then 0 else 1
	press(player, Rescue.lastTimeAt(attempt, x, now))
	return string.format(
		"%s hits=%d/%d paws=%d stage=%s",
		kind,
		attempt.hits,
		attempt.challenge.hitsNeeded or 0,
		attempt.paws,
		tostring(attempt.stage)
	)
end

return BinService
