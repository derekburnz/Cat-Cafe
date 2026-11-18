--!strict
-- Daily Treat v2 (Derek 2026-11-18 17:14 UTC: "no bad rewards in the daily treat ... make it show like 1hour of
-- earnings, 10spins, 5 gold crates, 500 gold fish load these up asap"; Design-Agent's daily-treat-v2 spec). Behind the
-- switch `bigTreats` (LiveFlags.OFF_BY_DEFAULT) the card's seven days pay Catalog.DAILY_TREAT_BIG. Both sides follow
-- the switch's ReplicatedStorage attribute (Catalog.setBigTreats), so the card shows what the claim pays. No save
-- change: stamps and days are the same.
--   on() -> boolean
--   follow()    sets the rows now and each time the switch flips

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(script.Parent.Catalog)
local LiveFlags = require(script.Parent.LiveFlags)

local BigTreats = {}

BigTreats.FLAG = "bigTreats"

local following = false

function BigTreats.on(): boolean
	return LiveFlags.shown(
		BigTreats.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. BigTreats.FLAG)
	)
end

function BigTreats.follow()
	Catalog.setBigTreats(BigTreats.on())
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. BigTreats.FLAG)
		:Connect(function()
			Catalog.setBigTreats(BigTreats.on())
		end)
end

return BigTreats
