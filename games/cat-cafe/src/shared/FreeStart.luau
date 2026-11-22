--!strict
-- #5533 v2 (Design-Agent's new-start-v2-spec.md, Derek 2026-11-20: "the steps right now are dull and hard to follow and
-- feel pushy follow other games"): play first, no tutorial steps. Behind the switch `freeStart` (LiveFlags,
-- OFF_BY_DEFAULT) a new save joins once, on its first session before its first step, and keeps it for good:
-- - it starts at the Alleyway landing, facing its waiting stray, with no flight (CannonService's homeArrival), by day;
-- - no dim, TutorialArrow, spotlight, catch dim, tutorial strip or tutorial move until Tier 3 (`active`);
-- - it is in the catch first order (TutorialOrder.CATCH), so orderSplit never puts it in the bowl first arm.
-- The mark is saved in the telemetry record (freeStart, no save version) and put on the Player as the attribute
-- FreeStart (ATTR) so both sides read the same answer. A save already in an orderSplit arm keeps that arm.
-- Behind its own switch `streetCats`: while a freeStart save is in its first STREET_SECONDS of play, the Alleyway keeps
-- STREET_COUNT Commons on the near points around it, and its first EASY_CATCHES catches by hand (and its first
-- EASY_CATCHES in the Park) are the slow, unlosable kind (CatService).
-- Behind `goalChip`: the two first goals (`goals`), each paying GOAL_PAY once (bits in telemetry.startPaid).
-- Pure but for the attribute reads.

local Players = game:GetService("Players")

local FreeStart = {}

FreeStart.FLAG = "freeStart"
FreeStart.STREET_FLAG = "streetCats"
FreeStart.GOAL_FLAG = "goalChip"
FreeStart.ATTR = "FreeStart"
-- #5616 (Derek 2026-11-20: "sometimes when first joining it doesn't spawn you in alleyway"): a save that joined once
-- and left before its first step joins the start too, and a first session's night pass lands it in the Alleyway
FreeStart.SPAWN_FLAG = "spawnAlley"
-- Sync's Studio run Nov 22 (a fresh save began in the Town Square): with spawnRetry on, a start that could not land
-- in the Alleyway tries again each second, SPAWN_TRIES times in all; every fresh start logs where it began
-- (free_start field "spawn_alley", "spawn_alley_retry" or "spawn_<spawnWord>")
FreeStart.RETRY_FLAG = "spawnRetry"
FreeStart.SPAWN_TRIES = 5
FreeStart.EVENT = "free_start" -- Telemetry.custom, once as a save joins
FreeStart.UNTIL_TIER = 3 -- the start's rules hold below this tier
FreeStart.STREET_SECONDS = 180 -- streetCats: the first three minutes of play
FreeStart.STREET_COUNT = 3
FreeStart.EASY_CATCHES = 3
FreeStart.GOAL_PAY = 100
FreeStart.PAID_CAUGHT = 1 -- telemetry.startPaid bits
FreeStart.PAID_HOME = 2
FreeStart.CATCH_LINE = "Catch a cat +100" -- goalChip: the goal card's two first goals (GOAL_PAY)
FreeStart.HOME_LINE = "Take it to camp +100"

local localPlayer: Player? = nil
pcall(function()
	localPlayer = Players.LocalPlayer
end)

-- Whether a loading save joins now: the switch on, never joined, no order arm yet, its first session, no step done.
function FreeStart.joins(
	on: boolean,
	sessions: number,
	tutorialStep: number,
	joined: boolean?,
	orderGroup: string?,
	again: boolean? -- SPAWN_FLAG: any session, while no step is done
): boolean
	return on
		and joined ~= true
		and orderGroup == nil
		and (sessions <= 1 or again == true)
		and tutorialStep == 0
end

-- Why the Alleyway start cannot land the character now, or nil when it can: "no_landing" (no pad spot), "no_root"
-- (no HumanoidRootPart yet), "gone" (a new character, or the player left), "launching", "carrying".
function FreeStart.spawnWord(
	landing: boolean,
	root: boolean,
	same: boolean,
	launching: boolean,
	carrying: boolean
): string?
	if not same then
		return "gone"
	elseif not landing then
		return "no_landing"
	elseif not root then
		return "no_root"
	elseif launching then
		return "launching"
	elseif carrying then
		return "carrying"
	end
	return nil
end

-- Whether the start's rules hold for a joined save at `tier`.
function FreeStart.active(joined: boolean?, tier: number): boolean
	return joined == true and tier < FreeStart.UNTIL_TIER
end

-- The player's FreeStart attribute (the server sets it at load); the local player's when `player` is nil.
function FreeStart.of(player: Player?): boolean
	local who = player or localPlayer
	return who ~= nil and who:GetAttribute(FreeStart.ATTR) == true
end

-- The client's gate for every tutorial pointer: the local player joined and below UNTIL_TIER (`tier` from the state,
-- else the Player's Tier attribute, which TradeService keeps).
function FreeStart.quiet(tier: number?): boolean
	if not FreeStart.of(nil) then
		return false
	end
	local who = localPlayer :: Player
	local raw = tier or who:GetAttribute("Tier")
	return (if type(raw) == "number" then raw else 1) < FreeStart.UNTIL_TIER
end

-- #5599 (rankPicker): a GuiObject with this attribute set true still gets its ring, arrow and spotlight while
-- quiet() holds (the cannon menu's Park Launch after the Tier 2 Rank Up: Derek 2026-11-20 "point at the park after
-- unlock so they know").
FreeStart.LOUD_ATTR = "PointEvenQuiet"

-- quiet(), except for a `target` marked LOUD_ATTR.
function FreeStart.quietFor(target: Instance?): boolean
	if target ~= nil and target:GetAttribute(FreeStart.LOUD_ATTR) == true then
		return false
	end
	return FreeStart.quiet(nil)
end

-- streetCats: whether the street's extra Commons still come for a joined save with `played` seconds of play.
function FreeStart.streetDue(joined: boolean?, played: number): boolean
	return joined == true and played < FreeStart.STREET_SECONDS
end

-- streetCats: whether a catch is one of the save's first EASY_CATCHES (`done` catches so far, by hand or in the Park).
-- #5562 (Sync's new start look 2026-11-20: a Park Rare still bolted): with `park` any rarity of the first three Park
-- catches is easy; on the street only Common and Uncommon are.
function FreeStart.easyDue(
	joined: boolean?,
	done: number,
	rarity: string,
	variant: string?,
	park: boolean?
): boolean
	return joined == true
		and done < FreeStart.EASY_CATCHES
		and (park == true or rarity == "Common" or rarity == "Uncommon")
		and (variant == nil or variant == "base")
end

-- goalChip: PlayerState.startGoals, or nil for a save not on this start. `caught` the catches by hand so far,
-- `home` the cats checked in from a hand catch so far.
function FreeStart.goals(
	joined: boolean?,
	tier: number,
	caught: number,
	home: number
): { caught: boolean, home: boolean }?
	if not FreeStart.active(joined, tier) then
		return nil
	end
	return { caught = caught > 0, home = home > 0 }
end

-- goalChip: whether the goal `bit` is still unpaid in `paid` (telemetry.startPaid).
function FreeStart.unpaid(paid: number?, bit: number): boolean
	return (paid or 0) // bit % 2 == 0
end

-- A saved startPaid made safe: a whole number from 0 to 3, else nil.
function FreeStart.validPaid(raw: unknown): number?
	if type(raw) == "number" and raw == raw and raw >= 0 and raw <= 3 and raw % 1 == 0 then
		return raw
	end
	return nil
end

return FreeStart
