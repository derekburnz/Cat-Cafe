--!strict
-- The Tackle button's rules (F74, data-model section 10c v0.11). Pure, so the cloud spec runner checks it.
--
-- A press lunges straight ahead and starts the cooldown at once; a miss never gives it back, only a refusal does
-- (carrying, in a minigame, outside an area). The button is also greyed while the player cannot tackle: mid-lunge,
-- down after a miss, held after a hit and while knocked down by someone else's tackle. Those come from the server
-- times on the local character (`TackleAt`, `TackleMissAt`, `ShovedAt`) and, for a hit, the local time of the
-- result. Numbers come from Config, with the design's values until the engineer's Config has them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local TackleLogic = {}

local function number(value: unknown, fallback: number): number
	return if type(value) == "number" and value == value then value else fallback
end

TackleLogic.REACH = number(Config.TackleLungeStuds, 12) -- how far the lunge goes
TackleLogic.LUNGE = number(Config.TackleLungeSeconds, 0.35)
TackleLogic.COOLDOWN = number(Config.TackleCooldownSeconds, 8)
TackleLogic.HIT_RECOVER = number(Config.TackleHitRecoverSeconds, 0.4)
TackleLogic.MISS_RECOVER = number(Config.TackleMissRecoverSeconds, 1.2)
-- the knockback takes 0.25 s (ShoveController's push), then the target is down TackledDownSeconds
TackleLogic.TACKLED = 0.25 + number(Config.TackledDownSeconds, 0.8)

-- The attributes on the local character, server times (workspace:GetServerTimeNow()).
export type Marks = { tackleAt: number?, missAt: number?, shovedAt: number? }

export type Look = "ready" | "cooling" | "down"

local HITS: { [string]: boolean } = { shove = true, loose = true, held = true }

-- The server time until which this player cannot tackle because of their own lunge, a miss or a tackle on them.
function TackleLogic.downUntil(marks: Marks): number
	local untilAt = -math.huge
	if marks.tackleAt then
		untilAt = math.max(untilAt, marks.tackleAt + TackleLogic.LUNGE)
	end
	if marks.missAt then
		untilAt = math.max(untilAt, marks.missAt + TackleLogic.MISS_RECOVER)
	end
	if marks.shovedAt then
		untilAt = math.max(untilAt, marks.shovedAt + TackleLogic.TACKLED)
	end
	return untilAt
end

-- How the button looks: the cooldown wipe while it drains, grey while down, else ready. `coolLeft` is the
-- cooldown's seconds left on this client and `down` whether a down state above (or a hit's hold) is running.
function TackleLogic.look(coolLeft: number, down: boolean): Look
	if coolLeft > 0 then
		return "cooling"
	end
	return if down then "down" else "ready"
end

-- The share of the button the cooldown wipe still covers, 1 at the press down to 0.
function TackleLogic.share(coolLeft: number): number
	return math.clamp(coolLeft / TackleLogic.COOLDOWN, 0, 1)
end

function TackleLogic.isHit(outcome: string?): boolean
	return outcome ~= nil and HITS[outcome] == true
end

-- The tackler's toast for a ShoveResult and whether it is good news: "Missed!" (false) or "Tackled Alex!" (true),
-- nothing for a refusal or an unknown outcome.
function TackleLogic.toast(ok: boolean, outcome: string?, name: string?): (string?, boolean)
	if not ok then
		return nil, false
	end
	if outcome == "miss" then
		return "Missed!", false
	end
	if TackleLogic.isHit(outcome) then
		return if name and name ~= "" then ("Tackled %s!"):format(name) else "Tackled!", true
	end
	return nil, false
end

return TackleLogic
