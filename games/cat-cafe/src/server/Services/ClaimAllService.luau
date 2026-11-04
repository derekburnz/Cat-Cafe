--!strict
-- Claim all (Derek 2026-10-28 and 10-29; ui-contract.md `claimAll`): ClaimAll(what) with `what` one of
-- shared/ClaimAll.KINDS. "daily" and "weekly" pay every finished quest of that set, "achievements" every met
-- achievement and "quests" (#1073) all three at once (QuestService), "index" every ready Index reward on every page (IndexRewardService) and "tipjar" every
-- ready Tip Jar step (TipJarService). Each pays exactly what its single Claims would, marked before it pays, with one
-- toast and one sync; nothing ready answers "Nothing to claim yet". Anything else is dropped. Net limits it to 2 per
-- 2 s. Nothing here is sold for Robux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClaimAll = require(ReplicatedStorage.Shared.ClaimAll)
local Guard = require(script.Parent.Parent.Util.Guard)
local IndexRewardService = require(script.Parent.IndexRewardService)
local Net = require(script.Parent.Net)
local QuestService = require(script.Parent.QuestService)
local TipJarService = require(script.Parent.TipJarService)

local ClaimAllService = {}

local function onClaimAll(player: Player, rawWhat: unknown)
	local what = Guard.oneOf(rawWhat, ClaimAll.KINDS)
	if what == "daily" then
		QuestService.claimAll(player, "daily")
	elseif what == "weekly" then
		QuestService.claimAll(player, "weekly")
	elseif what == "achievements" then
		QuestService.claimAllAchievements(player)
	elseif what == "quests" then
		QuestService.claimEverything(player)
	elseif what == "index" then
		IndexRewardService.claimAll(player)
	elseif what == "tipjar" then
		TipJarService.claimAll(player)
	end
end

function ClaimAllService.start()
	Net.on("ClaimAll", onClaimAll)
end

return ClaimAllService
