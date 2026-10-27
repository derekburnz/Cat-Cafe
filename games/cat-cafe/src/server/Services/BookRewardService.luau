--!strict
-- Book rewards (F48, data-model section 11b). ClaimBookReward(areaId, milestoneId) pays a milestone on an area's
-- Book page once the collection (or, for gold10, the gold collection) holds enough of that area's cats and it has
-- not been claimed. The claim is marked before anything is paid, so one milestone pays once. Book decor goes into
-- decorOwned and is placed at once, like a bought piece; nothing here can be bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BookRewards = require(ReplicatedStorage.Shared.BookRewards)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Net = require(script.Parent.Net)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local BookRewardService = {}

-- Pays the prize and returns what it paid, for the toast: "+$300", "2 Tuna", "Alley Mural Print".
local function pay(player: Player, profile: Types.PlayerProfile, prize: Types.BookPrize): { string }
	local paid: { string } = {}
	local coins = prize.coins
	if coins ~= nil and coins > 0 then
		Economy.credit(profile, coins)
		Telemetry.source(player, profile, coins, "Gameplay", "book_reward")
		table.insert(paid, string.format("+$%d", coins))
	end
	if prize.lures ~= nil then
		for lureId, count in prize.lures do
			profile.lures[lureId] = (profile.lures[lureId] or 0) + count
			local lure = Catalog.getLure(lureId)
			table.insert(
				paid,
				string.format("%d %s", count, if lure ~= nil then lure.name else lureId)
			)
		end
	end
	local decorId = prize.decorId
	if decorId ~= nil then
		profile.decorOwned[decorId] = true
		profile.decorPlaced[decorId] = true
		local decor = Catalog.getDecor(decorId)
		table.insert(paid, if decor ~= nil then decor.name else decorId)
	end
	return paid
end

local function onClaimBookReward(player: Player, rawArea: unknown, rawMilestone: unknown)
	local areaId, milestoneId = Guard.id(rawArea), Guard.id(rawMilestone)
	local profile = DataService.get(player)
	if areaId == nil or milestoneId == nil or profile == nil then
		return
	end
	local blocker = BookRewards.blocker(profile, areaId, milestoneId)
	if blocker ~= nil then
		Net.toast(player, blocker, "warn")
		CafeService.sync(player)
		return
	end
	local prize = BookRewards.prize(areaId, milestoneId) :: Types.BookPrize
	local claims = profile.bookRewards[areaId]
	if claims == nil then
		claims = {}
		profile.bookRewards[areaId] = claims
	end
	claims[milestoneId] = true
	local paid = pay(player, profile, prize)
	Telemetry.custom(player, "book_reward", prize.coins or 0, { areaId, milestoneId })
	local area = Catalog.getArea(areaId)
	Net.toast(
		player,
		string.format(
			"%s Book reward: %s",
			if area ~= nil then area.name else areaId,
			table.concat(paid, ", ")
		),
		"good"
	)
	if prize.decorId ~= nil then
		CafeService.refreshPlot(player)
	end
	CafeService.sync(player)
end

function BookRewardService.start()
	Net.on("ClaimBookReward", onClaimBookReward)
end

return BookRewardService
