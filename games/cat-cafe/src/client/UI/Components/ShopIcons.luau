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
--                                                     prize pictures (#1242); spins the 8-slice wheel (Icon_Hud_Spin,
--                                                     #1665) once it is uploaded
--   backup(image)                                     a HUD picture's clean symbol, which IconArt draws if the
--                                                     picture fails to load (#1665: the flat wheel behind the 8-slice)
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
local StationIcons = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StationIcons")
)

local ShopIcons = {}

local IDS: { [string]: string } = {
	Crate_Alley = "rbxassetid://89977150666551",
	Crate_Alley_Gold = "rbxassetid://71326180864166",
	Crate_Park = "rbxassetid://99138938694775",
	Crate_Park_Gold = "rbxassetid://106615919789791",
	Crate_Neighbourhood = "rbxassetid://126614055908675",
	Crate_Neighbourhood_Gold = "rbxassetid://113152390195595",
	Crate_Woods = "rbxassetid://89298263631374",
	Crate_Woods_Gold = "rbxassetid://88058616154989",
	Crate_Sewer = "rbxassetid://91699360088995",
	Crate_Sewer_Gold = "rbxassetid://124966004942410",
	-- Tier 6/7 (Model-Agent #2677, upload-image run 42585003460); dormant until the opening adds the crates
	Crate_Desert = "rbxassetid://108204341894175",
	Crate_Desert_Gold = "rbxassetid://94504392823331",
	Crate_Ruins = "rbxassetid://118466907555386",
	Crate_Ruins_Gold = "rbxassetid://131280595657141",
	-- Tier 8 Snowy Mountain (#3997, Model-Agent's 256 store pictures, group owned)
	Crate_Snowy = "rbxassetid://111252121844431",
	Crate_Snowy_Gold = "rbxassetid://77415248022047",
	-- Tier 9 Water Park (#4070, Model-Agent's 256 store pictures, group owned)
	Crate_WaterPark = "rbxassetid://131949222748155",
	Crate_WaterPark_Gold = "rbxassetid://85963054237364",
	-- Tier 10 Medieval Castle (#4184, Model-Agent's 256 store pictures, group owned)
	Crate_Castle = "rbxassetid://86599176060723",
	Crate_Castle_Gold = "rbxassetid://89340633875692",
	Crate_Classic = "rbxassetid://72888217681662",
	Crate_Classic_Gold = "rbxassetid://115785859034580",
	Crate_Rally = "rbxassetid://94810600062208", -- F101 Rally Crate (Model-Agent #766), banked only and no golden twin
	-- F97 sections 3 and 4: the seven foods, the treats and perks redrawn and the prize pictures (Model-Agent #690,
	-- uploaded by Tools-Agent 2026-11-02)
	Kibble = "rbxassetid://112495381512747",
	Tuna = "rbxassetid://114230467472743",
	Sardines = "rbxassetid://102256283854367",
	Salmon = "rbxassetid://72002329374539",
	Caviar = "rbxassetid://114217328456993",
	MoonMilk = "rbxassetid://94804178054390",
	StarTreat = "rbxassetid://89446428214368",
	Perk_GoldenEspresso = "rbxassetid://80895257824037",
	Perk_BigBowl = "rbxassetid://101890374566463",
	Perk_ExtraDecorSpot = "rbxassetid://127455759320133",
	-- #3330 (Derek 2026-11-12: "ok"): Swift Paws' own picture, the running cat
	-- (assets/cat-cafe/exports/icons/CatCafe_Icon_Perk_SwiftPaws.png); it was the paw cookie dish as a stand-in
	Perk_SwiftPaws = "rbxassetid://114197584746542",
	-- #3298: the Lucky Charm's own picture, the clover charm with a gold paw coin
	-- (assets/cat-cafe/exports/icons/CatCafe_Icon_Perk_LuckyCharm.png, upload run 43189985202); it was the luck clover
	Perk_LuckyCharm = "rbxassetid://133159412866776",
	Coins = "rbxassetid://79655038297576",
	Spin = "rbxassetid://112937898262429", -- the 8-slice wheel (#1603, Tools-Agent 11-05); was 109715715479737
	-- the redesigned nets (#989, Model-Agent; rendered and uploaded by Tools-Agent 2026-11-03, PR #1012)
	Net_L1 = "rbxassetid://73395070545023", -- Basic
	Net_L2 = "rbxassetid://115749849359916", -- Sturdy
	Net_L3 = "rbxassetid://81977508273905", -- Pro
	Net_L4 = "rbxassetid://139611963099304", -- Master
	Potion_Tip = "rbxassetid://78228531662647",
	Potion_Lucky = "rbxassetid://109956828055851",
	Potion_Swift = "rbxassetid://106601094256001",
	Potion_Steady = "rbxassetid://91408225655158",
	Potion_BigTip = "rbxassetid://84580069848778", -- the Big Money jug (Model-Agent #700, uploaded 2026-11-02)
	Potion_GoldRush = "rbxassetid://87524443156600",
	Potion_QuickBait = "rbxassetid://103827859918501",
	-- the HUD's Decor pill: a cat-eared armchair and a potted plant (Model-Agent, Set 5 Q10; uploaded 2026-11-02)
	Icon_Decor = "rbxassetid://87005516591423",
	-- the clean symbols on the HUD tiles (Derek 2026-11-03 "Build it as shown"; assets/cat-cafe/ui/icons-clean-2026-11-03,
	-- uploaded 2026-11-03): one bold symbol with a thick dark outline, the tile behind it drawn in Luau
	Icon_Clean_Areas = "rbxassetid://88534680940711",
	Icon_Clean_Bag = "rbxassetid://122240410730197", -- BagGold (#1253); was 81699518945581,
	Icon_Clean_Bowl = "rbxassetid://103532889738881",
	Icon_Clean_Cannon = "rbxassetid://136623310503178",
	Icon_Clean_Cats = "rbxassetid://98525501130510",
	Icon_Clean_Caviar = "rbxassetid://75650997072096",
	Icon_Clean_Coin = "rbxassetid://85581311877137", -- CoinGold (#1253); was 112195289471900,
	-- #2089 (Derek2: the "?" box "shouldn't be anywhere"): the crate glyph draws the Classic Crate's picture, not the
	-- mystery box (76162414943592) from icons-clean-2026-11-03
	Icon_Clean_Crate = "rbxassetid://81784091360384",
	Icon_Clean_Decor = "rbxassetid://91027671376875",
	Icon_Clean_Feedback = "rbxassetid://86899710660019",
	Icon_Clean_Fish = "rbxassetid://101061912700342", -- FishGold (#1253); was 111395416488950,
	Icon_Clean_Home = "rbxassetid://72142107975309",
	Icon_Clean_Index = StationIcons.index,
	Icon_Clean_Menu = "rbxassetid://139128379842736",
	Icon_Clean_Potion = "rbxassetid://78951217322160",
	Icon_Clean_Quests = "rbxassetid://117962329343232",
	Icon_Clean_Rewards = "rbxassetid://105337391774119",
	Icon_Clean_Store = "rbxassetid://111734554524173",
	Icon_Clean_Trade = "rbxassetid://83738164568639", -- #1024 (upload run 41649292093)
	Icon_Clean_Tutorial = "rbxassetid://83538572417569",
	Icon_Clean_Upgrades = "rbxassetid://138549739967320",
	-- #1070: the potions, foods and spin wheel redrawn clean (upload-image run 41840327151, 11-04)
	Icon_Clean_PotionTip = "rbxassetid://95886862906328",
	Icon_Clean_PotionLucky = "rbxassetid://110403070747780",
	Icon_Clean_PotionSwift = "rbxassetid://89283276917014",
	Icon_Clean_PotionSteady = "rbxassetid://98428729313169",
	Icon_Clean_PotionBigTip = "rbxassetid://111286476050307",
	Icon_Clean_PotionGoldRush = "rbxassetid://134577238271535",
	Icon_Clean_PotionQuickBait = "rbxassetid://117064600223329",
	Icon_Clean_Tuna = "rbxassetid://82422020475314",
	Icon_Clean_Salmon = "rbxassetid://118506839858835",
	Icon_Clean_Sardines = "rbxassetid://77462554026769",
	Icon_Clean_MoonMilk = "rbxassetid://109614940712323",
	Icon_Clean_StarTreat = "rbxassetid://109199304319470",
	-- #3462: the Day Cart's own two baits (upload run 43189985202, 11-12)
	Icon_Clean_HoneyCream = "rbxassetid://101594576071338",
	Icon_Clean_CometTreat = "rbxassetid://130150324251209",
	Icon_Clean_Spin = "rbxassetid://92256242473029",
	Icon_Clean_TipJar = "rbxassetid://88738180093821", -- #4046: the Tip Jar quest's picture (🫙 draws blank on Roblox)
	Icon_Clean_TipPile = "rbxassetid://120928045593770", -- #4046: the tip piles quest's (🪙 draws blank too)
	Icon_Clean_Kibble = "rbxassetid://73553280032864", -- its own bowl of kibble (run 41851955780, 11-04)
	-- #1176: Model-Agent's HUD button pictures (#1185; upload run 41891138375, 11-04), the HUD's tiles prefer them
	Icon_Hud_Store = "rbxassetid://93922915271593",
	Icon_Hud_Cats = "rbxassetid://128934109652993",
	Icon_Hud_Index = "rbxassetid://112280887799331",
	Icon_Hud_Quests = "rbxassetid://95564077416301",
	Icon_Hud_Upgrades = "rbxassetid://77095224499160",
	Icon_Hud_Decor = "rbxassetid://86813195597770",
	Icon_Hud_Rewards = "rbxassetid://92082059264129",
	Icon_Hud_Tutorial = "rbxassetid://135669221127164",
	Icon_Hud_Feedback = "rbxassetid://114483797911389",
	Icon_Hud_Menu = "rbxassetid://135021601977821",
	Icon_Hud_MyCafe = "rbxassetid://72852868500556",
	Icon_Hud_Cannon = "rbxassetid://72423459131220",
	Icon_Hud_Areas = "rbxassetid://140584233944874",
	Icon_Hud_Potions = "rbxassetid://130302894956532",
	Icon_Hud_Bait = "rbxassetid://102824386265413",
	-- #2836: the Bag tile's backpack, redrawn (Model-Agent); was 88244676943674 (#2453). #2866: these #2836 pictures
	-- are the group-owned uploads (run 42714863021): the first ones (run 42688251868) were owned by a user, not the
	-- Creampuff Games group that owns the experience, so they never loaded in game
	Icon_Hud_Bag = "rbxassetid://118552497512285",
	-- #2836 (Derek2 11-09: "make sure all our buttons/icons are high quality"): the icons that were still emoji, drawn
	-- by Model-Agent (PR #2837, group upload run 42714863021): window badges, Mystery Market items, Upgrades rows, staff roles
	-- and the glyphs of ShopIcons.glyph
	Icon_Hud_MysteryMarket = "rbxassetid://135736034982334",
	Icon_Hud_Codes = "rbxassetid://84414152743459",
	Icon_Hud_Collector = "rbxassetid://90382038437888",
	Icon_Hud_CornerShop = "rbxassetid://71531724995498",
	Icon_Hud_LawnStall = "rbxassetid://101264343022880",
	Icon_Hud_RankUp = "rbxassetid://87240525857020",
	Icon_Hud_Bellhop = "rbxassetid://72671179884106",
	Icon_Hud_YardSale = "rbxassetid://119512773142032",
	-- #3715: the Picnic Treats pick card (Model-Agent, icons-2836-pass2-asset-ids.md)
	Icon_Hud_PicnicSandwich = "rbxassetid://132726319271125",
	Icon_Hud_PicnicLemonade = "rbxassetid://81662521137810",
	Icon_Hud_PicnicCupcake = "rbxassetid://70925840022035",
	Icon_Hud_BigBackpack = "rbxassetid://80136188031786",
	Icon_Hud_LongNet = "rbxassetid://90836615615293",
	Icon_Hud_Tables = "rbxassetid://138663166395206",
	Icon_Hud_Espresso = "rbxassetid://70770941486788",
	Icon_Hud_LuckyCat = "rbxassetid://132227817822754",
	Icon_Hud_RoleBarista = "rbxassetid://139962570964663",
	Icon_Hud_RoleWaiter = "rbxassetid://83884948963742",
	Icon_Hud_RoleGreeter = "rbxassetid://121121309316758",
	Icon_Hud_RoleEntertainer = "rbxassetid://82059166033800",
	-- #3137 batch 1 (Derek2 11-10: "go through lots of simple plain looking images for ui/buttons and make them
	-- better", OK'd 22:18): the clean redraws of the Upgrades rows, the staff roles and the Oasis Spa (upload run
	-- 42913358930, assets/cat-cafe/ui/icons-clean-2026-11-10). They win over the #2836 pictures above, which stay as
	-- their backups (BACKUP) while one is in moderation or fails to load.
	Icon_Clean_Tables = "rbxassetid://78752964799899",
	Icon_Clean_Espresso = "rbxassetid://75462239871153",
	Icon_Clean_Net = "rbxassetid://107635112477250",
	Icon_Clean_LureBowl = "rbxassetid://125008235885167",
	Icon_Clean_LuckyCat = "rbxassetid://130158950733679",
	Icon_Clean_Barista = "rbxassetid://88726552754770",
	Icon_Clean_Waiter = "rbxassetid://122492899176267",
	Icon_Clean_Greeter = "rbxassetid://107746555479783",
	Icon_Clean_Entertainer = "rbxassetid://79258683838050",
	Icon_Clean_Spa = StationIcons.spa,
	-- #3137 batch 2 (Derek2 OK'd the night's uploads, 11-11 01:05): the seven places (upload run 42937300084,
	-- assets/cat-cafe/ui/icons-clean-2026-11-11), drawn wherever IconArt meets their emoji (Components/CleanGlyphs)
	Icon_Clean_Park = "rbxassetid://130402303377210",
	Icon_Clean_Neighbourhood = "rbxassetid://81559978948079",
	Icon_Clean_Woods = "rbxassetid://88100194069700",
	Icon_Clean_Sewer = "rbxassetid://73407312338999",
	Icon_Clean_Desert = "rbxassetid://105252509632683",
	Icon_Clean_Ruins = "rbxassetid://117006304300316",
	Icon_Clean_Town = "rbxassetid://84240054469741",
	-- #3137 batch 3 (upload run 42938004143): the moon and the open padlock
	Icon_Clean_Moon = "rbxassetid://113770680051546",
	Icon_Clean_Unlock = "rbxassetid://96025123745905",
	-- #3347 batch 4 (group upload run 43100302103): the station ring cards; Arcade is also its window badge
	Icon_Clean_Museum = StationIcons.museum,
	Icon_Clean_Picnic = StationIcons.picnic,
	Icon_Clean_YardSale = StationIcons.yardSale,
	Icon_Clean_Pond = StationIcons.pond,
	Icon_Clean_LostFound = StationIcons.lostFound,
	Icon_Clean_Arcade = StationIcons.arcade,
	-- #2836 pass 2: the Settings rows' pictures (Model-Agent, group upload run 42714863021 (#2866), PR #2841); ShopIcons.setting
	Icon_Hud_SetMusic = "rbxassetid://133550441899269",
	Icon_Hud_SetMusicVolume = "rbxassetid://121500344853399",
	Icon_Hud_SetSound = "rbxassetid://84421677689373",
	Icon_Hud_SetSoundVolume = "rbxassetid://112942895984882",
	Icon_Hud_SetShake = "rbxassetid://119648360278316",
	Icon_Hud_SetGraphics = "rbxassetid://101442452138583",
	Icon_Hud_SetOtherCats = "rbxassetid://135606355539286",
	Icon_Hud_SetMapIcons = "rbxassetid://92633540550530",
	Icon_Hud_SetAlerts = "rbxassetid://91320103356463",
	Icon_Hud_SetRecap = "rbxassetid://104775964175629",
	Icon_Hud_SetAutoEquip = "rbxassetid://111363357251441",
	Icon_Hud_Drop = "rbxassetid://97885622815890",
	Icon_Hud_Replay = "rbxassetid://139386695065503",
	Icon_Hud_Tag = "rbxassetid://118492801057625",
	Icon_Hud_Plate = "rbxassetid://95169380805311",
	-- #1665: the 8-slice Spin wheel (#1603's render; upload run 42119348490, 11-05), every spin picture prefers it
	Icon_Hud_Spin = "rbxassetid://112937898262429",
	-- #1204: Model-Agent's potion flasks (#1193), ShopIcons.potion prefers them; re-uploaded 11-05 with the Cat Whistles
	Icon_Flask_Tip = "rbxassetid://74973644801326",
	Icon_Flask_Lucky = "rbxassetid://82829893290049",
	Icon_Flask_Swift = "rbxassetid://90536678125794",
	Icon_Flask_Steady = "rbxassetid://113221296833434",
	Icon_Flask_QuickBait = "rbxassetid://101102332625782",
	Icon_Flask_BigTip = "rbxassetid://117105100466018",
	Icon_Flask_GoldRush = "rbxassetid://75986108239288",
	-- #3462: the Day Cart's three top potions (upload run 43189985202, 11-12)
	Icon_Flask_BigLucky = "rbxassetid://131006600838633",
	Icon_Flask_BigGoldRush = "rbxassetid://96835314776488",
	Icon_Flask_MegaTip = "rbxassetid://122723059581411",
	-- #1191 / #1186: the shop-only cats on their Store cards (upload run from main dee66576, 11-05)
	Icon_ShopCat_Sprinkles = "rbxassetid://111524784628537",
	Icon_ShopCat_DuchessMarzipan = "rbxassetid://115820297355843",
	Icon_ShopCat_KingCroissant = "rbxassetid://100720497654876",
	-- #950: the order bubbles' dishes, one per Catalog.menu model (Model-Agent #1101; upload run 41885238133, 11-04)
	Icon_Menu_Coffee = "rbxassetid://106215918587482",
	Icon_Menu_Milk = "rbxassetid://116135336951429",
	Icon_Menu_CakeSlice = "rbxassetid://124602951765371",
	Icon_Menu_PawCookie = "rbxassetid://132564442579365",
	Icon_Menu_Tea = "rbxassetid://140702037877822",
	Icon_Menu_FishBiscuit = "rbxassetid://135209087549936",
	Icon_Menu_KittyCupcake = "rbxassetid://105423706570074",
	Icon_Menu_HotCocoa = "rbxassetid://85713607228134",
	Icon_Menu_PancakeStack = "rbxassetid://82211436638659",
	Icon_Menu_Sundae = "rbxassetid://130689026766849",
	Icon_Menu_StrawberryRoll = "rbxassetid://139269731321730",
	Icon_Menu_RainbowCake = "rbxassetid://110794568072678",
	-- the Decor window's "Your cafe" slots (#964, upload-image run 41728803377 on 11-03)
	Icon_Clean_Wallpaper = "rbxassetid://82127824623670",
	Icon_Clean_Floor = "rbxassetid://100618134290369",
	Icon_Clean_Paint = "rbxassetid://92775201804283",
	Icon_Clean_Spots = "rbxassetid://85929419709001",
	Icon_Clean_Door = "rbxassetid://113159676338557",
	Icon_Clean_Catflap = "rbxassetid://119017572601877",
	-- #1136: the last glyphs that drew the old icon sheet (upload-image run 41889328270, 11-04)
	Icon_Clean_EquipBest = "rbxassetid://83467145782605",
	Icon_Clean_Invite = "rbxassetid://95257960737705",
	Icon_Clean_Lock = "rbxassetid://126676730576646",
	Icon_Clean_Clover = "rbxassetid://106109471292317", -- #1258: the luck clover (upload-image run 41904365295, 11-04)
	-- Tools-Agent's uploads of 11-05: the Fish Market's tabs and the Night Market bubble (#1607)
	Icon_Market_Crates = "rbxassetid://128217805544577",
	Icon_Market_Treats = "rbxassetid://116114044663145",
	Icon_Market_FreshCatch = "rbxassetid://77230621253557",
	Icon_Hud_NightMarket = "rbxassetid://98840630712996",
	-- the Store's sidebar tabs (#1674; Tools-Agent's upload run 42123273598, 11-05), by ShopIcons.storeTab
	Icon_StoreTab_Featured = "rbxassetid://137984752078851",
	Icon_StoreTab_Passes = "rbxassetid://121927064629507",
	Icon_StoreTab_Cats = "rbxassetid://136977692053739",
	Icon_StoreTab_Potions = "rbxassetid://110723659646530",
	Icon_StoreTab_Codes = "rbxassetid://126780860250721",
	Icon_StoreTab_Packs = "rbxassetid://125330764207763", -- #4026: the Winter Pack's icon
	-- the Store's card pictures, one per pass and product, by ShopIcons.store (#1762: the redrawn set, Tools-Agent 11-06;
	-- #2578: eight passes redrawn on clear backgrounds, upload run 42665652455, 11-09)
	-- #4026: the outfit packs' pass icons (512) and their 2:1 store art, cats close up in the pack (Model-Agent, 21:00
	-- UTC 2026-11-13, moderation passed)
	Icon_Store_PackStylish = "rbxassetid://108944643960006",
	Icon_Store_PackWinter = "rbxassetid://125330764207763",
	Icon_Store_PackChef = "rbxassetid://112087743532356",
	Icon_Store_PackSpace = "rbxassetid://108635017155209",
	Icon_Store_PackStylishArt = "rbxassetid://104257781959891",
	Icon_Store_PackWinterArt = "rbxassetid://124937928622829",
	Icon_Store_PackChefArt = "rbxassetid://114389016087315",
	Icon_Store_PackSpaceArt = "rbxassetid://130035950104996",
	Icon_Store_Money2x = "rbxassetid://106785644491188",
	Icon_Store_Money3x = "rbxassetid://124737817716796",
	Icon_Store_Money4x = "rbxassetid://103246165862005",
	Icon_Store_LongNap = "rbxassetid://127782122363076",
	Icon_Store_Vip = "rbxassetid://117039645402383",
	Icon_Store_Accessories = "rbxassetid://88912170837240",
	Icon_Store_Uniforms = "rbxassetid://72659576530521",
	Icon_Store_CafeStyle = "rbxassetid://119738111561829",
	Icon_Store_GrandTheme = "rbxassetid://86722907813381",
	Icon_Store_ExtraSlot = "rbxassetid://84395142080154",
	Icon_Store_RoyalCat = "rbxassetid://90935079354327",
	Icon_Store_KingPack = "rbxassetid://93204952454452",
	Icon_Store_GoldenPond = "rbxassetid://89558912583122",
	Icon_Store_SecondBowl = "rbxassetid://135271113321879",
	Icon_Store_StarterBundle = "rbxassetid://95362407964835",
	Icon_Store_PotionXS = "rbxassetid://97739871449916",
	Icon_Store_PotionS = "rbxassetid://101008485240894",
	Icon_Store_PotionM = "rbxassetid://86072236805576",
	Icon_Store_PotionL = "rbxassetid://71645537832257",
	Icon_Store_CafePass = "rbxassetid://73605076279409",
	-- #1168 cards (Tools-Agent 11-06; store-icon-asset-ids-2026-11-06.md)
	Icon_Store_SteadyPaw = "rbxassetid://101350837995186",
	Icon_Store_ThankYou = "rbxassetid://106632179958380",
	Icon_Store_SignStylePack = "rbxassetid://83129638022589",
	Icon_Store_GardenDecor = "rbxassetid://112628648933098",
	-- #2592 (Derek2: "these place holders in pass need fixes"): each uniform style's apron and cap, and the chat tags'
	-- speech bubbles, for the Cafe Pass tiles and the Style tab (Tools-Agent upload 2026-11-09, run 42556000980)
	Icon_Uniform_Striped = "rbxassetid://132599001543313",
	Icon_Uniform_Midnight = "rbxassetid://136919244269123",
	Icon_Uniform_Mint = "rbxassetid://121459226786912",
	Icon_Uniform_Pumpkin = "rbxassetid://124822185603420",
	Icon_Uniform_AcornBrown = "rbxassetid://75111557282973",
	Icon_Uniform_ForestGreen = "rbxassetid://88600068079230",
	Icon_Uniform_Cranberry = "rbxassetid://93417568952255",
	Icon_Tag_Maple = "rbxassetid://100120088018935",
	Icon_Tag_GrandOpener = "rbxassetid://92801665571397",
}

-- #2592: Looks.UNIFORMS id -> its picture's key, and ChatTags.TAGS id -> its bubble's
local UNIFORM_ART: { [string]: string } = {
	striped = "Icon_Uniform_Striped",
	midnight = "Icon_Uniform_Midnight",
	mint = "Icon_Uniform_Mint",
	uniform_pumpkin = "Icon_Uniform_Pumpkin",
	uniform_acorn_brown = "Icon_Uniform_AcornBrown",
	uniform_forest_green = "Icon_Uniform_ForestGreen",
	uniform_cranberry = "Icon_Uniform_Cranberry",
}
local TAG_ART: { [string]: string } = {
	tag_maple = "Icon_Tag_Maple",
	tag_grand_opener = "Icon_Tag_GrandOpener",
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

-- #1665 (Derek2 11-05, the 8-slice wheel everywhere): pictures whose 3D render (Icon_Hud_<Name>) wins over the clean
-- symbol once it is here; the clean one stays as its backup.
local HUD_FIRST: { [string]: boolean } = { Spin = true }

local function preferClean(name: string): string?
	local hud = if HUD_FIRST[name] then IDS["Icon_Hud_" .. name] else nil
	if hud then
		return hud
	end
	local clean = CLEAN_FOR[name]
	return (if clean then IDS["Icon_Clean_" .. clean] else nil) or IDS[name]
end

function ShopIcons.image(name: string): string?
	return preferClean(name)
end

-- #2592: a uniform style's picture (its apron and cap), nil for Classic or a style without one.
function ShopIcons.uniform(id: string): string?
	local key = UNIFORM_ART[id]
	return if key then IDS[key] else nil
end

-- #2592: a chat tag's speech bubble picture, nil for a tag without one.
function ShopIcons.tag(id: string): string?
	local key = TAG_ART[id]
	return if key then IDS[key] else nil
end

function ShopIcons.clean(name: string): string?
	return IDS["Icon_Clean_" .. name]
end

-- A HUD tile's picture (#1185): the 3D-rendered button picture when there is one, else the clean symbol. Named as the
-- clean symbols are (Home is My Cafe, Potion the Potions tile, Bowl the Bait tile).
local HUD_FOR: { [string]: string } = { Home = "MyCafe", Potion = "Potions", Bowl = "Bait" }
-- #1965: HUD tiles drawn with another picture of ours; the Pass tile wears the Cafe Pass medal from its Store card.
local HUD_PICTURE: { [string]: string } = { Pass = "Icon_Store_CafePass" }
function ShopIcons.hud(name: string): string?
	local picture = HUD_PICTURE[name]
	if picture then
		return IDS[picture]
	end
	return IDS["Icon_Hud_" .. (HUD_FOR[name] or name)] or IDS["Icon_Clean_" .. name]
end

-- #1665: each HUD picture's clean symbol, drawn in its place if the picture fails to load (IconArt.setImage). The
-- HUD names that differ from the clean ones are HUD_FOR's, the other way round.
local CLEAN_OF_HUD: { [string]: string } = { MyCafe = "Home", Potions = "Potion", Bait = "Bowl" }
-- #2453 (Derek2 11-08: "change the bag symbol to be a backpack since its a potion right now"): the Bag's backpack has
-- no clean symbol to fall back to (Icon_Clean_Bag is the gold money bag), so a failed load leaves the tile's 🎒
local NO_BACKUP: { [string]: boolean } = { Bag = true }
local BACKUP: { [string]: string } = {}
for key, id in IDS do
	local name = key:match("^Icon_Hud_(.+)$")
	local clean = if name and not NO_BACKUP[name]
		then IDS["Icon_Clean_" .. (CLEAN_OF_HUD[name] or name)]
		else nil
	if clean and clean ~= id then
		BACKUP[id] = clean
	end
end
-- #2866 (Derek2: "the bag image ... is using old images or potion placeholder"): the redrawn Bag (#2836) was uploaded
-- under a user, not the Creampuff Games group that owns the game, so it does not load there; until the group's copy
-- is in, a failed load falls back to the group's earlier backpack (#2453) instead of the window's potion glyph
BACKUP[IDS.Icon_Hud_Bag] = "rbxassetid://88244676943674"

-- #2500 (Derek2: "lots of store images when first opening store take a second to load and show old default images"):
-- every picture the Store can show (its cards, tabs, shop-only cats, potion flasks and the clean symbols behind
-- them), for Screens/Store to fetch in the background before it is first opened.
local STORE_PREFIXES = { "Icon_Store", "Icon_ShopCat", "Icon_Flask", "Icon_Clean_", "Potion" }
function ShopIcons.storeImages(): { string }
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	for key, id in IDS do
		for _, prefix in STORE_PREFIXES do
			if string.sub(key, 1, #prefix) == prefix and not seen[id] then
				seen[id] = true
				table.insert(list, id)
				break
			end
		end
	end
	table.sort(list)
	return list
end

function ShopIcons.backup(image: string?): string?
	return if type(image) == "string" then BACKUP[image] else nil
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
	return (Catalog :: any).areaArt(area), golden ~= nil -- #4070: Crate_WaterPark
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

-- Every bottle a potion has, best first (#1256): Model-Agent's flask (#1204), the clean flask in the potion's colour
-- (#1070), the older bottle. IconArt.setImages draws the first that loads, so a flask not yet shared with the game
-- falls back to the next bottle instead of the emoji. A Small or Big size runs its regular potion's timer, so it wears
-- that potion's bottles (corner-shop-v2.md, #1250).
local POTION_STAND_INS: { [string]: string } = {
	big_lucky_potion = "lucky_potion",
	big_gold_rush_potion = "gold_rush_potion",
	mega_tip_potion = "big_tip_potion",
}

function ShopIcons.potionAll(potionId: string?): { string }
	local list: { string } = {}
	if type(potionId) ~= "string" then
		return list
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
	-- #3462: a Tier 6 potion wears its smaller kind's bottles after its own flask, so it still has a picture if the
	-- flask does not load
	local standIn = POTION_STAND_INS[potionId]
	if standIn ~= nil then
		for _, id in ShopIcons.potionAll(standIn) do
			if not table.find(list, id) then
				table.insert(list, id)
			end
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
	-- #1822: the King Cat alone shows the pack's King Cat picture until it has a render of its own
	if key == "kingCat" then
		return IDS.Icon_Store_KingPack
	end
	return IDS["Icon_Store_" .. key:sub(1, 1):upper() .. key:sub(2)]
end

-- A Fish Market tab's picture: "Crates", "Treats" or "FreshCatch".
function ShopIcons.market(tab: string): string?
	return IDS["Icon_Market_" .. tab]
end

-- A Store sidebar tab's picture by its StoreLogic.TABS id (#1674): "featured", "passes", "cats", "potions" and "codes"
-- have their own; the Cafe Pass tab uses its Store card's medal. Nil for any other tab (its emoji stays).
-- #4026: an outfit pack's 2:1 store art (cats close up in the pack), by its Row key ("packWinter")
function ShopIcons.packArt(key: string): string?
	return IDS["Icon_Store_" .. key:sub(1, 1):upper() .. key:sub(2) .. "Art"]
end

function ShopIcons.storeTab(id: string): string?
	if id == "cafePass" then
		return IDS.Icon_Store_CafePass
	end
	return IDS["Icon_StoreTab_" .. id:sub(1, 1):upper() .. id:sub(2)]
end

-- A menu dish's picture for the order bubbles (#950), by its Catalog.menu id: the dish model's own render, or nil.
function ShopIcons.menu(orderId: string?): string?
	local item = if type(orderId) == "string" then Catalog.getMenuItem(orderId) else nil
	local model = if item then (item :: any).model else nil
	return if type(model) == "string" then IDS["Icon_Menu_" .. model] else nil
end

-- #1616: each cat food size has its own glyph, the same in the Bag, the Day Cart and prize chips, until the foods
-- have drawn pictures (they are XP treats, not bait, so they don't borrow the bait foods' bowls)
local SNACK_GLYPHS: { [string]: string } = {
	small_cat_snack = "🦐",
	cat_snack = "🍪",
	big_cat_snack = "🧁",
	cat_feast = "🍱",
}
ShopIcons.SNACK_GLYPH = "🍪" -- a cat food with no glyph of its own

function ShopIcons.snackGlyph(foodId: string?): string
	return (if type(foodId) == "string" then SNACK_GLYPHS[foodId] else nil) or ShopIcons.SNACK_GLYPH
end

-- Cat food's uploaded picture (#1181): the clean star treat, now only for a food without its own glyph (#1616)
function ShopIcons.catFood(foodId: string?): string?
	if type(foodId) ~= "string" or SNACK_GLYPHS[foodId] ~= nil then
		return nil
	end
	return IDS.Icon_Clean_StarTreat
end

-- #3462: the Day Cart's own baits have their own pictures now; the dealer's two best stay as the fallback key
local FOOD_STAND_INS: { [string]: string } =
	{ honey_cream = "moon_milk", comet_treat = "star_treat" }

function ShopIcons.food(lureId: string?): string?
	if type(lureId) ~= "string" then
		return nil
	end
	return IDS["Icon_Clean_" .. pascal(lureId)]
		or (
			if FOOD_STAND_INS[lureId]
				then IDS["Icon_Clean_" .. pascal(FOOD_STAND_INS[lureId])]
				else nil
		)
end

-- The clean picture for a money, golden fish or spin prize (#1242, the Tip Jar, Daily Treat, quest and Index prize
-- chips): the money bag, the golden fish coin and the wheel; nil for any other kind.
local PRIZE_FOR: { [string]: string } = { coins = "Bag", fish = "Fish", spins = "Spin" }
function ShopIcons.prize(kind: string?): string?
	local name = if type(kind) == "string" then PRIZE_FOR[kind] else nil
	-- the 8-slice wheel for spins once it is uploaded (#1665), else the clean picture. Only HUD_FIRST names take their
	-- 3D render: the coins' "Bag" is the gold money bag, not the HUD Bag tile's backpack (#2453)
	if name == nil then
		return nil
	end
	return (if HUD_FIRST[name] then IDS["Icon_Hud_" .. name] else nil) or IDS["Icon_Clean_" .. name]
end

-- A decor piece's clean picture by its catalog id (#1072, Components/DecorPictures), or nil for an unknown id.
function ShopIcons.decor(decorId: string?): string?
	return if type(decorId) == "string" then DecorPictures[decorId] else nil
end

function ShopIcons.net(level: number?): string?
	local owned = if type(level) == "number" and level == level then math.floor(level) else 0
	return IDS["Net_L" .. math.clamp(owned + 2, 1, NETS)] -- level n holds Net_L(n + 1) and offers the next
end

-- #2836 (Derek2 11-09: "make sure all our buttons/icons are high quality"): the drawn pictures Model-Agent made for
-- the icons that were still emoji (PR #2837). An id still in moderation draws blank, so the emoji shows until then.
-- #3137: the clean redraws first, each with its #2836 picture as the backup
local UPGRADE_ART: { [string]: string } = {
	tables = "Icon_Clean_Tables",
	espresso = "Icon_Clean_Espresso",
	lure_bowl = "Icon_Clean_LureBowl",
	lucky_cat = "Icon_Clean_LuckyCat",
}
local UPGRADE_OLD: { [string]: string } = {
	tables = "Icon_Hud_Tables",
	espresso = "Icon_Hud_Espresso",
	lure_bowl = "Icon_Hud_Bait",
	lucky_cat = "Icon_Hud_LuckyCat",
}
-- #2836 pass 2: a Settings row's picture by setting key; the cat income row draws the coin and the tutorial row the
-- HUD's Tutorial tile
local SETTING_ART: { [string]: string } = {
	music = "Icon_Hud_SetMusic",
	musicVolume = "Icon_Hud_SetMusicVolume",
	sfx = "Icon_Hud_SetSound",
	sfxVolume = "Icon_Hud_SetSoundVolume",
	screenShake = "Icon_Hud_SetShake",
	lowPerformance = "Icon_Hud_SetGraphics",
	showOtherCats = "Icon_Hud_SetOtherCats",
	markers = "Icon_Hud_SetMapIcons",
	shopAlerts = "Icon_Hud_SetAlerts",
	sessionRecap = "Icon_Hud_SetRecap",
	autoEquip = "Icon_Hud_SetAutoEquip",
	catIncome = "Coins",
	tutorialButton = "Icon_Hud_Tutorial",
}
local ROLE_ART: { [string]: string } = {
	barista = "Icon_Clean_Barista",
	waiter = "Icon_Clean_Waiter",
	greeter = "Icon_Clean_Greeter",
	entertainer = "Icon_Clean_Entertainer",
}
local ROLE_OLD: { [string]: string } = {
	barista = "Icon_Hud_RoleBarista",
	waiter = "Icon_Hud_RoleWaiter",
	greeter = "Icon_Hud_RoleGreeter",
	entertainer = "Icon_Hud_RoleEntertainer",
}
-- #3137: a clean redraw that fails to load (or waits in moderation) falls back to the #2836 picture it replaced
for _, pair in { { UPGRADE_ART, UPGRADE_OLD }, { ROLE_ART, ROLE_OLD } } do
	for key, name in pair[1] do
		local new, old = IDS[name], IDS[pair[2][key]]
		if new and old then
			BACKUP[new] = old
		end
	end
end

-- A glyph IconArt.set draws as a drawn picture wherever it shows (the Drop buttons' ⬇️, Settings' 🎬 Replay row, the
-- Mythical tag prize's 🏷️ and the 🍽️ of a food with no picture of its own), or nil. Glyphs that also mean other
-- things (☕ is the barista and the espresso machine) are drawn by their callers instead (upgrade, role).
local GLYPH_ART: { [string]: string } = {
	["⬇️"] = "Drop",
	["🎬"] = "Replay",
	["🏷️"] = "Tag",
	["🍽️"] = "Plate",
}
function ShopIcons.glyph(glyph: string?): string?
	local name = if type(glyph) == "string" then GLYPH_ART[glyph] else nil
	return if name then IDS["Icon_Hud_" .. name] else nil
end

-- An Upgrades row's picture by upgrade id (the Net row has its own, ShopIcons.net), or nil.
function ShopIcons.upgrade(id: string?): string?
	local name = if type(id) == "string" then UPGRADE_ART[id] else nil
	return if name then IDS[name] else nil
end

-- A staff role's picture (barista, waiter, greeter, entertainer), or nil.
function ShopIcons.role(role: string?): string?
	local name = if type(role) == "string" then ROLE_ART[role] else nil
	return if name then IDS[name] else nil
end

-- A Settings row's picture by its setting key (#2836 pass 2), or nil for a row that keeps its glyph.
function ShopIcons.setting(key: string?): string?
	local name = if type(key) == "string" then SETTING_ART[key] else nil
	return if name then IDS[name] else nil
end

return ShopIcons
