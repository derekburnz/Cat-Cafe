--!strict
-- Codes and the Codes Cat (F65, data-model section 11d). RedeemCode(text) from a player within CodesCatRange of a
-- station tagged CodesCat: the text is trimmed and lowercased (shared/Codes), looked up in Catalog.codes and paid
-- once per player through Payout, the code id saved in codesRedeemed before anything is paid. The answer is
-- CodeResult(ok, message, prize?). After CodeWrongLimit codes that do not exist within CodeWrongWindowSeconds the
-- box locks for CodeLockSeconds, so nobody can guess codes. A requiresGroup code asks IsInGroupAsync(Config.GroupId) in a
-- pcall, kept GroupCheckSeconds per player. The typed text is never shown to anyone or saved, so it needs no filter.
-- Nothing about codes is sold.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CafeService = require(script.Parent.CafeService)
local Codes = require(ReplicatedStorage.Shared.Codes)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local CodeService = {}

local guards: { [Player]: Codes.WrongGuard } = {} -- wrong codes and the lock, in os.clock()
local busy: { [Player]: boolean } = {} -- a redeem waiting on the group check
local groupAnswers: { [Player]: { member: boolean, at: number } } = {}

-- True when the player stands within CodesCatRange of a Codes Cat station.
local function nearStation(player: Player): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local position = (root :: BasePart).Position
	for _, instance in CollectionService:GetTagged(Codes.TAG) do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and (instance:GetPivot().Position - position).Magnitude <= Config.CodesCatRange
		then
			return true
		end
	end
	return false
end

-- Whether the player is in Config.GroupId, asked at most once per GroupCheckSeconds. A failed call counts as not a
-- member and is not kept, so the next try asks again. Yields.
local function inGroup(player: Player): boolean
	local kept = groupAnswers[player]
	if kept ~= nil and os.clock() - kept.at < Config.GroupCheckSeconds then
		return kept.member
	end
	local ok, member = pcall(function()
		return player:IsInGroupAsync(Config.GroupId)
	end)
	if not ok then
		return false
	end
	groupAnswers[player] = { member = member == true, at = os.clock() }
	return member == true
end

local function guardFor(player: Player): Codes.WrongGuard
	local guard = guards[player]
	if guard == nil then
		guard = Codes.newGuard()
		guards[player] = guard
	end
	return guard
end

local function answer(player: Player, ok: boolean, message: string, prize: Types.IndexPrize?)
	Net.fire(player, "CodeResult", ok, message, prize)
end

local function onRedeemCode(player: Player, raw: unknown)
	local profile = DataService.get(player)
	if profile == nil or busy[player] then
		return
	end
	local guard = guardFor(player)
	if Codes.locked(guard, os.clock()) then
		answer(player, false, Codes.LOCKED)
		return
	end
	if not nearStation(player) then
		answer(player, false, Codes.FAR)
		return
	end
	local code = Codes.normalize(raw)
	local def = if code ~= nil then Codes.get(code) else nil
	if code == nil or def == nil then
		local locked = Codes.noteWrong(guard, os.clock())
		answer(player, false, if locked then Codes.LOCKED else Codes.UNKNOWN)
		return
	end
	local member: boolean? = nil
	if def.requiresGroup == true and Config.GroupId ~= 0 then
		busy[player] = true
		member = inGroup(player)
		busy[player] = nil
		if player.Parent == nil then
			return
		end
	end
	-- checked again after the group call yielded, then marked before paying, so one code pays once
	local refusal = Codes.refusal(profile, code, os.time(), member)
	if refusal ~= nil then
		answer(player, false, refusal)
		return
	end
	profile.codesRedeemed[def.id] = os.time()
	Payout.pay(player, profile, def.prize, "code")
	Telemetry.custom(player, "code_redeemed", 1, { def.id })
	answer(player, true, Codes.REDEEMED, def.prize)
	CafeService.sync(player)
end

function CodeService.start()
	Players.PlayerRemoving:Connect(function(player)
		guards[player] = nil
		busy[player] = nil
		groupAnswers[player] = nil
	end)
	Net.on("RedeemCode", onRedeemCode)
end

-- Studio-only test hook (Debug.codes): forgets the player's redeemed codes and clears the lock. Returns how many
-- codes were forgotten.
function CodeService.debugReset(player: Player, profile: Types.PlayerProfile): number
	local n = 0
	for _ in profile.codesRedeemed do
		n += 1
	end
	table.clear(profile.codesRedeemed)
	guards[player] = nil
	groupAnswers[player] = nil
	return n
end

return CodeService
