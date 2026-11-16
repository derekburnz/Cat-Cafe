--!strict
-- #3558 (Derek 2026-11-12, on the Cat Arcade mock: "make sure all the other stations menu's etc look that good and
-- organized (and also work on phone)"): the station menu family's shared look, the only menu look since #4657
-- (the `menuFamily` switch is no longer read). Every dark window (Panel's `dark`) wears the family dress:
--   the cocoa body and cards of Theme.dark (PALETTE, #3965: violet, then near black, then back to cocoa; same keys, so a
--     window that colours itself from its palette changes with no code of its own),
--   a plain title band (BULBS = 0: Derek 2026-11-13 #3965 dropped the party bulbs for a cleaner look), a round
--     picture badge that sits straight, and no ears
--     (Components/Panel).
-- A screen takes its palette as `local PAL = MenuFamily.pal` (the family's colours; #4657: the only look).
-- Every text colour of PALETTE reads at 4.5:1 or better on the card, and white, `subtext`, `good` and `gold` do on
-- the body too (measured when the colours were picked; the UI gate checks the windows).

local Theme = require(script.Parent.Parent.Theme)

local MenuFamily = {}

export type Palette = typeof(Theme.dark)

-- #3965 (Derek 2026-11-13 17:32: "do the old colour for menus", "gives cozy vibes"): the cocoa body and cards of
-- Theme.dark again (it was violet, then near black for an hour); the cream picture cards, the plain title band and the
-- round badge stay
MenuFamily.PALETTE = table.clone(Theme.dark) :: Palette

-- the bulbs along the top of the title band: how many, their size in px and their two colours
MenuFamily.BULBS = 0 -- #3965: none (was 14)
MenuFamily.BULB_SIZE = 6
MenuFamily.BULB_COLORS = { Color3.fromHex("FFF096"), Color3.fromHex("FFFFFF") }

-- #4657 (Derek 2026-11-15 23:28 UTC, after #4607 sent fresh servers back to the old look: "remove the old stuff from
-- code so it doesn't happen again"): the family look is the only look. The `menuFamily` switch and MenuFamily.on()
-- are gone, so no server, Studio session or slow first DataStore read can draw the old one.

-- The family's picture cards (the mocks' cream cards on the dark body): the colours for a card and for what sits
-- on it, with the same keys as PALETTE. Every text colour reads at 4.5:1 or better on `card`.
MenuFamily.CARD = {
	panel = Theme.dark.panel,
	card = Color3.fromHex("FFF6E8"), -- Model-Agent's kit: cream card
	cardStroke = Color3.fromHex("2C1642"), -- the kit's ink
	text = Color3.fromHex("2C1642"),
	subtext = Color3.fromHex("6A4E7E"), -- the kit's soft purple words, a shade darker to read at 4.5:1
	line = Color3.fromHex("D9C9A6"), -- empty stars, bar tracks and chips
	good = Color3.fromHex("1F7A3E"),
	gold = Color3.fromHex("8F5A00"), -- gold words on cream (the bright gold does not read there)
	caramel = Color3.fromHex("D9C7F5"),
	red = Color3.fromHex("B3261E"),
	warn = Color3.fromHex("8F5200"),
	goldCard = Color3.fromHex("FFE296"), -- the kit's picture tile
} :: Palette

function MenuFamily.palette(): Palette
	return MenuFamily.PALETTE
end

MenuFamily.pal = MenuFamily.PALETTE

-- A screen's picture cards take their colours as `local CARD = MenuFamily.card`: the cream card's (#4657: the only
-- look).
MenuFamily.card = MenuFamily.CARD

-- A rarity as words on a picture card: its ink on the family's cream card.
function MenuFamily.rarity(rarity: string?): Color3
	return Theme.rarityInk(rarity)
end

-- A bright colour of its own (a trait's) for words on a picture card: darkened halfway to the ink on the cream card,
-- where a bright yellow or pink does not read.
function MenuFamily.onCard(color: Color3): Color3
	return color:Lerp(MenuFamily.CARD.text, 0.5)
end

-- A name on a picture card: nothing on the cream card, where the words are dark already (a dark outline round dark
-- words blurs them). Kept so the call sites read the same.
function MenuFamily.outline(_label: GuiObject, _thickness: number?) end

return MenuFamily
