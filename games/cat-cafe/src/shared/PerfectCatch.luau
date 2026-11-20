--!strict
-- #5300 (Derek 2026-11-18: "remove charm from game and just have it if you perfect catch a cat make it give +50% money
-- and show in a bubble like gold/rainbow bonuses"; Design-Agent's perfect-catch-5300 spec), switch perfectCatch (off by
-- default). A cat caught by net with every ring Perfect (Circles.finish "purrfect"), never while AutoPress is set, is
-- saved `perfect = true` and earns x1.5, multiplied with its coat; every cat's charm counts 1x. Off, Charm plays as
-- before and the saved charm is untouched.
--   follow()               both sides: CatStats.setPerfectCatch follows the switch
--   marks(finish, auto)    whether a catch's finish marks its cat
--   migrate(cats, seen)    once per account (tipsSeen KEY): cats with charm PERFECT_CHARM or more get the mark;
--                          returns how many it marked and how many sit at charm 50 to 79 (the ones that earn less)
--   chip()                 "Perfect +50%"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatStats = require(script.Parent.CatStats)
local LiveFlags = require(script.Parent.LiveFlags)
local Types = require(script.Parent.Types)

local PerfectCatch = {}

PerfectCatch.FLAG = "perfectCatch"
PerfectCatch.FLAGGED_FLAG = "perfectFlagged" -- #5379: the scripted-press flag no longer blocks the mark
PerfectCatch.KEY = "perfect_charm" -- tipsSeen: the charm migration ran (server only; TipSeen may not carry it)
PerfectCatch.CHIP = "Perfect +50%"
PerfectCatch.CATCH_LINE = "PERFECT! +50% money"
PerfectCatch.COLOR = Color3.fromRGB(143, 211, 255) -- #8FD3FF, pale sky (Design-Agent)

local following = false

function PerfectCatch.on(): boolean
	return LiveFlags.shown(
		PerfectCatch.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. PerfectCatch.FLAG)
	)
end

function PerfectCatch.follow()
	CatStats.setPerfectCatch(PerfectCatch.on())
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. PerfectCatch.FLAG)
		:Connect(function()
			CatStats.setPerfectCatch(PerfectCatch.on())
		end)
end

function PerfectCatch.marks(finish: unknown, autoPress: boolean?): boolean
	return finish == "purrfect" and autoPress ~= true
end

function PerfectCatch.migrate(
	cats: { [string]: Types.CatInstance },
	seen: { [string]: boolean }
): (number, number)
	if seen[PerfectCatch.KEY] == true then
		return 0, 0
	end
	seen[PerfectCatch.KEY] = true
	local marked, lower = 0, 0
	for _, instance in cats do
		local charm = CatStats.charm(instance)
		if charm >= CatStats.PERFECT_CHARM then
			if instance.perfect ~= true then
				instance.perfect = true
				marked += 1
			end
		elseif charm > CatStats.DEFAULT_CHARM and instance.perfect ~= true then
			lower += 1
		end
	end
	return marked, lower
end

return PerfectCatch
