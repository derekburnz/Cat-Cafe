--!strict
-- Which models only the server ever clones (#3743). Everything under ReplicatedStorage.Assets is sent to every
-- client as it joins and stays in its memory. The area kit sets (CatCafe_<Area>_Set...) and the backdrop rings
-- (CatCafe_<Area>_Backdrop...) are cloned into Workspace by the server alone, where streaming hands a client only
-- the parts near it, so their templates are moved to ServerStorage at start-up (AssetRegistry.stowServerOnly) and no
-- client downloads or keeps them. A name belongs here only when no client script looks its template up.

local ServerOnlyAssets = {}

local KINDS = { "Set", "Backdrop" }

-- The name is CatCafe_<Area>_Set or CatCafe_<Area>_Backdrop, alone or with a version tag of one capital and digits
-- (F85, V32). Nothing looser: a model named ..._Settee is not a set.
function ServerOnlyAssets.matches(name: string): boolean
	for _, kind in KINDS do
		local stem = "^CatCafe_%a+_" .. kind
		if
			string.match(name, stem .. "$") ~= nil
			or string.match(name, stem .. "%u%d+$") ~= nil
		then
			return true
		end
	end
	return false
end

return ServerOnlyAssets
