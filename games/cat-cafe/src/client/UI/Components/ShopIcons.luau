--!strict
-- The uploaded shop icons (Model-Agent's PRs #524 and #526, uploaded by Tools-Agent on 2026-10-28; the table is in
-- /mnt/project-files/Tools-Agent/icon-ids-2026-10-28.md and the sources in assets/cat-cafe/exports/icons): the
-- crates by pool, plain and gold, the Star Treat, the Golden Fish Market perks, the four nets and the seven
-- potions, 512 px PNGs with an outline that still read at 48 px. Each is found by the game's own id, so an id the
-- table does not know yet keeps its glyph:
--   crate("park_crate"), crate("park_golden_crate")   Crate_Park, Crate_Park_Gold
--   crateModel("park_crate")                          CatCafe_Prop_Crate_Park (ReplicatedStorage.Assets, Model-Agent's
--                                                     crates.py; _Gold for a golden crate), the 3D crate under its
--                                                     picture until the picture loads (ItemIcon)
--   potion("gold_rush_potion")                        Potion_GoldRush
--   perk("golden_espresso")                           Perk_GoldenEspresso
--   food("moon_milk")                                 MoonMilk: every food's picture on its rarity tile (F97 section 3,
--                                                     Model-Agent #690), in the bowl, bag, shop, dealer and prizes
--   net(level)                                        the net the Upgrades row offers next. Net levels are 0 Basic,
--                                                     1 Sturdy, 2 Pro, 3 Master (Net_L1 to Net_L4, Model-Agent
--                                                     #688), so level 0 offers Net_L2 and the top level keeps Net_L4
--   image("Icon_Decor")                               the HUD's Decor pill; image("Coins") and image("Spin") the
--                                                     prize pictures for coins and spins (F97 section 4)
--   clean("Cats")                                     Icon_Clean_Cats, a clean HUD tile's symbol (2026-11-03)
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
	Crate_Rally = "rbxassetid://98563574379030", -- F101 Rally Crate (Model-Agent #766), banked only and no golden twin
	-- F97 sections 3 and 4: the seven foods, the treats and perks redrawn and the prize pictures (Model-Agent #690,
	-- uploaded by Tools-Agent 2026-11-02)
	Kibble = "rbxassetid://72655226790914",
	Tuna = "rbxassetid://124162697131689",
	Sardines = "rbxassetid://139838878350639",
	Salmon = "rbxassetid://80858934641565",
	Caviar = "rbxassetid://85088071747450",
	MoonMilk = "rbxassetid://131532306991173",
	StarTreat = "rbxassetid://84410663358335",
	Perk_GoldenEspresso = "rbxassetid://98225135686857",
	Perk_BigBowl = "rbxassetid://106206692502921",
	Perk_ExtraDecorSpot = "rbxassetid://72709782259210",
	Coins = "rbxassetid://114567888385946",
	Spin = "rbxassetid://109715715479737",
	-- the redesigned nets (#989, Model-Agent; rendered and uploaded by Tools-Agent 2026-11-03, PR #1012)
	Net_L1 = "rbxassetid://78131427035748", -- Basic
	Net_L2 = "rbxassetid://126997379642004", -- Sturdy
	Net_L3 = "rbxassetid://113664337149561", -- Pro
	Net_L4 = "rbxassetid://115470138259311", -- Master
	Potion_Tip = "rbxassetid://93263370812167",
	Potion_Lucky = "rbxassetid://113720150794733",
	Potion_Swift = "rbxassetid://73826039259143",
	Potion_Steady = "rbxassetid://73487077104082",
	Potion_BigTip = "rbxassetid://88414799294549", -- the Big Money jug (Model-Agent #700, uploaded 2026-11-02)
	Potion_GoldRush = "rbxassetid://120517326297613",
	Potion_QuickBait = "rbxassetid://88867156736573",
	-- the HUD's Decor pill: a cat-eared armchair and a potted plant (Model-Agent, Set 5 Q10; uploaded 2026-11-02)
	Icon_Decor = "rbxassetid://132974074427583",
	-- the clean symbols on the HUD tiles (Derek 2026-11-03 "Build it as shown"; assets/cat-cafe/ui/icons-clean-2026-11-03,
	-- uploaded 2026-11-03): one bold symbol with a thick dark outline, the tile behind it drawn in Luau
	Icon_Clean_Areas = "rbxassetid://126370922327019",
	Icon_Clean_Bag = "rbxassetid://81699518945581",
	Icon_Clean_Bowl = "rbxassetid://80050724855728",
	Icon_Clean_Cannon = "rbxassetid://112726655919470",
	Icon_Clean_Cats = "rbxassetid://111022016391627",
	Icon_Clean_Caviar = "rbxassetid://94374227160258",
	Icon_Clean_Coin = "rbxassetid://112195289471900",
	Icon_Clean_Crate = "rbxassetid://85523439563968",
	Icon_Clean_Decor = "rbxassetid://130851033023889",
	Icon_Clean_Feedback = "rbxassetid://101390180819645",
	Icon_Clean_Fish = "rbxassetid://111395416488950",
	Icon_Clean_Home = "rbxassetid://102266682155402",
	Icon_Clean_Index = "rbxassetid://72904412280830",
	Icon_Clean_Menu = "rbxassetid://76526281703913",
	Icon_Clean_Potion = "rbxassetid://74312502748629",
	Icon_Clean_Quests = "rbxassetid://120388931985566",
	Icon_Clean_Rewards = "rbxassetid://100352240603614",
	Icon_Clean_Store = "rbxassetid://125596282319075",
	Icon_Clean_Tutorial = "rbxassetid://109885867788208",
	Icon_Clean_Upgrades = "rbxassetid://90691118878000",
}
local NETS = 4

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

function ShopIcons.clean(name: string): string?
	return IDS["Icon_Clean_" .. name]
end

-- The crate's pool in PascalCase and whether it is the golden twin, or nil for an id that is not a crate.
local function cratePool(crateId: string?): (string?, boolean)
	if type(crateId) ~= "string" then
		return nil, false
	end
	local golden = crateId:match("^(.+)_golden_crate$")
	local area = golden or crateId:match("^(.+)_crate$")
	if area == nil then
		return nil, false
	end
	return pascal(area), golden ~= nil
end

function ShopIcons.crate(crateId: string?): string?
	local pool, golden = cratePool(crateId)
	if pool == nil then
		return nil
	end
	return IDS["Crate_" .. pool .. (if golden then "_Gold" else "")]
end

function ShopIcons.crateModel(crateId: string?): string?
	local pool, golden = cratePool(crateId)
	if pool == nil then
		return nil
	end
	return "CatCafe_Prop_Crate_" .. pool .. (if golden then "_Gold" else "")
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
	return IDS["Net_L" .. math.clamp(owned + 2, 1, NETS)] -- level n holds Net_L(n + 1) and offers the next
end

return ShopIcons
