--!strict
-- #3022 (Derek2 2026-11-10: "make it obvious to go catch second cat to earn more money and progress 'your goal'"): the
-- goal card's words from the first customer served until the second cat is checked in (PlayerState.secondCat, the
-- server's shared/SecondCat.view). Every number is the server's, so each line is true:
--   the title                "Catch a 2nd cat 🐾 1/2"
--   under it on a wide card  "New cats pay +$50 💰" (Design's "Catch a 2nd cat: new cats pay +$50 💰 1/2" on two
--                            lines: as one it only fits the 250 px card at 12 px)
--   under that for a while   "New kind of cat: +$50" / "and 1 step closer to Cozy Cafe"
-- A new cafe's starter Tabby and first catch fill both Tier 1 jobs, so a second catch rests and the true money in it
-- is the new-cat bonus (Design-Agent 2026-11-10). Only when a job really is free, and the rate with a second cat
-- working is the server's, do the words become "2 cats earn 2x 💰" (at DOUBLE or more, else "earn more") and
-- "Now +$1.5/s" / "with 2 cats +$2.5/s".
-- While a cat is carried the card goes back to the tier goal: the carry banner says what to do with it.
-- #3238: at night the areas are shut and no stray waits, so the title reads "2nd cat at sunrise 🌅 1/2" and a wide
-- card's line under it "Strays come back at sunrise" (the server picks the waiting stray when day starts).
-- Pure (no Theme, no Format), so the cloud specs load it.
--   view(state, narrow, nextTier?, night?) -> View?   nil when there is nothing to say

local ShortNumber = require(script.Parent.ShortNumber)

local SecondCatGoal = {}

export type View = {
	title: string, -- the card's big line
	hook: string?, -- a wide card's line under it, as long as the goal shows: the money in it
	lines: { string }, -- the preview under that, for PREVIEW_SECONDS, once
	chip: string, -- the folded card's line
}

SecondCatGoal.NEED = 2 -- cats caught that end it (shared/SecondCat.CATS)
SecondCatGoal.DOUBLE = 1.9 -- the rate with a second cat over the rate now from which the card may say "2x"
SecondCatGoal.PREVIEW_SECONDS = 6 -- how long `lines` show (shared/SecondCat.PREVIEW_SECONDS)
SecondCatGoal.NUDGE_SECONDS = 45 -- the card's second bounce (shared/SecondCat.NUDGE_SECONDS)

-- 1.5 -> "+$1.5/s", 2 -> "+$2/s", 54045 -> "+$54K/s" (as Components/Format.rate)
local function rate(perSecond: number): string
	local value = if perSecond >= 10
		then ShortNumber.format(perSecond)
		else string.format("%.1f", perSecond)
	value = value:gsub("%.0$", "")
	return "+$" .. value .. "/s"
end

local function number(value: unknown): number?
	if type(value) == "number" and value == value and value >= 0 then
		return value
	end
	return nil
end

-- `state` is a PlayerState; `narrow` the phone and tablet's narrow goal card; `nextTier` the next tier's name for
-- the preview's second line (nil at the top tier, which drops it).
function SecondCatGoal.view(state: any, narrow: boolean, nextTier: string?, night: boolean?): View?
	local second = if type(state) == "table" then state.secondCat else nil
	if type(second) ~= "table" or state.carrying ~= nil then
		return nil
	end
	local now, with = number(second.now), number(second.with)
	local bonus = number(second.bonus)
	local cats = math.clamp(math.floor(number(second.cats) or 1), 0, SecondCatGoal.NEED - 1)
	local count = string.format("%d/%d", cats, SecondCatGoal.NEED)
	local title = "Catch a 2nd cat 🐾 " .. count
	local free = now ~= nil and with ~= nil and with > now -- a job is free and a second cat would earn
	local hook: string? = nil
	local lines: { string } = {}
	if free and now ~= nil and with ~= nil then
		hook = if now > 0 and with >= now * SecondCatGoal.DOUBLE
			then "2 cats earn 2x 💰"
			else "2 cats earn more 💰"
		lines = { "Now " .. rate(now), "with 2 cats " .. rate(with) }
	elseif bonus ~= nil and bonus > 0 then
		local pay = "+$" .. ShortNumber.format(bonus)
		hook = string.format("New cats pay %s 💰", pay)
		lines = { "New kind of cat: " .. pay }
		if nextTier ~= nil and nextTier ~= "" then
			table.insert(
				lines,
				(if narrow then "1 step closer to " else "and 1 step closer to ") .. nextTier
			)
		end
	end
	if night == true then
		title = "2nd cat at sunrise 🌅 " .. count
		hook = "Strays come back at sunrise"
	end
	return { title = title, hook = if narrow then nil else hook, lines = lines, chip = title }
end

return SecondCatGoal
