--!strict
-- #5311 (Derek 2026-11-18 17:27 UTC: "rebalance the tier 10 dragon warmth numbers to make it easier but also a proper
-- increase like 50,100,250,500,1000 and make it 500 for repeat rolls after maxed level dragon"): behind the switch
-- `easyKeep` (LiveFlags.OFF_BY_DEFAULT), Cinder's stage Warmths and the Rekindle step are EASY in place of PLAIN.
-- DragonKeep.STAGES and DragonKeep.REKINDLE are written in place, so every reader (grow, the server's view and its
-- nextAt, the Keep window's bar) agrees. Both sides follow the switch's ReplicatedStorage attribute, like
-- shared/CheapTiers. Nothing is taken away: switching it off later leaves the stages a save already reached.
--   stage       plain   easyKeep on
--   Hatchling   50      50
--   Whelp       300     100
--   Drake       1,000   250
--   Elder       1,400   500
--   Crowned     2,400   1,000
--   Rekindle    1,500   500
--   on() -> boolean
--   apply(on)   writes the numbers for on or off; returns whether any changed
--   follow()    applies now and each time the switch flips; onChange(fn) runs fn after each flip (the server regrows)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonKeep = require(script.Parent.DragonKeep)
local LiveFlags = require(script.Parent.LiveFlags)

local EasyKeep = {}

EasyKeep.FLAG = "easyKeep"
EasyKeep.EASY = table.freeze({ 50, 100, 250, 500, 1000 })
EasyKeep.EASY_REKINDLE = 500
local plain: { number } = {}
for index, stage in DragonKeep.STAGES do
	plain[index] = stage.warmth
end
EasyKeep.PLAIN = table.freeze(plain)
EasyKeep.PLAIN_REKINDLE = DragonKeep.REKINDLE

local following = false
local listeners: { () -> () } = {}

function EasyKeep.on(): boolean
	return LiveFlags.shown(
		EasyKeep.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. EasyKeep.FLAG)
	)
end

function EasyKeep.apply(on: boolean): boolean
	local want = if on then EasyKeep.EASY else EasyKeep.PLAIN
	local changed = false
	for index, stage in DragonKeep.STAGES do
		if stage.warmth ~= want[index] then
			stage.warmth = want[index]
			changed = true
		end
	end
	local rekindle = if on then EasyKeep.EASY_REKINDLE else EasyKeep.PLAIN_REKINDLE
	if DragonKeep.REKINDLE ~= rekindle then
		DragonKeep.REKINDLE = rekindle
		changed = true
	end
	return changed
end

function EasyKeep.onChange(fn: () -> ())
	table.insert(listeners, fn)
end

local function flip()
	if EasyKeep.apply(EasyKeep.on()) then
		for _, fn in listeners do
			task.spawn(fn)
		end
	end
end

function EasyKeep.follow()
	EasyKeep.apply(EasyKeep.on())
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. EasyKeep.FLAG)
		:Connect(flip)
end

return EasyKeep
