--!strict
-- Pass decor given by a game pass (#1168 row 3, the Garden Decor Pack), pure: Catalog.passDecor pieces with a
-- `passKey` are owned while the player owns that pass. ShopCatService gives each missing one into
-- profile.decorOwned at join and when PassService learns of a purchase; owning a piece twice is the same as once, so
-- nothing else is saved. They follow every pass decor rule: looks only, not for sale, trade or quests.
--   passId(def) -> number                       the pass id that gives `def`, 0 for none or not made
--   toGrant(profile, ownsPass) -> { decorId }   the pieces owed now, in Catalog order

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local PassDecor = {}

function PassDecor.passId(def: Types.DecorDef): number
	if def.passKey == nil then
		return 0
	end
	local id = (Config :: any)[def.passKey :: string]
	return if type(id) == "number" then id else 0
end

function PassDecor.toGrant(
	profile: Types.PlayerProfile,
	ownsPass: (passId: number) -> boolean
): { string }
	local out: { string } = {}
	for _, def in Catalog.passDecor do
		local id = PassDecor.passId(def)
		if id ~= 0 and ownsPass(id) and profile.decorOwned[def.id] ~= true then
			table.insert(out, def.id)
		end
	end
	return out
end

return PassDecor
