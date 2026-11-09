--!strict
-- The like and favourite gifts (like-prompts.md section 2, #1947 with Set 10 Q3), pure: two thank-you gifts for time
-- played on the account (stats.playtimeSeconds plus the session), once each per account. The gift is for playing,
-- never for liking or favouriting: it is paid when the card is sent, before any button, and Close keeps it.
--   like at Config.LikeGiftMinutes: LikeGiftIncomeMinutes of the cafe's income and a Tip Potion
--   fav at Config.FavGiftMinutes: FavGiftIncomeMinutes of income and a Tip, a Lucky and a Swift Potion
-- The like comes first. A save past both marks pays the like, then the favourite GAP_SECONDS later in the session,
-- so the two cards never stack.
-- #2791 (retention-ideas.md 5a, Derek2 2026-11-09: "we have gift milestones can be improved"): small steps join the
-- same track, Config.PlaytimeGiftSteps (2, 4 and 6 minutes before the like, 15 and 20 between the like and the
-- favourite), each paid with a toast instead of a card. The ladder is STEPS in minute order; a step is skipped once a
-- later one is paid, so an account that had the like before the ladder never gets the 2 to 6 minute steps.
--   due(profile, played) -> Step?    the step to pay now, if any (one at a time, in order)
--   prize(step) -> IndexPrize        what it pays (Payout)
--   mark(profile, step)              paid: never again on this account
--   isCard(step)                     the like and the favourite show their card; the rest a toast
--   upcoming(profile, n) -> { GiftStepView }  the next `n` steps still to come, for the HUD's gift icon
--   report(raw) -> (Kind?, button?)  a playtime_gift report "<kind>:<button>" read, analytics only

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local PlaytimeGifts = {}

export type Kind = "like" | "fav"
export type Step = string -- a Kind, or a Config.PlaytimeGiftSteps id ("m2", "m4", "m6", "m15", "m20")

local KINDS: { Kind } = { "like", "fav" }
table.freeze(KINDS)
PlaytimeGifts.KINDS = KINDS

type StepDef = { id: Step, minutes: number }

-- #2791: the whole ladder in minute order, the like and the favourite among the small steps.
local STEPS: { StepDef } = {
	{ id = "like", minutes = Config.LikeGiftMinutes },
	{ id = "fav", minutes = Config.FavGiftMinutes },
}
local EXTRA: { [string]: Types.IndexPrize } = {}
for _, row in Config.PlaytimeGiftSteps do
	table.insert(STEPS, { id = row.id, minutes = row.minutes })
	EXTRA[row.id] = row.prize :: any -- the IndexPrize fields Config uses
end
table.sort(STEPS, function(a: StepDef, b: StepDef): boolean
	return a.minutes < b.minutes
end)
PlaytimeGifts.STEPS = STEPS
PlaytimeGifts.BUTTONS = table.freeze({ "like", "favourite", "close", "gotit" }) :: { string } -- playtime_gift's buttons
-- (#2705: "gotit" is the like card's one button on touch, where Roblox has no in-game like prompt)
PlaytimeGifts.GAP_SECONDS = 60

-- Whether `step` has been paid on this account.
function PlaytimeGifts.paid(profile: Types.PlayerProfile, step: Step): boolean
	if step == "like" then
		return profile.likeGift
	elseif step == "fav" then
		return profile.favGift
	end
	return profile.giftSteps[step] == true
end

-- The steps still to come, in order: unpaid and with no later step paid.
local function ahead(profile: Types.PlayerProfile): { StepDef }
	local out: { StepDef } = {}
	for i = #STEPS, 1, -1 do
		local step = STEPS[i]
		if PlaytimeGifts.paid(profile, step.id) then
			break
		end
		table.insert(out, 1, step)
	end
	return out
end

-- The step due at `played` seconds of play on the account, the earliest first, or nil.
function PlaytimeGifts.due(profile: Types.PlayerProfile, played: number): Step?
	local first = ahead(profile)[1]
	if first ~= nil and played >= first.minutes * 60 then
		return first.id
	end
	return nil
end

export type GiftStepView = Types.GiftStepView

-- #2791: the next `n` steps still to come, for the HUD's gift icon and its popover; empty once the ladder is done.
function PlaytimeGifts.upcoming(profile: Types.PlayerProfile, n: number): { GiftStepView }
	local out: { GiftStepView } = {}
	for _, step in ahead(profile) do
		if #out >= n then
			break
		end
		table.insert(
			out,
			{ id = step.id, at = step.minutes * 60, prize = PlaytimeGifts.prize(step.id) }
		)
	end
	return out
end

function PlaytimeGifts.isCard(step: Step): boolean
	return step == "like" or step == "fav"
end

function PlaytimeGifts.prize(step: Step): Types.IndexPrize
	if step == "like" then
		return { coinSeconds = Config.LikeGiftIncomeMinutes * 60, potions = { tip_potion = 1 } }
	elseif step == "fav" then
		return {
			coinSeconds = Config.FavGiftIncomeMinutes * 60,
			potions = { tip_potion = 1, lucky_potion = 1, swift_potion = 1 },
		}
	end
	local extra: Types.IndexPrize = EXTRA[step] or {}
	return table.clone(extra)
end

function PlaytimeGifts.mark(profile: Types.PlayerProfile, step: Step)
	if step == "like" then
		profile.likeGift = true
	elseif step == "fav" then
		profile.favGift = true
	elseif EXTRA[step] ~= nil then
		profile.giftSteps[step] = true
	end
end

-- A save's giftSteps from anything: only the known small steps, only `true` kept.
function PlaytimeGifts.sanitize(raw: unknown): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(raw) == "table" then
		for id in EXTRA do
			if (raw :: any)[id] == true then
				out[id] = true
			end
		end
	end
	return out
end

-- A playtime_gift report's value read: (kind, button) when both are known, else nil.
function PlaytimeGifts.report(raw: unknown): (Kind?, string?)
	if type(raw) ~= "string" or #raw > 16 then
		return nil, nil
	end
	local kind, button = string.match(raw, "^(%a+):(%a+)$")
	if kind ~= "like" and kind ~= "fav" then
		return nil, nil
	end
	if button == nil or table.find(PlaytimeGifts.BUTTONS, button) == nil then
		return nil, nil
	end
	local read: Kind = if kind == "like" then "like" else "fav"
	return read, button
end

return PlaytimeGifts
