--!strict
-- #2797 (retention-ideas.md 5d, Derek2: "reward for inviting and do after 5 min-15 min dont want to overwhelm early"):
-- the one invite card with its reward, on the slide-in ask card (Invite, Not now). Once per account, never before
-- cardFrom seconds of play: at the first good moment between cardFrom and cardBy (a Rare-or-better cat caught,
-- rescued or at the bowl, or the Grand Opening's step 4), else at cardBy, each at the next calm moment. The server
-- sends PlayerState.invite = { cardShown, fish, leftToday, cardFrom, cardBy } and pays the reward; the card's
-- InviteCard reports are analytics only. Pure, so the cloud specs check it.
--   due(view, played, good) -> boolean   show it now (before the calm-moment wait)
--   goodRarity(rarity) -> boolean        Rare or better
--   title(view) -> string                "Invite a friend: you both get 🐟 20 when they start playing!"
--   played(sent, sentAt, now) -> number? the server's playSeconds counted on from when it came

local InviteCardLogic = {}

InviteCardLogic.INVITE = "Invite"
InviteCardLogic.NOT_NOW = "Not now"
InviteCardLogic.SECONDS = 20
InviteCardLogic.GOOD_STEP = 4 -- the Grand Opening's step 4, Tier 2

local GOOD: { [string]: boolean } = { Rare = true, Epic = true, Legendary = true, Mythical = true }

function InviteCardLogic.goodRarity(rarity: unknown): boolean
	return type(rarity) == "string" and GOOD[rarity] == true
end

function InviteCardLogic.due(view: unknown, played: number?, good: boolean): boolean
	if type(view) ~= "table" or played == nil then
		return false
	end
	local raw = view :: any
	local from, by = raw.cardFrom, raw.cardBy
	if raw.cardShown == true or type(from) ~= "number" or type(by) ~= "number" then
		return false
	end
	if played < from then
		return false -- never before minute 5 (Derek2: "dont want to overwhelm early")
	end
	return good or played >= by
end

function InviteCardLogic.title(view: unknown): string
	local fish = if type(view) == "table" then (view :: any).fish else nil
	if type(fish) ~= "number" or fish <= 0 then
		return "Invite a friend to play with you!"
	end
	return ("Invite a friend: you both get 🐟 %d when they start playing!"):format(fish)
end

function InviteCardLogic.played(sent: unknown, sentAt: number, now: number): number?
	if type(sent) ~= "number" then
		return nil
	end
	return sent + math.max(0, now - sentAt)
end

return InviteCardLogic
