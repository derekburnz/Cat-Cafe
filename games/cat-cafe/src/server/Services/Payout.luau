--!strict
-- Pays a prize in the Index prize shape (F54, F65; data-model sections 11b and 11d) for Index rewards and codes:
-- coins (a minimum or seconds of the day rate), foods, golden fish, banked spins (up to SpinBankCap; the rest are
-- dropped) and crates (banked for the Golden Fish Market, "highest" resolved now). The permanent bonuses are not
-- paid here: IndexRewards.totals reads them from the claims, so they are only named for the toast. The caller has
-- already checked and marked the prize as paid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Economy = require(ReplicatedStorage.Shared.Economy)
local GoldenFish = require(ReplicatedStorage.Shared.GoldenFish)
local Prizes = require(ReplicatedStorage.Shared.Prizes)
local Spin = require(ReplicatedStorage.Shared.Spin)
local Telemetry = require(script.Parent.Telemetry)
local Types = require(ReplicatedStorage.Shared.Types)

local Payout = {}

-- Pays the prize and returns what it paid, for the toast ("+$300", "2 Tuna", "+25 golden fish", "2 spins",
-- "1 Alley Crate", "+2% tips forever"), and the coins. `sku` names the source in analytics ("index_reward", "code").
function Payout.pay(
	player: Player,
	profile: Types.PlayerProfile,
	prize: Types.IndexPrize,
	sku: string
): ({ string }, number)
	local paid: { string } = {}
	local coins = Prizes.coins(prize.coins, prize.coinSeconds, Economy.incomePerSecond(profile))
	if coins > 0 then
		Economy.credit(profile, coins)
		Telemetry.source(player, profile, coins, "Gameplay", sku)
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
	local fish = prize.fish
	if fish ~= nil and fish > 0 then
		GoldenFish.credit(profile, fish)
		Telemetry.fishSource(player, profile, fish, "Gameplay", sku)
		table.insert(paid, string.format("+%d golden fish", fish))
	end
	local spins = prize.spins
	if spins ~= nil and spins > 0 then
		local banked = Spin.bank(profile.spin, spins)
		table.insert(
			paid,
			if banked < spins
				then string.format("%d of %d spins (Spins full)", banked, spins)
				else string.format("%d spin%s", spins, if spins == 1 then "" else "s")
		)
	end
	if prize.crates ~= nil then
		for crateId, count in prize.crates do
			local paidId = Prizes.crateFor(crateId, Economy.tier(profile))
			local crate = if paidId ~= nil then Catalog.getCrate(paidId) else nil
			if paidId ~= nil and crate ~= nil then
				profile.crates[paidId] = (profile.crates[paidId] or 0) + count
				table.insert(paid, string.format("%d %s", count, crate.name))
			end
		end
	end
	local forever = (prize.bonus or 0) + (prize.goldLuck or 0) + (prize.baitSpeed or 0)
	if forever > 0 then
		local what = if prize.goldLuck ~= nil
			then "gold luck"
			elseif prize.baitSpeed ~= nil then "faster bait"
			else "tips"
		table.insert(paid, string.format("+%d%% %s forever", math.floor(forever * 100 + 0.5), what))
	end
	if prize.tag ~= nil then
		table.insert(paid, string.format("the %s tag", prize.tag))
	end
	return paid, coins
end

return Payout
