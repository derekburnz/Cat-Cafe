--!strict
-- #5170 (Derek 2026-11-17: "make the stronger nets take less hits to catch cats also" and "add more tiers of nets
-- ... make it upgrade up to tier 5 not just 3"; Design-Agent's spec in the issue). Behind the switch `netTiers`
-- (LiveFlags.OFF_BY_DEFAULT):
--   each net level cuts the Perfect hits a catch needs (CUTS), as a trust head start of cut x TrustPerfect added to
--     the catch's own bonus (Circles.trustFor), never so much that fewer than two hits could catch;
--   Net 4 (Tier 7) and Net 5 (Tier 9): Catalog.setNetTiers sets the net's caps and maxLevel. Both sides follow the
--     switch's ReplicatedStorage attribute, so the server's buy check and the shop agree.
-- Off, catches and the net shop are as before, and a level 4 or 5 save plays as Net 3 (Circles clamps).
--   on() -> boolean
--   follow()                                  sets the caps now and each time the switch flips
--   cut(netLevel) -> number                   Perfect hits a level takes off
--   trustBonus(netLevel, start, need) -> number   the head start for a catch that starts at `start` (with any
--                                             other bonus) and is caught at `need`

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local LiveFlags = require(script.Parent.LiveFlags)

local NetTiers = {}

NetTiers.FLAG = "netTiers"
NetTiers.CUTS = table.freeze({ [0] = 0, [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3 })

local following = false

function NetTiers.on(): boolean
	return LiveFlags.shown(
		NetTiers.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. NetTiers.FLAG)
	)
end

function NetTiers.follow()
	Catalog.setNetTiers(NetTiers.on())
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. NetTiers.FLAG)
		:Connect(function()
			Catalog.setNetTiers(NetTiers.on())
		end)
end

function NetTiers.cut(netLevel: number): number
	local level = math.clamp(math.floor(netLevel), 0, Catalog.NET_MAX_TIERS)
	return NetTiers.CUTS[level] or 0
end

-- At least two hits always: the start stays at or below need - TrustPerfect - TrustGood, so one Perfect never
-- catches and a Perfect then a Good does.
function NetTiers.trustBonus(netLevel: number, start: number, need: number): number
	local room = need - Config.TrustPerfect - Config.TrustGood - start
	return math.max(0, math.min(NetTiers.cut(netLevel) * Config.TrustPerfect, room))
end

return NetTiers
