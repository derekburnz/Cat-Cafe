--!strict
-- #5505 part 2 (Design-Agent's come-back-tomorrow-spec.md section 1, moved onto the Rewards list on Nov 19 so the phone
-- HUD keeps its layout): from minute 4 of an account's play, a row on the Rewards list says what the cafe earns by
-- tomorrow while away, "Away: about $X by tomorrow", and in gold "Away: $X by tomorrow. Covers Tier N's coins!" when that
-- plus the coins held covers the next rank up's coins. X is a full away stretch at the cafe's rate (Economy.offlineGain
-- over a day: OfflineRate up to OfflineCapSeconds, the pass's values with Long Nap). Behind the switch `awayPromise`.
-- Pure, so the cloud specs check it.
--   line(view) -> (string?, boolean)   the row's words (nil: no row) and whether it is gold

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local ShortNumber = require(script.Parent.ShortNumber)

local AwayLineLogic = {}

AwayLineLogic.FLAG = "awayPromise"
AwayLineLogic.FROM_SECONDS = 4 * 60 -- of play on the account

export type View = {
	on: boolean,
	played: number?, -- seconds of play on the account (PlayerState.playSeconds counted on)
	rate: number, -- the cafe's money a second
	longNap: boolean,
	coins: number,
	nextTier: number?, -- the next tier's number, nil at the top
	nextCost: number?, -- its coins
}

function AwayLineLogic.amount(rate: number, longNap: boolean): number
	if rate ~= rate or rate <= 0 then
		return 0
	end
	local gain = Economy.offlineGain(rate, 0, 86400, longNap)
	return gain
end

function AwayLineLogic.line(view: View): (string?, boolean)
	if
		not view.on
		or view.played == nil
		or (view.played :: number) < AwayLineLogic.FROM_SECONDS
	then
		return nil, false
	end
	local amount = AwayLineLogic.amount(view.rate, view.longNap)
	if amount <= 0 then
		return nil, false
	end
	local money = "$" .. ShortNumber.format(amount)
	local cost = view.nextCost
	if
		view.nextTier ~= nil
		and cost ~= nil
		and cost > view.coins
		and view.coins + amount >= cost
	then
		return ("Away: %s by tomorrow. Covers Tier %d's coins!"):format(
			money,
			view.nextTier :: number
		),
			true
	end
	return ("Away: about %s by tomorrow"):format(money), false
end

return AwayLineLogic
