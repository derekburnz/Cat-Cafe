--!strict
-- #5303 (Design's companion-traits spec): both sides follow the `companionTraits` switch (LiveFlags.OFF_BY_DEFAULT)
-- through its ReplicatedStorage attribute, like shared/CheapTiers: Traits.setCompanion adds the companion traits to
-- the Mystic Pool's even pick and Eclipse's companion effects, or takes them out. The switch goes on only after a
-- restart publish, so no older server drops the new ids.
--   on() -> boolean
--   follow()          applies the switch now and each time it flips

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(script.Parent.LiveFlags)
local Traits = require(script.Parent.Traits)

local CompanionTraits = {}

CompanionTraits.FLAG = Traits.COMPANION_FLAG

local following = false

function CompanionTraits.on(): boolean
	return LiveFlags.shown(
		CompanionTraits.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. CompanionTraits.FLAG)
	)
end

local function apply()
	Traits.setCompanion(CompanionTraits.on())
end

function CompanionTraits.follow()
	apply()
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CompanionTraits.FLAG)
		:Connect(apply)
end

return CompanionTraits
