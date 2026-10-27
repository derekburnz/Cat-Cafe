--!strict
-- What the rich tip marker shows, from the plot's display attributes (data-model section 12) and the server clock:
--   read(amount, expiresAt, now, stay) -> { amount, left, fraction }? where left is whole seconds to go and
--   fraction is the share of the stay left (1 when it lands, 0 at expiry); nil when there is no tip to show
--   (no amount, a zero amount or an expiry already past). Attribute values come in as `any`, so wrong types are nil.
--   clock(seconds) -> "1:05"

local RichTipState = {}

export type View = {
	amount: number,
	left: number,
	fraction: number,
}

function RichTipState.read(amount: any, expiresAt: any, now: number, stay: number): View?
	if type(amount) ~= "number" or amount <= 0 then
		return nil
	end
	if type(expiresAt) ~= "number" or expiresAt <= now then
		return nil
	end
	local remaining = expiresAt - now
	return {
		amount = amount,
		left = math.ceil(remaining),
		fraction = if stay > 0 then math.clamp(remaining / stay, 0, 1) else 0,
	}
end

function RichTipState.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return RichTipState
