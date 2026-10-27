--!strict
-- Shove, a Tackle since v0.11 (data-model section 10c: the F29 carry bumps as v0.5 F41, v0.5.1 and v0.11 F74). The
-- Tackle() remote: a press is checked by Shove.tackleRefusal and, when it is not refused, starts the
-- TackleCooldownSeconds cooldown (hit or miss, never refunded) and a hit window of the lunge plus
-- TackleHitGraceSeconds. Every frame of the window the server looks for the nearest player in reach (Shove.inReach,
-- from the tackler's root as the server sees it) who could be shoved (Shove.targetRefusal); the first one is hit as a
-- landed shove: ShoveResult to every client, where the target's client pushes its own character ShoveKnockbackStuds
-- along the direction (characters are client-owned) and every client fires Moments.Shove, then BumpLoose or
-- BumpHeld; the carried cat is CatService's (tryKnockLoose). No hit by the window's end is a miss: TackleMissAt on
-- the tackler and ShoveResult "miss" to them alone. The tackler's own client moves its character for the lunge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Shove = require(ReplicatedStorage.Shared.Shove)
local Telemetry = require(script.Parent.Telemetry)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local ShoveService = {}

local lastTackleAt: { [Player]: number } = {} -- server time of each tackler's last press that was not refused
local lastShoveOf: { [Player]: { [number]: number } } = {} -- tackler -> target UserId -> server time of the hit
local lastShovedAt: { [number]: number } = {} -- target UserId -> server time anyone last hit them (S45)

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

local function since(at: number?, now: number): number?
	return if at ~= nil then now - at else nil
end

local function areaAt(position: Vector3): string?
	return WorldBuilder.areaAt(PlotService.world(), position)
end

-- Why the lunge passes through `target` standing at `position`, or nil when it would hit them.
local function targetRefusal(
	player: Player,
	target: Player,
	areaId: string,
	position: Vector3,
	now: number
): string?
	local plot = PlotService.get(target)
	return Shove.targetRefusal({
		self = target == player,
		sameArea = areaAt(position) == areaId,
		targetBusy = CatService.inMinigame(target),
		targetSafe = plot ~= nil
			and WorldBuilder.inSafeZone(plot, position, Config.BumpSafeRadiusStuds),
		sinceShoveTarget = since((lastShoveOf[player] or {})[target.UserId], now),
		sinceTargetShoved = since(lastShovedAt[target.UserId], now),
	})
end

-- The nearest player the lunge hits with the tackler at `at`, and where they stand, or nil.
local function firstHit(
	player: Player,
	areaId: string,
	start: Vector3,
	facing: Vector3,
	at: Vector3,
	now: number
): (Player?, Vector3?)
	local best: Player? = nil
	local bestAt: Vector3? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		local root = if other ~= player then rootOf(other) else nil
		if root == nil then
			continue
		end
		local position = root.Position
		local distance = (position - at).Magnitude
		if
			distance < bestDistance
			and Shove.inReach(start, facing, at, position)
			and targetRefusal(player, other, areaId, position, now) == nil
		then
			best, bestAt, bestDistance = other, position, distance
		end
	end
	return best, bestAt
end

-- A landed tackle: everything a landed shove did (v0.11 changes none of it).
local function land(
	player: Player,
	target: Player,
	areaId: string,
	from: Vector3,
	position: Vector3,
	facing: Vector3,
	forced: Shove.KnockResult?
)
	local now = serverNow()
	local mine = lastShoveOf[player] or {}
	mine[target.UserId] = now
	lastShoveOf[player] = mine
	lastShovedAt[target.UserId] = now
	-- Display only, for Effects' puff, skid and dizzy stars (effects README hook 9) and the target's fall
	local character = target.Character
	if character ~= nil then
		character:SetAttribute("ShovedAt", now)
		character:SetAttribute("ShovedBy", player.UserId)
	end

	local carriedId = CafeService.carrying(target)
	local carried = if carriedId ~= nil then Catalog.getCat(carriedId) else nil
	local rarity: string = if carried ~= nil then carried.rarity else "none"
	local knock = CatService.tryKnockLoose(target, player.UserId, areaId, forced)
	local profile = DataService.get(player)
	if profile ~= nil then
		profile.stats.bumpsLanded += 1
	end
	local targetProfile = DataService.get(target)
	if targetProfile ~= nil then
		targetProfile.stats.bumpsTaken += 1
	end
	Telemetry.custom(player, "shove", 1, { knock or "shove", rarity, areaId })
	if knock == "loose" then
		Telemetry.knockedLoose(target, rarity)
		-- v0.8 F56: anyone picks the cat up, and the old carrier can tackle back once that carry is 3 s old
		Net.toast(player, "It dropped! Pick it up quick!", "good")
		Net.toast(target, "You got tackled and dropped your cat! Grab it back!", "warn")
	elseif knock == "held" then
		Net.toast(player, "It held on tight!", "info")
		Net.toast(target, "It held on tight!", "good")
	else
		Net.toast(target, "You got tackled!", "info")
	end
	local direction = Shove.direction(from, position, facing)
	Net.fireAll("ShoveResult", knock or "shove", player.UserId, target.UserId, position, direction)
end

-- One press. `forced` is Studio's hook for the knock-loose roll.
local function tackle(player: Player, forced: Shove.KnockResult?)
	local profile = DataService.get(player)
	if profile == nil or not Config.BumpEnabled then
		return
	end
	local now = serverNow()
	local root = rootOf(player)
	-- the catching area the tackler stands in, "" outside every area
	local tackleArea: string = if root ~= nil then areaAt(root.Position) or "" else ""
	local area = Catalog.getArea(tackleArea)
	local reason = Shove.tackleRefusal({
		carrying = CatService.isCarrying(player),
		busy = CatService.inMinigame(player),
		area = if tackleArea ~= "" then tackleArea else nil,
		areaUnlocked = area ~= nil and Economy.tier(profile) >= area.tier,
		areasClosed = not ClockService.areasOpen(),
		sinceTackle = since(lastTackleAt[player], now),
	})
	if reason ~= nil or root == nil then
		-- a refusal spends nothing; the button is hidden or greyed in these states anyway
		Net.toast(player, reason or "You can only tackle inside a catching area", "warn")
		Net.fire(player, "ShoveResult", "refused", player.UserId, 0, nil, nil)
		return
	end
	lastTackleAt[player] = now
	profile.stats.bumpsGiven += 1
	local character = player.Character
	if character ~= nil then
		character:SetAttribute("TackleAt", now) -- display only: the lunge pose and dust on every screen
	end
	local start = root.Position
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local facing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local endsAt = now + Shove.window()

	task.spawn(function()
		local at = start
		while player.Parent == Players do
			local current = rootOf(player)
			if current == nil then
				break
			end
			at = current.Position
			local hitNow = serverNow()
			local target, position = firstHit(player, tackleArea, start, facing, at, hitNow)
			if target ~= nil and position ~= nil then
				land(player, target, tackleArea, at, position, facing, forced)
				return
			end
			if hitNow >= endsAt then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if player.Parent ~= Players then
			return
		end
		local missAt = serverNow()
		local tackler = player.Character
		if tackler ~= nil then
			tackler:SetAttribute("TackleMissAt", missAt) -- display only: the belly slide and the get up
		end
		Telemetry.custom(player, "shove", 1, { "miss", "none", tackleArea })
		Net.fire(player, "ShoveResult", "miss", player.UserId, 0, at, facing)
	end)
end

local function onTackle(player: Player)
	tackle(player, nil)
end

function ShoveService.start()
	Net.on("Tackle", onTackle)
	Players.PlayerRemoving:Connect(function(player)
		lastTackleAt[player] = nil
		lastShoveOf[player] = nil
		-- lastShovedAt stays by UserId: a rejoin does not lift the few seconds of immunity early or late
	end)
end

-- Studio-only test hook: `player` presses Tackle with every check, the knock-loose roll forced to `forced` when
-- given. Face the target first.
function ShoveService.debugTackle(player: Player, forced: Shove.KnockResult?)
	assert(RunService:IsStudio(), "debugTackle is Studio only")
	tackle(player, forced)
end

return ShoveService
