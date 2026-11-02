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
--   StarterCatResult(ok, reason?)         S -> C  ok plays the happy hop; a refusal's reason is the card's line.
-- Logs `starter_cat` (gate "task" or "group") and funnel step 25 `starter_cat`.

local CollectionService = game:GetService("CollectionService")
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

local function answer(player: Player, ok: boolean, reason: string?)
	Net.fire(player, "StarterCatResult", ok, reason)
end

local function onClaim(player: Player)
	local profile = DataService.get(player)
	if profile == nil or claiming[player] then
		return
	end
	local near = nearStand(player)
	local groupId = Config.GroupId
	local gate = StarterCat.gate(groupId)
	local member: boolean? = nil
	-- the cheap refusals first, so a claim already made or out of range never asks Roblox
	local early = StarterCat.blocker(profile, near, if gate == "group" then true else nil, groupId)
	if early ~= nil then
		answer(player, false, early)
		return
	end
	if gate == "group" then
		claiming[player] = true
		member = inGroup(player)
		claiming[player] = nil
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
	Telemetry.custom(player, "starter_cat", 1, { gate })
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
	CafeService.refreshPlot(player)
	CafeService.sync(player)
	return removed
end

function StarterCatService.start()
	Net.on("ClaimStarterCat", onClaim)
	Players.PlayerRemoving:Connect(function(player: Player)
		answers[player] = nil
		claiming[player] = nil
	end)
end

return StarterCatService
