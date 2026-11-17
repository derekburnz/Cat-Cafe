--!strict
-- #3867/#4763 (Derek 2026-11-13: "spread the upgrades out so not all tables can be unlocked at tier 3"): one more
-- table a tier, behind the `tablesSpread` switch (LiveFlags, off by default). Both sides follow the switch's
-- ReplicatedStorage attribute (LiveFlagService copies it there) and set Catalog's tables caps from it
-- (Catalog.setTablesSpread), so the server's buy check, the shop and the Rank Up card agree. A table level owned
-- above the cap is kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(script.Parent.Catalog)
local LiveFlags = require(script.Parent.LiveFlags)

local TablesSpread = {}

TablesSpread.FLAG = "tablesSpread"

local following = false

-- Whether the switch reads on now.
function TablesSpread.on(): boolean
	return LiveFlags.shown(
		TablesSpread.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. TablesSpread.FLAG)
	)
end

-- Sets the caps now and each time the switch flips. Safe to call more than once.
function TablesSpread.follow()
	Catalog.setTablesSpread(TablesSpread.on())
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. TablesSpread.FLAG)
		:Connect(function()
			Catalog.setTablesSpread(TablesSpread.on())
		end)
end

return TablesSpread
