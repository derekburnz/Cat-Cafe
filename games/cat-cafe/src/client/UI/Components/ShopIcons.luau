--!strict
-- The uploaded shop icons (Model-Agent's PRs #524 and #526, uploaded by Tools-Agent on 2026-10-28; the table is in
-- /mnt/project-files/Tools-Agent/icon-ids-2026-10-28.md and the sources in assets/cat-cafe/exports/icons): the
-- crates by pool, plain and gold, the Star Treat, the Golden Fish Market perks, the four nets and the seven
-- potions, 512 px PNGs with an outline that still read at 48 px. Each is found by the game's own id, so an id the
-- table does not know yet keeps its glyph:
--   crate("park_crate"), crate("park_golden_crate")   Crate_Park, Crate_Park_Gold
--   crateModel("park_crate")                          CatCafe_Prop_Crate_Park (ReplicatedStorage.Assets, Model-Agent's
--                                                     crates.py; _Gold for a golden crate), drawn by ItemIcon only
--                                                     where the crate has no picture (#1242)
--   potion("gold_rush_potion")                        Potion_GoldRush
--   perk("golden_espresso")                           Perk_GoldenEspresso
--   food("moon_milk")                                 Icon_Clean_MoonMilk: every food's clean picture on its rarity
--                                                     tile (#1070, #1242), in the bowl, bag, shop, dealer and prizes
--   prize("coins"), prize("fish"), prize("spins")     Icon_Clean_Bag, _Fish, _Spin: the money, golden fish and spin
--                                                     prize pictures (#1242)
--   net(level)                                        the net the Upgrades row offers next. Net levels are 0 Basic,
--                                                     1 Sturdy, 2 Pro, 3 Master (Net_L1 to Net_L4, Model-Agent
--                                                     #688), so level 0 offers Net_L2 and the top level keeps Net_L4
--   image("Icon_Decor")                               the HUD's Decor pill; image("Coins") and image("Spin") the
--                                                     prize pictures for coins and spins (F97 section 4)
--   clean("Cats")                                     Icon_Clean_Cats, a clean HUD tile's symbol (2026-11-03)
-- A new upload draws blank until Roblox moderation approves it; IconArt.setImage keeps the glyph until the picture
-- has loaded. Each upload is a new asset, so a changed icon gets a new id here, never a second upload of the same file.
-- Pure, so the cloud test runner checks it.

local Catalog =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))
local DecorPictures = require(script.Parent.DecorPictures)

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
	Spin = "rbxassetid://121432011555252", -- the 8-slice wheel (#1603, Tools-Agent 11-05); was 109715715479737
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
	Icon_Clean_Bag = "rbxassetid://136712178087593", -- BagGold (#1253); was 81699518945581,
	Icon_Clean_Bowl = "rbxassetid://80050724855728",
	Icon_Clean_Cannon = "rbxassetid://134222859642759",
	Icon_Clean_Cats = "rbxassetid://111022016391627",
	Icon_Clean_Caviar = "rbxassetid://94374227160258",
	Icon_Clean_Coin = "rbxassetid://82051681772490", -- CoinGold (#1253); was 112195289471900,
	Icon_Clean_Crate = "rbxassetid://85523439563968",
	Icon_Clean_Decor = "rbxassetid://130851033023889",
	Icon_Clean_Feedback = "rbxassetid://101390180819645",
	Icon_Clean_Fish = "rbxassetid://105273249926486", -- FishGold (#1253); was 111395416488950,
	Icon_Clean_Home = "rbxassetid://128704819455880",
	Icon_Clean_Index = "rbxassetid://72904412280830",
	Icon_Clean_Menu = "rbxassetid://76526281703913",
	Icon_Clean_Potion = "rbxassetid://92456971844930",
	Icon_Clean_Quests = "rbxassetid://120388931985566",
	Icon_Clean_Rewards = "rbxassetid://100352240603614",
	Icon_Clean_Store = "rbxassetid://125596282319075",
	Icon_Clean_Trade = "rbxassetid://86243209880722", -- #1024 (upload run 41649292093)
	Icon_Clean_Tutorial = "rbxassetid://109885867788208",
	Icon_Clean_Upgrades = "rbxassetid://90691118878000",
	-- #1070: the potions, foods and spin wheel redrawn clean (upload-image run 41840327151, 11-04)
	Icon_Clean_PotionTip = "rbxassetid://86488148454995",
	Icon_Clean_PotionLucky = "rbxassetid://105359839986454",
	Icon_Clean_PotionSwift = "rbxassetid://123223898814902",
	Icon_Clean_PotionSteady = "rbxassetid://121053101784702",
	Icon_Clean_PotionBigTip = "rbxassetid://89235368935178",
	Icon_Clean_PotionGoldRush = "rbxassetid://117084495995856",
	Icon_Clean_PotionQuickBait = "rbxassetid://103272653422076",
	Icon_Clean_Tuna = "rbxassetid://128749627858421",
	Icon_Clean_Salmon = "rbxassetid://78789450804337",
	Icon_Clean_Sardines = "rbxassetid://133035243124941",
	Icon_Clean_MoonMilk = "rbxassetid://107176560784324",
	Icon_Clean_StarTreat = "rbxassetid://127060767808144",
	Icon_Clean_Spin = "rbxassetid://126057350997233",
	Icon_Clean_Kibble = "rbxassetid://92153852858346", -- its own bowl of kibble (run 41851955780, 11-04)
	-- #1176: Model-Agent's HUD button pictures (#1185; upload run 41891138375, 11-04), the HUD's tiles prefer them
	Icon_Hud_Store = "rbxassetid://124606819909900",
	Icon_Hud_Cats = "rbxassetid://114712006834691",
	Icon_Hud_Index = "rbxassetid://92879334010014",
	Icon_Hud_Quests = "rbxassetid://117754240235784",
	Icon_Hud_Upgrades = "rbxassetid://90888785565724",
	Icon_Hud_Decor = "rbxassetid://84550217471389",
	Icon_Hud_Rewards = "rbxassetid://85822642571481",
	Icon_Hud_Tutorial = "rbxassetid://86238131724533",
	Icon_Hud_Feedback = "rbxassetid://92396498739111",
	Icon_Hud_Menu = "rbxassetid://137145051907694",
	Icon_Hud_MyCafe = "rbxassetid://133654340052418",
	Icon_Hud_Cannon = "rbxassetid://139270542593530",
	Icon_Hud_Areas = "rbxassetid://74170242876257",
	Icon_Hud_Potions = "rbxassetid://123878686865679",
	Icon_Hud_Bait = "rbxassetid://119953797390858",
	-- #1204: Model-Agent's potion flasks (#1193), ShopIcons.potion prefers them; re-uploaded 11-05 with the Cat Whistles
	Icon_Flask_Tip = "rbxassetid://123800504967936",
	Icon_Flask_Lucky = "rbxassetid://98048607296719",
	Icon_Flask_Swift = "rbxassetid://135893717257825",
	Icon_Flask_Steady = "rbxassetid://113351212828251",
	Icon_Flask_QuickBait = "rbxassetid://72948017962638",
	Icon_Flask_BigTip = "rbxassetid://92073889406433",
	Icon_Flask_GoldRush = "rbxassetid://118260703338891",
	-- #1191 / #1186: the shop-only cats on their Store cards (upload run from main dee66576, 11-05)
	Icon_ShopCat_Sprinkles = "rbxassetid://123101439533132",
	Icon_ShopCat_DuchessMarzipan = "rbxassetid://105207350898043",
	Icon_ShopCat_KingCroissant = "rbxassetid://127183027799927",
	-- #950: the order bubbles' dishes, one per Catalog.menu model (Model-Agent #1101; upload run 41885238133, 11-04)
	Icon_Menu_Coffee = "rbxassetid://79738997061623",
	Icon_Menu_Milk = "rbxassetid://76795195002258",
	Icon_Menu_CakeSlice = "rbxassetid://138724649868181",
	Icon_Menu_PawCookie = "rbxassetid://105880991505196",
	Icon_Menu_Tea = "rbxassetid://134890892831983",
	Icon_Menu_FishBiscuit = "rbxassetid://118748045182640",
	Icon_Menu_KittyCupcake = "rbxassetid://88442415090027",
	Icon_Menu_HotCocoa = "rbxassetid://85103380790377",
	Icon_Menu_PancakeStack = "rbxassetid://132289857954730",
	Icon_Menu_Sundae = "rbxassetid://107717113357371",
	Icon_Menu_StrawberryRoll = "rbxassetid://139023173238823",
	Icon_Menu_RainbowCake = "rbxassetid://120021844545771",
	-- #1302: Model-Agent's Cat Whistle flasks, one per size (re-uploaded 11-05 with the potion flasks)
	Icon_Flask_CatWhistleSmall = "rbxassetid://71443833712403",
	Icon_Flask_CatWhistle = "rbxassetid://94091051776887",
	Icon_Flask_CatWhistleBig = "rbxassetid://82693373943515",
	-- the Decor window's "Your cafe" slots (#964, upload-image run 41728803377 on 11-03)
	Icon_Clean_Wallpaper = "rbxassetid://102259047705880",
	Icon_Clean_Floor = "rbxassetid://100560850589029",
	Icon_Clean_Paint = "rbxassetid://88844625138910",
	Icon_Clean_Spots = "rbxassetid://74579562921955",
	Icon_Clean_Door = "rbxassetid://82896268186640",
	Icon_Clean_Catflap = "rbxassetid://99900172207666",
	-- #1136: the last glyphs that drew the old icon sheet (upload-image run 41889328270, 11-04)
	Icon_Clean_EquipBest = "rbxassetid://89501318892947",
	Icon_Clean_Invite = "rbxassetid://136442901295833",
	Icon_Clean_Lock = "rbxassetid://133489571923895",
	Icon_Clean_Clover = "rbxassetid://70755641486261", -- #1258: the luck clover (upload-image run 41904365295, 11-04)
	-- Tools-Agent's uploads of 11-05: the Fish Market's tabs and the Night Market bubble (#1607)
	Icon_Market_Crates = "rbxassetid://136579300796731",
	Icon_Market_Treats = "rbxassetid://77636724948052",
	Icon_Market_FreshCatch = "rbxassetid://126946598739456",
	Icon_Hud_NightMarket = "rbxassetid://131849751291155",
	-- the Store's card pictures, one per pass and product (Tools-Agent 11-05), by ShopIcons.store
	Icon_Store_Money2x = "rbxassetid://72414082780413",
	Icon_Store_Money3x = "rbxassetid://93298940995735",
	Icon_Store_Money4x = "rbxassetid://106773934084025",
	Icon_Store_LongNap = "rbxassetid://110728484969633",
	Icon_Store_Vip = "rbxassetid://133569273850177",
	Icon_Store_Accessories = "rbxassetid://91892368233364",
	Icon_Store_Uniforms = "rbxassetid://116190763390206",
	Icon_Store_CafeStyle = "rbxassetid://125700174103006",
	Icon_Store_GrandTheme = "rbxassetid://135539710810962",
	Icon_Store_ExtraSlot = "rbxassetid://130412920081703",
	Icon_Store_RoyalCat = "rbxassetid://106295146921956",
	Icon_Store_KingPack = "rbxassetid://96230403324433",
	Icon_Store_GoldenPond = "rbxassetid://118816331540525",
	Icon_Store_SecondBowl = "rbxassetid://130144477542913",
	Icon_Store_StarterBundle = "rbxassetid://72549988670948",
	Icon_Store_PotionXS = "rbxassetid://134857251578252",
	Icon_Store_PotionS = "rbxassetid://123654589605243",
	Icon_Store_PotionM = "rbxassetid://140183392726574",
	Icon_Store_PotionL = "rbxassetid://123626192150241",
	Icon_Store_CafePass = "rbxassetid://114155805195660",
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

-- #1070 (Derek's live v184 check: "the new clean UI pictures in general are not live"): a picture with a clean
-- redraw (Icon_Clean_<Name>) shows that once its id is here; until then the older upload stands in.
local CLEAN_FOR: { [string]: string } = {
	Spin = "Spin",
	Kibble = "Kibble",
	Tuna = "Tuna",
	Sardines = "Sardines",
	Salmon = "Salmon",
	Caviar = "Caviar",
	MoonMilk = "MoonMilk",
	StarTreat = "StarTreat",
}

local function preferClean(name: string): string?
	local clean = CLEAN_FOR[name]
	return (if clean then IDS["Icon_Clean_" .. clean] else nil) or IDS[name]
end

function ShopIcons.image(name: string): string?
	return preferClean(name)
end

function ShopIcons.clean(name: string): string?
	return IDS["Icon_Clean_" .. name]
end

-- A HUD tile's picture (#1185): the 3D-rendered button picture when there is one, else the clean symbol. Named as the
-- clean symbols are (Home is My Cafe, Potion the Potions tile, Bowl the Bait tile).
local HUD_FOR: { [string]: string } =
	{ Home = "MyCafe", Potion = "Potions", Bowl = "Bait", Bag = "Potions" }
function ShopIcons.hud(name: string): string?
	return IDS["Icon_Hud_" .. (HUD_FOR[name] or name)] or IDS["Icon_Clean_" .. name]
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

-- Bottles for potions with no flask of their own yet (#1250): the Cat Whistle borrows the Lucky flask for now.
local POTION_STANDIN: { [string]: string } = {
	cat_whistle = "Icon_Flask_Lucky",
}
-- A size with a flask of its own (#1302) shows it first, then its regular potion's bottles behind it.
local OWN_FLASK: { [string]: string } = {
	cat_whistle_small = "Icon_Flask_CatWhistleSmall",
	cat_whistle = "Icon_Flask_CatWhistle",
	cat_whistle_big = "Icon_Flask_CatWhistleBig",
}

-- Every bottle a potion has, best first (#1256): Model-Agent's flask (#1204), the clean flask in the potion's colour
-- (#1070), the older bottle. IconArt.setImages draws the first that loads, so a flask not yet shared with the game
-- falls back to the next bottle instead of the emoji. A Small or Big size runs its regular potion's timer, so it wears
-- that potion's bottles (corner-shop-v2.md, #1250).
function ShopIcons.potionAll(potionId: string?): { string }
	local list: { string } = {}
	if type(potionId) ~= "string" then
		return list
	end
	local own = OWN_FLASK[potionId]
	if own and IDS[own] then
		table.insert(list, IDS[own])
	end
	local def = Catalog.getPotion(potionId)
	if def and def.buff and def.buff ~= potionId then
		for _, id in ShopIcons.potionAll(def.buff) do
			if not table.find(list, id) then
				table.insert(list, id)
			end
		end
		return list
	end
	local standin = POTION_STANDIN[potionId]
	if standin and IDS[standin] then
		table.insert(list, IDS[standin])
		return list
	end
	local name = potionId:match("^(.+)_potion$")
	if name == nil then
		return list
	end
	local key = pascal(name)
	for _, prefix in { "Icon_Flask_", "Icon_Clean_Potion", "Potion_" } do
		local id = IDS[prefix .. key]
		if id then
			table.insert(list, id)
		end
	end
	return list
end

function ShopIcons.potion(potionId: string?): string?
	return ShopIcons.potionAll(potionId)[1]
end

function ShopIcons.perk(perkId: string?): string?
	return if type(perkId) == "string" then IDS["Perk_" .. pascal(perkId)] else nil
end

-- The one food picture lookup (#1242): every place a food shows (the bowl's card and rows, Market, Fresh Catch, the
-- night dealer, the Tip Jar, Daily Treat, quest and spin prizes) reaches it through ItemIcon.setFood. Only the clean
-- 2D picture (Icon_Clean_<Food>, assets/cat-cafe/ui/icons-clean-2026-11-03) counts: the older food uploads were 3D
-- renders, so a food without a clean picture gets nil and the spec fails.
-- A shop-only cat's picture (#1191) by its name, such as "KingCroissant", or nil.
function ShopIcons.shopCat(name: string?): string?
	return if type(name) == "string" then IDS["Icon_ShopCat_" .. name] else nil
end

-- A Store card's own picture (Tools-Agent's uploads, 11-05), by the card's StoreLogic key: "vip" is Icon_Store_Vip.
-- The money card takes its rung ("money", 3 is Icon_Store_Money3x). Nil for a card with no picture yet.
function ShopIcons.store(key: string?, multiplier: number?): string?
	if type(key) ~= "string" or key == "" then
		return nil
	end
	if key == "money" then
		return if type(multiplier) == "number"
			then IDS[("Icon_Store_Money%dx"):format(multiplier)]
			else nil
	end
	return IDS["Icon_Store_" .. key:sub(1, 1):upper() .. key:sub(2)]
end

-- A Fish Market tab's picture: "Crates", "Treats" or "FreshCatch".
function ShopIcons.market(tab: string): string?
	return IDS["Icon_Market_" .. tab]
end

-- A menu dish's picture for the order bubbles (#950), by its Catalog.menu id: the dish model's own render, or nil.
function ShopIcons.menu(orderId: string?): string?
	local item = if type(orderId) == "string" then Catalog.getMenuItem(orderId) else nil
	local model = if item then (item :: any).model else nil
	return if type(model) == "string" then IDS["Icon_Menu_" .. model] else nil
end

-- Cat food in the Bag (#1181): the clean star treat for every size until the foods have pictures of their own (they
-- are XP treats, not bait, so they don't borrow the bait foods' bowls).
function ShopIcons.catFood(foodId: string?): string?
	return if type(foodId) == "string" then IDS.Icon_Clean_StarTreat else nil
end

function ShopIcons.food(lureId: string?): string?
	return if type(lureId) == "string" then IDS["Icon_Clean_" .. pascal(lureId)] else nil
end

-- The clean picture for a money, golden fish or spin prize (#1242, the Tip Jar, Daily Treat, quest and Index prize
-- chips): the money bag, the golden fish coin and the wheel; nil for any other kind.
local PRIZE_FOR: { [string]: string } = { coins = "Bag", fish = "Fish", spins = "Spin" }
function ShopIcons.prize(kind: string?): string?
	local name = if type(kind) == "string" then PRIZE_FOR[kind] else nil
	return if name then IDS["Icon_Clean_" .. name] else nil
end

-- A decor piece's clean picture by its catalog id (#1072, Components/DecorPictures), or nil for an unknown id.
function ShopIcons.decor(decorId: string?): string?
	return if type(decorId) == "string" then DecorPictures[decorId] else nil
end

function ShopIcons.net(level: number?): string?
	local owned = if type(level) == "number" and level == level then math.floor(level) else 0
	return IDS["Net_L" .. math.clamp(owned + 2, 1, NETS)] -- level n holds Net_L(n + 1) and offers the next
end

return ShopIcons
