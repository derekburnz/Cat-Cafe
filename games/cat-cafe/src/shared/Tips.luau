--!strict
-- Context tips and the feedback page's fixed values (F87, easy-start.md sections 3, 4 and 6). Pure.
--
-- A context tip shows once per account, the first time a player meets something: a card of one line or a camera cut
-- of 3 to 4 seconds. Which tip, when, is decided by `by`: the server sends ShowTip(id) for the ones it can see
-- (`due` for the ones that follow from the saved state, the rest at their event), the client finds the ones only it
-- can see (a stuck cat's "!" or the Codes Cat in view, F88's luck chip, and the offline card's line, shown when the
-- OfflineEarnings card comes after OFFLINE_SECONDS or more away). The client shows a tip by its own timing rules
-- (never mid-catch, mid-carry or late in the dusk warning, one every TipGapSeconds, a queue of three) and then sends
-- TipSeen(id, skipped?), which saves it in `tipsSeen`. ClearTips ("Show tips again") forgets the tips, not the asks.
-- Three more ids ride TipSeen: `like_ask` (the one unrewarded like ask, kept in tipsSeen and never cleared),
-- `feedback_ask` (the one slide-in faces ask: sets feedbackAsked) and `stuck_help` (the "Need a hand?" card: sets
-- stuckHelpShown for the current tutorialStep).

local Economy = require(script.Parent.Economy)
local Types = require(script.Parent.Types)

local Tips = {}

export type TipKind = "card" | "cut"
export type TipBy = "server" | "client"
export type TipDef = { id: string, kind: TipKind, by: TipBy }

local function tip(id: string, kind: TipKind, by: TipBy): TipDef
	local def: TipDef = { id = id, kind = kind, by = by }
	table.freeze(def :: any) -- frozen at run time; typed as a plain TipDef
	return def
end

-- easy-start.md section 3's table, in its order.
Tips.LIST = table.freeze({
	tip("bowl", "cut", "server"),
	tip("second_cat", "card", "server"),
	tip("stuck_cat", "card", "client"),
	tip("tackle", "card", "server"),
	tip("dropped", "card", "server"),
	tip("night", "card", "server"),
	tip("rank_up", "cut", "server"),
	tip("golden_fish", "cut", "server"),
	tip("potion", "card", "server"),
	tip("dealer", "cut", "server"),
	tip("spin_wheel", "cut", "server"),
	tip("codes_cat", "card", "client"),
	tip("luck", "card", "client"),
	tip("offline", "card", "client"),
} :: { TipDef })

-- The offline card gets its line ("Your cats earned while you were away!") after this long away (section 3).
Tips.OFFLINE_SECONDS = 600

Tips.LIKE_ASK = "like_ask"
Tips.FEEDBACK_ASK = "feedback_ask"
Tips.STUCK_HELP = "stuck_help"

-- SendFeedback's values (section 4): the three faces and the optional chips, as analytics' short fixed values.
Tips.FACES = table.freeze({ "love", "ok", "no" })
Tips.CHIPS = table.freeze({ "too_hard", "confusing", "boring", "laggy", "more_cats", "other" })

local byId: { [string]: TipDef } = {}
for _, def in Tips.LIST do
	byId[def.id] = def
end

function Tips.get(id: string): TipDef?
	return byId[id]
end

-- Whether TipSeen may carry `id`: a tip or one of the three asks.
function Tips.seenId(id: string): boolean
	return byId[id] ~= nil
		or id == Tips.LIKE_ASK
		or id == Tips.FEEDBACK_ASK
		or id == Tips.STUCK_HELP
end

local function anyCount(counts: { [string]: number }): boolean
	for _, count in counts do
		if count > 0 then
			return true
		end
	end
	return false
end

-- What the server's clock says for `due`: `duskWarning` during the last DuskWarningSeconds of the day, `night` from
-- nightfall to sunrise (the dealer's cart is out).
export type Moment = { duskWarning: boolean, night: boolean }

-- The server's tips whose moment follows from the saved state and the clock, not yet seen, in LIST order. The event
-- tips (second_cat, tackle, dropped) and the like ask are sent where they happen.
function Tips.due(profile: Types.PlayerProfile, moment: Moment): { string }
	local tier = Economy.tier(profile)
	local now: { [string]: boolean } = {
		-- Derek's example: food and a bowl, and nothing in the bowl
		bowl = Economy.level(profile, "lure_bowl") >= 1 and profile.bait == nil and anyCount(
			profile.lures
		),
		night = moment.duskWarning,
		rank_up = tier == 1 and Economy.rankUpBlocker(profile) == nil,
		golden_fish = profile.goldenFish > 0,
		potion = anyCount(profile.potions),
		dealer = tier >= 2 and moment.night, -- the camera swings to the cart, which is out only at night
		spin_wheel = profile.tutorialStep >= 5,
	}
	local out: { string } = {}
	for _, def in Tips.LIST do
		if now[def.id] == true and profile.tipsSeen[def.id] ~= true then
			table.insert(out, def.id)
		end
	end
	return out
end

-- A saved tipsSeen: only known tips and the like ask, each true. `veteran` (a save from before version 20 that is
-- past the first loop) has seen every tip, so an old account is not walked through what it already knows.
function Tips.sanitizeSeen(raw: any, veteran: boolean): { [string]: boolean }
	local seen: { [string]: boolean } = {}
	if veteran then
		for _, def in Tips.LIST do
			seen[def.id] = true
		end
	end
	if type(raw) == "table" then
		for key, value in raw do
			if
				type(key) == "string"
				and value == true
				and (byId[key] ~= nil or key == Tips.LIKE_ASK)
			then
				seen[key] = true
			end
		end
	end
	return seen
end

-- A saved stuckHelpShown: tutorialStep keys "0" to "5", each true.
function Tips.sanitizeHelp(raw: any): { [string]: boolean }
	local shown: { [string]: boolean } = {}
	if type(raw) == "table" then
		for step = 0, 5 do
			local key = tostring(step)
			if raw[key] == true then
				shown[key] = true
			end
		end
	end
	return shown
end

-- What ClearTips leaves: the like ask only.
function Tips.cleared(seen: { [string]: boolean }): { [string]: boolean }
	return if seen[Tips.LIKE_ASK] == true then { [Tips.LIKE_ASK] = true } else {}
end

return Tips
