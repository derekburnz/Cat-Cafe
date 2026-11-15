--!strict
-- #4255 follow-up (Design-Agent, Nov 14: Secrets hopped away before 6 of 7 swings in a test): a Secret's rarity comes
-- from its spawn, not the swing, so a player who follows one always gets a swing. Pure rules, no instances; CatService
-- applies them to a Secret only:
--   1. it hops away from a player at most MAX_HOPS a visit (its Skittish startle and a near-miss hop both count), so
--      after one hop it holds still for the next approach;
--   2. it startles only at a player running at it (RUN_SHARE of Config.NormalWalkSpeed or faster), never a slow walk-up;
--   3. it never startles at a player whose swing is in the air (within SWING_SECONDS of the press).
--   MAX_HOPS, RUN_SHARE, SWING_SECONDS
--   mayHop(hops?)            whether a Secret that already hopped `hops` times from this player may hop again
--   running(velocity)        whether a root moving at `velocity` counts as running at the cat
--   swinging(sinceSwing?)    whether a swing pressed `sinceSwing` seconds ago is still in the air

local Config = require(script.Parent.Config)

local SecretCalm = {}

SecretCalm.MAX_HOPS = 1
SecretCalm.RUN_SHARE = 0.7 -- of NormalWalkSpeed: a full-speed walk or faster startles, a part-tilted stick does not
SecretCalm.SWING_SECONDS = Config.NetSmackDelay + 0.3

function SecretCalm.mayHop(hops: number?): boolean
	return (hops or 0) < SecretCalm.MAX_HOPS
end

function SecretCalm.running(velocity: Vector3): boolean
	local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	return flat >= Config.NormalWalkSpeed * SecretCalm.RUN_SHARE
end

function SecretCalm.swinging(sinceSwing: number?): boolean
	return sinceSwing ~= nil and sinceSwing >= 0 and sinceSwing < SecretCalm.SWING_SECONDS
end

return SecretCalm
