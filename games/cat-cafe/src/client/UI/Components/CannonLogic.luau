--!strict
-- The Cat Cannon's rules and words for the UI (F84, hometown-cannon.md sections 3 and 5; Derek 2026-10-28 13:39 to
-- 14:10): which places a cannon's picker lists, what each Launch button and the line under the title say at dusk
-- and at night, the hints that point a player at the cannon, and when the destination's name card in the clouds
-- pops in, wobbles and flies off. Every catching area is a cannon area since 14:09, the Alleyway included.
--   destinations(areas, tier, cannonId)  the picker's cards: opened areas in tier order, Town Square first from a camp
--   moreToOpen(areas, tier)  whether a rank up opens more ("More open as you rank up.")
--   button(destination, closed, dusk, carrying)  a card's Launch: "launch", "carrying", "dusk" or "night"
--   notice(closed, dusk, carrying, remaining)  the line under the picker's title, or nil for the plain one
--   cardTitle            "To the Woods!" (the card's sub line went 2026-11-03)
--   cardTimes(hold?, from?) / cardPhase(elapsed, hold?, from?)  the name card's steps, seconds after its start
--   hint(view)  the cannon hint over the HUD, or nil
-- Pure, no Theme, so the cloud spec runner can load it.

export type AreaLike = { id: string, name: string, tier: number }
export type Destination = { id: string, name: string, tier: number }
export type ButtonState = "launch" | "carrying" | "dusk" | "night"
export type CardPhase = "waiting" | "in" | "wobble" | "out" | "gone"
export type HintView = {
	on: boolean, -- the cannon is live on this server (UI.cannon.setEnabled)
	wild: boolean, -- the player is in a wild area, camp included
	intro: boolean, -- the intro cutscene is playing
	launched: boolean, -- the player has flown this session
	tier: number,
	tutorialStep: number, -- state.tutorialStep: 0 and 1 are before the first catch
	told: boolean, -- the onboarding line (UI.tutorial.show) is up
	opened: string?, -- the area a rank up to Tier 2 opened this session, until the next launch
	first: string?, -- the Tier 1 area's name, for the first flight
}

local CannonLogic = {}

CannonLogic.TOWN = "town" -- the Town Square cannon's id, and a camp cannon's way home
CannonLogic.TOWN_NAME = "Town Square"
CannonLogic.CARRY_SUB = "Bring it to the camp!" -- the carry banner's line once every area is a wild area
CannonLogic.CARRY_REFUSED = "Bring your cat to the camp first"
CannonLogic.HINT_TIER = 2 -- the rank up that gets its own "is open!" hint (section 3a)
-- how long that hint, its marker and its trail of dots stay up when the player does not fly (Derek 2026-11-03: "the
-- tutorial yellow dots are still showing")
CannonLogic.OPENED_HINT_SECONDS = 45

-- The name card in the clouds, seconds after CannonLaunchAt: it pops in as the clouds cover the screen (VFX: 1.6),
-- wobbles as the tunnel takes the destination's colour (2.0), zips up and off as the clouds part (2.4) and is gone by
-- 2.6. Since #1163 only the intro's shot 2 keeps this schedule (cardTimes(0.4)).
CannonLogic.CARD_IN = 1.6
CannonLogic.CARD_WOBBLE = 2.0
CannonLogic.CARD_OUT = 2.4
CannonLogic.CARD_GONE = 2.6
-- A player's own flight (Derek 2026-11-04, #1163: "show right after the destination menu closes"): the card starts
-- the moment the picker closes on the server's accepted CannonLaunch (a refused Launch never gets one), pops in at
-- once, wobbles at 0.3, zips off at 0.6 as the BOOM fires (0.5 s after CannonLaunchAt) and is gone by 0.8.
CannonLogic.CHOSEN_IN = 0
CannonLogic.CHOSEN_HOLD = 0.6

-- The cards `cannonId`'s picker shows a player at `tier`: every area the tier has opened, in tier order (catalog
-- order within a tier), and from a camp's cannon Town Square first and never the camp's own area.
function CannonLogic.destinations(
	areas: { AreaLike },
	tier: number,
	cannonId: string
): { Destination }
	local list: { Destination } = {}
	local order: { [string]: number } = {}
	for index, area in areas do
		if area.tier <= tier and area.id ~= cannonId and area.id ~= CannonLogic.TOWN then
			table.insert(list, { id = area.id, name = area.name, tier = area.tier })
			order[area.id] = index
		end
	end
	table.sort(list, function(a: Destination, b: Destination): boolean
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return order[a.id] < order[b.id]
	end)
	if cannonId ~= CannonLogic.TOWN then
		table.insert(list, 1, { id = CannonLogic.TOWN, name = CannonLogic.TOWN_NAME, tier = 0 })
	end
	return list
end

function CannonLogic.moreToOpen(areas: { AreaLike }, tier: number): boolean
	for _, area in areas do
		if area.tier > tier then
			return true
		end
	end
	return false
end

-- A card's Launch. Carrying shuts every one (the server refuses it); Town Square is open at dusk and at night, so a
-- player at a camp can always fly home; an area shuts in the dusk warning and at night.
function CannonLogic.button(
	destination: string,
	closed: boolean,
	dusk: boolean,
	carrying: boolean
): ButtonState
	if carrying then
		return "carrying"
	elseif destination == CannonLogic.TOWN then
		return "launch"
	elseif closed then
		return "night"
	elseif dusk then
		return "dusk"
	end
	return "launch"
end

-- 160 -> "2m 40s", 45 -> "45s", counted up so 159.2 s still says 2m 40s.
local function countdown(remaining: number): string
	local seconds = math.max(0, math.ceil(remaining - 1e-6))
	if seconds >= 60 then
		return ("%dm %ds"):format(seconds // 60, seconds % 60)
	end
	return ("%ds"):format(seconds)
end
CannonLogic.countdown = countdown

-- The line under the picker's title: why Launch is off, with the sunrise countdown at night. nil when every opened
-- area can be flown to.
function CannonLogic.notice(
	closed: boolean,
	dusk: boolean,
	carrying: boolean,
	remaining: number?
): string?
	if carrying then
		return CannonLogic.CARRY_REFUSED
	elseif closed then
		return if remaining
			then "Closed until sunrise · " .. countdown(remaining)
			else "Closed until sunrise"
	elseif dusk then
		return "Night is coming. Launch opens again at sunrise."
	end
	return nil
end

function CannonLogic.cardTitle(destination: string, name: string): string
	if destination == CannonLogic.TOWN then
		return "To " .. CannonLogic.TOWN_NAME .. "!"
	end
	return "To the " .. name .. "!"
end

-- When the card pops in, wobbles, zips off and is gone, in seconds after its start. `from` is when it pops in
-- (CARD_IN, in the clouds, by default; CHOSEN_IN for a player's own flight) and `hold` how long it stays from popping
-- in to zipping off (CARD_OUT - CARD_IN, 0.8 s, by default; CHOSEN_HOLD for a player's own flight); the intro's shot 2
-- holds it 0.4 s in the clouds (intro-cutscene.md section 4). The zip takes CARD_GONE - CARD_OUT (0.2 s) either way.
function CannonLogic.cardTimes(hold: number?, from: number?): (number, number, number, number)
	local inAt = math.max(0, from or CannonLogic.CARD_IN)
	local shown = math.max(0, hold or (CannonLogic.CARD_OUT - CannonLogic.CARD_IN))
	local out = inAt + shown
	return inAt, inAt + shown / 2, out, out + (CannonLogic.CARD_GONE - CannonLogic.CARD_OUT)
end

function CannonLogic.cardPhase(elapsed: number, hold: number?, from: number?): CardPhase
	local inAt, wobbleAt, outAt, goneAt = CannonLogic.cardTimes(hold, from)
	if elapsed < inAt then
		return "waiting"
	elseif elapsed < wobbleAt then
		return "in"
	elseif elapsed < outAt then
		return "wobble"
	elseif elapsed < goneAt then
		return "out"
	end
	return "gone"
end

-- The hint line and arrow at the cannon (section 3a): "The Park is open! Hop in the cannon to fly there." after the
-- rank up to Tier 2, and "Hop in the cannon to fly to the Alleyway!" for a Tier 1 player who has not flown yet this
-- session. Only in town and never during the intro. Before the first catch it takes the place of the onboarding
-- line (the catch needs the flight); after that the onboarding line comes first.
function CannonLogic.hint(view: HintView): string?
	if not view.on or view.wild or view.intro then
		return nil
	end
	local text: string? = nil
	if view.opened then
		text = "The " .. view.opened .. " is open! Hop in the cannon to fly there."
	elseif not view.launched and view.tier <= 1 and view.first then
		text = "Hop in the cannon to fly to the " .. view.first .. "!"
	end
	if text and view.told and view.tutorialStep >= 2 then
		return nil
	end
	return text
end

return CannonLogic
