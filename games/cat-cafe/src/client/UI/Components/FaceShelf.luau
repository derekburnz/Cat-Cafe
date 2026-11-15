--!strict
-- #4271 (Derek 2026-11-14: "when going to this screen each time to pick a cat takes a second to load the cats faces"):
-- the little head faces of the Pick a cat lists (the Mystic Pool's and the Oasis Spa's) are kept between opens
-- instead of built again. A face a list lets go (Back, a closed card, a row scrolled far away, a rebuilt list) is
-- parked here by its look (the cat, its gold coat, its ZIndex); the next row with that look takes it back at once, so
-- no cat model is cloned again. warm() builds the faces of a list's first rows a few a frame while its card is open,
-- so the first Pick a cat is quick too. At most MAX faces wait here; past that the oldest is destroyed.
-- A face that showed the cat's initial (Assets had no model yet) tries its model again when taken.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatPortrait = require(script.Parent.CatPortrait)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any

local FaceShelf = {}

FaceShelf.MAX = 48
FaceShelf.WARM_PER_FRAME = 4

export type Look = { catId: string, gold: boolean }

type Parked = { key: string, portrait: CatPortrait.CatPortrait }

local parked: { Parked } = {} -- oldest first
local warmToken = 0

local function keyOf(catId: string, gold: boolean, zIndex: number): string
	return ("%s:%s:%d"):format(catId, if gold then "g" else "n", zIndex)
end

local function build(catId: string, gold: boolean, zIndex: number): CatPortrait.CatPortrait
	local portrait = CatPortrait.new({
		parent = nil :: any,
		size = UDim2.fromScale(1, 1),
		still = true,
		head = true,
		zIndex = zIndex,
	})
	portrait:set(Catalog.getCat(catId), gold)
	return portrait
end

-- a face for the cat in `parent`: a parked one with the same look when there is one, else a new one
function FaceShelf.take(
	parent: Instance,
	catId: string,
	gold: boolean,
	zIndex: number
): CatPortrait.CatPortrait
	local key = keyOf(catId, gold, zIndex)
	for index = #parked, 1, -1 do
		local entry = parked[index]
		if entry.key == key then
			table.remove(parked, index)
			local portrait = entry.portrait
			if not portrait:hasModel() then
				portrait:set(Catalog.getCat(catId), gold)
			end
			portrait.frame.Parent = parent
			return portrait
		end
	end
	local portrait = build(catId, gold, zIndex)
	portrait.frame.Parent = parent
	return portrait
end

-- parks a face a list let go, for the next row with its look
function FaceShelf.give(
	portrait: CatPortrait.CatPortrait,
	catId: string,
	gold: boolean,
	zIndex: number
)
	portrait.frame.Parent = nil
	table.insert(parked, { key = keyOf(catId, gold, zIndex), portrait = portrait })
	while #parked > FaceShelf.MAX do
		local oldest = table.remove(parked, 1)
		if oldest then
			oldest.portrait:destroy()
		end
	end
end

-- how many faces with this look are parked
function FaceShelf.count(catId: string, gold: boolean, zIndex: number): number
	local key = keyOf(catId, gold, zIndex)
	local count = 0
	for _, entry in parked do
		if entry.key == key then
			count += 1
		end
	end
	return count
end

-- builds the faces `looks` will need that are not parked yet, WARM_PER_FRAME a frame; a later warm() stops this one
function FaceShelf.warm(looks: { Look }, zIndex: number)
	warmToken += 1
	local token = warmToken
	local need: { [string]: number } = {}
	local todo: { Look } = {}
	for _, look in looks do
		local key = keyOf(look.catId, look.gold, zIndex)
		need[key] = (need[key] or 0) + 1
		if need[key] > FaceShelf.count(look.catId, look.gold, zIndex) then
			table.insert(todo, look)
		end
	end
	if #todo == 0 then
		return
	end
	task.spawn(function()
		for index, look in todo do
			if warmToken ~= token or #parked >= FaceShelf.MAX then
				return
			end
			FaceShelf.give(build(look.catId, look.gold, zIndex), look.catId, look.gold, zIndex)
			if index % FaceShelf.WARM_PER_FRAME == 0 then
				task.wait()
			end
		end
	end)
end

-- every parked face destroyed (tests, and a list that is torn down for good)
function FaceShelf.clear()
	warmToken += 1
	for _, entry in parked do
		entry.portrait:destroy()
	end
	table.clear(parked)
end

return FaceShelf
