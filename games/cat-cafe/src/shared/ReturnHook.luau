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
-- No timers, no "you'll lose" and nothing paid: it only names what is already there.

local Config = require(script.Parent.Config)
local DailyTreat = require(script.Parent.DailyTreat)
local Spin = require(script.Parent.Spin)
local Types = require(script.Parent.Types)

local ReturnHook = {}

export type Mode = "recap" | "join"
-- Types.ReturnHookView: `kind` one of KINDS, `day` the Daily Treat day for "treat"
export type Hook = Types.ReturnHookView

ReturnHook.KINDS = table.freeze({ "gift", "bait", "treat", "quests" }) :: { string }

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

return ReturnHook
