--!strict
-- #4437 (zero-sales dig, Derek 2026-11-15; Growth-Agent's spec): the HUD's green "2x Money" button opened Roblox's
-- prompt on the first tap, so a curious Tier 1 player saw only a price. Now the first tap of a session opens a small
-- card (Screens/MoneyCard) that says what the pass does for this cafe: its money a minute now and with the pass, the
-- pass picture, "Yours forever", a Buy button with the price and the X. Buy opens Roblox's prompt (source
-- money_card); later taps that session go straight to the prompt as before. No countdown, no "only X left".
-- The numbers come from shared/MoneyCard.perMinute (Gameplay-Engineer). Pure, so the cloud specs check it.

local ShortNumber = require(script.Parent.ShortNumber)

local MoneyCardLogic = {}

-- as Format.money writes it (Theme.currencySymbol), without Theme so the specs can load this
local function money(n: number): string
	return "$" .. ShortNumber.format(n)
end

MoneyCardLogic.FLAG = "moneyCard" -- LiveFlags: on by default; false sends the HUD button straight to the prompt again
MoneyCardLogic.SUBTITLE = "Yours forever"

export type View = {
	title: string, -- "2x Money"
	subtitle: string,
	now: string?, -- "$180 a minute"; nil when the cafe makes nothing yet
	with: string?, -- "$360 a minute"
	withLabel: string, -- "With 2x Money"
	plain: string?, -- in place of the two numbers while the cafe makes nothing yet
	buy: string, -- "Buy R$49", or "Buy" until Roblox's price is known
}

-- The Money pass rung (2 to 10) whose pass id is `id` in config.MoneyPassIds, or nil.
function MoneyCardLogic.rungOf(config: any, id: unknown): number?
	local money = if type(config) == "table" then config.MoneyPassIds else nil
	if type(money) ~= "table" or type(id) ~= "number" or id <= 0 then
		return nil
	end
	for multiplier = 2, 10 do
		if money[multiplier] == id then
			return multiplier
		end
	end
	return nil
end

export type Offer = {
	on: boolean, -- the moneyCard switch
	shown: boolean, -- the card already came up this session
	rung: number?, -- the tapped pass's rung (rungOf)
	current: number, -- PlayerState.passBoosts.money (1 without a Money pass)
}

-- Whether the HUD button's tap opens the card (else the prompt, as before): once a session, for a rung above the
-- one the cafe has.
function MoneyCardLogic.offer(o: Offer): boolean
	return o.on and not o.shown and o.rung ~= nil and (o.rung :: number) > o.current
end

-- The card's words for the `rung` pass, with shared/MoneyCard.perMinute's `now` and `with` and Roblox's price.
function MoneyCardLogic.view(rung: number, now: number, with: number, robux: number?): View
	local named = ("%dx Money"):format(rung)
	local numbers = now > 0 and with > now
	return {
		title = named,
		subtitle = MoneyCardLogic.SUBTITLE,
		now = if numbers then money(now) .. " a minute" else nil,
		with = if numbers then money(with) .. " a minute" else nil,
		withLabel = "With " .. named,
		plain = if numbers then nil else "More money from every cat in your cafe",
		buy = if type(robux) == "number" and robux > 0
			then "Buy R$" .. tostring(math.floor(robux))
			else "Buy",
	}
end

return MoneyCardLogic
