--!strict
-- The Cats screen: the cats the player owns, with the crew strip to put them to work (Screens/CatRoom). Its own
-- window since 2026-10-27 (Derek: "cat equip and index shouldn't be linked should be separate things"); the
-- Index and the Decor Index stay together in Screens/CatCollection.
-- The title counts the cats and how many work: "14 cats · 4 working".

local CatRoom = require(script.Parent.CatRoom)
local Create = require(script.Parent.Parent.Components.Create)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	placeCat: (uid: string, spotId: string) -> (),
	unplaceCat: (uid: string) -> (),
	sellCat: (uid: string) -> (),
	lockCat: (uid: string, locked: boolean) -> (),
	renameCat: (uid: string, name: string) -> (),
	equipBest: () -> (),
	unequipAll: () -> (),
	close: () -> (),
}

export type MyCats = {
	frame: Frame,
	setCatalog: (self: MyCats, catalog: Types.Catalog) -> (),
	render: (self: MyCats, state: Types.PlayerState) -> (),
	reset: (self: MyCats) -> (),
	destroy: (self: MyCats) -> (),
}

local MyCats = {}
MyCats.__index = MyCats

function MyCats.new(callbacks: Callbacks): MyCats
	local self = setmetatable({}, MyCats) :: any
	local panel = Panel.new({
		name = "Cats",
		color = Theme.colors.sky,
		icon = Theme.icons.cats,
		title = "Cats",
		subtitle = "0 cats",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(820, 580), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	self._catRoom = CatRoom.new(panel.content, {
		placeCat = callbacks.placeCat,
		unplaceCat = callbacks.unplaceCat,
		sellCat = callbacks.sellCat,
		lockCat = callbacks.lockCat,
		renameCat = callbacks.renameCat,
		equipBest = callbacks.equipBest,
		unequipAll = callbacks.unequipAll,
	})

	return self :: MyCats
end

function MyCats.setCatalog(self: any, catalog: Types.Catalog)
	self._catRoom:setCatalog(catalog)
end

-- A fresh open drops a half-done Assign, Sell confirm or rename.
function MyCats.reset(self: any)
	self._catRoom:reset()
end

function MyCats.render(self: any, state: Types.PlayerState)
	if not self.frame.Visible then
		return
	end
	local cats: { [string]: Types.CatInstance } = state.cats or {}
	local count, working = 0, 0
	for _, instance in cats do
		count += 1
		if instance.spotId then
			working += 1
		end
	end
	local subtitle = if count == 1 then "1 cat" else ("%d cats"):format(count)
	if count > 0 then
		subtitle ..= ("  ·  %d working"):format(working)
	end
	self._panel:setTitle("Cats", subtitle)
	self._catRoom:render(state)
end

function MyCats.destroy(self: any)
	self._catRoom:destroy()
	self._panel:destroy()
end

return MyCats
