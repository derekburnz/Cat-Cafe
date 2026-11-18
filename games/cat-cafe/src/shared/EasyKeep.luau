--!strict
-- #5311 (Derek 2026-11-18 17:27 UTC: "rebalance the tier 10 dragon warmth numbers to make it easier but also a proper
-- increase like 50,100,250,500,1000"): behind the switch `easyKeep` (LiveFlags.OFF_BY_DEFAULT), the Dragon Keep's
-- stage Warmths and Rekindle step are Design-Agent's lower ones. They are written into DragonKeep.STAGES and
-- DragonKeep.REKINDLE in place, so every reader (the server's grow, the Keep window's bar) agrees; both sides
-- follow the switch's ReplicatedStorage attribute, like shared/CheapTiers.
--   stage       plain    easyKeep on
--   Hatchling   50       50
--   Whelp       300      100
--   Drake       1,000    250
--   Elder       1,400    500
--   Crowned     2,400    1,000
--   Rekindle    1,500    500 (each hand after Crowned)
-- A save already past a lowered stage gets it, and its hand, when it next loads (DragonKeep.sanitize's grow) or at
-- its next gift; nothing is taken away, and switching it off keeps the stages reached.
--   on() -> boolean
--   apply(on)        writes one set of numbers
--   follow()         sets them now and each time the switch flips

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonKeep = require(script.Parent.DragonKeep)
local LiveFlags = require(script.Parent.LiveFlags)

local EasyKeep = {}

EasyKeep.FLAG = "easyKeep"
EasyKeep.EASY = { 50, 100, 250, 500, 1000 }
EasyKeep.EASY_REKINDLE = 500

local plain: { number } = {}
for index, stage in DragonKeep.STAGES do
	plain[index] = stage.warmth
end
local plainRekindle = DragonKeep.REKINDLE
EasyKeep.PLAIN = table.freeze(table.clone(plain))
EasyKeep.PLAIN_REKINDLE = plainRekindle

local following = false

function EasyKeep.on(): boolean
	return LiveFlags.shown(
		EasyKeep.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. EasyKeep.FLAG)
	)
end

function EasyKeep.apply(on: boolean)
	local list = if on then EasyKeep.EASY else plain
	for index, stage in DragonKeep.STAGES do
		local warmth = list[index]
		if warmth ~= nil then
			stage.warmth = warmth
		end
	end
	DragonKeep.REKINDLE = if on then EasyKeep.EASY_REKINDLE else plainRekindle
end

function EasyKeep.follow()
	EasyKeep.apply(EasyKeep.on())
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. EasyKeep.FLAG)
		:Connect(function()
			EasyKeep.apply(EasyKeep.on())
		end)
end

return EasyKeep
