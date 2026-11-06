--!strict
-- Game passes (F95, economy-ladder.md section 6): which of the Money, Long Nap, extra slot and Second Bait Bowl
-- (#1161) passes a player owns, as Economy.Passes. DataService checks at join, before it works out offline pay, and Economy.setPasses holds the
-- result on the profile for the session; nothing is saved. A pass bought in game counts from the purchase:
-- MarketplaceService fires PromptGamePassPurchaseFinished on the server, and `changed` passes the new set on.
-- The Golden Pond pass (#1368, camp-stations.md section 4) gives no Economy.Passes: PassService sets the owner's
-- CampExtras.GOLD_POND_ATTRIBUTE so their client shows the gold Fishing Hut.
-- The five store passes (#1624, economy-ladder.md section 6a): VIP, Cat Accessories, Uniform Styles, Cafe Style and
-- Grand Cafe give Economy.Passes flags, and VIP also sets the player's ChatTags attribute for the "[VIP]" chat tag.
-- #1770 owner test mode: for a Config.OwnerTestUserIds player every made pass counts as owned (shared/OwnerTest).
-- A Config id of 0 is a pass not made yet and is never looked up, so until Tools-Agent makes them every player has
-- Economy's no passes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampExtras = require(ReplicatedStorage.Shared.CampExtras)
local ChatTags = require(ReplicatedStorage.Shared.ChatTags)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local OwnerTest = require(ReplicatedStorage.Shared.OwnerTest)
local ShopCats = require(ReplicatedStorage.Shared.ShopCats)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PassService = {}

-- A player's passes changed in game (a purchase); CafeService settles at the old rate, sets them and syncs.
PassService.changed = Signal.new() :: Signal.Signal<Player, Economy.Passes>

-- pass id -> owned, per player, from join; a purchase sets its id true. Weak keys: a player who leaves during the
-- join lookup is never seen by PlayerRemoving afterwards.
local owned: { [Player]: { [number]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

-- The five store passes (#1624) that are made (not 0).
local function storePassIds(): { number }
	local ids: { number } = {}
	for _, id in
		{
			Config.VipPassId,
			Config.CatAccessoriesPassId,
			Config.UniformStylesPassId,
			Config.CafeStylePassId,
			Config.GrandThemePassId,
			Config.JukeboxPassId, -- #1168 row 2: off sale, songs free since #1875; kept for earlier buyers
			Config.SignStylePackPassId, -- #1168 row 1: SignStyles reads it with `owns`
			Config.GardenDecorPackPassId, -- #1168 row 3: ShopCatService gives its decor (PassDecor)
		}
	do
		if id ~= 0 then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Every pass id Config names that is made (not 0).
local function passIds(): { number }
	-- #1447: the shop-only cats' passes (Royal Cat, King Cat Pack); ShopCatService reads them with `owns`
	local ids: { number } = ShopCats.passIds()
	if Config.LongNapPassId ~= 0 then
		table.insert(ids, Config.LongNapPassId)
	end
	for _, id in Config.MoneyPassIds do
		if id ~= 0 then
			table.insert(ids, id)
		end
	end
	for _, id in Config.ExtraSlotPassIds do
		if id ~= 0 then
			table.insert(ids, id)
		end
	end
	if Config.GoldenPondPassId ~= 0 then
		table.insert(ids, Config.GoldenPondPassId)
	end
	if Config.SecondBowlPassId ~= 0 then
		table.insert(ids, Config.SecondBowlPassId) -- #1161
	end
	for _, id in storePassIds() do
		table.insert(ids, id) -- #1624
	end
	return ids
end

-- Whether `set` holds pass `id` (never for a 0 id).
local function has(set: { [number]: boolean }, id: number): boolean
	return id ~= 0 and set[id] == true
end

-- #1626: each player's chat tag pick and Cafe Pass items (CafePassService.applyTag), so markPlayer can show the
-- right tag once the join lookup or a purchase says whether they own VIP.
type TagPick = { pick: string?, items: { [string]: boolean } }
local tagPicks: { [Player]: TagPick } = {}

-- Shows the Golden Pond pass on the player for their client (#1368), and their chat tag (#1624, #1626): their pick
-- among VIP and their season tags, or by default VIP, then their first season tag (ChatTags.shown).
local function markPlayer(player: Player, set: { [number]: boolean })
	player:SetAttribute(CampExtras.GOLD_POND_ATTRIBUTE, has(set, Config.GoldenPondPassId))
	local pick = tagPicks[player]
	player:SetAttribute(
		ChatTags.CHAT_TAG_ATTRIBUTE,
		ChatTags.shown(
			if pick ~= nil then pick.pick else nil,
			has(set, Config.VipPassId),
			if pick ~= nil then pick.items else {}
		)
	)
end

-- #1626: records the player's saved tag pick and pass items and shows their tag now (CafePassService calls it at
-- join, after a claim and after PassSetTag). `items` is read, never changed.
function PassService.setTagPick(player: Player, pick: string?, items: { [string]: boolean })
	tagPicks[player] = { pick = pick, items = items }
	markPlayer(player, owned[player] or {})
end

-- The passes an owned-id set gives: the highest Money pass, Long Nap and one slot per extra slot pass.
function PassService.fromOwned(set: { [number]: boolean }): Economy.Passes
	local money = 1
	for multiplier, id in Config.MoneyPassIds do
		if id ~= 0 and set[id] and multiplier > money then
			money = multiplier
		end
	end
	local slots = 0
	for _, id in Config.ExtraSlotPassIds do
		if id ~= 0 and set[id] then
			slots += 1
		end
	end
	return {
		money = money,
		longNap = Config.LongNapPassId ~= 0 and set[Config.LongNapPassId] == true,
		slots = slots,
		-- #1161: bowl 2 (CafeService.secondBowl)
		secondBowl = if Config.SecondBowlPassId ~= 0 and set[Config.SecondBowlPassId]
			then true
			else nil,
		-- #1624: the five store passes
		vip = if has(set, Config.VipPassId) then true else nil,
		accessories = if has(set, Config.CatAccessoriesPassId) then true else nil,
		uniforms = if has(set, Config.UniformStylesPassId) then true else nil,
		cafeStyle = if has(set, Config.CafeStylePassId) then true else nil,
		grand = if has(set, Config.GrandThemePassId) then true else nil,
	}
end

-- Seconds between the tries again for a lookup that failed at join (review S97): a passing Marketplace outage
-- should not keep a paid pass off for the whole session.
local RETRY_SECONDS = { 5, 15, 45 }

-- Whether `player` owns pass `id`, or nil when the lookup failed (warned).
local function lookup(player: Player, id: number): boolean?
	local ok, result =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	if ok then
		return result == true
	end
	warn("[PassService] pass lookup failed for", player.UserId, id, result)
	return nil
end

-- Tries the failed ids again on RETRY_SECONDS while the player stays and this join's set is still theirs, and
-- fires `changed` when one turns out owned. Offline pay was already worked out at join, so a Long Nap found here
-- counts from the next join.
local function retry(player: Player, set: { [number]: boolean }, failed: { number })
	local left = failed
	for _, seconds in RETRY_SECONDS do
		task.wait(seconds)
		if owned[player] ~= set or player.Parent ~= Players then
			return
		end
		local still: { number } = {}
		local gained = false
		for _, id in left do
			local result = lookup(player, id)
			if result == nil then
				table.insert(still, id)
			elseif result and not set[id] then
				set[id] = true
				gained = true
			end
		end
		if gained then
			markPlayer(player, set)
			PassService.changed:Fire(player, PassService.fromOwned(set))
		end
		left = still
		if #left == 0 then
			return
		end
	end
end

-- Looks up every made pass for `player` (yields) and returns what they give. DataService calls it once at join; a
-- failed lookup counts as not owned until `retry` gets an answer.
function PassService.check(player: Player): Economy.Passes
	local set: { [number]: boolean } = {}
	if OwnerTest.isOwner(player.UserId) then
		-- #1770 owner test mode: every made pass counts as owned, with no lookup and nothing bought
		for _, id in passIds() do
			set[id] = true
		end
		print(
			string.format(
				"[OwnerTest] %d: every made pass counts as owned (%d)",
				player.UserId,
				#passIds()
			)
		)
		owned[player] = set
		markPlayer(player, set)
		return PassService.fromOwned(set)
	end
	local failed: { number } = {}
	for _, id in passIds() do
		local result = lookup(player, id)
		if result == nil then
			table.insert(failed, id)
		else
			set[id] = result
		end
	end
	owned[player] = set
	markPlayer(player, set)
	if #failed > 0 then
		task.spawn(retry, player, set, failed)
	end
	return PassService.fromOwned(set)
end

-- Whether `player` owns pass `id` as far as this session knows: looked up at join, or bought since (#1447). False
-- before the join lookup and while a failed lookup waits for its retry, which fires `changed` once it answers.
function PassService.owns(player: Player, id: number): boolean
	local set = owned[player]
	return id ~= 0 and set ~= nil and set[id] == true
end

local function onPurchaseFinished(player: Player, passId: number, purchased: boolean)
	if not purchased or type(passId) ~= "number" or passId == 0 then
		return
	end
	local isOurs = false
	for _, id in passIds() do
		if id == passId then
			isOurs = true
		end
	end
	local set = owned[player]
	if not isOurs or set == nil or set[passId] then
		return
	end
	set[passId] = true
	markPlayer(player, set)
	PassService.changed:Fire(player, PassService.fromOwned(set))
end

function PassService.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPurchaseFinished)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		tagPicks[player] = nil
	end)
end

return PassService
