--!strict
-- #3558 (Derek 2026-11-12, on the Cat Arcade mock: "make sure all the other stations menu's etc look that good and
-- organized (and also work on phone)"): the station menu family's shared look, behind the `menuFamily` switch
-- (shared/LiveFlags, off by default). With the switch on, every dark window (Panel's `dark`) wears the family dress:
--   a violet body with deep violet cards, in place of the cocoa body (PALETTE, the same keys as Theme.dark, so a
--     window that colours itself from its palette changes with no code of its own),
--   a row of party bulbs along the top of its title band, a round picture badge that sits straight, and no ears
--     (Components/Panel reads `on()`).
-- A screen takes its palette as `local PAL = MenuFamily.pal`: each read gives the family's colour while the switch
-- is on and Theme.dark's otherwise, so a window opened after the switch flips has the new look and a window built
-- before keeps the one it was built with.
-- Every text colour of PALETTE reads at 4.5:1 or better on the card, and white, `subtext`, `good` and `gold` do on
-- the body too (measured when the colours were picked; the UI gate checks the windows).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local MenuFamily = {}

MenuFamily.FLAG = "menuFamily"

export type Palette = typeof(Theme.dark)

MenuFamily.PALETTE = {
	panel = Color3.fromHex("6646A8"),
	card = Color3.fromHex("3C286E"),
	cardStroke = Color3.fromHex("24163F"),
	text = Theme.colors.white,
	subtext = Color3.fromHex("E6DCFA"),
	line = Color3.fromHex("513893"), -- bar tracks and chips
	good = Color3.fromHex("9BF5AE"),
	gold = Color3.fromHex("FFD650"),
	caramel = Color3.fromHex("D9C7F5"), -- scroll bars
	red = Color3.fromHex("FFC4BF"),
	warn = Color3.fromHex("FFC896"),
	goldCard = Color3.fromHex("5A4370"), -- a gold-tinted card
} :: Palette

-- the bulbs along the top of the title band: how many, their size in px and their two colours
MenuFamily.BULBS = 14
MenuFamily.BULB_SIZE = 6
MenuFamily.BULB_COLORS = { Color3.fromHex("FFF096"), Color3.fromHex("FFFFFF") }

function MenuFamily.on(): boolean
	return LiveFlags.shown(
		MenuFamily.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. MenuFamily.FLAG)
	)
end

-- The family's picture cards (the mocks' cream cards on the violet body): the colours for a card and for what sits
-- on it, with the same keys as PALETTE. Every text colour reads at 4.5:1 or better on `card`.
MenuFamily.CARD = {
	panel = Color3.fromHex("6646A8"),
	card = Color3.fromHex("FFF4DC"),
	cardStroke = Color3.fromHex("24163F"),
	text = Color3.fromHex("33205F"),
	subtext = Color3.fromHex("5A4680"),
	line = Color3.fromHex("D9C9A6"), -- empty stars, bar tracks and chips
	good = Color3.fromHex("1F7A3E"),
	gold = Color3.fromHex("8F5A00"), -- gold words on cream (the bright gold does not read there)
	caramel = Color3.fromHex("D9C7F5"),
	red = Color3.fromHex("B3261E"),
	warn = Color3.fromHex("8F5200"),
	goldCard = Color3.fromHex("FFE49A"),
} :: Palette

function MenuFamily.palette(): Palette
	return if MenuFamily.on() then MenuFamily.PALETTE else Theme.dark
end

MenuFamily.pal = (
	setmetatable({}, {
		__index = function(_, key: string): any
			return (MenuFamily.palette() :: any)[key]
		end,
	}) :: any
) :: Palette

-- A screen's picture cards take their colours as `local CARD = MenuFamily.card`: the cream card's while the switch
-- is on, Theme.dark's otherwise (so the same code draws today's dark card).
MenuFamily.card = (
	setmetatable({}, {
		__index = function(_, key: string): any
			return (if MenuFamily.on() then MenuFamily.CARD else Theme.dark :: any)[key]
		end,
	}) :: any
) :: Palette

-- A rarity as words on a picture card: its ink on the family's cream card, its light colour on today's dark card.
function MenuFamily.rarity(rarity: string?): Color3
	return if MenuFamily.on() then Theme.rarityInk(rarity) else Theme.rarityLight(rarity)
end

-- A name on a picture card: the dark outline that lifts white words off a dark card, and nothing on the cream card,
-- where the words are dark already (a dark outline round dark words blurs them).
function MenuFamily.outline(label: GuiObject, thickness: number?)
	if not MenuFamily.on() then
		Outline.text(label, thickness)
	end
end

return MenuFamily
