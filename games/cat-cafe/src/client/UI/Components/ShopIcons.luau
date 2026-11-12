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
	Crate_Alley = "rbxassetid://118147349586878",
	Crate_Alley_Gold = "rbxassetid://132731396817052",
	Crate_Park = "rbxassetid://101095772309543",
	Crate_Park_Gold = "rbxassetid://91088824824991",
	Crate_Neighbourhood = "rbxassetid://92817214486463",
	Crate_Neighbourhood_Gold = "rbxassetid://128520140100676",
	Crate_Woods = "rbxassetid://129576196167321",
	Crate_Woods_Gold = "rbxassetid://92790512876175",
	Crate_Sewer = "rbxassetid://114716437470272",
	Crate_Sewer_Gold = "rbxassetid://126554679284620",
	-- Tier 6/7 (Model-Agent #2677, upload-image run 42585003460); dormant until the opening adds the crates
	Crate_Desert = "rbxassetid://113188441612780",
	Crate_Desert_Gold = "rbxassetid://75758913767954",
	Crate_Ruins = "rbxassetid://130303593286077",
	Crate_Ruins_Gold = "rbxassetid://89879105168160",
	Crate_Classic = "rbxassetid://81784091360384",
	Crate_Classic_Gold = "rbxassetid://116503754623416",
	Crate_Rally = "rbxassetid://82686246354257", -- F101 Rally Crate (Model-Agent #766), banked only and no golden twin
	-- F97 sections 3 and 4: the seven foods, the treats and perks redrawn and the prize pictures (Model-Agent #690,
	-- uploaded by Tools-Agent 2026-11-02)
	Kibble = "rbxassetid://121225021616932",
	Tuna = "rbxassetid://87478361053625",
	Sardines = "rbxassetid://107275778149741",
	Salmon = "rbxassetid://129783857409099",
	Caviar = "rbxassetid://129013688724246",
	MoonMilk = "rbxassetid://113810533125769",
	StarTreat = "rbxassetid://98456303045539",
	Perk_GoldenEspresso = "rbxassetid://82998610743733",
	Perk_BigBowl = "rbxassetid://102328473529046",
	Perk_ExtraDecorSpot = "rbxassetid://80180214035870",
	-- #3330 (Derek 2026-11-12: "ok"): Swift Paws' own picture, the running cat
	-- (assets/cat-cafe/exports/icons/CatCafe_Icon_Perk_SwiftPaws.png); it was the paw cookie dish as a stand-in
	Perk_SwiftPaws = "rbxassetid://79732833265075",
	-- #3298: the Lucky Charm's own picture, the clover charm with a gold paw coin
	-- (assets/cat-cafe/exports/icons/CatCafe_Icon_Perk_LuckyCharm.png, upload run 43189985202); it was the luck clover
	Perk_LuckyCharm = "rbxassetid://137010775246897",
	Coins = "rbxassetid://136732540501959",
	Spin = "rbxassetid://137218266791913", -- the 8-slice wheel (#1603, Tools-Agent 11-05); was 109715715479737
	-- the redesigned nets (#989, Model-Agent; rendered and uploaded by Tools-Agent 2026-11-03, PR #1012)
	Net_L1 = "rbxassetid://99316727357448", -- Basic
	Net_L2 = "rbxassetid://134909350394500", -- Sturdy
	Net_L3 = "rbxassetid://77963365598179", -- Pro
	Net_L4 = "rbxassetid://84787270752939", -- Master
	Potion_Tip = "rbxassetid://71156048685457",
	Potion_Lucky = "rbxassetid://127283192762466",
	Potion_Swift = "rbxassetid://87123601243534",
	Potion_Steady = "rbxassetid://108955761710279",
	Potion_BigTip = "rbxassetid://93787186698096", -- the Big Money jug (Model-Agent #700, uploaded 2026-11-02)
	Potion_GoldRush = "rbxassetid://126243258953579",
	Potion_QuickBait = "rbxassetid://134792809441547",
	-- the HUD's Decor pill: a cat-eared armchair and a potted plant (Model-Agent, Set 5 Q10; uploaded 2026-11-02)
	Icon_Decor = "rbxassetid://88901788469222",
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
	Icon_Clean_Spin = "rbxassetid://92256242473029",
	Icon_Clean_Kibble = "rbxassetid://73553280032864", -- its own bowl of kibble (run 41851955780, 11-04)
	-- #1176: Model-Agent's HUD button pictures (#1185; upload run 41891138375, 11-04), the HUD's tiles prefer them
	Icon_Hud_Store = "rbxassetid://77204455675221",
	Icon_Hud_Cats = "rbxassetid://97097188877122",
	Icon_Hud_Index = "rbxassetid://82285471270885",
	Icon_Hud_Quests = "rbxassetid://97659350053374",
	Icon_Hud_Upgrades = "rbxassetid://128316759336656",
	Icon_Hud_Decor = "rbxassetid://80492341106168",
	Icon_Hud_Rewards = "rbxassetid://105161245613543",
	Icon_Hud_Tutorial = "rbxassetid://93888683657240",
	Icon_Hud_Feedback = "rbxassetid://137424185196920",
	Icon_Hud_Menu = "rbxassetid://113965263311042",
	Icon_Hud_MyCafe = "rbxassetid://122844759326775",
	Icon_Hud_Cannon = "rbxassetid://101405634472030",
	Icon_Hud_Areas = "rbxassetid://111104265458192",
	Icon_Hud_Potions = "rbxassetid://128266096924783",
	Icon_Hud_Bait = "rbxassetid://118400972292559",
	-- #2836: the Bag tile's backpack, redrawn (Model-Agent); was 88244676943674 (#2453). #2866: these #2836 pictures
	-- are the group-owned uploads (run 42714863021): the first ones (run 42688251868) were owned by a user, not the
	-- Creampuff Games group that owns the experience, so they never loaded in game
	Icon_Hud_Bag = "rbxassetid://96046816170155",
	-- #2836 (Derek2 11-09: "make sure all our buttons/icons are high quality"): the icons that were still emoji, drawn
	-- by Model-Agent (PR #2837, group upload run 42714863021): window badges, Mystery Market items, Upgrades rows, staff roles
	-- and the glyphs of ShopIcons.glyph
	Icon_Hud_MysteryMarket = "rbxassetid://128397134889785",
	Icon_Hud_Codes = "rbxassetid://90572843028192",
	Icon_Hud_Collector = "rbxassetid://113368124154344",
	Icon_Hud_CornerShop = "rbxassetid://108333779650464",
	Icon_Hud_LawnStall = "rbxassetid://98418962223467",
	Icon_Hud_RankUp = "rbxassetid://127214291195682",
	Icon_Hud_Bellhop = "rbxassetid://97210946668732",
	Icon_Hud_YardSale = "rbxassetid://88120131351409",
	Icon_Hud_BigBackpack = "rbxassetid://131490615321312",
	Icon_Hud_LongNet = "rbxassetid://130482158389482",
	Icon_Hud_Tables = "rbxassetid://81935605293259",
	Icon_Hud_Espresso = "rbxassetid://79788347112327",
	Icon_Hud_LuckyCat = "rbxassetid://105000043321459",
	Icon_Hud_RoleBarista = "rbxassetid://80403532411028",
	Icon_Hud_RoleWaiter = "rbxassetid://136846403223735",
	Icon_Hud_RoleGreeter = "rbxassetid://113660188682260",
	Icon_Hud_RoleEntertainer = "rbxassetid://122759156405446",
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
	Icon_Hud_SetMusic = "rbxassetid://73874755116021",
	Icon_Hud_SetMusicVolume = "rbxassetid://105488499187015",
	Icon_Hud_SetSound = "rbxassetid://121444904115039",
	Icon_Hud_SetSoundVolume = "rbxassetid://75716081933440",
	Icon_Hud_SetShake = "rbxassetid://112459776492103",
	Icon_Hud_SetGraphics = "rbxassetid://101020067002517",
	Icon_Hud_SetOtherCats = "rbxassetid://103722542206840",
	Icon_Hud_SetMapIcons = "rbxassetid://129607991876280",
	Icon_Hud_SetAlerts = "rbxassetid://70517244790381",
	Icon_Hud_SetRecap = "rbxassetid://80422313296946",
	Icon_Hud_SetAutoEquip = "rbxassetid://76312765072688",
	Icon_Hud_Drop = "rbxassetid://125743788740482",
	Icon_Hud_Replay = "rbxassetid://71017921859211",
	Icon_Hud_Tag = "rbxassetid://132164260519001",
	Icon_Hud_Plate = "rbxassetid://138660554143642",
	-- #1665: the 8-slice Spin wheel (#1603's render; upload run 42119348490, 11-05), every spin picture prefers it
	Icon_Hud_Spin = "rbxassetid://137218266791913",
	-- #1204: Model-Agent's potion flasks (#1193), ShopIcons.potion prefers them; re-uploaded 11-05 with the Cat Whistles
	Icon_Flask_Tip = "rbxassetid://119761482103232",
	Icon_Flask_Lucky = "rbxassetid://71905546163410",
	Icon_Flask_Swift = "rbxassetid://125878060323149",
	Icon_Flask_Steady = "rbxassetid://115717683361509",
	Icon_Flask_QuickBait = "rbxassetid://125904802830743",
	Icon_Flask_BigTip = "rbxassetid://134020459369552",
	Icon_Flask_GoldRush = "rbxassetid://111453568394621",
	-- #1191 / #1186: the shop-only cats on their Store cards (upload run from main dee66576, 11-05)
	Icon_ShopCat_Sprinkles = "rbxassetid://132934776901111",
	Icon_ShopCat_DuchessMarzipan = "rbxassetid://120092810809619",
	Icon_ShopCat_KingCroissant = "rbxassetid://97923289789222",
	-- #950: the order bubbles' dishes, one per Catalog.menu model (Model-Agent #1101; upload run 41885238133, 11-04)
	Icon_Menu_Coffee = "rbxassetid://125460054012555",
	Icon_Menu_Milk = "rbxassetid://72641810895454",
	Icon_Menu_CakeSlice = "rbxassetid://113748237219444",
	Icon_Menu_PawCookie = "rbxassetid://99959252804941",
	Icon_Menu_Tea = "rbxassetid://130287445866202",
	Icon_Menu_FishBiscuit = "rbxassetid://134696295564908",
	Icon_Menu_KittyCupcake = "rbxassetid://108497305922541",
	Icon_Menu_HotCocoa = "rbxassetid://104195355228946",
	Icon_Menu_PancakeStack = "rbxassetid://76434618664065",
	Icon_Menu_Sundae = "rbxassetid://121110664035796",
	Icon_Menu_StrawberryRoll = "rbxassetid://136083620718199",
	Icon_Menu_RainbowCake = "rbxassetid://124138968942476",
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
	Icon_Market_Crates = "rbxassetid://86512063079182",
	Icon_Market_Treats = "rbxassetid://86498761565767",
	Icon_Market_FreshCatch = "rbxassetid://74465916818248",
	Icon_Hud_NightMarket = "rbxassetid://73145081487107",
	-- the Store's sidebar tabs (#1674; Tools-Agent's upload run 42123273598, 11-05), by ShopIcons.storeTab
	Icon_StoreTab_Featured = "rbxassetid://137967213846475",
	Icon_StoreTab_Passes = "rbxassetid://138534778728309",
	Icon_StoreTab_Cats = "rbxassetid://110429227735134",
	Icon_StoreTab_Potions = "rbxassetid://108107558597243",
	Icon_StoreTab_Codes = "rbxassetid://96392852887729",
	-- the Store's card pictures, one per pass and product, by ShopIcons.store (#1762: the redrawn set, Tools-Agent 11-06;
	-- #2578: eight passes redrawn on clear backgrounds, upload run 42665652455, 11-09)
	Icon_Store_Money2x = "rbxassetid://82155674128354",
	Icon_Store_Money3x = "rbxassetid://97377712325581",
	Icon_Store_Money4x = "rbxassetid://120063755686083",
	Icon_Store_LongNap = "rbxassetid://136378395182949",
	Icon_Store_Vip = "rbxassetid://109916448622519",
	Icon_Store_Accessories = "rbxassetid://136336138442757",
	Icon_Store_Uniforms = "rbxassetid://99066678778963",
	Icon_Store_CafeStyle = "rbxassetid://89762000752230",
	Icon_Store_GrandTheme = "rbxassetid://103774365148160",
	Icon_Store_ExtraSlot = "rbxassetid://75936392036642",
	Icon_Store_RoyalCat = "rbxassetid://96961392510216",
	Icon_Store_KingPack = "rbxassetid://103094049281221",
	Icon_Store_GoldenPond = "rbxassetid://110272347269933",
	Icon_Store_SecondBowl = "rbxassetid://102367339294167",
	Icon_Store_StarterBundle = "rbxassetid://83823033546025",
	Icon_Store_PotionXS = "rbxassetid://71370653826352",
	Icon_Store_PotionS = "rbxassetid://131227419238833",
	Icon_Store_PotionM = "rbxassetid://106789127093559",
	Icon_Store_PotionL = "rbxassetid://92155513144309",
	Icon_Store_CafePass = "rbxassetid://79367870405446",
	-- #1168 cards (Tools-Agent 11-06; store-icon-asset-ids-2026-11-06.md)
	Icon_Store_SteadyPaw = "rbxassetid://124844091674201",
	Icon_Store_ThankYou = "rbxassetid://124763763193731",
	Icon_Store_SignStylePack = "rbxassetid://111176293548634",
	Icon_Store_GardenDecor = "rbxassetid://76001339098213",
	-- #2592 (Derek2: "these place holders in pass need fixes"): each uniform style's apron and cap, and the chat tags'
	-- speech bubbles, for the Cafe Pass tiles and the Style tab (Tools-Agent upload 2026-11-09, run 42556000980)
	Icon_Uniform_Striped = "rbxassetid://127804747085841",
	Icon_Uniform_Midnight = "rbxassetid://119683626403907",
	Icon_Uniform_Mint = "rbxassetid://72120020405949",
	Icon_Uniform_Pumpkin = "rbxassetid://119763026239046",
	Icon_Uniform_AcornBrown = "rbxassetid://94802328915220",
	Icon_Uniform_ForestGreen = "rbxassetid://139125716682352",
	Icon_Uniform_Cranberry = "rbxassetid://91660701696915",
	Icon_Tag_Maple = "rbxassetid://124452576665708",
	Icon_Tag_GrandOpener = "rbxassetid://84485042386479",
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
	-- #3462: a Tier 6 potion wears its smaller kind's bottles after its own, so it has a picture before its flask is
	-- uploaded
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

-- #3462: the Day Cart's own baits borrow the dealer's two best pictures until theirs are drawn
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
