--!strict
-- #3558 (Derek 2026-11-12, on the Cat Arcade mock: "make sure all the other stations menu's etc look that good and
-- organized (and also work on phone)"): the station menu family's shared look, behind the `menuFamily` switch
-- (shared/LiveFlags, off by default). With the switch on, every dark window (Panel's `dark`) wears the family dress:
--   the cocoa body and cards of Theme.dark (PALETTE, #3965: violet, then near black, then back to cocoa; same keys, so a
--     window that colours itself from its palette changes with no code of its own),
--   a plain title band (BULBS = 0: Derek 2026-11-13 #3965 dropped the party bulbs for a cleaner look), a round
--     picture badge that sits straight, and no ears
--     (Components/Panel reads `on()`).
-- A screen takes its palette as `local PAL = MenuFamily.pal`: each read gives the family's colour when the switch
-- was on at this session's start and Theme.dark's otherwise (`on` keeps its first answer).
-- Every text colour of PALETTE reads at 4.5:1 or better on the card, and white, `subtext`, `good` and `gold` do on
-- the body too (measured when the colours were picked; the UI gate checks the windows).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local MenuFamily = {}

MenuFamily.FLAG = "menuFamily"

export type Palette = typeof(Theme.dark)

-- #3965 (Derek 2026-11-13 17:32: "do the old colour for menus", "gives cozy vibes"): the cocoa body and cards of
-- Theme.dark again (it was violet, then near black for an hour); the cream picture cards, the plain title band and the
-- round badge stay
MenuFamily.PALETTE = table.clone(Theme.dark) :: Palette

-- the bulbs along the top of the title band: how many, their size in px and their two colours
MenuFamily.BULBS = 0 -- #3965: none (was 14)
MenuFamily.BULB_SIZE = 6
MenuFamily.BULB_COLORS = { Color3.fromHex("FFF096"), Color3.fromHex("FFFFFF") }

-- One look for a whole session: the switch is read the first time anything asks (the UI's build at the start) and
-- kept. Windows take some colours when they are built and others each time they paint, so a switch that flipped
-- mid-session left cream cards under white words (Quests, the Mystic Pool's cat list) and an old Store beside new
-- windows (Studio look, 2026-11-13). A flip now reaches each player at their next join.
local latched: boolean? = nil

function MenuFamily.on(): boolean
	local was = latched
	if was ~= nil then
		return was
	end
	local now = LiveFlags.shown(
		MenuFamily.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. MenuFamily.FLAG)
	)
	latched = now
	return now
end

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

-- A bright colour of its own (a trait's) for words on a picture card: as it is on a dark card, and darkened halfway
-- to the ink on the cream card, where a bright yellow or pink does not read.
function MenuFamily.onCard(color: Color3): Color3
	return if MenuFamily.on() then color:Lerp(MenuFamily.CARD.text, 0.5) else color
end

-- A name on a picture card: the dark outline that lifts white words off a dark card, and nothing on the cream card,
-- where the words are dark already (a dark outline round dark words blurs them).
function MenuFamily.outline(label: GuiObject, thickness: number?)
	if not MenuFamily.on() then
		Outline.text(label, thickness)
	end
end

return MenuFamily
