--!strict
-- Models merged before their feature is built, held back behind an off switch (Derek 2026-11-20: "merge it into the
-- game but behind a switch so its not on yet"). At start-up AssetRegistry.stowServerOnly moves each held template out
-- of ReplicatedStorage.Assets into ServerStorage.HeldAssets, a folder `has`, `known` and `clone` never read, so no
-- client downloads them and no script can place them. A held name comes back only when its switch is on and the code
-- that places it calls AssetRegistry.release(switch).
--
-- cherryGrove: Cherry Blossom Grove, the spring event (Mar 27 to Apr 3 2027, #4386; models from #5339). No code
-- places the Grove yet; the event build releases these when it lands.

local HeldAssets = {}

local GROVE_CATS = { "Sakura", "Koi", "Matcha", "Origami", "PaperLantern", "Bonsai", "BlossomFox", "PetalDragon" }

local HELD: { [string]: { string } } = {
	cherryGrove = {
		"CatCafe_Cherry_Set",
		"CatCafe_Cherry_Portal",
		"CatCafe_Cherry_Stall",
		"CatCafe_Cherry_Petals",
		"CatCafe_Accessory_FlowerCrown",
		"CatCafe_Accessory_LanternHat",
		"CatCafe_Decor_LittleKoiPond",
		"CatCafe_Decor_GroveBlossomTree",
		"CatCafe_Decor_TeaSet",
		"CatCafe_Decor_LanternString",
	},
}
for _, cat in GROVE_CATS do
	for _, pose in { "", "_Sit", "_Work" } do
		table.insert(HELD.cherryGrove, "CatCafe_Cat_" .. cat .. pose)
	end
end

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
