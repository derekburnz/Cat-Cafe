# Store set icons at 256 x 256: key to id (#3792)

Every key in ShopIcons.storeImages() (113). 39 were still 512 and got a new 256 upload on 2026-11-13 (upload-image.yml run 43364534064, group owned, branch claude/icons-256). 12 come from the shop256 batch (run 43360820097). The other 62 (Icon_Clean_*) were drawn and uploaded at 256 already, so their id stays.

Change: 51 ids. Keep: 62.

| Key | Old id | New id | Note |
|---|---|---|---|
| Icon_Clean_Areas | 88534680940711 | 88534680940711 | already 256, keep |
| Icon_Clean_Bag | 122240410730197 | 122240410730197 | already 256, keep |
| Icon_Clean_Barista | 88726552754770 | 88726552754770 | already 256, keep |
| Icon_Clean_Bowl | 103532889738881 | 103532889738881 | already 256, keep |
| Icon_Clean_Cannon | 136623310503178 | 136623310503178 | already 256, keep |
| Icon_Clean_Catflap | 119017572601877 | 119017572601877 | already 256, keep |
| Icon_Clean_Cats | 98525501130510 | 98525501130510 | already 256, keep |
| Icon_Clean_Caviar | 75650997072096 | 75650997072096 | already 256, keep |
| Icon_Clean_Clover | 106109471292317 | 106109471292317 | already 256, keep |
| Icon_Clean_Coin | 85581311877137 | 85581311877137 | already 256, keep |
| Icon_Clean_CometTreat | 80411294789891 | 130150324251209 | new 256 upload (store256/CatCafe_Icon_CometTreat.png) |
| Icon_Clean_Crate | 81784091360384 | 81784091360384 | already 256, keep |
| Icon_Clean_Decor | 91027671376875 | 91027671376875 | already 256, keep |
| Icon_Clean_Desert | 105252509632683 | 105252509632683 | already 256, keep |
| Icon_Clean_Door | 113159676338557 | 113159676338557 | already 256, keep |
| Icon_Clean_Entertainer | 79258683838050 | 79258683838050 | already 256, keep |
| Icon_Clean_EquipBest | 83467145782605 | 83467145782605 | already 256, keep |
| Icon_Clean_Espresso | 75462239871153 | 75462239871153 | already 256, keep |
| Icon_Clean_Feedback | 86899710660019 | 86899710660019 | already 256, keep |
| Icon_Clean_Fish | 101061912700342 | 101061912700342 | already 256, keep |
| Icon_Clean_Floor | 100618134290369 | 100618134290369 | already 256, keep |
| Icon_Clean_Greeter | 107746555479783 | 107746555479783 | already 256, keep |
| Icon_Clean_Home | 72142107975309 | 72142107975309 | already 256, keep |
| Icon_Clean_HoneyCream | 123524050779950 | 101594576071338 | new 256 upload (store256/CatCafe_Icon_HoneyCream.png) |
| Icon_Clean_Invite | 95257960737705 | 95257960737705 | already 256, keep |
| Icon_Clean_Kibble | 73553280032864 | 73553280032864 | already 256, keep |
| Icon_Clean_Lock | 126676730576646 | 126676730576646 | already 256, keep |
| Icon_Clean_LuckyCat | 130158950733679 | 130158950733679 | already 256, keep |
| Icon_Clean_LureBowl | 125008235885167 | 125008235885167 | already 256, keep |
| Icon_Clean_Menu | 139128379842736 | 139128379842736 | already 256, keep |
| Icon_Clean_Moon | 113770680051546 | 113770680051546 | already 256, keep |
| Icon_Clean_MoonMilk | 109614940712323 | 109614940712323 | already 256, keep |
| Icon_Clean_Neighbourhood | 81559978948079 | 81559978948079 | already 256, keep |
| Icon_Clean_Net | 107635112477250 | 107635112477250 | already 256, keep |
| Icon_Clean_Paint | 92775201804283 | 92775201804283 | already 256, keep |
| Icon_Clean_Park | 130402303377210 | 130402303377210 | already 256, keep |
| Icon_Clean_Potion | 78951217322160 | 78951217322160 | already 256, keep |
| Icon_Clean_PotionBigTip | 111286476050307 | 111286476050307 | already 256, keep |
| Icon_Clean_PotionGoldRush | 134577238271535 | 134577238271535 | already 256, keep |
| Icon_Clean_PotionLucky | 110403070747780 | 110403070747780 | already 256, keep |
| Icon_Clean_PotionQuickBait | 117064600223329 | 117064600223329 | already 256, keep |
| Icon_Clean_PotionSteady | 98428729313169 | 98428729313169 | already 256, keep |
| Icon_Clean_PotionSwift | 89283276917014 | 89283276917014 | already 256, keep |
| Icon_Clean_PotionTip | 95886862906328 | 95886862906328 | already 256, keep |
| Icon_Clean_Quests | 117962329343232 | 117962329343232 | already 256, keep |
| Icon_Clean_Rewards | 105337391774119 | 105337391774119 | already 256, keep |
| Icon_Clean_Ruins | 117006304300316 | 117006304300316 | already 256, keep |
| Icon_Clean_Salmon | 118506839858835 | 118506839858835 | already 256, keep |
| Icon_Clean_Sardines | 77462554026769 | 77462554026769 | already 256, keep |
| Icon_Clean_Sewer | 73407312338999 | 73407312338999 | already 256, keep |
| Icon_Clean_Spin | 92256242473029 | 92256242473029 | already 256, keep |
| Icon_Clean_Spots | 85929419709001 | 85929419709001 | already 256, keep |
| Icon_Clean_StarTreat | 109199304319470 | 109199304319470 | already 256, keep |
| Icon_Clean_Store | 111734554524173 | 111734554524173 | already 256, keep |
| Icon_Clean_Tables | 78752964799899 | 78752964799899 | already 256, keep |
| Icon_Clean_Town | 84240054469741 | 84240054469741 | already 256, keep |
| Icon_Clean_Trade | 83738164568639 | 83738164568639 | already 256, keep |
| Icon_Clean_Tuna | 82422020475314 | 82422020475314 | already 256, keep |
| Icon_Clean_Tutorial | 83538572417569 | 83538572417569 | already 256, keep |
| Icon_Clean_Unlock | 96025123745905 | 96025123745905 | already 256, keep |
| Icon_Clean_Upgrades | 138549739967320 | 138549739967320 | already 256, keep |
| Icon_Clean_Waiter | 122492899176267 | 122492899176267 | already 256, keep |
| Icon_Clean_Wallpaper | 82127824623670 | 82127824623670 | already 256, keep |
| Icon_Clean_Woods | 88100194069700 | 88100194069700 | already 256, keep |
| Icon_Flask_BigGoldRush | 83653025631059 | 96835314776488 | new 256 upload (store256/CatCafe_Icon_PotionFlask_BigGoldRush.png) |
| Icon_Flask_BigLucky | 134852143844550 | 131006600838633 | new 256 upload (store256/CatCafe_Icon_PotionFlask_BigLucky.png) |
| Icon_Flask_BigTip | 134020459369552 | 117105100466018 | new 256 upload (store256/CatCafe_Icon_PotionFlask_BigTip.png) |
| Icon_Flask_GoldRush | 111453568394621 | 75986108239288 | new 256 upload (store256/CatCafe_Icon_PotionFlask_GoldRush.png) |
| Icon_Flask_Lucky | 71905546163410 | 82829893290049 | new 256 upload (store256/CatCafe_Icon_PotionFlask_Lucky.png) |
| Icon_Flask_MegaTip | 116956200423881 | 122723059581411 | new 256 upload (store256/CatCafe_Icon_PotionFlask_MegaTip.png) |
| Icon_Flask_QuickBait | 125904802830743 | 101102332625782 | new 256 upload (store256/CatCafe_Icon_PotionFlask_QuickBait.png) |
| Icon_Flask_Steady | 115717683361509 | 113221296833434 | new 256 upload (store256/CatCafe_Icon_PotionFlask_Steady.png) |
| Icon_Flask_Swift | 125878060323149 | 90536678125794 | new 256 upload (store256/CatCafe_Icon_PotionFlask_Swift.png) |
| Icon_Flask_Tip | 119761482103232 | 74973644801326 | new 256 upload (store256/CatCafe_Icon_PotionFlask_Tip.png) |
| Icon_ShopCat_DuchessMarzipan | 120092810809619 | 115820297355843 | new 256 upload (store256/CatCafe_Icon_Cat_DuchessMarzipan.png) |
| Icon_ShopCat_KingCroissant | 97923289789222 | 100720497654876 | new 256 upload (store256/CatCafe_Icon_Cat_KingCroissant.png) |
| Icon_ShopCat_Sprinkles | 132934776901111 | 111524784628537 | new 256 upload (store256/CatCafe_Icon_Cat_Sprinkles.png) |
| Icon_StoreTab_Cats | 110429227735134 | 136977692053739 | from the shop256 batch |
| Icon_StoreTab_Codes | 96392852887729 | 126780860250721 | from the shop256 batch |
| Icon_StoreTab_Featured | 137967213846475 | 137984752078851 | from the shop256 batch |
| Icon_StoreTab_Passes | 138534778728309 | 121927064629507 | from the shop256 batch |
| Icon_StoreTab_Potions | 108107558597243 | 110723659646530 | from the shop256 batch |
| Icon_Store_Accessories | 136336138442757 | 88912170837240 | new 256 upload (store256/CatCafe_Icon_Pass_Accessories.png) |
| Icon_Store_CafePass | 79367870405446 | 73605076279409 | new 256 upload (store256/CatCafe_Icon_Product_CafePass.png) |
| Icon_Store_CafeStyle | 89762000752230 | 119738111561829 | new 256 upload (store256/CatCafe_Icon_Pass_CafeStyle.png) |
| Icon_Store_ExtraSlot | 75936392036642 | 84395142080154 | new 256 upload (store256/CatCafe_Icon_Pass_ExtraSlot.png) |
| Icon_Store_GardenDecor | 76001339098213 | 112628648933098 | new 256 upload (store256/CatCafe_Icon_Pass_GardenDecorPack.png) |
| Icon_Store_GoldenPond | 110272347269933 | 89558912583122 | new 256 upload (store256/CatCafe_Icon_Pass_GoldenPond.png) |
| Icon_Store_GrandTheme | 103774365148160 | 86722907813381 | new 256 upload (store256/CatCafe_Icon_Pass_GrandTheme.png) |
| Icon_Store_KingPack | 103094049281221 | 93204952454452 | new 256 upload (store256/CatCafe_Icon_Pass_KingPack.png) |
| Icon_Store_LongNap | 136378395182949 | 127782122363076 | new 256 upload (store256/CatCafe_Icon_Pass_LongNap.png) |
| Icon_Store_Money2x | 82155674128354 | 106785644491188 | new 256 upload (store256/CatCafe_Icon_Pass_Money2x.png) |
| Icon_Store_Money3x | 97377712325581 | 124737817716796 | new 256 upload (store256/CatCafe_Icon_Pass_Money3x.png) |
| Icon_Store_Money4x | 120063755686083 | 103246165862005 | new 256 upload (store256/CatCafe_Icon_Pass_Money4x.png) |
| Icon_Store_PotionL | 92155513144309 | 71645537832257 | new 256 upload (store256/CatCafe_Icon_Product_PotionL.png) |
| Icon_Store_PotionM | 106789127093559 | 86072236805576 | new 256 upload (store256/CatCafe_Icon_Product_PotionM.png) |
| Icon_Store_PotionS | 131227419238833 | 101008485240894 | new 256 upload (store256/CatCafe_Icon_Product_PotionS.png) |
| Icon_Store_PotionXS | 71370653826352 | 97739871449916 | new 256 upload (store256/CatCafe_Icon_Product_PotionXS.png) |
| Icon_Store_RoyalCat | 96961392510216 | 90935079354327 | new 256 upload (store256/CatCafe_Icon_Pass_RoyalCat.png) |
| Icon_Store_SecondBowl | 102367339294167 | 135271113321879 | new 256 upload (store256/CatCafe_Icon_Pass_SecondBaitBowl.png) |
| Icon_Store_SignStylePack | 111176293548634 | 83129638022589 | new 256 upload (store256/CatCafe_Icon_Pass_SignStylePack.png) |
| Icon_Store_StarterBundle | 83823033546025 | 95362407964835 | new 256 upload (store256/CatCafe_Icon_Product_StarterBundle.png) |
| Icon_Store_SteadyPaw | 124844091674201 | 101350837995186 | new 256 upload (store256/CatCafe_Icon_Product_SteadyPawPack.png) |
| Icon_Store_ThankYou | 124763763193731 | 106632179958380 | new 256 upload (store256/CatCafe_Icon_Product_ThankYouBadge.png) |
| Icon_Store_Uniforms | 99066678778963 | 72659576530521 | new 256 upload (store256/CatCafe_Icon_Pass_Uniforms.png) |
| Icon_Store_Vip | 109916448622519 | 117039645402383 | new 256 upload (store256/CatCafe_Icon_Pass_VIP.png) |
| Potion_BigTip | 93787186698096 | 84580069848778 | from the shop256 batch |
| Potion_GoldRush | 126243258953579 | 87524443156600 | from the shop256 batch |
| Potion_Lucky | 127283192762466 | 109956828055851 | from the shop256 batch |
| Potion_QuickBait | 134792809441547 | 103827859918501 | from the shop256 batch |
| Potion_Steady | 108955761710279 | 91408225655158 | from the shop256 batch |
| Potion_Swift | 87123601243534 | 106601094256001 | from the shop256 batch |
| Potion_Tip | 71156048685457 | 78228531662647 | from the shop256 batch |
