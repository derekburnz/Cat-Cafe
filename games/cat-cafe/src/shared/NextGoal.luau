--!strict
-- #5202 (Derek 2026-11-18: after the first Park catch, a short "what next" moment: collect cats and build up your
-- cafe). Design-Agent's spec on the issue. Behind the nextGoalBeat switch (off by default), once per account (the
-- TipSeen id SEEN, kept like the asks): after the first Park cat is checked in, at the first calm CALM seconds, a
-- small "What next?" card with two choices shows for SECONDS (or until a tap). Rank Up not ready: variant A, what
-- Tier 3 still needs (the same numbers as the goal card). Rank Up ready: parkRankPoint goes first and the card waits
-- for Tier 3, then variant B with the long goals. Client side: UI.nextGoal (UI/init). The server logs
-- next_goal_shown and next_goal_tap from the client's REPORT. Pure, so the specs load it.

local NextGoal = {}

NextGoal.FLAG = "nextGoalBeat" -- shared/LiveFlags, off by default
NextGoal.SEEN = "next_goal" -- shared/Tips.seenId: kept in tipsSeen like the asks, never cleared
NextGoal.REPORT = "next_goal" -- the TelemetryReport name
NextGoal.SHOWN = { "A", "B" } -- next_goal_shown's variant
NextGoal.TAPS = { "cats", "cafe", "closed" } -- next_goal_tap's target
NextGoal.CALM = 3 -- seconds of calm first (2 s idle, and 3 s after any other scene closes)
NextGoal.SECONDS = 8 -- on screen at most
NextGoal.WAIT_A = 180 -- seconds variant A waits for calm before it gives up this session
NextGoal.WAIT_B = 900 -- seconds variant B waits for Tier 3 and calm
NextGoal.TITLE = "What next?"
NextGoal.CATS = "Collect cats"
NextGoal.CAFE = "Build up your cafe"

export type Needs = {
	catsHave: number,
	catsNeed: number,
	rarity: string?,
	rarityHave: number,
	rarityNeed: number,
	coinsHave: number,
	coinsNeed: number,
}

export type Card = {
	variant: string, -- "A" or "B"
	line: string, -- the two goals in short words, over the buttons
	first: string, -- "cats" or "cafe": the choice that blocks first (the primary button)
}

-- The report value for a shown variant or a tap target, or nil when it is neither.
function NextGoal.encode(kind: "shown" | "tap", value: string): string?
	local list = if kind == "shown" then NextGoal.SHOWN else NextGoal.TAPS
	if table.find(list, value) == nil then
		return nil
	end
	return kind .. ":" .. value
end

-- The server's read of a report value: ("shown", "A") and the like, or nil.
function NextGoal.decode(raw: unknown): (string?, string?)
	if type(raw) ~= "string" then
		return nil, nil
	end
	local kind, value = string.match(raw, "^(%a+):(%a+)$")
	if kind == nil or value == nil then
		return nil, nil
	end
	local list = if kind == "shown"
		then NextGoal.SHOWN
		elseif kind == "tap" then NextGoal.TAPS
		else nil
	if list ~= nil and table.find(list, value :: string) ~= nil then
		return kind, value
	end
	return nil, nil
end

-- The card's words. `needs` nil (or every need met) is variant B, after Tier 3; else variant A from the next tier's
-- needs, cats first as Economy.rankUpBlocker checks them. `money` writes coins ("$1.2K").
function NextGoal.card(needs: Needs?, money: (number) -> string): Card
	if needs == nil then
		return {
			variant = "B",
			line = "Catch all 110+ cats, and rank up for new areas.",
			first = "cats",
		}
	end
	local catsShort = math.max(0, needs.catsNeed - needs.catsHave)
	local rareShort = math.max(0, needs.rarityNeed - needs.rarityHave)
	local coinsShort = needs.coinsHave < needs.coinsNeed
	local parts: { string } = {}
	if catsShort > 0 then
		table.insert(
			parts,
			string.format("%d more kind%s of cat", catsShort, if catsShort == 1 then "" else "s")
		)
	elseif rareShort > 0 and needs.rarity ~= nil then
		table.insert(parts, string.format("a %s or better cat", needs.rarity :: string))
	end
	if coinsShort then
		table.insert(parts, money(needs.coinsNeed - needs.coinsHave))
	end
	local line = if #parts == 0
		then "Tier 3 is ready: rank up!"
		else "Tier 3 needs " .. table.concat(parts, " and ") .. "."
	return {
		variant = "A",
		line = line,
		first = if catsShort > 0 or rareShort > 0 then "cats" else "cafe",
	}
end

return NextGoal
