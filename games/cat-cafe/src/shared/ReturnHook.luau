--!strict
-- One reason to come back tomorrow (#2123, first-hour.md section 6a): the recap card's "Tomorrow" line and the welcome
-- back card's line name the single best thing waiting, picked in this order. Pure; nothing new is saved.
--   pick(profile, now, "recap", gift?) -> Hook?   at the end of a session, what waits after the player leaves:
--       "gift"    #3772: `gift` is true, so tomorrow's first join pays the welcome back golden crate
--                 (shared/ReturnGift; the caller checks the switch) ("Come back tomorrow for a golden crate")
--       "bait"    a bowl's bait cat comes after now ("Your bait cat will be waiting for you")
--       "treat"   today's Daily Treat stamp is claimed, so tomorrow's day `day` is certain ("Tomorrow: Daily Treat
--                 day D, PRIZE"; the UI words the prize from Catalog.dailyTreat[day])
--       "quests"  otherwise ("Tomorrow: new daily quests")
--   pick(profile, now, "join") -> Hook?    on a rejoin, from the save as it was left, in the present tense:
--       "bait"    a bowl's bait cat has come ("Your bait cat is ready!")
--       "treat"   a Daily Treat stamp is due, day `day` ("Daily Treat day D is ready")
--       "quests"  a new UTC day since the player was last seen, so the daily quests are new ("New daily quests are here")
--       nil       none of these, and the line is left out
--   early(profile, now, giftOn) -> Hook?   #4626: the line a new player sees at minute 6 (PlayerState.tomorrowHook):
--       "gift"    the welcome back golden crate pays tomorrow (giftOn: the gift is on; always true since #4654 retired the returnGift switch)
--       "treat"   today's Daily Treat stamp is claimed, so tomorrow's day `day` is certain
--       nil       neither (an unclaimed stamp today is the better nudge, and a bowl's cat comes this session)
-- No timers, no "you'll lose" and nothing paid: it only names what is already there.

local Config = require(script.Parent.Config)
local DailyTreat = require(script.Parent.DailyTreat)
local ReturnGift = require(script.Parent.ReturnGift)
local Spin = require(script.Parent.Spin)
local Types = require(script.Parent.Types)

local ReturnHook = {}

export type Mode = "recap" | "join"
-- Types.ReturnHookView: `kind` one of KINDS, `day` the Daily Treat day for "treat"
export type Hook = Types.ReturnHookView

ReturnHook.KINDS = table.freeze({ "gift", "bait", "treat", "quests" }) :: { string }

-- #4626 (Design-Agent's spec): the early line's switch (LiveFlags.OFF_BY_DEFAULT), the Tiers it is for (new players,
-- before Tier 3) and the kinds it can name (also the return_hook_early report's values)
ReturnHook.EARLY_FLAG = "returnHookEarly"
ReturnHook.EARLY_MAX_TIER = 2
ReturnHook.EARLY_KINDS = table.freeze({ "gift", "treat" }) :: { string }
-- #3951 (Design-Agent's spec, Growth's Nov 17 read: day 1 return 2.7 to 6.5% on Nov 12 to 14, under the 6% line): the
-- come back tomorrow card (UI/Components/TomorrowCard), on a new account's first UTC day once the walk-through and
-- first 5 minutes hold ends, in place of the minute 6 line. Its switch (LiveFlags.OFF_BY_DEFAULT) and the
-- tomorrow_card report's values: shown, then ok (its button), closed (the X) or hidden (something took the card).
ReturnHook.CARD_FLAG = "tomorrowCard"
ReturnHook.CARD_OUTCOMES = table.freeze({ "shown", "ok", "closed", "hidden" }) :: { string }

-- When the bowl's cat comes (a save from before readyAt waits LureWaitSeconds from placedAt).
local function readyAt(bait: Types.BaitState): number
	return if type(bait.readyAt) == "number"
		then bait.readyAt
		else bait.placedAt + Config.LureWaitSeconds
end

-- Whether either bowl matches: still cooking after `now` (recap) or ready by `now` (join).
local function baitWaiting(profile: Types.PlayerProfile, now: number, mode: Mode): boolean
	for _, bait in { profile.bait, profile.bait2 } do
		if bait ~= nil then
			local at = readyAt(bait)
			if (mode == "recap" and at > now) or (mode == "join" and at <= now) then
				return true
			end
		end
	end
	return false
end

function ReturnHook.pick(
	profile: Types.PlayerProfile,
	now: number,
	mode: Mode,
	gift: boolean?
): Hook?
	if mode == "recap" and gift == true then
		return { kind = "gift" }
	end
	if baitWaiting(profile, now, mode) then
		return { kind = "bait" }
	end
	local treat = profile.dailyTreat
	local due = DailyTreat.due(treat, now)
	if mode == "recap" and not due then
		return { kind = "treat", day = DailyTreat.nextDay(treat) }
	elseif mode == "join" and due then
		return { kind = "treat", day = DailyTreat.nextDay(treat) }
	end
	if mode == "recap" or Spin.day(now) > Spin.day(profile.lastSeen) then
		return { kind = "quests" }
	end
	return nil
end

-- #4626: the early line's pick (see the header): the recap's own gift and treat lines, never bait or quests.
function ReturnHook.early(profile: Types.PlayerProfile, now: number, giftOn: boolean): Hook?
	if giftOn and ReturnGift.waiting(profile, now) then
		return { kind = "gift" }
	end
	local treat = profile.dailyTreat
	if not DailyTreat.due(treat, now) then
		return { kind = "treat", day = DailyTreat.nextDay(treat) }
	end
	return nil
end

return ReturnHook
