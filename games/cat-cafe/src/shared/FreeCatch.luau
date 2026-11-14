--!strict
-- Derek 2026-11-14 ("lower difficulty and give the circles basically free for console, tablet, phone players until
-- tier 2"; #4307: touch players quit at the first cat about 20 times as often, and 19% of their catches bolt): a
-- player on a phone, tablet or console below Tier 2 catches every stray the way a beginner catches their tutorial
-- stray (CatService.easyCatch): one slow circle with wide bands, a ring that waits on its target for the press, and a
-- miss that costs nothing and tries again. Behind the live switch `freeCatchPads` (on). The device is the client's
-- own report (Telemetry.device); a spoofed one only gets Tier 1's catches made easy, the same as a real phone.
--   FLAG, DEVICES, BELOW_TIER
--   applies(on, device?, tier)   whether a player's catches are made free now

local FreeCatch = {}

FreeCatch.FLAG = "freeCatchPads"
FreeCatch.DEVICES =
	table.freeze({ phone = true, tablet = true, console = true }) :: { [string]: boolean }
FreeCatch.BELOW_TIER = 2

function FreeCatch.applies(on: boolean, device: string?, tier: number): boolean
	return on
		and device ~= nil
		and FreeCatch.DEVICES[device] == true
		and tier < FreeCatch.BELOW_TIER
end

return FreeCatch
