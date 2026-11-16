--!strict
-- The free Bellhop Cat (F96, starter-cat.md sections 2 and 4; shared/StarterCat):
--   ClaimStarterCat()                     C -> S  1 per 2 s: within StarterCatRangeStuds (flat) of a BellhopStand under
--                                                 Workspace, not claimed yet, and the first goals done while
--                                                 Config.GroupId is 0 (tutorialStep StarterCatTutorialStep), else a
--                                                 member of the group (IsInGroupAsync in a pcall, a yes kept
--                                                 GroupCheckSeconds, a no asked again; a failed call answers "Try
--                                                 again in a moment"). The cat (level 1, base coat, StarterCatCharm) takes a
--                                                 free role slot or rests (CafeService.addGiftCat); starterCatClaimed
--                                                 is saved before the answer, so one claim per account.
--   GroupJoinPrompted()                   C -> S  1 per 5 s (#4679): "Join the group" was pressed and the prompt
--                                                 opened. Kept for the session. A claim inside
--                                                 GroupJoinTrustSeconds of it that Roblox still answers "no" asks
--                                                 again (IsInGroupAsync, then the uncached
--                                                 GroupService:GetGroupsAsync) GroupJoinRetries times,
--                                                 GroupJoinRetrySeconds apart, while the card shows its "..."; if
--                                                 it is still "no" the cat goes home anyway (gate "join_prompt").
--                                                 Nothing else changes: range, one claim per account.
--   StarterCatResult(ok, reason?)         S -> C  ok plays the happy hop; a refusal's reason is the card's line.
-- Logs `starter_cat` (gate "task", "group", "group_fresh" when only the uncached check said yes, or "join_prompt")
-- and funnel step 25 `starter_cat`.

local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local StarterCat = require(ReplicatedStorage.Shared.StarterCat)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local StarterCatService = {}

type Answer = { member: boolean, at: number } -- os.clock()

local answers: { [Player]: Answer } = {}
local claiming: { [Player]: boolean } = {} -- a claim waiting on IsInGroupAsync
local prompted: { [Player]: number } = {} -- #4679: os.clock() of the last "Join the group" press

-- True when the player stands within StarterCatRangeStuds of a stand, measured flat like the Codes Cat's.
local function nearStand(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, instance in CollectionService:GetTagged(StarterCat.TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			local pivot = (instance :: Model):GetPivot().Position
			if
				Vector2.new(pivot.X - position.X, pivot.Z - position.Z).Magnitude
				<= Config.StarterCatRangeStuds
			then
				return true
			end
		end
	end
	return false
end

-- Whether the player is in Config.GroupId; nil when the call failed. Only a yes is kept, for GroupCheckSeconds: a
-- no is asked again on the next claim, so "Join the group" then "Take me home" works at once (review S108; the
-- 1 per 2 s limit bounds the calls). Yields.
local function inGroup(player: Player): boolean?
	local kept = answers[player]
	if kept ~= nil and os.clock() - kept.at < Config.GroupCheckSeconds then
		return kept.member
	end
	local ok, member = pcall(function()
		return player:IsInGroupAsync(Config.GroupId)
	end)
	if not ok then
		return nil
	end
	if member == true then
		answers[player] = { member = true, at = os.clock() }
	end
	return member == true
end

-- #4679: the same question asked past Roblox's per-session answer: the player's group list, fetched new each call.
-- nil when the call failed. Yields.
local function inGroupFresh(player: Player): boolean?
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if not ok or type(groups) ~= "table" then
		return nil
	end
	for _, group in groups :: { any } do
		if type(group) == "table" and group.Id == Config.GroupId then
			answers[player] = { member = true, at = os.clock() }
			return true
		end
	end
	return false
end

local function answer(player: Player, ok: boolean, reason: string?)
	Net.fire(player, "StarterCatResult", ok, reason)
end

-- #4679: how the group gate was passed, for the log: "group" (Roblox's own answer), "group_fresh" (only the uncached
-- list said yes) or "join_prompt" (still "no" after the retries, let through on the join press); nil when it was not.
-- `member` is the first answer. Asks again only for a player who pressed "Join the group" this session. Yields.
local function passGroup(player: Player, member: boolean?): (boolean?, string?)
	if member == true then
		return true, "group"
	end
	local at = prompted[player]
	if not StarterCat.trustsJoin(if at ~= nil then os.clock() - at else nil) then
		return member, nil
	end
	-- no line is sent while this runs: the card shows its own "..." until the answer (5 s at most, which the
	-- retries below stay inside)
	for try = 1, Config.GroupJoinRetries do
		if inGroupFresh(player) == true then
			return true, "group_fresh"
		end
		if player.Parent == nil then
			return nil, nil
		end
		if try < Config.GroupJoinRetries then
			task.wait(Config.GroupJoinRetrySeconds)
			if inGroup(player) == true then
				return true, "group"
			end
		end
	end
	return true, "join_prompt"
end

local function onClaim(player: Player)
	local profile = DataService.get(player)
	if profile == nil or claiming[player] then
		return
	end
	local near = nearStand(player)
	local groupId = Config.GroupId
	local gate = StarterCat.gate(groupId)
	local logGate: string = gate -- #4679: how the gate was passed, for the log
	local member: boolean? = nil
	-- the cheap refusals first, so a claim already made or out of range never asks Roblox
	local early = StarterCat.blocker(profile, near, if gate == "group" then true else nil, groupId)
	if early ~= nil then
		answer(player, false, early)
		return
	end
	if gate == "group" then
		claiming[player] = true
		local how: string?
		member, how = passGroup(player, inGroup(player))
		claiming[player] = nil
		if how ~= nil then
			logGate = how
		end
		-- the call yielded: the player may have left, claimed on another path or walked away
		local now = DataService.get(player)
		if now ~= profile or player.Parent == nil then
			return
		end
		near = nearStand(player)
	end
	local blocker = StarterCat.blocker(profile, near, member, groupId)
	if blocker ~= nil then
		answer(player, false, blocker)
		return
	end
	local def = Catalog.getCat(StarterCat.CAT_ID) :: Types.CatDef
	profile.starterCatClaimed = true -- before the cat, so nothing can claim twice
	CafeService.addGiftCat(player, profile, def, Config.StarterCatCharm)
	Telemetry.custom(player, "starter_cat", 1, { logGate })
	Telemetry.onboarding(player, profile, "starter_cat")
	answer(player, true, nil)
end

-- Studio hook (Debug.starterCat): forgets the claim and sends every Bellhop Cat away, so it can be claimed again.
-- Returns the cats removed.
function StarterCatService.debugReset(player: Player, profile: Types.PlayerProfile): number
	local removed = 0
	for uid, instance in profile.cats do
		if instance.catId == StarterCat.CAT_ID then
			profile.cats[uid] = nil
			removed += 1
		end
	end
	profile.starterCatClaimed = false
	answers[player] = nil
	prompted[player] = nil
	CafeService.refreshPlot(player)
	CafeService.sync(player)
	return removed
end

function StarterCatService.start()
	Net.on("ClaimStarterCat", onClaim)
	Net.on("GroupJoinPrompted", function(player: Player)
		if Config.GroupId ~= 0 then
			prompted[player] = os.clock()
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		answers[player] = nil
		claiming[player] = nil
		prompted[player] = nil
	end)
end

return StarterCatService
