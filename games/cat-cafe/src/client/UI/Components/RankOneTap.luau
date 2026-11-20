--!strict
-- #5533 (Derek 2026-11-20: "a quick easy rankup system", "maybe it should be goals turns into a one click on side to
-- rankup"), behind the switch `rankOneTap` (LiveFlags.OFF_BY_DEFAULT): once the next tier's every need is met, the
-- goal card becomes a gold RANK UP button in the same spot with the cost on it, and one tap on it ranks up (the
-- RankUp remote, which checks everything again on the server). No window opens. The Rank Up window stays in the
-- menu for the list of what a tier opens. The player always taps; nothing ranks up by itself.
-- A tap in the first GUARD seconds after the card turned into the button is ignored, so a tap aimed at the card it
-- was a moment ago never spends coins, and after a tap the button rests REST seconds while the server answers.
-- Pure, so the spec checks it.

local RankOneTap = {}

RankOneTap.FLAG = "rankOneTap"
RankOneTap.LOOK_FLAG = "rankTapLook" -- #5592: the button in the clean green button look (Screens/GoalCard)
RankOneTap.GUARD = 0.4
RankOneTap.REST = 1.5
RankOneTap.TITLE = "RANK UP!"
RankOneTap.CHIP = "🏆 RANK UP!"

-- Whether the card is the button now: the switch on and the rank up ready.
function RankOneTap.active(on: boolean, ready: boolean): boolean
	return on and ready
end

-- Whether a tap at `now` counts: the button has been up for GUARD seconds (`since` is when it turned into the
-- button) and the last counted tap (`fired`, nil for none) was REST seconds ago or more.
function RankOneTap.accepts(now: number, since: number?, fired: number?): boolean
	if since == nil or now - since < RankOneTap.GUARD then
		return false
	end
	return fired == nil or now - fired >= RankOneTap.REST
end

-- The line under RANK UP!: the tier it buys and what it costs ("Cozy Cafe · 1,000 coins"; `cost` already worded).
function RankOneTap.line(tierName: string?, cost: string?): string
	if tierName ~= nil and cost ~= nil then
		return tierName .. " · " .. cost
	end
	return tierName or cost or ""
end

return RankOneTap
