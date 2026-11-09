--!strict
-- The like and favourite gift cards (#1947, like-prompts.md section 2): what they say, the gift's pictures and when one
-- may show. The gift is for playing, never for the like: the server has paid it before the card comes, so Close keeps
-- it, and no line here says the gift needs a like. Pure, so the specs load it.
--   TEXT[kind]                 the card's words and its first button ("like" or "fav")
--   prize(prize, paid) -> IndexPrize   shared/PlaytimeGifts.prize with the coins Payout really paid ("+$12345")
--   report(kind, button) -> string     the playtime_gift report: "like:like", "fav:favourite", "like:close",
--                                      "like:gotit" (#2705)
--   single(kind, touch) -> boolean     #2705: Got it alone, the like card on touch
--   canShow(gate) -> boolean           idle GiftIdleSeconds and not catching, rescuing, carrying, in the intro or a menu

export type Kind = "like" | "fav"

export type Text = {
	title: string,
	body: string,
	action: string, -- the first button's words
	button: string, -- the first button's playtime_gift name
	icon: string,
	after: string, -- the body once the first button is pressed
}

export type Gate = {
	idleSeconds: number,
	idleNeeded: number, -- Config.GiftIdleSeconds
	catching: boolean, -- the catch circles or the rescue bar
	carrying: boolean,
	intro: boolean,
	menuOpen: boolean, -- a window, a card or the recap
}

local GiftCardLogic = {}

GiftCardLogic.GIFT_LINE = "Gift added!"
GiftCardLogic.CLOSE = "Close"
GiftCardLogic.CLOSE_BUTTON = "close"
GiftCardLogic.IDLE_SECONDS = 3 -- Config.GiftIdleSeconds when the Config has none
-- #2705 (Derek2 11-09: mobile players may "tab out which leaves the game"): on touch the like card has one button,
-- Got it, which closes it; the words already say to tap 👍 next time
GiftCardLogic.GOT_IT = "Got it"
GiftCardLogic.GOT_IT_BUTTON = "gotit"

GiftCardLogic.TEXT = table.freeze({
	like = table.freeze({
		title = "Thanks for playing!",
		-- #2705: the gift is for playing, and the 👍 is for next time on the game's page, so nobody leaves to do it
		body = "Here's a gift for playing! Enjoying the cafe? Next time you're on the game's page, a 👍 helps others find it.",
		-- #1981: Roblox gives a game no like prompt (Favorite has one), so the button says what it does: it shows
		-- where the thumbs-up is, and nothing opens (Derek2 pressed "Like the game" and expected a prompt)
		action = "How to like",
		button = "like",
		icon = "👍",
		after = "The 👍 is under the game's name on its page. No need to leave now, next time is perfect. Thank you!",
	}),
	fav = table.freeze({
		title = "You've played 30 minutes!",
		body = "Here's another gift. Favorite the game to find it quickly next time.",
		action = "Favorite",
		button = "favourite",
		icon = "⭐",
		after = "Thank you!",
	}),
}) :: { [string]: Text }

-- The coins in Payout's "+$12345" line, or nil.
function GiftCardLogic.coins(paid: { string }?): number?
	if type(paid) ~= "table" then
		return nil
	end
	for _, line in paid do
		if type(line) == "string" then
			local digits = line:match("^%+%$(%d+)$")
			if digits then
				return tonumber(digits)
			end
		end
	end
	return nil
end

-- The prize to draw: the coins really paid in place of coinSeconds when Payout's line has them.
function GiftCardLogic.prize(prize: { [string]: any }, paid: { string }?): { [string]: any }
	local out = table.clone(prize)
	local coins = GiftCardLogic.coins(paid)
	if coins ~= nil then
		out.coins = coins
		out.coinSeconds = nil
	end
	return out
end

-- Whether the card shows Got it alone (the like card on touch, #2705).
function GiftCardLogic.single(kind: Kind, touch: boolean): boolean
	return kind == "like" and touch
end

function GiftCardLogic.report(kind: Kind, button: string): string
	return kind .. ":" .. button
end

function GiftCardLogic.canShow(gate: Gate): boolean
	return gate.idleSeconds >= gate.idleNeeded
		and not gate.catching
		and not gate.carrying
		and not gate.intro
		and not gate.menuOpen
end

return GiftCardLogic
