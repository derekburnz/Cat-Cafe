--!strict
-- #4005 (Derek 2026-11-13: "putting less pop ups at the start of gameplay that are not needed" and "making the new
-- player immune to getting other player pop ups on their screen for first 15 minute"; Growth-Agent's
-- home-recs-2026-11-13/first-5-min-popups.md, Part 1 confirmed by Design-Agent). Behind the `quietStart` switch.
--   * A new player is quiet for their account's first SECONDS of play, counted across visits like the tackle shield
--     (#3629, stats.playtimeSeconds): the server puts the end time on the player as ATTRIBUTE at load.
--   * While quiet, other players' pop ups do not reach them (the rank up, rare catch, rare decor, lucky cat and cat
--     shower toasts, the big pull effects, the rainbow cat toast and the owner's shout), trade requests to them are
--     refused, and the "try a tackle" tip waits.
--   * Until Tier 2 the extra tips (spin wheel, golden fish, potion, Codes Cat, luck), the first visit calls (rich
--     customer, Mystery Visitor gift, Cat Collector) and the full "cat found" card for a kind below Epic wait or shrink
--     to a toast; with the rank up walk through on, the rank up camera cut goes; on the first day the Daily Treat
--     window does not open itself (its "!" still shows).
-- Pure, so the cloud specs check it; the callers read the switch and the clock.

local LiveFlags = require(script.Parent.LiveFlags)

local QuietStart = {}

QuietStart.FLAG = "quietStart"
QuietStart.ATTRIBUTE = "QuietUntil"
QuietStart.DAY_ATTRIBUTE = "QuietFirstDay" -- the UTC day number the save was first seen (telemetry.firstDay)
QuietStart.DAY_SECONDS = 86400
QuietStart.SECONDS = 900 -- the first 15 minutes of play on the account, as the tackle shield (#3629)
QuietStart.TIER = 2 -- the extras wait until this tier
QuietStart.TRADE_REFUSED = "They just started, try again later"

-- Tips that wait until TIER.
QuietStart.TIER_TIPS = {
	spin_wheel = true,
	golden_fish = true,
	potion = true,
	codes_cat = true,
	luck = true,
} :: { [string]: boolean }

-- Tips that wait while the player is quiet.
QuietStart.QUIET_TIPS = {
	tackle_try = true, -- nobody can tackle them for these 15 minutes anyway (#3629)
} :: { [string]: boolean }

-- Rarities whose "cat found" card stays full size before TIER.
QuietStart.FULL_CARD = {
	Epic = true,
	Legendary = true,
	Mythical = true,
	Secret = true,
	Golden = true,
} :: { [string]: boolean }

-- The server time a player's quiet start ends, joining at `joinedAt` with `played` seconds of play on the account
-- before this join, or nil when they are past it. A missing or damaged count is treated as past it.
function QuietStart.untilAt(joinedAt: number, played: unknown): number?
	if type(played) ~= "number" or played ~= played then
		return nil
	end
	local left = QuietStart.SECONDS - math.max(0, played)
	if left <= 0 then
		return nil
	end
	return joinedAt + left
end

-- Whether a player whose attribute reads `untilAt` is quiet at `now` with the switch `on`.
function QuietStart.quiet(on: boolean, untilAt: unknown, now: number): boolean
	return on and type(untilAt) == "number" and now < untilAt
end

-- Whether tip `id` waits now. `tier` is the player's tier (nil reads as 1); `quiet` is QuietStart.quiet's answer;
-- `spotlight` says the rank up walk through (`rankUpSpotlight`) is on.
function QuietStart.holdsTip(
	on: boolean,
	id: string,
	tier: number?,
	quiet: boolean,
	spotlight: boolean?
): boolean
	if not on then
		return false
	end
	if QuietStart.TIER_TIPS[id] and (tier or 1) < QuietStart.TIER then
		return true
	end
	if QuietStart.QUIET_TIPS[id] and quiet then
		return true
	end
	-- the walk through and the camera cut came at the same moment: two pop ups for one step
	return id == "rank_up" and spotlight == true
end

-- Whether the first visit calls wait (before TIER).
function QuietStart.holdsFirstVisit(on: boolean, tier: number?): boolean
	return on and (tier or 1) < QuietStart.TIER
end

-- Whether a "cat found" card for a new kind of `rarity` is a toast instead. The first catch's card always shows
-- (`first`): it is the big reward moment.
function QuietStart.foundToast(on: boolean, tier: number?, rarity: string?, first: boolean): boolean
	if not on or first or (tier or 1) >= QuietStart.TIER then
		return false
	end
	return rarity == nil or not QuietStart.FULL_CARD[rarity]
end

-- Whether the Daily Treat window may open itself: not on the account's first day (`firstDay`, the UTC day number
-- the save was first seen; `today` the same for now).
function QuietStart.treatOpensItself(on: boolean, firstDay: unknown, today: number): boolean
	if not on then
		return true
	end
	return type(firstDay) ~= "number" or firstDay <= 0 or today > firstDay
end

-- The client's read: whether the switch is on, and whether the local player is quiet now. Not for the specs.
function QuietStart.live(): (boolean, boolean)
	local on = LiveFlags.shown(
		QuietStart.FLAG,
		game:GetService("ReplicatedStorage")
			:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. QuietStart.FLAG)
	)
	local player = game:GetService("Players").LocalPlayer
	if player == nil then
		return on, false
	end
	local quiet = QuietStart.quiet(
		on,
		player:GetAttribute(QuietStart.ATTRIBUTE),
		game:GetService("Workspace"):GetServerTimeNow()
	)
	return on, quiet
end

return QuietStart
