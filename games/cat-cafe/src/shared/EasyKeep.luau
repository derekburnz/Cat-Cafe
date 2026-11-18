--!strict
-- #5311 (Derek 2026-11-18 17:27 UTC: "rebalance the tier 10 dragon warmth numbers to make it easier but also a proper
-- increase like 50,100,250,500,1000"; Design-Agent's numbers): behind the switch `easyKeep` (LiveFlags.OFF_BY_DEFAULT)
-- the Dragon Keep's stages ask DragonKeep.EASY_WARMTH and Rekindle EASY_REKINDLE. DragonKeep.setEasy writes them in
-- place, so the server's grow, the client's bar and the cards agree. Both sides follow the switch's ReplicatedStorage
-- attribute, like shared/CheapTiers. Nothing is taken away: Warmth, stages reached and cards stay as they are.
--   stage      plain    easyKeep
--   Hatchling  50       50
--   Whelp      300      100
--   Drake      1,000    250
--   Elder      1,400    500
--   Crowned    2,400    1,000
--   Rekindle   1,500    500
--   on() -> boolean
--   follow()   sets the goals now and each time the switch flips

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonKeep = require(script.Parent.DragonKeep)
local LiveFlags = require(script.Parent.LiveFlags)

local EasyKeep = {}

EasyKeep.FLAG = "easyKeep"

local following = false

function EasyKeep.on(): boolean
	return LiveFlags.shown(
		EasyKeep.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. EasyKeep.FLAG)
	)
end

local function apply()
	DragonKeep.setEasy(EasyKeep.on())
end

function EasyKeep.follow()
	apply()
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. EasyKeep.FLAG)
		:Connect(apply)
end

return EasyKeep
