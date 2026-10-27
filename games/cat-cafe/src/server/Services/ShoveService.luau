--!strict
-- Shove (data-model section 10c: the F29 carry bumps as v0.5 F41 and v0.5.1). The Bump(targetUserId) remote: the
-- checks are Shove.refusal over facts gathered here, the cooldowns and the target immunity (S45) live in this
-- service's own tables, and the carried cat is CatService's (tryKnockLoose). A landed shove goes to every client as
-- ShoveResult; the target's client pushes its own character ShoveKnockbackStuds along the direction, since
-- characters are client-owned, and every client fires Moments.Shove, then BumpLoose or BumpHeld.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local CatService = require(script.Parent.CatService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local Shove = require(ReplicatedStorage.Shared.Shove)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local ShoveService = {}

-- Studio test players have negative UserIds, so the range is symmetric; Players:GetPlayerByUserId does the rest.
local MAX_USER_ID = 2 ^ 53

local lastShoveAt: { [Player]: number } = {} -- server time of each shover's last landed shove
local lastShoveOf: { [Player]: { [number]: number } } = {} -- shover -> target UserId -> server time
local lastShovedAt: { [number]: number } = {} -- target UserId -> server time anyone last shoved them (S45)

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

-- Everything section 10c checks, or the reason this shove is refused. On success also the area and the push.
local function check(
	player: Player,
	target: Player,
	profile: Types.PlayerProfile
): (string?, string?, Vector3?, Vector3?)
	local shoverRoot, targetRoot = rootOf(player), rootOf(target)
	local world = PlotService.world()
	local shoverArea = if shoverRoot ~= nil
		then WorldBuilder.areaAt(world, shoverRoot.Position)
		else nil
	local targetArea = if targetRoot ~= nil
		then WorldBuilder.areaAt(world, targetRoot.Position)
		else nil
	local area = if shoverArea ~= nil then Catalog.getArea(shoverArea :: string) else nil
	local plot = PlotService.get(target)
	local now = serverNow()
	local reason = Shove.refusal({
		self = target == player,
		shoverCarrying = CatService.isCarrying(player),
		shoverBusy = CatService.inMinigame(player),
		shoverArea = shoverArea,
		targetArea = targetArea,
		areaUnlocked = area ~= nil and Economy.tier(profile) >= area.tier,
		distance = if shoverRoot ~= nil and targetRoot ~= nil
			then (shoverRoot.Position - targetRoot.Position).Magnitude
			else nil,
		targetBusy = CatService.inMinigame(target),
		targetSafe = targetRoot ~= nil
			and plot ~= nil
			and WorldBuilder.inSafeZone(plot, targetRoot.Position, Config.BumpSafeRadiusStuds),
		sinceShove = since(lastShoveAt[player], now),
		sinceShoveTarget = since((lastShoveOf[player] or {})[target.UserId], now),
		sinceTargetShoved = since(lastShovedAt[target.UserId], now),
	})
	if reason ~= nil or shoverRoot == nil or targetRoot == nil then
		return reason or "Too far away", nil, nil, nil
	end
	local look = shoverRoot.CFrame.LookVector
	local direction = Shove.direction(
		shoverRoot.Position,
		targetRoot.Position,
		Vector3.new(look.X, 0, look.Z).Unit
	)
	return nil, shoverArea, targetRoot.Position, direction
end

local function shove(player: Player, target: Player, forced: Shove.KnockResult?)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local reason, areaId, position, direction = check(player, target, profile)
	if reason ~= nil or areaId == nil or position == nil or direction == nil then
		Net.toast(player, reason or "Too far away", "warn")
		Net.fire(player, "ShoveResult", "refused", player.UserId, target.UserId, nil, nil)
		return
	end
	local now = serverNow()
	lastShoveAt[player] = now
	local mine = lastShoveOf[player] or {}
	mine[target.UserId] = now
	lastShoveOf[player] = mine
	lastShovedAt[target.UserId] = now
	-- Display only, for Effects' puff, skid and dizzy stars (effects README hook 9)
	local character = target.Character
	if character ~= nil then
		character:SetAttribute("ShovedAt", now)
		character:SetAttribute("ShovedBy", player.UserId)
	end

	local carriedId = CafeService.carrying(target)
	local carried = if carriedId ~= nil then Catalog.getCat(carriedId) else nil
	local rarity: string = if carried ~= nil then carried.rarity else "none"
	local knock = CatService.tryKnockLoose(target, player.UserId, areaId, direction, forced)
	profile.stats.bumpsGiven += 1
	Telemetry.custom(player, "shove", 1, { knock or "shove", rarity, areaId })
	if knock == "loose" then
		Telemetry.knockedLoose(target, rarity)
	end
	if knock == "loose" then
		profile.stats.bumpsLanded += 1
		local targetProfile = DataService.get(target)
		if targetProfile ~= nil then
			targetProfile.stats.bumpsTaken += 1
		end
		Net.toast(player, "You knocked it loose!", "good")
		Net.toast(
			target,
			string.format(
				"You got shoved! Net it back, only you can for %d seconds",
				Config.DropOwnerPrioritySeconds
			),
			"warn"
		)
	elseif knock == "held" then
		Net.toast(player, "It held on tight!", "info")
		Net.toast(target, "It held on tight!", "good")
	else
		Net.toast(target, "You got shoved!", "info")
	end
	Net.fireAll("ShoveResult", knock or "shove", player.UserId, target.UserId, position, direction)
end

local function onBump(player: Player, rawTargetUserId: unknown)
	local targetUserId = Guard.int(rawTargetUserId, -MAX_USER_ID, MAX_USER_ID)
	if not Config.BumpEnabled or targetUserId == nil then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil then
		return
	end
	shove(player, target, nil)
end

function ShoveService.start()
	Net.on("Bump", onBump)
	Players.PlayerRemoving:Connect(function(player)
		lastShoveAt[player] = nil
		lastShoveOf[player] = nil
		-- lastShovedAt stays by UserId: a rejoin does not lift the few seconds of immunity early or late
	end)
end

-- Studio-only test hook: `shover` shoves `target` with every check, the roll forced to `forced` when given.
function ShoveService.debugShove(shover: Player, target: Player, forced: Shove.KnockResult?)
	assert(RunService:IsStudio(), "debugShove is Studio only")
	shove(shover, target, forced)
end

return ShoveService
