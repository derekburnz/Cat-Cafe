--!strict
-- The cafe's money pop-ups, batched (#2413, Derek2 2026-11-08: "make the money popups from customers in cafe much less
-- often and also round it to the K/M/B like 16400 to 16K"). Every payment and tip in a cafe adds to one batch; the
-- float over the counter shows at most once every GAP seconds and carries everything paid since the last one, so the
-- money still adds up and the screen stays quiet.
--   GAP                       seconds between two floats in one cafe
--   new()                     an empty batch
--   add(batch, amount, now)   adds a payment: returns the amount to float now, or nil and the seconds until flush
--   flush(batch, now)         the amount to float once the wait add asked for is over, or nil (nothing waiting)
--   text(amount)              "+$16K": the amount as the HUD writes money (shared/ShortNumber)
-- Pure, so the cloud spec runner checks it; Controllers/CustomerController floats it.

local ShortNumber = require(script.Parent.ShortNumber)

local PayBatch = {}

PayBatch.GAP = 6

export type Batch = { amount: number, shownAt: number?, waiting: boolean }

function PayBatch.new(): Batch
	return { amount = 0, shownAt = nil, waiting = false }
end

local function take(batch: Batch, now: number): number
	local amount = batch.amount
	batch.amount = 0
	batch.shownAt = now
	batch.waiting = false
	return amount
end

-- Adds `amount` (a NaN, a negative or a zero adds nothing). Returns the total to float now when the gap since the last
-- float is over; otherwise nil and, the first time a batch starts waiting, the seconds until flush should be called.
function PayBatch.add(batch: Batch, amount: number, now: number): (number?, number?)
	if amount == amount and amount > 0 then
		batch.amount += amount
	end
	if batch.amount <= 0 then
		return nil, nil
	end
	local shownAt = batch.shownAt
	if shownAt == nil or now - shownAt >= PayBatch.GAP then
		return take(batch, now), nil
	end
	if batch.waiting then
		return nil, nil
	end
	batch.waiting = true
	return nil, shownAt + PayBatch.GAP - now
end

function PayBatch.flush(batch: Batch, now: number): number?
	if batch.amount <= 0 then
		batch.waiting = false
		return nil
	end
	return take(batch, now)
end

function PayBatch.text(amount: number): string
	return "+$" .. ShortNumber.format(amount)
end

return PayBatch
