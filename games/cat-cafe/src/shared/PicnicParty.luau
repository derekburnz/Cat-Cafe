--!strict
-- #5572 (Derek 2026-11-20: "rework the picnic basket into being something cool and clean because its where a lot of
-- people leave so it has to be something that hooks"; Design's Picnic Party spec): behind the switch `picnicParty`.
-- A ready Picnic Basket starts Picnic Time when the player steps into its ring: +100% money for SECONDS, running at
-- once (the potion POTION, shown as the HUD's potion chip). Then it is ready again EVERY seconds later, holding one,
-- and always on the first settle of a new UTC day (shared/CampExtras.settle with `party`). The first is ready the
-- moment the Park opens, as every extra's first fill is.
--
-- Restart safe: the save is the picnic slot every server knows ({ at, held }); an older server reads a ready party as
-- a ready Picnic Treats pick. Picnic Time is a potion an older server drops (it runs out in minutes anyway).
--
-- The client reads these Player attributes (the server sets them; nothing is sent):
--   PicnicReady   boolean   a party waits at the basket
--   PicnicNextAt  number    os.time() the next one is ready (nil while one waits)
--   PicnicEndsAt  number    os.time() Picnic Time ends, set when a party starts (nil or past when none runs)

local PicnicParty = {}

PicnicParty.FLAG = "picnicParty"
PicnicParty.EVERY = 20 * 60 -- seconds from one party's start to the next one ready
PicnicParty.HOLD = 1
PicnicParty.SECONDS = 3 * 60 -- Picnic Time
PicnicParty.POTION = "picnic_time" -- Catalog.potions: +100% money (tipsOver 1) for 3 minutes
PicnicParty.CAT_NEXT_SECONDS = 2 -- the next picnic cat sits down this long after the one before is caught
PicnicParty.SEEN_STUDS = 60 -- picnic_ready_seen: a ready basket this near counts as seen
-- #5676 (Sync's Studio run Nov 22: the blanket lies inside the Park camp, where the net is away, so only 1 of 3 cats
-- was caught): with picnicNet on, a player with a party running has the net out and may swing and catch within
-- NET_STUDS of their own blanket's middle, camp or not (CatService)
PicnicParty.NET_FLAG = "picnicNet"
PicnicParty.NET_STUDS = 12
-- #5707 (Growth Nov 23: picnic cat 1 caught by 38, cat 2 by 7, cat 3 by 1): with picnicFlow on, a picnic cat that is
-- missed stays on its seat (parkCatchNormal took the old "cannot be lost" away, so a miss sent it bolting off the
-- blanket, out of the net's reach), a carrier within NET_STUDS of their own blanket checks in as at its camp, so the
-- next swing is never refused for the cat in their arms, and each catch says what comes next (NEXT_LINE, LAST_LINE)
PicnicParty.FLOW_FLAG = "picnicFlow"
PicnicParty.NEXT_LINE = "Another picnic cat is sitting down on the blanket!"
PicnicParty.LAST_LINE = "Last picnic cat: %s %s is sitting down on the blanket!"
function PicnicParty.nextLine(nextRarity: string?, last: boolean): string?
	if nextRarity == nil then
		return nil
	end
	if not last then
		return PicnicParty.NEXT_LINE
	end
	-- "an Epic", "a Rare": the article follows the rarity's first letter
	local article = if nextRarity:match("^[AEIOUaeiou]") then "an" else "a"
	return string.format(PicnicParty.LAST_LINE, article, nextRarity)
end

PicnicParty.READY = "PicnicReady"
PicnicParty.NEXT_AT = "PicnicNextAt"
PicnicParty.ENDS_AT = "PicnicEndsAt"

local DAY = 86400

-- Pure: a picnic slot `slot` brought up to `now` under the party's day rule: an empty basket whose clock is from an
-- earlier UTC day is ready now. Call before the fill. Returns whether it filled.
function PicnicParty.dayFill(slot: { at: number, held: number }, now: number): boolean
	if slot.held >= PicnicParty.HOLD then
		return false
	end
	if math.floor(slot.at / DAY) < math.floor(now / DAY) then
		slot.held = PicnicParty.HOLD
		slot.at = now
		return true
	end
	return false
end

-- Pure: starts a party from `slot` at `now` when one waits: empties it and starts its clock. False when none waits.
function PicnicParty.start(slot: { at: number, held: number }, now: number): boolean
	if slot.held < 1 then
		return false
	end
	slot.held = 0
	slot.at = now
	return true
end

return PicnicParty
