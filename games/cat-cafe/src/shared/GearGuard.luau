--!strict
-- No avatar gear in game (Derek 2026-11-04, #1062: "no gear from items allowed in game"). Gear is a catalog item that
-- puts a Tool in the player's Backpack (a sword, a launcher). The game itself hands out no Tools: the net, carried
-- cats and the cannon are all drawn by client Effects. So a Tool or HopperBin is foreign unless the game marked it
-- with the attribute MARK = true. Accessories, clothing and anything else on the avatar are never foreign. Pure, so
-- the spec can check it; GearGuardService does the removing.
--
-- Roblox terms: a Tool is an item a character holds in its hand, kept in the player's Backpack while not held and
-- copied in from StarterGear at every spawn. A HopperBin is the old, deprecated kind.

local GearGuard = {}

GearGuard.MARK = "CatCafeTool" -- set to true on a Tool the game makes, so the guard keeps it
GearGuard.CLASSES = { "Tool", "HopperBin" }

-- Whether `instance` is a Tool (or HopperBin) the game did not make, and so is removed.
function GearGuard.isForeign(instance: Instance): boolean
	local held = false
	for _, className in GearGuard.CLASSES do
		if instance:IsA(className) then
			held = true
			break
		end
	end
	return held and instance:GetAttribute(GearGuard.MARK) ~= true
end

return GearGuard
