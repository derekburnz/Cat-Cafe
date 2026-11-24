--!strict
-- Models merged before their feature is built, held back behind an off switch (Derek 2026-11-20: "merge it into the
-- game but behind a switch so its not on yet"). At start-up AssetRegistry.stowServerOnly moves each held template out
-- of ReplicatedStorage.Assets into ServerStorage.HeldAssets, a folder `has`, `known` and `clone` never read, so no
-- client downloads them and no script can place them. A held name comes back only when its switch is on and the code
-- that places it calls AssetRegistry.release(switch).
--
-- Nothing is held now: Cherry Blossom Grove (cherryGrove, #5339), the only held set, was removed with its models
-- (Derek 2026-11-24: "remove the cherryblossom event and code from game").

local HeldAssets = {}

local HELD: { [string]: { string } } = {}

local owner: { [string]: string } = {}
for switch, names in HELD do
	for _, name in names do
		owner[name] = switch
	end
end

-- The switch holding `name` back, or nil when it is not held.
function HeldAssets.switchFor(name: string): string?
	return owner[name]
end

-- The template names `switch` holds back (empty for an unknown switch).
function HeldAssets.names(switch: string): { string }
	return table.clone(HELD[switch] or {})
end

return HeldAssets
