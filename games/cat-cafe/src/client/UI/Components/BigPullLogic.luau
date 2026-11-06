--!strict
-- The big pull card's choices, words and times (F89, luck-and-rare-moments.md 2a and 2b; F99 rainbow-coat.md
-- section 2), pure. Screens/BigPull draws the card from these.
--   forCat(rarity, gold, variant) -> Card?        the card the server's SecuredRare plays on its owner's screen
--   forPiece(rarity) -> Card?                     a crate piece's: Legendary and Mythical only
--   word(card, rarity, gold, variant) -> string   "LEGENDARY!", "GOLD MYTHICAL!", "RAINBOW COMMON!", "FIRST EPIC!"
--   tone(gold, variant) -> Tone                   what colours the edges, the rays and the word
--   times(card) -> (tapAfter, closeAt)            seconds from the card's start
--   mine(userId, localUserId) -> boolean          only the securing player's screen plays the card
--   wowWord(rarity, first) -> string              #1897 the first wow cat's word: "YOUR FIRST RARE!", "AN EPIC VISITOR!"
--   wowLine(rarity, first) -> string              its toast when there is no card: "Your first Rare!"
--   WOW_LINE                                      the bowl's line while that cat is on its way

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RareMoments =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RareMoments")) :: any

local BigPullLogic = {}

-- "big": the 2.4 s card of a Legendary, a Mythical, a gold Epic or better, any rainbow cat and a Legendary or Mythical
-- crate piece; "first_epic": the smaller card of the first Epic a player ever secures.
export type Card = "big" | "first_epic"
-- "rarity": the rarity's colour; "gold": the gold coat's; "rainbow": a rainbow coat's bands
export type Tone = "rarity" | "gold" | "rainbow"

-- The rarity word slams in from this size.
BigPullLogic.SLAM = 1.6

-- Seconds a crate piece's card waits after the prize shows: Effects' crate glows and shakes this long
-- (Presets.bigPull.crateShake) before its lid blows open, and the card lands with the lid.
BigPullLogic.CRATE_HOLD = 0.6

local TIMES: { [string]: { number } } = {
	big = { 1, 2.4 },
	first_epic = { 1, 2 },
}

local function coat(gold: boolean?, variant: string?): string?
	if variant == "rainbow" then
		return "rainbow"
	elseif gold == true or variant == "gold" then
		return "gold"
	end
	return nil
end

-- The server sends SecuredRare for a big pull to everyone and, for a first Epic, to its owner alone with a plain Epic,
-- so a plain Epic here is always the first one.
function BigPullLogic.forCat(rarity: string, gold: boolean?, variant: string?): Card?
	if type(rarity) ~= "string" then
		return nil
	end
	return RareMoments.card(rarity, coat(gold, variant), false)
end

function BigPullLogic.forPiece(rarity: string?): Card?
	if rarity == "Legendary" or rarity == "Mythical" then
		return "big"
	end
	return nil
end

function BigPullLogic.word(card: Card, rarity: string, gold: boolean?, variant: string?): string
	if card == "first_epic" then
		return "FIRST EPIC!"
	end
	local which = coat(gold, variant)
	local prefix = if which == "rainbow" then "RAINBOW " elseif which == "gold" then "GOLD " else ""
	return prefix .. rarity:upper() .. "!"
end

function BigPullLogic.tone(gold: boolean?, variant: string?): Tone
	local which = coat(gold, variant)
	if which == "rainbow" then
		return "rainbow"
	elseif which == "gold" then
		return "gold"
	end
	return "rarity"
end

function BigPullLogic.times(card: Card): (number, number)
	local pair = TIMES[card] or TIMES.big
	return pair[1], pair[2]
end

function BigPullLogic.mine(userId: unknown, localUserId: number): boolean
	return type(userId) == "number" and userId == localUserId
end

-- #1897 (first-hour.md 2): the second bait result is Rare or better, and the bowl says so honestly while it waits
BigPullLogic.WOW_LINE = "Your next cat will be Rare or better!"

-- "a Rare", "an Epic"
local function article(rarity: string): string
	return if string.match(rarity, "^[AEIOUaeiou]") then "an" else "a"
end

-- The card's word for the first wow cat: the first of its rarity the player has, else a visitor of it
function BigPullLogic.wowWord(rarity: string, first: boolean?): string
	if first then
		return "YOUR FIRST " .. rarity:upper() .. "!"
	end
	return ("%s %s VISITOR!"):format(article(rarity):upper(), rarity:upper())
end

function BigPullLogic.wowLine(rarity: string, first: boolean?): string
	if first then
		return ("Your first %s!"):format(rarity)
	end
	local a = article(rarity)
	return ("%s%s %s visitor!"):format(a:sub(1, 1):upper(), a:sub(2), rarity)
end

return BigPullLogic
