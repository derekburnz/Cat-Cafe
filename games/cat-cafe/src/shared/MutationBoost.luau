--!strict
-- #5493 (Derek 2026-11-19, from a player: "more cat spawn please ... my collection isnt complete"; Derek: "increase the
-- mutation rate spawns so that people who are index hunting can find it easier"): behind the switch `mutationBoost`
-- (off by default), a wild stray's gold and rainbow coat chances before luck and day bonuses are SCALE times
-- Config.GoldChanceNet and Config.RainbowChanceNet. Bait and rescue coats are untouched (the food cards show bait odds).
-- Both sides read the switch's ReplicatedStorage attribute. Pure apart from that read.
--   scale(on) -> number           SCALE with the switch on, else 1
--   on() -> boolean               the switch, from ReplicatedStorage
--   gold(), rainbow() -> number   a wild stray's base chances now

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local LiveFlags = require(script.Parent.LiveFlags)

local MutationBoost = {}

MutationBoost.FLAG = "mutationBoost"
MutationBoost.SCALE = 2

function MutationBoost.scale(on: boolean): number
	return if on then MutationBoost.SCALE else 1
end

function MutationBoost.on(): boolean
	return LiveFlags.shown(
		MutationBoost.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. MutationBoost.FLAG)
	)
end

function MutationBoost.gold(): number
	return (Config.GoldChanceNet :: number) * MutationBoost.scale(MutationBoost.on())
end

function MutationBoost.rainbow(): number
	return (Config.RainbowChanceNet :: number) * MutationBoost.scale(MutationBoost.on())
end

return MutationBoost
