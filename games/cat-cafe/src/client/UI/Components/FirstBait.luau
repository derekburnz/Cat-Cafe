--!strict
-- The account's first bait (#1895): it waits at most FirstBaitWaitSeconds (2 minutes, shared Bait.firstWait) so a
-- first session sees its first bait cat, and while it waits the game says so ("A cat is coming! 1m 42s") on the HUD's
-- row over the money and in the Bait bowl window, so the player stays and does something else meanwhile. No Robux
-- skip, ever. Pure, so the cloud specs check it.
--   wait() -> number                          FirstBaitWaitSeconds (120 until Config has it)
--   firstWait(firstBait, wait) -> number      the empty bowl's promised wait: capped while state.firstBait is true
--   coming(bait) -> boolean                   the bait in the bowl is the short first one: a day bait whose whole
--                                             wait (readyAt - placedAt) is the first wait or less, not yet ready
--   chip(bait, now) -> string?                "A cat is coming! 1m 42s" while it waits, else nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FirstBait = {}

FirstBait.SLACK = 1 -- seconds: the server stamps placedAt and readyAt from one os.time(), so the gap is exact

export type Bait = { readyAt: number, placedAt: number?, night: boolean? }

function FirstBait.wait(): number
	local value = (Config :: any).FirstBaitWaitSeconds
	return if type(value) == "number" and value > 0 then value else 120
end

function FirstBait.firstWait(firstBait: unknown, wait: number): number
	if firstBait == true then
		return math.min(wait, FirstBait.wait())
	end
	return wait
end

function FirstBait.coming(bait: Bait?): boolean
	if bait == nil or bait.night == true or type(bait.placedAt) ~= "number" then
		return false
	end
	return bait.readyAt - (bait.placedAt :: number) <= FirstBait.wait() + FirstBait.SLACK
end

function FirstBait.chip(bait: Bait?, now: number): string?
	if bait == nil or not FirstBait.coming(bait) then
		return nil
	end
	local left = bait.readyAt - now
	if left <= 0 then
		return nil
	end
	-- Format.duration's words ("1m 42s", "40s"), here so the cloud specs need no Theme
	local seconds = math.ceil(left)
	local minutes = seconds // 60
	local when = if minutes > 0
		then string.format("%dm %ds", minutes, seconds % 60)
		else string.format("%ds", seconds)
	return "A cat is coming! " .. when
end

return FirstBait
