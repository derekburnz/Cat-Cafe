--!strict
-- #5441 (Derek 2026-11-19: "the tier 10 cafe now feels a little empty make it so there are 2 more table upgrades in
-- the game and spread them out properly ... now should be a max of 8 tables"): Tables 7 and 8 at Tiers 9 and 10,
-- behind the `tablesEight` switch (LiveFlags, off by default). Both sides follow the switch's ReplicatedStorage
-- attribute (LiveFlagService copies it there) and set Catalog's tables caps, maxLevel and costs from it
-- (Catalog.setTablesEight), so the server's buy check, the shop and the Rank Up card agree. The two tables stand in
-- the back of the grown room (Layout.plot.tablesBig, WorldBuilder.setRoom). A level owned above the cap is kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(script.Parent.Catalog)
local LiveFlags = require(script.Parent.LiveFlags)

local TablesEight = {}

TablesEight.FLAG = "tablesEight"

local following = false

-- Whether the switch reads on now.
function TablesEight.on(): boolean
	return LiveFlags.shown(
		TablesEight.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. TablesEight.FLAG)
	)
end

-- Sets the caps now and each time the switch flips. Safe to call more than once.
function TablesEight.follow()
	Catalog.setTablesEight(TablesEight.on())
	if following then
		return
	end
	following = true
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. TablesEight.FLAG)
		:Connect(function()
			Catalog.setTablesEight(TablesEight.on())
		end)
end

return TablesEight
