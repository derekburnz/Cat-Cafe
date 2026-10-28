--!strict
-- The uploaded shop icons (Model-Agent's PRs #524 and #526, uploaded by Tools-Agent on 2026-10-28; the table is in
-- /mnt/project-files/Tools-Agent/icon-ids-2026-10-28.md and the sources in assets/cat-cafe/exports/icons): the
-- crates by pool, plain and gold, the Star Treat, the Golden Fish Market perks, the three nets and the seven
-- potions, 512 px PNGs with an outline that still read at 48 px. Each is found by the game's own id, so an id the
-- table does not know yet keeps its glyph:
--   crate("park_crate"), crate("park_golden_crate")   Crate_Park, Crate_Park_Gold
--   potion("gold_rush_potion")                        Potion_GoldRush
--   perk("golden_espresso")                           Perk_GoldenEspresso
--   food("star_treat")                                StarTreat (the Market's treat row; foods elsewhere show models)
--   net(level)                                        the net the Upgrades row offers next: Net_L1 at level 0, up to
--                                                     Net_L3, which stays at the top level
-- A new upload draws blank until Roblox moderation approves it; IconArt.setImage keeps the glyph until the picture
-- has loaded. Each upload is a new asset, so a changed icon gets a new id here, never a second upload of the same file.
-- Pure, so the cloud test runner checks it.

local ShopIcons = {}

local IDS: { [string]: string } = {
	Crate_Alley = "rbxassetid://78708739857652",
	Crate_Alley_Gold = "rbxassetid://94773200670831",
	Crate_Park = "rbxassetid://93890210834888",
	Crate_Park_Gold = "rbxassetid://128353692348155",
	Crate_Neighbourhood = "rbxassetid://123846771813925",
	Crate_Neighbourhood_Gold = "rbxassetid://104596302682923",
	Crate_Woods = "rbxassetid://107036042438670",
	Crate_Woods_Gold = "rbxassetid://96093365525602",
	Crate_Sewer = "rbxassetid://71389193378915",
	Crate_Sewer_Gold = "rbxassetid://120879068594961",
	Crate_Classic = "rbxassetid://133393182247275",
	Crate_Classic_Gold = "rbxassetid://128067890373321",
	StarTreat = "rbxassetid://89972376116236",
	Perk_GoldenEspresso = "rbxassetid://132258611907175",
	Perk_BigBowl = "rbxassetid://94394216447416",
	Perk_ExtraDecorSpot = "rbxassetid://124769414540372",
	Net_L1 = "rbxassetid://104509386957749",
	Net_L2 = "rbxassetid://94191591906324",
	Net_L3 = "rbxassetid://120155972260812",
	Potion_Tip = "rbxassetid://93263370812167",
	Potion_Lucky = "rbxassetid://113720150794733",
	Potion_Swift = "rbxassetid://73826039259143",
	Potion_Steady = "rbxassetid://73487077104082",
	Potion_BigTip = "rbxassetid://72358158442143",
	Potion_GoldRush = "rbxassetid://120517326297613",
	Potion_QuickBait = "rbxassetid://88867156736573",
}
local NETS = 3

-- "gold_rush" -> "GoldRush", the asset names' way of writing an id
local function pascal(id: string): string
	local words: { string } = {}
	for word in id:gmatch("[^_]+") do
		table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
	end
	return table.concat(words)
end

function ShopIcons.image(name: string): string?
	return IDS[name]
end

function ShopIcons.crate(crateId: string?): string?
	if type(crateId) ~= "string" then
		return nil
	end
	local golden = crateId:match("^(.+)_golden_crate$")
	local area = golden or crateId:match("^(.+)_crate$")
	if area == nil then
		return nil
	end
	return IDS["Crate_" .. pascal(area) .. (if golden then "_Gold" else "")]
end

function ShopIcons.potion(potionId: string?): string?
	local name = if type(potionId) == "string" then potionId:match("^(.+)_potion$") else nil
	return if name then IDS["Potion_" .. pascal(name)] else nil
end

function ShopIcons.perk(perkId: string?): string?
	return if type(perkId) == "string" then IDS["Perk_" .. pascal(perkId)] else nil
end

function ShopIcons.food(lureId: string?): string?
	return if type(lureId) == "string" then IDS[pascal(lureId)] else nil
end

function ShopIcons.net(level: number?): string?
	local owned = if type(level) == "number" and level == level then math.floor(level) else 0
	return IDS["Net_L" .. math.clamp(owned + 1, 1, NETS)]
end

return ShopIcons
