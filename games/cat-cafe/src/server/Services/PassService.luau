--!strict
-- Game passes (F95, economy-ladder.md section 6): which of the Money, Long Nap and extra slot passes a player owns,
-- as Economy.Passes. DataService checks at join, before it works out offline pay, and Economy.setPasses holds the
-- result on the profile for the session; nothing is saved. A pass bought in game counts from the purchase:
-- MarketplaceService fires PromptGamePassPurchaseFinished on the server, and `changed` passes the new set on.
-- A Config id of 0 is a pass not made yet and is never looked up, so until Tools-Agent makes them every player has
-- Economy's no passes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PassService = {}

-- A player's passes changed in game (a purchase); CafeService settles at the old rate, sets them and syncs.
PassService.changed = Signal.new() :: Signal.Signal<Player, Economy.Passes>

-- pass id -> owned, per player, from join; a purchase sets its id true. Weak keys: a player who leaves during the
-- join lookup is never seen by PlayerRemoving afterwards.
local owned: { [Player]: { [number]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

-- Every pass id Config names that is made (not 0).
local function passIds(): { number }
	local ids: { number } = {}
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
	return ids
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
	}
end

-- Looks up every made pass for `player` (yields; a failed lookup counts as not owned for this session and warns)
-- and returns what they give. DataService calls it once at join.
function PassService.check(player: Player): Economy.Passes
	local set: { [number]: boolean } = {}
	for _, id in passIds() do
		local ok, result =
			pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		if ok then
			set[id] = result == true
		else
			warn("[PassService] pass lookup failed for", player.UserId, id, result)
		end
	end
	owned[player] = set
	return PassService.fromOwned(set)
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
	PassService.changed:Fire(player, PassService.fromOwned(set))
end

function PassService.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPurchaseFinished)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return PassService
